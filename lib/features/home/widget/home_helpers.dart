import '../../../shared/models/reading_session.dart';

const kGoalMessages = [
  '오늘 목표 완료! 멈추라고는 안 했어요',
  '30분 달성! 이 기세 계속 가요',
  '오늘의 독서 완료. 내일도 이 기세로요',
  '훌륭해요. 이게 쌓이면 습관이 돼요',
];

const kStreakSuffix = ['오늘 빠지면 너무 아깝잖아요', '이 기록, 오늘도 이어가요', '여기서 멈추실 건 아니죠?'];

const kSlackMessages = [
  '요즘 바쁘신가봐요?',
  '책이 먼지 쌓이기 시작했어요',
  '독서는 하루 건너뛰면 이틀 잊어요',
  '오늘 딱 5분만요. 딱 5분',
];

const kNudgeMessages = ['오늘 첫 독서를 시작해볼까요?', '딱 10분만 읽어볼까요?', '책이 기다리고 있어요'];

class SessionPromptSeed {
  final String sentence;
  final String thought;
  final int weight;

  const SessionPromptSeed({
    required this.sentence,
    this.thought = '',
    this.weight = 0,
  });
}

int calcReadStreak(int todayIndex, List<int> weeklyMinutes) {
  int streak = 0;
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (weeklyMinutes[i] >= 30) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

int daysSinceLastRead(int todayIndex, List<int> weeklyMinutes) {
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (weeklyMinutes[i] > 0) return todayIndex - i;
  }
  return todayIndex + 1;
}

const List<int> kWeeklyMinutes = [42, 28, 55, 0, 35, 18, 0];

String todayInsightText(int todayMinutes, int exitCount, int goalMinutes) {
  if (todayMinutes <= 0) return '';
  if (todayMinutes >= goalMinutes) {
    if (exitCount == 0) return '한 번도 안 나가셨어요. 완전한 몰입이었어요';
    return '오늘 목표를 달성했어요! 내일도 이 기세로요';
  }

  final remaining = goalMinutes - todayMinutes;
  return '오늘 $remaining분만 더 읽어볼까요?';
}

String dailyHomeMessage({
  required DateTime now,
  required List<int> weeklyMinutes,
  required int todayMinutes,
  required List<Book> books,
}) {
  final readingBooks = books
      .where((book) => book.status == ReadingStatus.reading)
      .toList();
  final nearlyDone = readingBooks.where((book) => book.readingProgress >= 0.85);

  if (todayMinutes > 0) {
    return _dailyPick(now, [
      '한 장만 더 읽어요',
      '오늘 흐름 좋아요',
      '조금만 더 이어가요',
    ], salt: todayMinutes);
  }

  final todayIndex = (now.weekday - 1).clamp(0, 6);
  final streak = weeklyMinutes.length > todayIndex
      ? calcReadStreak(todayIndex, weeklyMinutes)
      : 0;
  if (streak >= 2) {
    return _dailyPick(now, kStreakSuffix, salt: streak);
  }

  final bookToFinish = nearlyDone.isEmpty ? null : nearlyDone.first;
  if (bookToFinish != null) {
    return '완독까지 조금만';
  }

  if (readingBooks.isNotEmpty) {
    return _dailyPick(now, [
      '읽던 책 이어가요',
      '책이 기다리고 있어요',
      '오늘도 같이 읽어요',
    ], salt: readingBooks.length);
  }

  return _dailyPick(now, kNudgeMessages);
}

String sessionEntryPrompt({
  required String bookTitle,
  required int currentPage,
  required int totalPages,
  required DateTime now,
  List<SessionPromptSeed> seeds = const [],
}) {
  final title = bookTitle.trim();
  final progress = totalPages > 0 ? currentPage / totalPages : 0.0;
  final socialPrompt = _socialSessionPrompt(seeds, now);
  if (socialPrompt != null) return socialPrompt;

  if (title.contains('채식주의자')) {
    return _dailyPick(now, [
      '영혜는 왜 채식을 결심했을까요?',
      '이 가족은 무엇을 못 보고 있을까요?',
      '몸은 어디까지 자기 것일까요?',
    ], salt: _stableHash(title));
  }

  if (progress >= 0.85) {
    return _dailyPick(now, [
      '마지막에 어떤 문장이 남을까요?',
      '이 책은 어떤 감정으로 닫힐까요?',
      '끝까지 읽으면 무엇이 달라질까요?',
    ], salt: _stableHash(title) + 85);
  }

  if (progress >= 0.35) {
    return _dailyPick(now, [
      '지금까지 가장 오래 남은 장면은 뭔가요?',
      '이 책은 어디로 향하고 있을까요?',
      '오늘은 어떤 문장을 붙잡게 될까요?',
    ], salt: _stableHash(title) + 35);
  }

  return _dailyPick(now, [
    '이 책은 어떤 질문을 남길까요?',
    '첫 인상과 달라진 점이 있을까요?',
    '오늘 읽을 부분은 어떤 분위기일까요?',
  ], salt: _stableHash(title));
}

String? _socialSessionPrompt(List<SessionPromptSeed> seeds, DateTime now) {
  final useful =
      seeds.where((seed) => seed.sentence.trim().length >= 8).toList()
        ..sort((a, b) => b.weight.compareTo(a.weight));
  if (useful.isEmpty) return null;

  final picked =
      useful[(DateTime(now.year, now.month, now.day).day + useful.first.weight)
              .abs() %
          useful.take(3).length];
  final thought = picked.thought.trim();
  if (thought.isNotEmpty) {
    return '“${_shortPromptText(thought)}” 이 생각은 어디서 시작됐을까요?';
  }
  return '“${_shortPromptText(picked.sentence)}” 왜 이 문장이 남았을까요?';
}

String _shortPromptText(String value) {
  final compact = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (compact.length <= 18) return compact;
  return '${compact.substring(0, 18)}...';
}

String _dailyPick(DateTime now, List<String> messages, {int salt = 0}) {
  final day =
      DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return messages[(day + salt).abs() % messages.length];
}

int _stableHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x3fffffff;
  }
  return hash;
}
