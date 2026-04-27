import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

abstract class OcrService {
  Future<String?> extractTextFromCamera();
}

class CloudVisionOcrService implements OcrService {
  final _imagePicker = ImagePicker();
  static const _endpoint = 'https://vision.googleapis.com/v1/images:annotate';
  static final _httpClient = http.Client();
  static final _apiKey = dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'] ?? '';

  @override
  Future<String?> extractTextFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return null;
    if (_apiKey.isEmpty) return null;

    try {
      final bytes = await File(photo.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await _httpClient.post(
        Uri.parse('$_endpoint?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'TEXT_DETECTION', 'maxResults': 1}
              ],
              'imageContext': {
                'languageHints': ['ko']
              },
            }
          ]
        }),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final text = data['responses']?[0]?['fullTextAnnotation']?['text'] as String?;
      return text?.trim();
    } catch (_) {
      return null;
    }
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) => CloudVisionOcrService());
