/// 세션 집중도·점수 산출 로직 (순수 함수 — UI 비의존).
///
/// 집중도는 앱 이탈 시간 대비 실제 독서 시간 비율로 계산하고,
/// 점수는 시간·문장 기본점수에 집중도 계수를 곱해 종합한다.
library;

/// 집중도 (0~100). 이탈 시간이 없으면 100%.
double sessionFocusPercent({
  required int readSeconds,
  required int exitDurationSeconds,
}) {
  final total = readSeconds + exitDurationSeconds;
  if (total <= 0) return 100.0;
  return (readSeconds / total * 100).clamp(0.0, 100.0);
}

/// 세션 점수: 시간 + 문장 수 기본점수에 집중도 계수(0.6~1.0)를 곱한다.
/// 집중도가 0%여도 점수가 폭락하지 않도록 하한 계수를 둔다.
int sessionScore({
  required int seconds,
  required int sentenceCount,
  required double focusPercent,
}) {
  final timePts = (seconds / 90).clamp(0.0, 40.0).toInt();
  final sentPts = (sentenceCount * 3).clamp(0, 15);
  final base = (45 + timePts + sentPts).clamp(0, 100);
  final focusFactor = 0.6 + 0.4 * (focusPercent.clamp(0.0, 100.0) / 100);
  return (base * focusFactor).round().clamp(0, 100);
}

/// 점수·집중도 기반 평가 문구.
String sessionEvalText(int score, int sentenceCount, double focusPercent) {
  if (focusPercent < 70) {
    return '읽는 동안 잠깐씩 폰을 들여다봤어요.\n다음엔 폰을 내려놓고 더 깊이 빠져봐요.';
  }
  if (score >= 90) return '오늘은 정말 깊이 있는 독서를 했어요.\n최고의 집중력을 보여줬어요!';
  if (score >= 75) return '훌륭한 독서 세션이었어요.\n꾸준히 이 페이스를 유지해봐요.';
  if (score >= 60) {
    if (sentenceCount > 0) return '좋은 독서였어요. 수집한 문장들이\n피드에 올라갔어요!';
    return '좋은 시작이에요. 다음엔 문장도\n한 번 수집해봐요!';
  }
  return '짧지만 의미 있는 독서였어요.\n오늘도 잘 했어요.';
}
