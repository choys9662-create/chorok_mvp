import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
  const OcrSuccess(this.text);
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

/// Vision fullTextAnnotation의 문단 구조를 살려 텍스트를 조립한다.
/// 문단 내부 줄바꿈은 [normalizeOcrText]의 한국어 규칙으로 이어붙이고,
/// 문단 사이에만 줄바꿈을 남긴다. 구조가 없으면 null (호출부에서 평문 폴백).
String? extractParagraphsFromAnnotation(Map<String, dynamic>? annotation) {
  if (annotation == null) return null;
  try {
    final paragraphs = <String>[];
    for (final page in (annotation['pages'] as List? ?? const [])) {
      for (final block
          in ((page as Map<String, dynamic>)['blocks'] as List? ?? const [])) {
        for (final para
            in ((block as Map<String, dynamic>)['paragraphs'] as List? ??
                const [])) {
          final buf = StringBuffer();
          for (final word
              in ((para as Map<String, dynamic>)['words'] as List? ??
                  const [])) {
            for (final symbol
                in ((word as Map<String, dynamic>)['symbols'] as List? ??
                    const [])) {
              final s = symbol as Map<String, dynamic>;
              buf.write(s['text'] ?? '');
              final breakType =
                  (s['property'] as Map<String, dynamic>?)?['detectedBreak']
                      ?['type'] as String?;
              switch (breakType) {
                case 'SPACE' || 'SURE_SPACE':
                  buf.write(' ');
                // 줄 끝 개행은 normalizeOcrText의 한국어 규칙으로 잇는다
                case 'EOL_SURE_SPACE' || 'HYPHEN' || 'LINE_BREAK':
                  buf.write('\n');
              }
            }
          }
          final normalized = normalizeOcrText(buf.toString());
          if (normalized.isNotEmpty) paragraphs.add(normalized);
        }
      }
    }
    if (paragraphs.isEmpty) return null;
    return paragraphs.join('\n');
  } catch (_) {
    return null;
  }
}

abstract class OcrService {
  Future<OcrResult> extractTextFromCamera();
  Future<OcrResult> extractTextFromBytes(List<int> bytes);
}

class CloudVisionOcrService implements OcrService {
  final _imagePicker = ImagePicker();
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static const _imageReadTimeout = Duration(seconds: 12);
  static const _requestTimeout = Duration(seconds: 24);
  static final _httpClient = http.Client();
  static const _apiKeyFromDefine = String.fromEnvironment(
    'GOOGLE_CLOUD_VISION_API_KEY',
  );
  static String get _apiKey => _apiKeyFromDefine.isNotEmpty
      ? _apiKeyFromDefine
      : dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'] ?? '';

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
    if (_apiKey.isEmpty) {
      return const OcrError('OCR API 키가 설정되지 않았어요');
    }

    try {
      final base64Image = base64Encode(bytes);

      final response = await _httpClient
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'requests': [
                {
                  'image': {'content': base64Image},
                  'features': [
                    {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
                  ],
                  'imageContext': {
                    'languageHints': ['ko'],
                  },
                },
              ],
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        final snippet = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        return OcrError(snippet);
      }

      final data = jsonDecode(response.body);
      final annotation =
          data['responses']?[0]?['fullTextAnnotation'] as Map<String, dynamic>?;
      // 문단 구조(pages→blocks→paragraphs)를 우선 사용 — 문단 사이 줄바꿈 유지.
      // 구조 파싱 실패 시 평문(text) 폴백.
      final structured = extractParagraphsFromAnnotation(annotation);
      final trimmed =
          structured ?? normalizeOcrText(annotation?['text'] as String? ?? '');
      if (trimmed.isEmpty) return const OcrNoText();
      return OcrSuccess(trimmed);
    } on TimeoutException {
      return const OcrError('OCR 응답이 지연되고 있어요. 네트워크를 확인한 뒤 다시 시도해 주세요.');
    } catch (e) {
      return OcrError('OCR 처리 중 오류: $e');
    }
  }
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

// 온디바이스(무료) 전환. 유료 폴백이 필요하면 CloudVisionOcrService()로 교체.
final ocrServiceProvider = Provider<OcrService>(
  (ref) => OnDeviceOcrService(),
);
