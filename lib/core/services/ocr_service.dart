import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

sealed class OcrResult {
  const OcrResult();
}

class OcrCancelled extends OcrResult {
  const OcrCancelled();
}

class OcrNoText extends OcrResult {
  const OcrNoText();
}

class OcrError extends OcrResult {
  final String message;
  const OcrError(this.message);
}

class OcrSuccess extends OcrResult {
  final String text;

  /// AI가 문단→문장 구조로 끊어 준 경우 채워진다(각 원소가 한 문단의 문장 목록).
  /// null이면 호출부에서 규칙 기반으로 분리.
  final List<List<String>>? paragraphs;

  const OcrSuccess(this.text, {this.paragraphs});
}

String normalizeOcrText(String text) {
  final lineBreak = RegExp(r'([^\s])[\t ]*\r?\n[\t ]*([^\s])');
  final spacing = RegExp(r'[ \t]+');

  return text
      .replaceAllMapped(lineBreak, (match) {
        final left = match.group(1)!;
        final right = match.group(2)!;
        if (_shouldKeepLineBreakSpace(left, right)) {
          return '$left $right';
        }
        return '$left$right';
      })
      .replaceAll(spacing, ' ')
      .trim();
}

bool _shouldKeepLineBreakSpace(String left, String right) {
  if (RegExp(r'[.!?。！？…,:;，、)\]」』”’]$').hasMatch(left)) {
    return true;
  }
  return !_isKoreanSyllable(left.runes.last) ||
      !_isKoreanSyllable(right.runes.first);
}

bool _isKoreanSyllable(int codeUnit) =>
    codeUnit >= 0xAC00 && codeUnit <= 0xD7A3;

abstract class OcrService {
  Future<OcrResult> extractTextFromCamera();
  Future<OcrResult> extractTextFromBytes(List<int> bytes);
}

/// Apple Vision(iOS) 온디바이스 OCR. 무료·오프라인·네트워크 호출 없음.
/// 네이티브 인식은 `ios/Runner/AppDelegate.swift`의 `chorok/ocr` MethodChannel.
/// Android는 추후 같은 인터페이스로 ML Kit 분기를 추가한다.
class OnDeviceOcrService implements OcrService {
  final _imagePicker = ImagePicker();
  static const _channel = MethodChannel('chorok/ocr');
  static const _imageReadTimeout = Duration(seconds: 12);

  @override
  Future<OcrResult> extractTextFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return const OcrCancelled();
    final bytes = await photo.readAsBytes().timeout(_imageReadTimeout);
    return extractTextFromBytes(bytes);
  }

  @override
  Future<OcrResult> extractTextFromBytes(List<int> bytes) async {
    try {
      final raw = await _channel.invokeMethod<String>('recognizeText', {
        'bytes': Uint8List.fromList(bytes),
      });
      final trimmed = normalizeOcrText(raw ?? '');
      if (trimmed.isEmpty) return const OcrNoText();
      return OcrSuccess(trimmed);
    } on PlatformException catch (e) {
      return OcrError('OCR 처리 중 오류: ${e.message ?? e.code}');
    } catch (e) {
      return OcrError('OCR 처리 중 오류: $e');
    }
  }
}

typedef GeminiOcrFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);

// Edge Function input is base64 encoded, so keep its payload below 20MB.
const _maxInlineImageBytes = 14 * 1024 * 1024;

class SupabaseGeminiOcrService implements OcrService {
  final ImagePicker _imagePicker;
  final GeminiOcrFunctionInvoker _invoke;

  static const _imageReadTimeout = Duration(seconds: 12);

  SupabaseGeminiOcrService({
    required GeminiOcrFunctionInvoker invoke,
    ImagePicker? imagePicker,
  }) : _invoke = invoke,
       _imagePicker = imagePicker ?? ImagePicker();

  factory SupabaseGeminiOcrService.fromClient(SupabaseClient client) {
    return SupabaseGeminiOcrService(
      invoke: (body) async {
        final response = await client.functions.invoke(
          'gemini-ocr',
          body: body,
        );
        return response.data;
      },
    );
  }

