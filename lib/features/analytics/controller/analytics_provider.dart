import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/isar/isar_choseo.dart';

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
typedef SocialSentenceEntry = ({
  String content,
  String bookTitle,
  String bookAuthor,
  int likeCount,
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

  // ─── Week (속도) ─────────────────────────────────────────────────────────
  final int weekAvgPagesPerMin;

  // ─── Month (속도) ────────────────────────────────────────────────────────
  final int monthAvgPagesPerMin;

  // ─── Year ────────────────────────────────────────────────────────────────
  final int yearTotalSeconds;
  final int yearReadDays;
  final int yearChoseoCount;
  final List<IsarBook> completedBooks;
  final List<int> yearMonthlyMinutes; // 12개, 1월=0
  final int yearFocusScore;
  final int yearMaxStreak;
  final int yearMaxSessionMinutes;
  final int yearAvgSessionMinutes;
  final int yearAvgPagesPerMin;
  final Map<String, int> yearGenreDistribution; // 장르 → 완독 권 수
  final List<IsarChoseo> yearTopChoseo; // 올해 수집 문장 (최근 순)

  // ─── 소셜 (좋아요·커뮤니티) ────────────────────────────────────────────────
  final List<SocialSentenceEntry> weekMyReactions;
  final List<SocialSentenceEntry> weekCommunityHighlights;
  final List<SocialSentenceEntry> monthMyReactions;
  final List<SocialSentenceEntry> monthCommunityHighlights;
  final List<SocialSentenceEntry> yearMyReactions;
  final List<SocialSentenceEntry> yearCommunityHighlights;

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
    this.weekAvgPagesPerMin = 0,
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
    this.monthAvgPagesPerMin = 0,
    this.yearTotalSeconds = 0,
    this.yearReadDays = 0,
    this.yearChoseoCount = 0,
    this.completedBooks = const [],
    this.yearMonthlyMinutes = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.yearFocusScore = 0,
    this.yearMaxStreak = 0,
    this.yearMaxSessionMinutes = 0,
    this.yearAvgSessionMinutes = 0,
    this.yearAvgPagesPerMin = 0,
    this.yearGenreDistribution = const {},
    this.yearTopChoseo = const [],
    this.weekMyReactions = const [],
    this.weekCommunityHighlights = const [],
    this.monthMyReactions = const [],
    this.monthCommunityHighlights = const [],
    this.yearMyReactions = const [],
    this.yearCommunityHighlights = const [],
    this.allRecentSessions = const [],
  });
}

// ─── 공통 집계 헬퍼 ──────────────────────────────────────────────────────────

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
    return _loadFromSupabase();
  }

  // ─── Supabase ───────────────────────────────────────────────────────────

  Future<AnalyticsState> _loadFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const AnalyticsState();
    return _analyticsFromSupabase(ref, userId, includeSocial: true);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFromSupabase);
  }
}

