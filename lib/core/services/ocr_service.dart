import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract class OcrService {
  Future<String?> extractTextFromCamera();
}

class _MockOcrService implements OcrService {
  @override
  Future<String?> extractTextFromCamera() async => null;
}

class RealOcrService implements OcrService {
  final _imagePicker = ImagePicker();

  @override
  Future<String?> extractTextFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return null;

    String extractedText = '';
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final inputImage = InputImage.fromFilePath(photo.path);
      final recognized = await recognizer.processImage(inputImage);
      extractedText = recognized.text.trim();
    } catch (_) {
      extractedText = '';
    } finally {
      recognizer.close();
    }
    return extractedText;
  }
}

final ocrServiceProvider = Provider<OcrService>((ref) {
  if (Platform.isMacOS) return _MockOcrService();
  return RealOcrService();
});
