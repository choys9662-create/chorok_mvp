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

abstract class OcrService {
  Future<OcrResult> extractTextFromCamera();
}

class CloudVisionOcrService implements OcrService {
  final _imagePicker = ImagePicker();
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static final _httpClient = http.Client();
  static final _apiKey = dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'] ?? '';

  @override
  Future<OcrResult> extractTextFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return const OcrCancelled();
    if (_apiKey.isEmpty) {
      return const OcrError('OCR API 키가 설정되지 않았어요');
    }

    try {
      final bytes = await photo.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _httpClient.post(
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
      );

      if (response.statusCode != 200) {
        return OcrError('OCR 요청 실패 (${response.statusCode})');
      }

      final data = jsonDecode(response.body);
      final text =
          data['responses']?[0]?['fullTextAnnotation']?['text'] as String?;
      final trimmed = text?.trim() ?? '';
      if (trimmed.isEmpty) return const OcrNoText();
      return OcrSuccess(trimmed);
    } catch (e) {
      return OcrError('OCR 처리 중 오류: $e');
    }
  }
}

final ocrServiceProvider = Provider<OcrService>(
  (ref) => CloudVisionOcrService(),
);
