import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract class OcrService {
  Future<String?> extractTextFromCamera();
}

class MockOcrService implements OcrService {
  @override
  Future<String?> extractTextFromCamera() async {
    await Future.delayed(const Duration(seconds: 1)); // 처리 시간 시뮬레이션
    return "우리가 빛의 속도로 갈 수 없다면, 우리가 볼 수 있는 세계는 이 우주의 아주 일부분에 불과할 것이다.\n(임시 목업 텍스트)";
  }
}

// class RealOcrService implements OcrService {
//   final _imagePicker = ImagePicker();
//   
//   @override
//   Future<String?> extractTextFromCamera() async {
//     final photo = await _imagePicker.pickImage(
//       source: ImageSource.camera,
//       imageQuality: 85,
//     );
//     if (photo == null) return null;
//     
//     String extractedText = '';
//     final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
//     try {
//       final inputImage = InputImage.fromFilePath(photo.path);
//       final recognized = await recognizer.processImage(inputImage);
//       extractedText = recognized.text.trim();
//     } catch (_) {
//       extractedText = '';
//     } finally {
//       recognizer.close();
//     }
//     return extractedText;
//   }
// }

// TODO: 릴리즈 빌드나 실제 기기 테스트 시 RealOcrService()로 변경
final ocrServiceProvider = Provider<OcrService>((ref) => MockOcrService());
