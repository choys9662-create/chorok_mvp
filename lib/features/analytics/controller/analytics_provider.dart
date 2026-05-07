import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/isar/isar_reading_session.dart';
import '../../../shared/repositories/book_repository.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

typedef TodSlot = ({String label, String range, int minutes});
typedef SessionEntry = ({
  String title,
  String author,
  String duration,
  String date,
});
typedef FinishedBookEntry = ({
  String title,
  String author,
  String date,
  int pages,
});

class AnalyticsState {
  // ─── Week ────────────────────────────────────────────────────────────────
  final int weekTotalSeconds;
  final int weekReadDays;
  final int weekChoseoCount;
  final int prevWeekTotalSeconds;
  final List<int> weekDailyMinutes; // 7개, 월=0
  final List<TodSlot> weekTimeOfDay;
  final List<SessionEntry> weekSessions;
  final List<IsarChoseo> weekChoseo;
  final int weekFocusScore;
  final int weekMaxSessionMinutes;
  final int weekAvgSessionMinutes;
  final List<double> weekRadar; // [독서시간, 초서수, 집중도, 완독률, 연속성]

  // ─── Month ───────────────────────────────────────────────────────────────
  final int monthTotalSeconds;
  final int monthReadDays;
  final int monthChoseoCount;
  final int prevMonthTotalSeconds;
  final Map<DateTime, int> heatmap;
  final int monthMaxStreak;
  final int monthTotalDays;
  final int monthFocusScore;
  final int monthMaxSessionMinutes;
  final int monthAvgSessionMinutes;

  // ─── Year ────────────────────────────────────────────────────────────────
  final int yearTotalSeconds;
  final int yearReadDays;
  final int yearChoseoCount;
  final List<IsarBook> completedBooks;
  final List<int> yearMonthlyMinutes; // 12개, 1월=0
  final int yearFocusScore;

  // ─── All sessions (전체 목록용) ──────────────────────────────────────────
  final List<SessionEntry> allRecentSessions;

  const AnalyticsState({
    this.weekTotalSeconds = 0,
    this.weekReadDays = 0,
    this.weekChoseoCount = 0,
    this.prevWeekTotalSeconds = 0,
    this.weekDailyMinutes = const [0, 0, 0, 0, 0, 0, 0],
    this.weekTimeOfDay = const [],
    this.weekSessions = const [],
    this.weekChoseo = const [],
    this.weekFocusScore = 0,
    this.weekMaxSessionMinutes = 0,
    this.weekAvgSessionMinutes = 0,
    this.weekRadar = const [0, 0, 0, 0, 0],
    this.monthTotalSeconds = 0,
    this.monthReadDays = 0,
    this.monthChoseoCount = 0,
    this.prevMonthTotalSeconds = 0,
    this.heatmap = const {},
    this.monthMaxStreak = 0,
    this.monthTotalDays = 30,
    this.monthFocusScore = 0,
    this.monthMaxSessionMinutes = 0,
    this.monthAvgSessionMinutes = 0,
    this.yearTotalSeconds = 0,
    this.yearReadDays = 0,
    this.yearChoseoCount = 0,
    this.completedBooks = const [],
    this.yearMonthlyMinutes = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.yearFocusScore = 0,
    this.allRecentSessions = const [],
  });
}

// ─── 내부 헬퍼 ───────────────────────────────────────────────────────────────

int _focusScore(List<IsarReadingSession> sessions) {
  if (sessions.isEmpty) return 0;
  final avg = sessions.fold(0.0, (s, r) => s + r.focusPercent) / sessions.length;
  return avg.round().clamp(0, 100);
}

List<double> _radar({
  required int totalSeconds,
  required int choseoCount,
  required int focusScore,
  required int completedCount,
  required int readDays,
  int periodDays = 7,
}) {
  return [
    (totalSeconds / (periodDays * 3600.0)).clamp(0.0, 1.0),
    (choseoCount / 10.0).clamp(0.0, 1.0),
    focusScore / 100.0,
    (completedCount / 12.0).clamp(0.0, 1.0),
    (readDays / periodDays.toDouble()).clamp(0.0, 1.0),
  ];
}

String _fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분';
  return '$seconds초';
}

