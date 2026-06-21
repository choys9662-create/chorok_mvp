import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  /// AI가 문장 단위로 끊어 준 경우 채워진다. null이면 호출부에서 규칙 기반으로 분리.
  final List<String>? sentences;

  const OcrSuccess(this.text, {this.sentences});
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
                  (s['property']
                          as Map<String, dynamic>?)?['detectedBreak']?['type']
                      as String?;
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

/// Gemini 멀티모달 문장 분석. 사진에서 본문을 글자 그대로 전사하면서
/// **문장 경계까지 AI가 직접 구분**해 배열로 돌려준다(규칙 정규식보다 한국어
/// 대화문·인용·줄바꿈 처리가 정확). LLM이라 의역/교정 위험이 있어 "글자 그대로
/// 전사, 교정 금지" 프롬프트 + temperature 0으로 비결정성을 최대한 억제한다.
class GeminiOcrService implements OcrService {
  // Inline 요청 전체가 20MB 미만이어야 하므로 base64 팽창(약 4/3)을 고려한다.
  static const maxInlineImageBytes = 14 * 1024 * 1024;

  final ImagePicker _imagePicker;
  final http.Client _httpClient;
  final GeminiOcrConfig config;

  static const _imageReadTimeout = Duration(seconds: 12);

  static const _prompt =
      '이 이미지는 책의 한 페이지야. 본문 텍스트를 문장 단위로 정확히 끊어서 각 문장을 배열의 한 원소로 반환해. '
      '글자 그대로 전사하고 맞춤법·띄어쓰기·문장부호를 절대 교정하거나 바꾸지 마. '
      '대화문과 인용부호("…")를 고려해 자연스러운 문장 경계로 나눠. '
      '페이지 번호·머리말·각주 등 본문 외 요소는 제외해. 본문이 없으면 빈 배열을 반환해.';

  GeminiOcrService({
    GeminiOcrConfig? config,
    ImagePicker? imagePicker,
    http.Client? httpClient,
  }) : config = config ?? GeminiOcrConfig.fromEnvironment(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _httpClient = httpClient ?? http.Client();

  Uri get _generateContentUri => Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/${config.model}:generateContent',
  );

