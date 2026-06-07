import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../forest/widget/live_forest_widget.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/profile_header.dart';
import '../widget/library_calendar_view.dart';
import '../widget/library_stats_view.dart';
import '../../../shared/widgets/book_cover.dart';

import '../widget/today_goal_banner.dart';
import '../../../shared/models/user_profile.dart';

final activeReadersProvider = FutureProvider<List<UserProfile>>((ref) async {
  if (kUseMock) return const [];
  final client = Supabase.instance.client;
  final me = client.auth.currentUser?.id;
  if (me == null) return const [];

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toUtc();

  final rows = await client
      .from('reading_sessions')
      .select(
        'user_id, profiles!reading_sessions_user_id_fkey(id, display_name, username)',
      )
      .neq('user_id', me)
      .gte('started_at', todayStart.toIso8601String())
      .order('started_at', ascending: false);

  final seen = <String>{};
  final readers = <UserProfile>[];
  for (final row in rows as List) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    if (profile == null) continue;
    final id = profile['id'] as String? ?? '';
    if (seen.add(id)) readers.add(UserProfile.fromRow(profile));
  }
  return readers;
});

final readingLogsProvider = FutureProvider<List<ReadingLog>>((ref) async {
  if (kUseMock) return const [];
  if (kIsWeb) {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _fetchSupabaseReadingLogs(client, userId);
    return rows.map<ReadingLog>((r) {
      final book = r['books'] as Map<String, dynamic>?;
      final secs = (r['duration_seconds'] as num?)?.toInt() ?? 0;
      final dateStr = r['ended_at'] as String? ?? r['started_at'] as String?;
      final title = book?['title'] as String? ?? '알 수 없는 책';
      return (
        date: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
        bookTitle: title,
        bookAuthor: book?['author'] as String? ?? '',
        minutes: (secs / 60).round(),
        pages: (r['pages_read'] as num?)?.toInt() ?? 0,
        coverUrl: book?['cover_url'] as String?,
        gradientIndex: title.hashCode.abs() % AppTheme.coverGradients.length,
      );
    }).toList();
  }
  final repo = ref.read(bookRepositoryProvider);
  if (repo == null) return const [];
  final rows = await repo.getAllReadingLogs();
  return rows
      .map<ReadingLog>(
        (r) => (
          date: DateTime.parse(r['started_at'] as String),
          bookTitle: r['book_title'] as String,
          bookAuthor: r['book_author'] as String,
          minutes: ((r['duration_seconds'] as num?)?.toInt() ?? 0) ~/ 60,
          pages: (r['pages_read'] as num?)?.toInt() ?? 0,
          coverUrl: r['cover_url'] as String?,
          gradientIndex:
              (r['book_title'] as String).hashCode.abs() %
              AppTheme.coverGradients.length,
        ),
      )
      .toList();
});

Future<List<dynamic>> _fetchSupabaseReadingLogs(
  SupabaseClient client,
  String userId,
) async {
  try {
    return await client
        .from('reading_sessions')
        .select(
          'ended_at, started_at, duration_seconds, pages_read, books(title, author, cover_url)',
        )
        .eq('user_id', userId)
        .order('ended_at', ascending: false);
  } catch (_) {
    return await client
        .from('reading_sessions')
        .select(
          'ended_at, started_at, duration_seconds, books(title, author, cover_url)',
        )
        .eq('user_id', userId)
        .order('ended_at', ascending: false);
  }
}

// ─── 뷰 모드 / 정렬 옵션 ──────────────────────────────────────────────────
enum _LibraryViewMode { grid, list }

enum _SortOption {
  recent,
  progress,
  title,
  added;

  String get label => switch (this) {
    _SortOption.recent => '최근 읽은 순',
    _SortOption.progress => '진행률 순',
    _SortOption.title => '제목 순',
    _SortOption.added => '추가 순',
  };
}