String _fmtRelativeDate(DateTime dt) {
  final diff = DateTime.now().difference(dt).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '$diff일 전';
}

List<SessionEntry> _toSessionEntries(List<Map<String, dynamic>> logs) {
  return logs.map((r) {
    final secs = (r['duration_seconds'] as int?) ?? 0;
    final startedAt = DateTime.tryParse(r['started_at'] as String? ?? '') ?? DateTime.now();
    return (
      title: r['book_title'] as String? ?? '알 수 없는 책',
      author: r['book_author'] as String? ?? '',
      duration: _fmtDuration(secs),
      date: _fmtRelativeDate(startedAt),
    );
  }).toList();
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  @override
  Future<AnalyticsState> build() async {
    if (_useMock) return const AnalyticsState();
    final repo = ref.watch(bookRepositoryProvider);
    if (repo == null) return const AnalyticsState();
    return _load(repo);
  }

  Future<AnalyticsState> _load(BookRepository repo) async {

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Week
    final weekday = today.weekday; // 1=월, 7=일
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));

    // Month
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final prevMonthStart = now.month == 1
        ? DateTime(now.year - 1, 12, 1)
        : DateTime(now.year, now.month - 1, 1);
    final monthTotalDays = nextMonthStart.subtract(const Duration(days: 1)).day;

    // Year
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);

    // ─── Parallel queries ─────────────────────────────────────────────────
    final results = await Future.wait([
      repo.getSessionsInRange(weekStart, weekEnd),              // 0
      repo.getSessionsInRange(prevWeekStart, weekStart),        // 1
      repo.getReadingLogsInRange(weekStart, weekEnd),           // 2
      repo.getChoseoInRange(weekStart, weekEnd),                // 3
      repo.getSessionsInRange(monthStart, nextMonthStart),      // 4
      repo.getSessionsInRange(prevMonthStart, monthStart),      // 5
      repo.getChoseoInRange(monthStart, nextMonthStart),        // 6
      repo.getSessionsInRange(yearStart, yearEnd),              // 7
      repo.getChoseoInRange(yearStart, yearEnd),                // 8
      repo.getHeatmapDataForYear(now.year),                     // 9
      repo.getMonthlyMinutesForYear(now.year),                  // 10
      repo.getBooksByStatus(IsarReadingStatus.completed),       // 11
      repo.getAllReadingLogs(),                                  // 12
      repo.getCompletedBooksInRange(weekStart, weekEnd),        // 13
    ]);

    final weekSess = results[0] as List<IsarReadingSession>;
    final prevWeekSess = results[1] as List<IsarReadingSession>;
    final weekLogs = results[2] as List<Map<String, dynamic>>;
    final weekChoseo = results[3] as List<IsarChoseo>;
    final monthSess = results[4] as List<IsarReadingSession>;
    final prevMonthSess = results[5] as List<IsarReadingSession>;
    final monthChoseo = results[6] as List<IsarChoseo>;
    final yearSess = results[7] as List<IsarReadingSession>;
    final yearChoseo = results[8] as List<IsarChoseo>;
    final heatmap = results[9] as Map<DateTime, int>;
    final yearMonthlyMinutes = results[10] as List<int>;
    final completedBooks = results[11] as List<IsarBook>;
    final allLogs = results[12] as List<Map<String, dynamic>>;
    final weekCompletedBooks = results[13] as List<IsarBook>;

    // ─── Week 집계 ────────────────────────────────────────────────────────
    final weekTotal = weekSess.fold(0, (s, r) => s + r.durationSeconds);
    final weekDaySet = <String>{};
    for (final s in weekSess) {
      weekDaySet.add('${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}');
    }
    final weekDailyMin = List<int>.filled(7, 0);
    for (final s in weekSess) {
      weekDailyMin[s.startedAt.weekday - 1] += s.durationSeconds ~/ 60;
    }
    final todSlots = [0, 0, 0, 0]; // 새벽·오전·오후·저녁
    for (final s in weekSess) {
      final h = s.startedAt.hour;
      if (h < 6) {
        todSlots[0] += s.durationSeconds ~/ 60;
      } else if (h < 12) {
        todSlots[1] += s.durationSeconds ~/ 60;
      } else if (h < 18) {
        todSlots[2] += s.durationSeconds ~/ 60;
      } else {
        todSlots[3] += s.durationSeconds ~/ 60;
      }
    }
    final prevWeekTotal = prevWeekSess.fold(0, (s, r) => s + r.durationSeconds);
    final wFocus = _focusScore(weekSess);
    final wMaxSessMin = weekSess.isEmpty
        ? 0
        : weekSess.map((s) => s.durationSeconds).reduce((a, b) => a > b ? a : b) ~/ 60;
    final wAvgSessMin = weekSess.isEmpty ? 0 : weekTotal ~/ weekSess.length ~/ 60;

    // ─── Month 집계 ───────────────────────────────────────────────────────
    final monthTotal = monthSess.fold(0, (s, r) => s + r.durationSeconds);
    final monthDaySet = <String>{};
    for (final s in monthSess) {
      monthDaySet.add('${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}');
    }
    final prevMonthTotal = prevMonthSess.fold(0, (s, r) => s + r.durationSeconds);
    final mFocus = _focusScore(monthSess);
    final mMaxSessMin = monthSess.isEmpty
        ? 0
        : monthSess.map((s) => s.durationSeconds).reduce((a, b) => a > b ? a : b) ~/ 60;
    final mAvgSessMin = monthSess.isEmpty ? 0 : monthTotal ~/ monthSess.length ~/ 60;

    // 월 최장 연속일 (히트맵 기반)
    int maxStreak = 0, curStreak = 0;
    for (int d = 1; d <= monthTotalDays; d++) {
      if (heatmap.containsKey(DateTime(now.year, now.month, d))) {
        curStreak++;
        if (curStreak > maxStreak) maxStreak = curStreak;
      } else {
        curStreak = 0;
      }
    }

    // ─── Year 집계 ────────────────────────────────────────────────────────
    final yearTotal = yearSess.fold(0, (s, r) => s + r.durationSeconds);
    final yearDaySet = <String>{};
    for (final s in yearSess) {
      yearDaySet.add('${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}');
    }
    final yFocus = _focusScore(yearSess);

    // 주간 레이더
    final wRadar = _radar(
      totalSeconds: weekTotal,
      choseoCount: weekChoseo.length,
      focusScore: wFocus,
      completedCount: weekCompletedBooks.length,
      readDays: weekDaySet.length,
      periodDays: 7,
    );

    return AnalyticsState(
      weekTotalSeconds: weekTotal,
      weekReadDays: weekDaySet.length,
      weekChoseoCount: weekChoseo.length,
      prevWeekTotalSeconds: prevWeekTotal,
      weekDailyMinutes: weekDailyMin,
      weekTimeOfDay: [
        (label: '새벽', range: '00–06', minutes: todSlots[0]),
        (label: '오전', range: '06–12', minutes: todSlots[1]),
        (label: '오후', range: '12–18', minutes: todSlots[2]),
        (label: '저녁', range: '18–24', minutes: todSlots[3]),
      ],
      weekSessions: _toSessionEntries(weekLogs),
      weekChoseo: weekChoseo,
      weekFocusScore: wFocus,
      weekMaxSessionMinutes: wMaxSessMin,
      weekAvgSessionMinutes: wAvgSessMin,
      weekRadar: wRadar,
      monthTotalSeconds: monthTotal,
      monthReadDays: monthDaySet.length,
      monthChoseoCount: monthChoseo.length,
      prevMonthTotalSeconds: prevMonthTotal,
      heatmap: heatmap,
      monthMaxStreak: maxStreak,
      monthTotalDays: monthTotalDays,
      monthFocusScore: mFocus,
      monthMaxSessionMinutes: mMaxSessMin,
      monthAvgSessionMinutes: mAvgSessMin,
      yearTotalSeconds: yearTotal,
      yearReadDays: yearDaySet.length,
      yearChoseoCount: yearChoseo.length,
      completedBooks: completedBooks,
      yearMonthlyMinutes: yearMonthlyMinutes,
      yearFocusScore: yFocus,
      allRecentSessions: _toSessionEntries(allLogs.take(20).toList()),
    );
  }

  Future<void> refresh() async {
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _load(repo));
  }
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
  AnalyticsNotifier.new,
);
