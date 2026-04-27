import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

abstract class SttService {
  Future<bool> initialize();
  Future<void> listen({
    required void Function(String text) onResult,
    required Duration listenFor,
  });
  Future<void> stop();
}

class RealSttService implements SttService {
  final _stt = SpeechToText();

  @override
  Future<bool> initialize() async {
    return await _stt.initialize();
  }

  @override
  Future<void> listen({
    required void Function(String text) onResult,
    required Duration listenFor,
  }) async {
    await _stt.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenFor: listenFor,
      localeId: 'ko_KR',
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  @override
  Future<void> stop() async {
    await _stt.stop();
  }
}

class MockSttService implements SttService {
  bool _isListening = false;

  final List<List<String>> _mockPhrases = [
    [
      '우리가 빛의 ',
      '우리가 빛의 속도로 갈 수 없다면, ',
      '우리가 빛의 속도로 갈 수 없다면, 우리가 볼 수 있는 세계는 (목업)',
    ],
    ['사랑을 잃고 ', '사랑을 잃고 나는 쓰네, ', '사랑을 잃고 나는 쓰네, 잘 있거라, 짧았던 밤들아 (목업)'],
    ['모든 사람은 ', '모든 사람은 태어날 때부터 ', '모든 사람은 태어날 때부터 자유롭고 존엄하며 평등하다 (목업)'],
    ['가장 개인적인 것이 ', '가장 개인적인 것이 가장 창의적인 ', '가장 개인적인 것이 가장 창의적인 것이다 (목업)'],
  ];

  @override
  Future<bool> initialize() async {
    return true; // 시뮬레이터 항상 성공
  }

  @override
  Future<void> listen({
    required void Function(String text) onResult,
    required Duration listenFor,
  }) async {
    _isListening = true;
    final random = Random();
    final phraseSteps = _mockPhrases[random.nextInt(_mockPhrases.length)];

    for (int i = 0; i < phraseSteps.length; i++) {
      await Future.delayed(Duration(milliseconds: i == 0 ? 500 : 1000));
      if (!_isListening) break;
      onResult(phraseSteps[i]);
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
  }
}

final sttServiceProvider = Provider<SttService>((ref) => RealSttService());
