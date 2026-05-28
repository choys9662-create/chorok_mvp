import 'package:chorok_app/features/home/screen/session_score.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sessionFocusPercent', () {
    test('이탈이 없으면 100%', () {
      expect(
        sessionFocusPercent(readSeconds: 4860, exitDurationSeconds: 0),
        100.0,
      );
    });

    test('시간이 0이면 100% (분모 0 방지)', () {
      expect(
        sessionFocusPercent(readSeconds: 0, exitDurationSeconds: 0),
        100.0,
      );
    });

    test('이탈 시간 비율만큼 집중도가 낮아진다', () {
      // 900초 독서 + 100초 이탈 → 900/1000 = 90%
      expect(
        sessionFocusPercent(readSeconds: 900, exitDurationSeconds: 100),
        90.0,
      );
    });
  });

  group('sessionScore', () {
    test('이탈 없는 1h21m·0문장 세션은 85점 (회귀 기준)', () {
      // 기본 = 45 + min(4860/90,40)=40 + 0 = 85, 집중도 100% → 계수 1.0
      expect(
        sessionScore(seconds: 4860, sentenceCount: 0, focusPercent: 100.0),
        85,
      );
    });

    test('집중도 70%면 기본점수에 0.88 계수가 적용된다', () {
      // 85 * (0.6 + 0.4*0.7) = 85 * 0.88 = 74.8 → 75
      expect(
        sessionScore(seconds: 4860, sentenceCount: 0, focusPercent: 70.0),
        75,
      );
    });

    test('집중도 0%여도 하한 계수 0.6으로 점수가 폭락하지 않는다', () {
      // 85 * 0.6 = 51
      expect(
        sessionScore(seconds: 4860, sentenceCount: 0, focusPercent: 0.0),
        51,
      );
    });

    test('문장 수집은 기본점수를 최대 15점까지 올린다', () {
      // 45 + 40 + min(6*3,15)=15 = 100, 계수 1.0
      expect(
        sessionScore(seconds: 4860, sentenceCount: 6, focusPercent: 100.0),
        100,
      );
    });
  });

  group('sessionEvalText', () {
    test('집중도 70% 미만이면 폰을 내려놓도록 권한다', () {
      final text = sessionEvalText(80, 0, 69.0);
      expect(text, contains('폰을 내려놓고'));
    });

    test('집중도 70% 이상이면 점수 기반 일반 문구', () {
      final text = sessionEvalText(85, 0, 100.0);
      expect(text, isNot(contains('폰을 내려놓고')));
      expect(text, contains('훌륭한 독서 세션'));
    });
  });
}