  Map<String, dynamic> _requestBody(List<int> bytes, String mimeType) {
    return {
      'contents': [
        {
          'parts': [
            {'text': _prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(bytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
      },
    };
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
    if (config.apiKey.isEmpty) {
      return const OcrError('Gemini API 키가 설정되지 않았어요');
    }
    if (bytes.isEmpty) return const OcrError('이미지 데이터가 비어 있어요');
    if (bytes.length > maxInlineImageBytes) {
      return const OcrError('이미지가 너무 커요. 크기를 줄인 뒤 다시 시도해 주세요');
    }

    final mimeType = detectImageMimeType(bytes);
    if (mimeType == null) {
      return const OcrError(
        '지원하지 않는 이미지 형식이에요. JPG, PNG, WebP, HEIC를 사용해 주세요.',
      );
    }

    try {
      final response = await _httpClient
          .post(
            _generateContentUri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': config.apiKey,
            },
            body: jsonEncode(_requestBody(bytes, mimeType)),
          )
          .timeout(config.requestTimeout);

      if (response.statusCode != 200) {
        return OcrError(
          geminiApiErrorMessage(
            response.statusCode,
            apiStatus: extractGeminiApiStatus(response.body),
          ),
        );
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return const OcrError('Gemini 응답 형식을 확인할 수 없어요');
      }

      final raw = extractGeminiResponseText(data);
      if (raw == null) {
        final blockReason =
            (data['promptFeedback'] as Map<String, dynamic>?)?['blockReason'];
        return OcrError(
          blockReason == null
              ? 'Gemini가 텍스트를 반환하지 않았어요'
              : '이미지 분석 요청이 안전 정책으로 처리되지 않았어요',
        );
      }

      final sentences = parseGeminiSentenceArray(raw);
      if (sentences == null) {
        return const OcrError('Gemini 문장 응답 형식을 확인할 수 없어요');
      }
      if (sentences.isEmpty) return const OcrNoText();
      return OcrSuccess(sentences.join('\n'), sentences: sentences);
    } on TimeoutException {
      return const OcrError('OCR 응답이 지연되고 있어요. 네트워크를 확인한 뒤 다시 시도해 주세요.');
    } catch (_) {
      return const OcrError('Gemini OCR 처리 중 오류가 발생했어요');
    }
  }
}

typedef GeminiOcrFunctionInvoker =
    Future<dynamic> Function(Map<String, dynamic> body);

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
    if (bytes.length > GeminiOcrService.maxInlineImageBytes) {
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
      final rawSentences = data['sentences'];
      if (rawSentences is! List) {
        return const OcrError('Gemini 프록시가 문장 목록을 반환하지 않았어요');
      }
      final sentences = rawSentences
          .whereType<String>()
          .map((sentence) => sentence.trim())
          .where((sentence) => sentence.isNotEmpty)
          .toList(growable: false);
      if (sentences.isEmpty) return const OcrNoText();
      return OcrSuccess(sentences.join('\n'), sentences: sentences);
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

class GeminiOcrConfig {
  static const defaultModel = 'gemini-2.5-flash';

  final String apiKey;
  final String model;
  final Duration requestTimeout;

  const GeminiOcrConfig({
    required this.apiKey,
    this.model = defaultModel,
    this.requestTimeout = const Duration(seconds: 30),
  });

  factory GeminiOcrConfig.fromEnvironment() {
    const apiKeyFromDefine = String.fromEnvironment('GEMINI_API_KEY');
    const modelFromDefine = String.fromEnvironment('GEMINI_OCR_MODEL');
    final apiKey = apiKeyFromDefine.trim().isNotEmpty
        ? apiKeyFromDefine.trim()
        : (dotenv.env['GEMINI_API_KEY'] ?? '').trim();
    final configuredModel = modelFromDefine.trim().isNotEmpty
        ? modelFromDefine.trim()
        : (dotenv.env['GEMINI_OCR_MODEL'] ?? '').trim();

    return GeminiOcrConfig(
      apiKey: apiKey,
      model: normalizeGeminiModelName(configuredModel),
    );
  }
}

String normalizeGeminiModelName(String model) {
  final normalized = model.trim().replaceFirst(RegExp(r'^models/'), '');
  return normalized.isEmpty ? GeminiOcrConfig.defaultModel : normalized;
}

List<String>? parseGeminiSentenceArray(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! List) return null;
    return decoded
        .whereType<String>()
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return null;
  }
}

String? extractGeminiResponseText(Map<String, dynamic> data) {
  final candidates = data['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final first = candidates.first;
  if (first is! Map<String, dynamic>) return null;
  final content = first['content'];
  if (content is! Map<String, dynamic>) return null;
  final parts = content['parts'];
  if (parts is! List) return null;

  final text = parts
      .whereType<Map>()
      .map((part) => part['text'])
      .whereType<String>()
      .join()
      .trim();
  return text.isEmpty ? null : text;
}

String? extractGeminiApiStatus(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;
    final error = decoded['error'];
    if (error is! Map<String, dynamic>) return null;
    return error['status'] as String?;
  } catch (_) {
    return null;
  }
}

String geminiApiErrorMessage(int statusCode, {String? apiStatus}) {
  switch (apiStatus) {
    case 'UNAUTHENTICATED' || 'PERMISSION_DENIED':
      return 'Gemini API 키 또는 사용 권한을 확인해 주세요';
    case 'RESOURCE_EXHAUSTED':
      return 'Gemini 사용량 한도에 도달했어요. 잠시 후 다시 시도해 주세요';
    case 'NOT_FOUND':
      return '설정된 Gemini 모델을 찾을 수 없어요';
    case 'INVALID_ARGUMENT':
      return 'Gemini 요청 형식이 올바르지 않아요';
  }

  return switch (statusCode) {
    400 => 'Gemini 요청 형식이 올바르지 않아요',
    401 || 403 => 'Gemini API 키 또는 사용 권한을 확인해 주세요',
    404 => '설정된 Gemini 모델을 찾을 수 없어요',
    429 => 'Gemini 사용량 한도에 도달했어요. 잠시 후 다시 시도해 주세요',
    >= 500 => 'Gemini 서버가 일시적으로 응답하지 않아요',
    _ => 'Gemini 요청을 처리하지 못했어요',
  };
}

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

// Gemini 멀티모달 OCR 사용. 온디바이스(무료)로 되돌리려면 OnDeviceOcrService(),
// 결정론적 OCR이 필요하면 CloudVisionOcrService()로 교체.
final ocrServiceProvider = Provider<OcrService>((ref) {
  return SupabaseGeminiOcrService.fromClient(Supabase.instance.client);
});
