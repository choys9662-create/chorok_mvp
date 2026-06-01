import 'dart:async';
import 'dart:convert';
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
                    {'type': 'TEXT_DETECTION', 'maxResults': 1},
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
      final text =
          data['responses']?[0]?['fullTextAnnotation']?['text'] as String?;
      final trimmed = normalizeOcrText(text ?? '');
      if (trimmed.isEmpty) return const OcrNoText();
      return OcrSuccess(trimmed);
    } on TimeoutException {
      return const OcrError('OCR 응답이 지연되고 있어요. 네트워크를 확인한 뒤 다시 시도해 주세요.');
    } catch (e) {
      return OcrError('OCR 처리 중 오류: $e');
    }
  }
}

final ocrServiceProvider = Provider<OcrService>(
  (ref) => CloudVisionOcrService(),
);