/// Supabase에서 특정 사용자의 통계를 계산한다. 내 통계와 다른 사용자(소셜) 통계 공용.
/// includeSocial=false면 "내가 좋아요한 문장" 등 me 전용 소셜 섹션을 비운다.
Future<AnalyticsState> _analyticsFromSupabase(
  Ref ref,
  String userId, {
  required bool includeSocial,
}) async {
  final client = Supabase.instance.client;

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
        .gte('ended_at', yearStart.toUtc().toIso8601String())
        .lt('ended_at', yearEnd.toUtc().toIso8601String())
        .order('ended_at', ascending: false),
    client
        .from('sentences')
        .select('created_at, content, books(title, author)')
        .eq('user_id', userId)
        .gte('created_at', yearStart.toUtc().toIso8601String())
        .lt('created_at', yearEnd.toUtc().toIso8601String())
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
        // timestamptz 는 UTC 로 파싱된다. weekday·hour 를 로컬 기준으로 읽으려면 변환이 필요하다.
        date: (DateTime.tryParse(dateStr) ?? now).toLocal(),
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
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? now,
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
      : (weekSess.fold(0, (s, r) => s + r.sentenceCount) / weekSess.length * 10)
            .round()
            .clamp(40, 100);

  // Month 집계
  final mStats = _computeSessStats(monthSess);
  final prevMonthTotal = prevMonthSess.fold(0, (s, r) => s + r.durationSeconds);
  final mFocus = monthSess.isEmpty
      ? 0
      : (monthSess.fold(0, (s, r) => s + r.sentenceCount) /
                monthSess.length *
                10)
            .round()
            .clamp(40, 100);

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
  final yFocus = allSess.isEmpty
      ? 0
      : (allSess.fold(0, (s, r) => s + r.sentenceCount) / allSess.length * 10)
            .round()
            .clamp(40, 100);
  final yStats = _computeSessStats(allSess);

  // Year max streak
  int yearMaxStreak = 0, yearCurStreak = 0;
  for (int m = 1; m <= 12; m++) {
    final daysInMonth = DateTime(now.year, m + 1, 0).day;
    for (int d = 1; d <= daysInMonth; d++) {
      if (heatmap.containsKey(DateTime(now.year, m, d))) {
        yearCurStreak++;
        if (yearCurStreak > yearMaxStreak) yearMaxStreak = yearCurStreak;
      } else {
        yearCurStreak = 0;
      }
    }
  }

  // Genre distribution (Supabase 경로에서는 genre 미지원 — 빈 맵)
  final genreDistribution = <String, int>{};

  // 소셜 데이터 — 좋아요 수 + 커뮤니티 하이라이트 (내 통계 전용)
  List<SocialSentenceEntry> toSocial(List<Map<String, dynamic>> rows) => rows
      .map(
        (r) => (
          content: r['content'] as String,
          bookTitle: r['book_title'] as String,
          bookAuthor: r['book_author'] as String,
          likeCount: r['like_count'] as int,
        ),
      )
      .toList();

  final db = ref.read(dbServiceProvider);
  final socialResults = includeSocial
      ? await Future.wait([
          db
              .fetchMySentencesWithLikes(from: weekStart, to: weekEnd)
              .catchError((_) => <Map<String, dynamic>>[]),
          db
              .fetchCommunityHighlights(from: weekStart, to: weekEnd)
              .catchError((_) => <Map<String, dynamic>>[]),
          db
              .fetchMySentencesWithLikes(from: monthStart, to: nextMonthStart)
              .catchError((_) => <Map<String, dynamic>>[]),
          db
              .fetchCommunityHighlights(from: monthStart, to: nextMonthStart)
              .catchError((_) => <Map<String, dynamic>>[]),
          db
              .fetchMySentencesWithLikes(from: yearStart, to: yearEnd)
              .catchError((_) => <Map<String, dynamic>>[]),
          db
              .fetchCommunityHighlights(from: yearStart, to: yearEnd)
              .catchError((_) => <Map<String, dynamic>>[]),
        ])
      : const <List<Map<String, dynamic>>>[[], [], [], [], [], []];

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
    weekAvgPagesPerMin: 0,
    monthTotalSeconds: mStats.totalSeconds,
    monthReadDays: mStats.readDays,
    monthChoseoCount: monthChoseo.length,
    prevMonthTotalSeconds: prevMonthTotal,
    heatmap: heatmap,
    monthMaxStreak: maxStreak,
    monthTotalDays: monthTotalDays,
    monthFocusScore: mFocus,
    monthMaxSessionMinutes: mStats.maxSessionMinutes,
    monthAvgSessionMinutes: mStats.avgSessionMinutes,
    monthAvgPagesPerMin: 0,
    yearTotalSeconds: yearTotal,
    yearReadDays: yearDaySet.length,
    yearChoseoCount: yearChoseo.length,
    completedBooks: completedBooks,
    yearMonthlyMinutes: yearMonthlyMinutes,
    yearFocusScore: yFocus,
    yearMaxStreak: yearMaxStreak,
    yearMaxSessionMinutes: yStats.maxSessionMinutes,
    yearAvgSessionMinutes: yStats.avgSessionMinutes,
    yearAvgPagesPerMin: 0,
    yearGenreDistribution: genreDistribution,
    yearTopChoseo: yearChoseo.take(5).toList(),
    allRecentSessions: _sessToEntries(allSess.take(20).toList()),
    weekMyReactions: toSocial(socialResults[0]),
    weekCommunityHighlights: toSocial(socialResults[1]),
    monthMyReactions: toSocial(socialResults[2]),
    monthCommunityHighlights: toSocial(socialResults[3]),
    yearMyReactions: toSocial(socialResults[4]),
    yearCommunityHighlights: toSocial(socialResults[5]),
  );
}

final analyticsProvider =
    AsyncNotifierProvider<AnalyticsNotifier, AnalyticsState>(
      AnalyticsNotifier.new,
    );

/// 다른 사용자(팔로우한 사람)의 통계. 소셜 섹션(내가 좋아요한 문장 등)은 제외.
/// 항상 Supabase에서 읽으며, RLS의 *_select_following 정책이 접근을 제어한다.
final userAnalyticsProvider = FutureProvider.family<AnalyticsState, String>((
  ref,
  userId,
) {
  return _analyticsFromSupabase(ref, userId, includeSocial: false);
});
