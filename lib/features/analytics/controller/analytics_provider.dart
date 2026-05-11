import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/isar/isar_reading_session.dart';
import '../../../shared/repositories/book_repository.dart';

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

// ─── 내부 통합 세션 타입 (SQLite·Supabase 공통) ──────────────────────────────
typedef _Sess = ({
  DateTime date,
  int durationSeconds,
  int sentenceCount,
  String bookTitle,
  String bookAuthor,
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

  // ─── 전체 세션 (모달용) ───────────────────────────────────────────────────
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

// ─── 공통 집계 헬퍼 ──────────────────────────────────────────────────────────

int _focusScoreFromIsarSessions(List<IsarReadingSession> sessions) {
  if (sessions.isEmpty) return 0;
  final avg =
      sessions.fold(0.0, (s, r) => s + r.focusPercent) / sessions.length;
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

List<SessionEntry> _sessToEntries(List<_Sess> sessions) {
  return sessions
      .map(
        (s) => (
          title: s.bookTitle.isNotEmpty ? s.bookTitle : '알 수 없는 책',
          author: s.bookAuthor,
          duration: _fmtDuration(s.durationSeconds),
          date: _fmtRelativeDate(s.date),
        ),
      )
      .toList();
}

// ─── 세션 리스트에서 공통 통계 계산 ─────────────────────────────────────────

({
  int totalSeconds,
  int readDays,
  List<int> dailyMinutes,
  List<int> todSlots,
  int maxSessionMinutes,
  int avgSessionMinutes,
  int monthlyMinutes, // minute for single month/year bucket
})
_computeSessStats(List<_Sess> sessions) {
  final daySet = <String>{};
  final daily = List<int>.filled(7, 0);
  final tod = [0, 0, 0, 0];
  int total = 0;
  int maxSess = 0;

  for (final s in sessions) {
    total += s.durationSeconds;
    if (s.durationSeconds > maxSess) maxSess = s.durationSeconds;
    daySet.add('${s.date.year}-${s.date.month}-${s.date.day}');
    daily[s.date.weekday - 1] += s.durationSeconds ~/ 60;
    final h = s.date.hour;
    if (h < 6) {
      tod[0] += s.durationSeconds ~/ 60;
    } else if (h < 12) {
      tod[1] += s.durationSeconds ~/ 60;
    } else if (h < 18) {
      tod[2] += s.durationSeconds ~/ 60;
    } else {
      tod[3] += s.durationSeconds ~/ 60;
    }
  }

  final avg = sessions.isEmpty ? 0 : total ~/ sessions.length ~/ 60;

  return (
    totalSeconds: total,
    readDays: daySet.length,
    dailyMinutes: daily,
    todSlots: tod,
    maxSessionMinutes: maxSess ~/ 60,
    avgSessionMinutes: avg,
    monthlyMinutes: total ~/ 60,
  );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class AnalyticsNotifier extends AsyncNotifier<AnalyticsState> {
  @override
  Future<AnalyticsState> build() async {
    if (kUseMock) return const AnalyticsState();
    return _load();
  }

  Future<AnalyticsState> _load() async {
    if (kIsWeb) {
      return _loadFromSupabase();
    }
    return _loadFromSqlite();
  }

  // ─── SQLite ─────────────────────────────────────────────────────────────

  Future<AnalyticsState> _loadFromSqlite() async {
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return const AnalyticsState();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday;
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final prevMonthStart = now.month == 1
        ? DateTime(now.year - 1, 12, 1)
        : DateTime(now.year, now.month - 1, 1);
    final monthTotalDays = nextMonthStart.subtract(const Duration(days: 1)).day;
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);

    final results = await Future.wait([
      repo.getSessionsInRange(weekStart, weekEnd),
      repo.getSessionsInRange(prevWeekStart, weekStart),
      repo.getReadingLogsInRange(weekStart, weekEnd),
      repo.getChoseoInRange(weekStart, weekEnd),
      repo.getSessionsInRange(monthStart, nextMonthStart),
      repo.getSessionsInRange(prevMonthStart, monthStart),
      repo.getChoseoInRange(monthStart, nextMonthStart),
      repo.getSessionsInRange(yearStart, yearEnd),
      repo.getChoseoInRange(yearStart, yearEnd),
      repo.getHeatmapDataForYear(now.year),
      repo.getMonthlyMinutesForYear(now.year),
      repo.getBooksByStatus(IsarReadingStatus.completed),
      repo.getAllReadingLogs(),
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

    // Week
    final weekTotal = weekSess.fold(0, (s, r) => s + r.durationSeconds);
    final weekDaySet = <String>{};
    for (final s in weekSess) {
      weekDaySet.add(
        '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}',
      );
    }
    final weekDailyMin = List<int>.filled(7, 0);
    for (final s in weekSess) {
      weekDailyMin[s.startedAt.weekday - 1] += s.durationSeconds ~/ 60;
    }
    final todSlots = [0, 0, 0, 0];
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
    final wFocus = _focusScoreFromIsarSessions(weekSess);
    final wMaxSessMin = weekSess.isEmpty
        ? 0
        : weekSess
                  .map((s) => s.durationSeconds)
                  .reduce((a, b) => a > b ? a : b) ~/
              60;
    final wAvgSessMin = weekSess.isEmpty
        ? 0
        : weekTotal ~/ weekSess.length ~/ 60;

    // Month
    final monthTotal = monthSess.fold(0, (s, r) => s + r.durationSeconds);
    final monthDaySet = <String>{};
    for (final s in monthSess) {
      monthDaySet.add(
        '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}',
      );
    }
    final prevMonthTotal = prevMonthSess.fold(
      0,
      (s, r) => s + r.durationSeconds,
    );
    final mFocus = _focusScoreFromIsarSessions(monthSess);
    final mMaxSessMin = monthSess.isEmpty
        ? 0
        : monthSess
                  .map((s) => s.durationSeconds)
                  .reduce((a, b) => a > b ? a : b) ~/
              60;
    final mAvgSessMin = monthSess.isEmpty
        ? 0
        : monthTotal ~/ monthSess.length ~/ 60;

    int maxStreak = 0, curStreak = 0;
    for (int d = 1; d <= monthTotalDays; d++) {
      if (heatmap.containsKey(DateTime(now.year, now.month, d))) {
        curStreak++;
        if (curStreak > maxStreak) maxStreak = curStreak;
      } else {
        curStreak = 0;
      }
    }

    // Year
    final yearTotal = yearSess.fold(0, (s, r) => s + r.durationSeconds);
    final yearDaySet = <String>{};
    for (final s in yearSess) {
      yearDaySet.add(
        '${s.startedAt.year}-${s.startedAt.month}-${s.startedAt.day}',
      );
    }
    final yFocus = _focusScoreFromIsarSessions(yearSess);

    final wRadar = _radar(
      totalSeconds: weekTotal,
      choseoCount: weekChoseo.length,
      focusScore: wFocus,
      completedCount: completedBooks.length,
      readDays: weekDaySet.length,
    );

    final weekSessions = weekLogs.map((r) {
      final secs = (r['duration_seconds'] as int?) ?? 0;
      final startedAt =
          DateTime.tryParse(r['started_at'] as String? ?? '') ?? DateTime.now();
      return (
        title: r['book_title'] as String? ?? '알 수 없는 책',
        author: r['book_author'] as String? ?? '',
        duration: _fmtDuration(secs),
        date: _fmtRelativeDate(startedAt),
      );
    }).toList();

    final allSessions = allLogs.take(20).map((r) {
      final secs = (r['duration_seconds'] as int?) ?? 0;
      final startedAt =
          DateTime.tryParse(r['started_at'] as String? ?? '') ?? DateTime.now();
      return (
        title: r['book_title'] as String? ?? '알 수 없는 책',
        author: r['book_author'] as String? ?? '',
        duration: _fmtDuration(secs),
        date: _fmtRelativeDate(startedAt),
      );
    }).toList();

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
      weekSessions: weekSessions,
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
      allRecentSessions: allSessions,
    );
  }

  // ─── Supabase (웹) ───────────────────────────────────────────────────────

  Future<AnalyticsState> _loadFromSupabase() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const AnalyticsState();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = today.weekday;
    final weekStart = today.subtract(Duration(days: weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prevWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonthStart = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final prevMonthStart = now.month == 1
        ? DateTime(now.year - 1, 12, 1)
        : DateTime(now.year, now.month - 1, 1);
    final monthTotalDays = nextMonthStart.subtract(const Duration(days: 1)).day;
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year + 1, 1, 1);

    // 연 단위로 한 번에 로드 후 메모리에서 필터링 (3개 쿼리 병렬)
    final results = await Future.wait([
      client
          .from('reading_sessions')
          .select(
            'started_at, ended_at, duration_seconds, sentence_count, books(title, author)',
          )
          .eq('user_id', userId)
          .gte('ended_at', yearStart.toIso8601String())
          .lt('ended_at', yearEnd.toIso8601String())
          .order('ended_at', ascending: false),
      client
          .from('sentences')
          .select('created_at, content, books(title, author)')
          .eq('user_id', userId)
          .gte('created_at', yearStart.toIso8601String())
          .lt('created_at', yearEnd.toIso8601String())
          .order('created_at', ascending: false),
      client
          .from('books')
          .select('id, title, author, total_pages, updated_at')
          .eq('user_id', userId)
          .eq('status', 'completed')
          .order('updated_at', ascending: false),
    ]);
    final sessionsRes = results[0];
    final sentencesRes = results[1];
    final completedBooksRes = results[2];

    // Supabase rows → 공통 _Sess 타입으로 변환
    List<_Sess> rowsToSess(List rows) {
      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        final dateStr =
            map['ended_at'] as String? ??
            map['started_at'] as String? ??
            now.toIso8601String();
        final book = map['books'] as Map<String, dynamic>?;
        return (
          date: DateTime.tryParse(dateStr) ?? now,
          durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
          sentenceCount: (map['sentence_count'] as num?)?.toInt() ?? 0,
          bookTitle: book?['title'] as String? ?? '',
          bookAuthor: book?['author'] as String? ?? '',
        );
      }).toList();
    }

    final allSess = rowsToSess(sessionsRes as List);

    bool inRange(DateTime d, DateTime from, DateTime to) =>
        !d.isBefore(from) && d.isBefore(to);

    final weekSess = allSess
        .where((s) => inRange(s.date, weekStart, weekEnd))
        .toList();
    final prevWeekSess = allSess
        .where((s) => inRange(s.date, prevWeekStart, weekStart))
        .toList();
    final monthSess = allSess
        .where((s) => inRange(s.date, monthStart, nextMonthStart))
        .toList();
    final prevMonthSess = allSess
        .where((s) => inRange(s.date, prevMonthStart, monthStart))
        .toList();

    // Sentences (choseo equivalent)
    List<IsarChoseo> rowsToChoseo(List rows) {
      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        final book = map['books'] as Map<String, dynamic>?;
        return IsarChoseo(
          choseoId: map['id'] as String? ?? '',
          bookId: map['book_id'] as String? ?? '',
          bookTitle: book?['title'] as String? ?? '',
          bookAuthor: book?['author'] as String? ?? '',
          content: map['content'] as String? ?? '',
          createdAt:
              DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
        );
      }).toList();
    }

    final allChoseo = rowsToChoseo(sentencesRes as List);
    final weekChoseo = allChoseo
        .where((c) => inRange(c.createdAt, weekStart, weekEnd))
        .toList();
    final monthChoseo = allChoseo
        .where((c) => inRange(c.createdAt, monthStart, nextMonthStart))
        .toList();
    final yearChoseo = allChoseo; // already filtered to year

    // 히트맵 계산
    final heatmap = <DateTime, int>{};
    for (final s in allSess) {
      final day = DateTime(s.date.year, s.date.month, s.date.day);
      heatmap[day] = (heatmap[day] ?? 0) + s.durationSeconds ~/ 60;
    }

    // 월별 분 계산
    final yearMonthlyMinutes = List<int>.filled(12, 0);
    for (final s in allSess) {
      yearMonthlyMinutes[s.date.month - 1] += s.durationSeconds ~/ 60;
    }

    // 완독 책
    final completedBooks = (completedBooksRes as List).map((r) {
      final map = r as Map<String, dynamic>;
      return IsarBook(
        bookId: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        currentPage: 0,
        totalPages: (map['total_pages'] as num?)?.toInt() ?? 0,
        status: IsarReadingStatus.completed,
        createdAt: DateTime.now(),
        updatedAt:
            DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();

    // Week 집계
    final wStats = _computeSessStats(weekSess);
    final prevWeekTotal = prevWeekSess.fold(0, (s, r) => s + r.durationSeconds);
    final wFocus = weekSess.isEmpty
        ? 0
        : (weekSess.fold(0, (s, r) => s + r.sentenceCount) /
                  weekSess.length *
                  10)
              .round()
              .clamp(40, 100);

    // Month 집계
    final mStats = _computeSessStats(monthSess);
    final prevMonthTotal = prevMonthSess.fold(
      0,
      (s, r) => s + r.durationSeconds,
    );

    int maxStreak = 0, curStreak = 0;
    for (int d = 1; d <= monthTotalDays; d++) {
      if (heatmap.containsKey(DateTime(now.year, now.month, d))) {
        curStreak++;
        if (curStreak > maxStreak) maxStreak = curStreak;
      } else {
        curStreak = 0;
      }
    }

    // Year 집계
    final yearTotal = allSess.fold(0, (s, r) => s + r.durationSeconds);
    final yearDaySet = <String>{};
    for (final s in allSess) {
      yearDaySet.add('${s.date.year}-${s.date.month}-${s.date.day}');
    }

    final wRadar = _radar(
      totalSeconds: wStats.totalSeconds,
      choseoCount: weekChoseo.length,
      focusScore: wFocus,
      completedCount: completedBooks.length,
      readDays: wStats.readDays,
    );

    return AnalyticsState(
      weekTotalSeconds: wStats.totalSeconds,
      weekReadDays: wStats.readDays,
      weekChoseoCount: weekChoseo.length,
      prevWeekTotalSeconds: prevWeekTotal,
      weekDailyMinutes: wStats.dailyMinutes,
      weekTimeOfDay: [
        (label: '새벽', range: '00–06', minutes: wStats.todSlots[0]),
        (label: '오전', range: '06–12', minutes: wStats.todSlots[1]),
        (label: '오후', range: '12–18', minutes: wStats.todSlots[2]),
        (label: '저녁', range: '18–24', minutes: wStats.todSlots[3]),
      ],
      weekSessions: _sessToEntries(weekSess),
      weekChoseo: weekChoseo,
      weekFocusScore: wFocus,
      weekMaxSessionMinutes: wStats.maxSessionMinutes,
      weekAvgSessionMinutes: wStats.avgSessionMinutes,
      weekRadar: wRadar,
      monthTotalSeconds: mStats.totalSeconds,
      monthReadDays: mStats.readDays,
      monthChoseoCount: monthChoseo.length,
      prevMonthTotalSeconds: prevMonthTotal,
      heatmap: heatmap,
      monthMaxStreak: maxStreak,
      monthTotalDays: monthTotalDays,
      monthFocusScore: 0,
      monthMaxSessionMinutes: mStats.maxSessionMinutes,
      monthAvgSessionMinutes: mStats.avgSessionMinutes,
      yearTotalSeconds: yearTotal,
      yearReadDays: yearDaySet.length,
      yearChoseoCount: yearChoseo.length,
      completedBooks: completedBooks,
      yearMonthlyMinutes: yearMonthlyMinutes,
      yearFocusScore: 0,
      allRecentSessions: _sessToEntries(allSess.take(20).toList()),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
      AnalyticsNotifier.new,
    );