  @override
  Future<OcrResult> extractTextFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return const OcrCancelled();
    final bytes = await photo.readAsBytes().timeout(_imageReadTimeout);
    return extractTextFromBytes(bytes);
  }

  @override
  Future<OcrResult> extractTextFromBytes(List<int> bytes) async {
    if (bytes.isEmpty) return const OcrError('이미지 데이터가 비어 있어요');
    if (bytes.length > _maxInlineImageBytes) {
      return const OcrError('이미지가 너무 커요. 크기를 줄인 뒤 다시 시도해 주세요');
    }

    final mimeType = detectImageMimeType(bytes);
    if (mimeType == null) {
      return const OcrError(
        '지원하지 않는 이미지 형식이에요. JPG, PNG, WebP, HEIC, HEIF를 사용해 주세요.',
      );
    }

    try {
      final data = await _invoke({
        'imageBase64': base64Encode(bytes),
        'mimeType': mimeType,
      });
      if (data is! Map) {
        return const OcrError('Gemini 프록시 응답 형식을 확인할 수 없어요');
      }
      final rawParagraphs = data['paragraphs'];
      final rawSentences = data['sentences'];
      final List<List<String>> paragraphs;
      if (rawParagraphs is List) {
        paragraphs = cleanParagraphs(rawParagraphs);
      } else if (rawSentences is List) {
        // 문단 정보가 없는 구버전 함수 응답: 전체를 한 문단으로 취급.
        final flat = cleanSentences(rawSentences);
        paragraphs = flat.isEmpty ? const [] : [flat];
      } else {
        return const OcrError('Gemini 프록시가 문장 목록을 반환하지 않았어요');
      }
      if (paragraphs.isEmpty) return const OcrNoText();
      return OcrSuccess(joinParagraphsText(paragraphs), paragraphs: paragraphs);
    } on FunctionException catch (error) {
      return OcrError(supabaseGeminiErrorMessage(error.status));
    } on TimeoutException {
      return const OcrError('OCR 응답이 지연되고 있어요. 네트워크를 확인한 뒤 다시 시도해 주세요.');
    } catch (_) {
      return const OcrError('Gemini OCR 서버에 연결할 수 없어요');
    }
  }
}

String supabaseGeminiErrorMessage(int statusCode) {
  return switch (statusCode) {
    401 => '로그인 상태를 확인한 뒤 다시 시도해 주세요',
    413 => '이미지가 너무 커요. 크기를 줄인 뒤 다시 시도해 주세요',
    429 => 'Gemini 사용량 한도에 도달했어요. 잠시 후 다시 시도해 주세요',
    >= 500 => 'Gemini OCR 서버가 일시적으로 응답하지 않아요',
    _ => 'Gemini OCR 요청을 처리하지 못했어요',
  };
}

List<String> cleanSentences(List raw) => raw
    .whereType<String>()
    .map((sentence) => sentence.trim())
    .where((sentence) => sentence.isNotEmpty)
    .toList(growable: false);

List<List<String>> cleanParagraphs(List raw) => raw
    .whereType<List>()
    .map(cleanSentences)
    .where((paragraph) => paragraph.isNotEmpty)
    .toList(growable: false);

/// 문단 안은 공백으로, 문단 사이는 줄바꿈으로 잇는다 — 규칙 분리 폴백(_split)의
/// "한 줄 = 한 문단" 관례와 동일한 평문 표현.
String joinParagraphsText(List<List<String>> paragraphs) =>
    paragraphs.map((paragraph) => paragraph.join(' ')).join('\n');

String? detectImageMimeType(List<int> bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp') {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const {'heic', 'heix', 'hevc', 'hevx'}.contains(brand)) {
      return 'image/heic';
    }
    if (const {'mif1', 'msf1'}.contains(brand)) return 'image/heif';
  }
  return null;
}

// Gemini OCR API 키는 Edge Function에만 보관한다.
final ocrServiceProvider = Provider<OcrService>((ref) {
  return SupabaseGeminiOcrService.fromClient(Supabase.instance.client);
});