IconData _statusIcon(ReadingStatus s) => switch (s) {
  ReadingStatus.reading => Icons.auto_stories_rounded,
  ReadingStatus.completed => Icons.check_circle_outline_rounded,
  ReadingStatus.wantToRead => Icons.bookmark_outline_rounded,
};

/// 현재 페이지 / 독서 시간 기반 완독 예상일 (30분/일 가정)
String? _estimateCompletion(Book book) {
  if (book.totalReadingHours <= 0 ||
      book.currentPage <= 0 ||
      book.totalPages <= book.currentPage) {
    return null;
  }
  final pagesPerHour = book.currentPage / book.totalReadingHours;
  if (pagesPerHour <= 0) return null;
  final pagesPerDay = pagesPerHour * 0.5;
  final remaining = book.totalPages - book.currentPage;
  final daysLeft = (remaining / pagesPerDay).ceil();
  final date = DateTime.now().add(Duration(days: daysLeft));
  return '${date.month}월 ${date.day}일 완독 예상';
}

// ─── 메인 스크린 ──────────────────────────────────────────────────────────
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _viewIndex = 0; // 0: 서재, 1: 캘린더

  @override
  Widget build(BuildContext context) {
    if (!kUseMock) {
      ref.listen(readingLogsProvider, (_, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '독서 기록을 불러오지 못했어요',
                style: TextStyle(color: Colors.white),
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      body: SingleChildScrollView(
        controller: ref.read(tabScrollControllersProvider)[3],
        child: Column(
          children: [
            SizedBox(height: topPad),
            // ── 프로필 + 설정 ───────────────────────────────────
            Consumer(
              builder: (context, ref, _) {
                final streak =
                    ref
                        .watch(readingStreakProvider)
                        .whenOrNull(data: (v) => v) ??
                    0;
                return ProfileHeader(
                  onSettingsTap: () {
                    HapticFeedback.selectionClick();
                    context.push(AppConstants.routeSettings);
                  },
                  streak: streak,
                );
              },
            ),

            // ── 소셜 피드 스트립 ─────────────────────────────────
            const _SocialFeedStrip(),

            // ── 내 문장장 (Quotes Archive) ──────────────────────
            Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(choseoListProvider);
                final items = state.items;
                if (items.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.screenPadding,
                        8,
                        AppTheme.screenPadding,
                        12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '내 문장장',
                            style: AppTheme.headingSmall.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Semantics(
                            label: '수집한 문장 전체 보기',
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                context.push(AppConstants.routeChoseoList);
                              },
                              child: Text(
                                '전체보기',
                                style: AppTheme.captionLarge.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.screenPadding,
                        ),
                        itemCount: items.length > 5 ? 5 : items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];

                          // 배지/특성 부여 로직
                          String badge = '수집한 문장';
                          if (index == 0 || item.content.length > 60) {
                            badge = '이 책의 핵심!';
                          } else if (index == 1) {
                            badge = '나만의 발견';
                          } else if (item.content.length < 20) {
                            badge = '짧고 강렬한';
                          } else if (index == 2) {
                            badge = '최근 수집';
                          } else {
                            badge = '긴 여운';
                          }

                          return Container(
                            width: 240,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.smoothBox(
                              color: context.appCardElevated,
                              radius: AppTheme.radiusLG,
                              side: BorderSide.none,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.appPrimaryAccent
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        badge,
                                        style: AppTheme.captionSmall.copyWith(
                                          color: context.appPrimaryAccent,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.format_quote_rounded,
                                      size: 14,
                                      color: context.appTextTertiary.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Text(
                                    item.content,
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: context.appTextPrimary,
                                      height: 1.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${item.bookTitle} · ${item.bookAuthor}',
                                  style: AppTheme.captionSmall.copyWith(
                                    color: context.appTextTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // ── 세그먼트 토글 ────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                0,
                AppTheme.screenPadding,
                4,
              ),
              child: SegmentToggle(
                labels: const ['서재', '통계', '캘린더'],
                selectedIndex: _viewIndex,
                onChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _viewIndex = i);
                },
              ),
            ),
            if (_viewIndex == 0)
              Consumer(
                builder: (ctx, r, _) {
                  final books = r.watch(libraryProvider);
                  final logs = kUseMock
                      ? mockReadingLogs
                      : r.watch(readingLogsProvider).valueOrNull ??
                            const <ReadingLog>[];
                  return _LibraryTab(
                    books: books,
                    logs: logs,
                    onAddBook: () => ctx.push(AppConstants.routeSearch),
                  );
                },
              )
            else if (_viewIndex == 1)
              LibraryStatsView(scrollController: null)
            else
              Consumer(
                builder: (ctx2, r, child) {
                  final logs = kUseMock
                      ? mockReadingLogs
                      : r.watch(readingLogsProvider).valueOrNull ??
                            const <ReadingLog>[];
                  final books = r.watch(libraryProvider);
                  return LibraryCalendarView(
                    logs: logs,
                    books: books,
                    scrollController: null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 서재 탭
// ════════════════════════════════════════════════════════════════════════════
class _LibraryTab extends StatefulWidget {
  final List<Book> books;
  final List<ReadingLog> logs;
  final VoidCallback onAddBook;

  const _LibraryTab({
    required this.books,
    required this.logs,
    required this.onAddBook,
  });

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  late ReadingStatus _selectedStatus;
  _LibraryViewMode _viewMode = _LibraryViewMode.grid;
  _SortOption _sortOption = _SortOption.recent;

  @override
  void initState() {
    super.initState();
    final hasReading = widget.books.any(
      (b) => b.status == ReadingStatus.reading,
    );
    if (hasReading &&
        widget.books.any((b) => b.status == ReadingStatus.completed)) {
      _selectedStatus = ReadingStatus.completed;
    } else if (hasReading) {
      _selectedStatus = ReadingStatus.wantToRead;
    } else {
      _selectedStatus = ReadingStatus.reading;
    }
  }

  ReadingLog? _lastLogFor(Book book) =>
      widget.logs.where((l) => l.bookTitle == book.title).firstOrNull;

  List<Book> get _filteredBooks {
    final list = widget.books
        .where((b) => b.status == _selectedStatus)
        .toList();
    return switch (_sortOption) {
      _SortOption.progress =>
        list..sort((a, b) => b.readingProgress.compareTo(a.readingProgress)),
      _SortOption.title => list..sort((a, b) => a.title.compareTo(b.title)),
      _SortOption.recent || _SortOption.added => list,
    };
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SortSheet(
        current: _sortOption,
        onSelected: (opt) {
          setState(() => _sortOption = opt);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final logs = widget.logs;

    // books 1회 순회: 카운트, reading 목록, 오늘 분 합산
    final statusCounts = <ReadingStatus, int>{
      for (final s in ReadingStatus.values) s: 0,
    };
    final readingBooks = <Book>[];
    for (final b in widget.books) {
      statusCounts[b.status] = (statusCounts[b.status] ?? 0) + 1;
      if (b.status == ReadingStatus.reading) readingBooks.add(b);
    }
    final todayMinutes = logs
        .where(
          (l) =>
              l.date.year == now.year &&
              l.date.month == now.month &&
              l.date.day == now.day,
        )
        .fold<int>(0, (a, l) => a + l.minutes);

    return CustomScrollView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // ── 오늘의 독서 목표 배너 (항상 표시) ───────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              12,
              AppTheme.screenPadding,
              0,
            ),
            child: TodayGoalBanner(
              todayMinutes: todayMinutes,
              goalMinutes: 30,
              firstReadingBook: readingBooks.isEmpty
                  ? null
                  : readingBooks.first,
            ),
          ),
        ),

        // ── 지금 읽는 책 히어로 카드 ──────────────────────────────
        if (readingBooks.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: const ChorokSectionHeader(title: '지금 읽는 책'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: _HeroBookCard(
                book: readingBooks.first,
                lastLog: _lastLogFor(readingBooks.first),
              ),
            ),
          ),
        ],

        // ── 이번 달 성과 ─────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: const _MonthlyAchievementCard(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── 전체 서재 섹션 헤더 ──────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: ChorokSectionHeader(
              title: '전체 서재',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: AppTheme.smoothBox(
                      color: context.appPrimaryAccent.withValues(alpha: 0.1),
                      radius: 10,
                    ),
                    child: Text(
                      '${widget.books.length}권',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: '정렬 방식 변경',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showSortSheet(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 32,
                        height: 32,
                        decoration: AppTheme.smoothBox(
                          color: _sortOption != _SortOption.recent
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : context.appCardElevated,
                          radius: 10,
                        ),
                        child: Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: _sortOption != _SortOption.recent
                              ? (isDark
                                    ? AppTheme.primaryLight
                                    : AppTheme.lightPrimaryAccent)
                              : context.appTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Semantics(
                    label: _viewMode == _LibraryViewMode.grid
                        ? '리스트 보기로 전환'
                        : '그리드 보기로 전환',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _viewMode = _viewMode == _LibraryViewMode.grid
                              ? _LibraryViewMode.list
                              : _LibraryViewMode.grid;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: 32,
                        height: 32,
                        decoration: AppTheme.smoothBox(
                          color: context.appCardElevated,
                          radius: 10,
                        ),
                        child: Icon(
                          _viewMode == _LibraryViewMode.grid
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                          size: 16,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // ── 필터 칩 + 책 추가 버튼 ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Row(
              children: [
                ...ReadingStatus.values.map((status) {
                  final count = statusCounts[status] ?? 0;
                  final isSelected = status == _selectedStatus;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: status != ReadingStatus.values.last ? 8 : 0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStatus = status);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: AppTheme.smoothPill(
                          color: isSelected
                              ? AppTheme.primary
                              : context.appCard,
                          side: BorderSide.none,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(status),
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : context.appTextTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${status.label} $count',
                              style: AppTheme.captionLarge.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : context.appTextTertiary,
                                fontWeight: isSelected
                                    ? FontWeight.w400
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Semantics(
                  label: '책 추가',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onAddBook();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),

        // ── 책 그리드 / 리스트 / 빈 상태 ─────────────────────────────
        if (_filteredBooks.isEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: _EmptyShelf(status: _selectedStatus),
            ),
          )
        else if (_viewMode == _LibraryViewMode.grid)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spaceLG,
              AppTheme.screenPadding,
              AppTheme.spaceLG,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _filteredBooks.length,
              itemBuilder: (_, i) => _BookCard(book: _filteredBooks[i]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spaceMD,
              AppTheme.screenPadding,
              AppTheme.spaceLG,
            ),
            sliver: SliverList.separated(
              itemCount: _filteredBooks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BookListTile(book: _filteredBooks[i]),
            ),
          ),
      ],
    );
  }
}

// ─── 이번 달 독서 성과 뱃지 ──────────────────────────────────────────────────
class _MonthlyAchievementCard extends ConsumerWidget {
  const _MonthlyAchievementCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider).valueOrNull;
    final books = ref.watch(libraryProvider);
    final now = DateTime.now();
    final monthCompleted = books
        .where(
          (b) =>
              b.status == ReadingStatus.completed &&
              b.completedAt != null &&
              b.completedAt!.year == now.year &&
              b.completedAt!.month == now.month,
        )
        .length;

    final items = [
      (
        icon: Icons.menu_book_rounded,
        value: kUseMock ? '2권' : '$monthCompleted권',
        label: '이번 달 완독',
      ),
      (
        icon: Icons.local_fire_department_rounded,
        value: kUseMock ? '5일' : '${analytics?.monthMaxStreak ?? 0}일',
        label: '최장 연속',
      ),
      (
        icon: Icons.format_quote_rounded,
        value: kUseMock ? '47개' : '${analytics?.monthChoseoCount ?? 0}개',
        label: '수집 문장',
      ),
    ];

    return Semantics(
      label: '이번 달 독서 성과 — 분석 보기',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(AppConstants.routeAnalytics);
        },
        child: ChorokCard(
          padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
          child: Row(
            children: items.asMap().entries.expand((e) {
              final item = e.value;
              return [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: AppTheme.smoothBox(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.10,
                          ),
                          radius: AppTheme.radiusMD,
                          side: BorderSide.none,
                        ),
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: AppTheme.headingSmall.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (e.key < items.length - 1)
                  Container(width: 1, height: 48, color: Colors.transparent),
              ];
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── 도서 카드 ────────────────────────────────────────────────────────────
class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = book.status == ReadingStatus.completed;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppConstants.routeBookDetail, extra: book.id);
      },
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 10,
          side: BorderSide.none,
          shadows: isDark ? null : AppTheme.lightCardShadows,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: SmoothRectangleBorder(
                    smoothness: 0.6,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── 배경 (커버 or 그라디언트 플레이스홀더) ─────
                    BookCover(
                      coverUrl: book.coverUrl,
                      gradientIndex:
                          book.title.hashCode.abs() %
                          AppTheme.coverGradients.length,
                      width: double.infinity,
                      height: double.infinity,
                      radius: 0,
                    ),
                    // ── 완독 배지 ──────────────────────────────────
                    if (isCompleted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    // ── 초서 수 뱃지 ──────────────────────────────
                    if (book.savedSentences.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: AppTheme.smoothPill(
                            color: AppTheme.primary.withValues(alpha: 0.88),
                            side: BorderSide.none,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${book.savedSentences.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headingSmall.copyWith(
                      color: context.appTextPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  if (book.status == ReadingStatus.reading) ...[
                    const SizedBox(height: AppTheme.spaceSM),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: book.readingProgress,
                        backgroundColor: context.appBorder,
                        valueColor: AlwaysStoppedAnimation(
                          context.appPrimaryAccent,
                        ),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${(book.readingProgress * 100).toInt()}%',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${book.currentPage}/${book.totalPages}쪽',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                    // ── 완독 예상일 ──────────────────────────────────
                    if (_estimateCompletion(book) case final est?)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          est,
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // ── 바로 읽기 버튼 ──────────────────────────────
                    Semantics(
                      label: '${book.title} 이어 읽기',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          final outerCtx = context;
                          outerCtx.push(
                            AppConstants.routeSession,
                            extra: SessionExtra(
                              bookId: book.id,
                              bookTitle: book.title,
                              bookAuthor: book.author,
                              coverUrl: book.coverUrl,
                              startPage: book.currentPage,
                              totalPages: book.totalPages,
                            ),
                          );
                        },
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: AppTheme.smoothBox(
                            color: isDark
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.lightPrimaryAccent,
                            radius: AppTheme.radiusMD,
                          ),
                          child: Text(
                            '이어 읽기  ${(book.readingProgress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? AppTheme.primaryLight
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (book.status == ReadingStatus.completed &&
                      book.totalReadingHours > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: context.appTextTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${book.totalReadingHours.toStringAsFixed(1)}시간',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                        if (book.savedSentences.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.format_quote_rounded,
                            size: 11,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${book.savedSentences.length}',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 빈 서재 ─────────────────────────────────────────────────────────────
class _EmptyShelf extends StatelessWidget {
  final ReadingStatus status;
  const _EmptyShelf({required this.status});

  @override
  Widget build(BuildContext context) {
    final (message, sub) = switch (status) {
      ReadingStatus.reading => ('읽는 중인 책이 없어요', '+ 책 추가 버튼으로 시작해보세요'),
      ReadingStatus.completed => ('아직 완독한 책이 없어요', '첫 번째 책을 완독해보세요 🌿'),
      ReadingStatus.wantToRead => ('읽고 싶은 책을 추가해보세요', '+ 책 추가 버튼을 눌러보세요'),
    };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 52,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            message,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            sub,
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 도서 리스트 타일 ─────────────────────────────────────────────────────
class _BookListTile extends StatelessWidget {
  final Book book;
  const _BookListTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;

    return Semantics(
      label: '${book.title}, ${book.author}',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeBookDetail, extra: book.id);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 10,
            side: BorderSide.none,
            shadows: isDark ? null : AppTheme.lightCardShadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 커버 썸네일
              BookCover(
                coverUrl: book.coverUrl,
                gradientIndex:
                    book.title.hashCode.abs() % AppTheme.coverGradients.length,
                width: 52,
                height: 72,
                radius: 10,
              ),
              const SizedBox(width: 12),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodySmall.copyWith(
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isReading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: book.readingProgress,
                          backgroundColor: context.appBorder,
                          valueColor: AlwaysStoppedAnimation(
                            context.appPrimaryAccent,
                          ),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${(book.readingProgress * 100).toInt()}%',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${book.currentPage}/${book.totalPages}쪽',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                          if (_estimateCompletion(book) case final est?) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '· $est',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          if (book.totalReadingHours > 0) ...[
                            Icon(
                              Icons.schedule_rounded,
                              size: 11,
                              color: context.appTextTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${book.totalReadingHours.toStringAsFixed(1)}시간',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
                          if (book.savedSentences.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.format_quote_rounded,
                              size: 11,
                              color: context.appTextTertiary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${book.savedSentences.length}문장',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // 이어읽기 버튼 (읽는 중)
              if (isReading) ...[
                const SizedBox(width: 8),
                Semantics(
                  label: '${book.title} 이어 읽기',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          bookId: book.id,
                          bookTitle: book.title,
                          bookAuthor: book.author,
                          coverUrl: book.coverUrl,
                          startPage: book.currentPage,
                          totalPages: book.totalPages,
                        ),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: AppTheme.smoothBox(
                        color: isDark
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : AppTheme.lightPrimaryAccent,
                        radius: 10,
                        side: BorderSide.none,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 18,
                        color: isDark ? AppTheme.primaryLight : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 정렬 바텀시트 ────────────────────────────────────────────────────────
class _SortSheet extends StatelessWidget {
  final _SortOption current;
  final ValueChanged<_SortOption> onSelected;

  const _SortSheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChorokSheetHandle(),
          const SizedBox(height: 16),
          Text(
            '정렬',
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...(_SortOption.values.map(
            (opt) => Semantics(
              label: opt.label,
              button: true,
              selected: opt == current,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(opt);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: AppTheme.smoothBox(
                    color: opt == current
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : context.appCardElevated,
                    radius: 10,
                    side: BorderSide.none,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          opt.label,
                          style: AppTheme.bodyMedium.copyWith(
                            color: opt == current
                                ? context.appPrimaryAccent
                                : context.appTextPrimary,
                            fontWeight: opt == current
                                ? FontWeight.w400
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (opt == current)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: isDark
                              ? AppTheme.primaryLight
                              : AppTheme.lightPrimaryAccent,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

// ─── 소셜 피드 스트립 ────────────────────────────────────────────────────────
class _SocialFeedStrip extends ConsumerWidget {
  const _SocialFeedStrip();

  static const _avatarColors = [
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ];

  static Color _colorFor(String id) =>
      _avatarColors[id.hashCode.abs() % _avatarColors.length];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readers = ref.watch(activeReadersProvider).valueOrNull;
    if (readers == null || readers.isEmpty) return const SizedBox.shrink();

    final shown = readers.take(3).toList();
    final extra = readers.length - 1;

    final activeCount = readers.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        8,
        AppTheme.screenPadding,
        0,
      ),
      child: GestureDetector(
        onTap: () => HapticFeedback.selectionClick(),
        child: ForestAccentCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          radius: AppTheme.radiusMD,
          child: SizedBox(
            height: 56,
            child: Stack(
              children: [
                // 우측에 라이브 포레스트 반딧불 미니뷰 (배경 레이어)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: 0.55,
                        child: LiveForestWidget(
                          activeCount: activeCount.clamp(3, 18),
                          todayCount: (activeCount * 2).clamp(8, 32),
                          weekCount: (activeCount * 2).clamp(8, 28),
                        ),
                      ),
                    ),
                  ),
                ),
                // 전경: 아바타 + 텍스트 + 화살표
                Row(
                  children: [
                    SizedBox(
                      width: 16.0 * (shown.length - 1) + 26,
                      height: 26,
                      child: Stack(
                        children: [
                          for (var i = 0; i < shown.length; i++)
                            Positioned(
                              left: i * 16.0,
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _colorFor(shown[i].id),
                                  border: Border.all(
                                    color: context.appBg,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  shown[i].displayName.isNotEmpty
                                      ? shown[i].displayName[0]
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appTextSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: shown[0].displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: context.appTextPrimary,
                              ),
                            ),
                            TextSpan(
                              text: extra > 0
                                  ? ' 외 $extra명이 지금 독서 중'
                                  : '이 지금 독서 중',
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: context.appTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 히어로 도서 카드 ─────────────────────────────────────────────────────────
class _HeroBookCard extends StatelessWidget {
  final Book book;
  final ReadingLog? lastLog;

  const _HeroBookCard({required this.book, this.lastLog});

  String _lastSessionLabel() {
    if (lastLog == null) return '';
    final diff = DateTime.now().difference(lastLog!.date);
    if (diff.inDays == 0) return '오늘';
    if (diff.inDays == 1) return '어제';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradIdx = book.title.hashCode.abs() % AppTheme.coverGradients.length;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppConstants.routeBookDetail, extra: book.id);
      },
      child: Container(
        height: 200,
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusXL,
          side: BorderSide(
            color: context.appPrimaryAccent.withValues(alpha: 0.20),
          ),
          shadows: isDark ? null : AppTheme.lightCardShadows,
        ),
        child: Row(
          children: [
            // ── 커버 ──────────────────────────────────────────────
            ClipPath(
              clipper: ShapeBorderClipper(
                shape: SmoothRectangleBorder(
                  smoothness: 0.6,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
              ),
              child: BookCover(
                coverUrl: book.coverUrl,
                gradientIndex: gradIdx,
                width: 130,
                height: 200,
                radius: 0,
              ),
            ),
            // ── 정보 ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lastLog != null)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: context.appPrimaryAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '마지막 · ${_lastSessionLabel()}',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: lastLog != null ? 8 : 0),
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: book.readingProgress,
                        backgroundColor: context.appBorder,
                        valueColor: AlwaysStoppedAnimation(
                          context.appPrimaryAccent,
                        ),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.currentPage}/${book.totalPages}쪽 · ${(book.readingProgress * 100).toInt()}%',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      label: '${book.title} 이어 읽기',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          context.push(
                            AppConstants.routeSession,
                            extra: SessionExtra(
                              bookId: book.id,
                              bookTitle: book.title,
                              bookAuthor: book.author,
                              coverUrl: book.coverUrl,
                              startPage: book.currentPage,
                              totalPages: book.totalPages,
                            ),
                          );
                        },
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: AppTheme.smoothBox(
                            color: isDark
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.lightPrimaryAccent,
                            radius: AppTheme.radiusMD,
                            side: BorderSide.none,
                          ),
                          child: Text(
                            '이어 읽기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? AppTheme.primaryLight
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 책 추가 바텀시트 ─────────────────────────────────────────────────────
