import 'package:smooth_corner/smooth_corner.dart';
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
import '../../../shared/providers/follow_overlap_provider.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../../home/widget/overlap_section.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/library_stats_view.dart';
import '../widget/profile_header.dart';
import '../widget/library_calendar_view.dart';
import '../../../shared/widgets/book_cover.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/utils/follow_relationship_text.dart';
import '../../profile/controller/user_profile_provider.dart';

typedef _LibraryQuote = ({String content, String bookTitle, String bookAuthor});
typedef _CalendarDaySummary = ({ReadingLog representative, int bookCount});

final readingLogsProvider = FutureProvider<List<ReadingLog>>((ref) async {
  if (kUseMock) return const [];
  if (kUseRemoteDb) {
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
  /// null이면 내 서재. 값이 있으면 해당 사용자의 서재(읽기 전용 소셜 뷰).
  final UserProfile? viewedUser;

  const LibraryScreen({super.key, this.viewedUser});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool get _isOwner => widget.viewedUser == null;
  String? get _uid => widget.viewedUser?.id;

  @override
  Widget build(BuildContext context) {
    if (!kUseMock && _isOwner) {
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

    // 다른 사용자 보기 — 프로필/문장/팔로우 상태 로드
    final viewerData = _isOwner
        ? null
        : ref.watch(userProfileProvider(_uid!)).valueOrNull;
    final isLocked =
        !_isOwner &&
        widget.viewedUser!.isPrivate &&
        viewerData?.relationship.outgoing != FollowState.accepted;

    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: _isOwner
          ? null
          : AppBar(
              backgroundColor: context.appBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                '@${widget.viewedUser!.username}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.appTextPrimary,
                ),
              ),
            ),
      body: SingleChildScrollView(
        controller: _isOwner ? ref.read(tabScrollControllersProvider)[3] : null,
        child: Column(
          children: [
            if (_isOwner) SizedBox(height: topPad),
            // ── 프로필 헤더 ──────────────────────────────────────
            if (_isOwner)
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
              )
            else
              _ViewerProfileHeader(profile: widget.viewedUser!),

            if (isLocked)
              const _PrivateLibraryLock()
            else
              _buildOverviewTab(viewerData),
          ],
        ),
      ),
    );
  }

  // ── 서재 탭 (내/다른 사용자 데이터 분기) ──────────────────────────
  Widget _buildShelfTab({ReadingStatus? initialStatus}) {
    return Consumer(
      builder: (ctx, r, _) {
        final List<Book> books;
        final List<ReadingLog> logs;
        if (_isOwner) {
          books = r.watch(libraryProvider);
          logs = kUseMock
              ? mockReadingLogs
              : r.watch(readingLogsProvider).valueOrNull ??
                    const <ReadingLog>[];
        } else {
          books =
              r.watch(userBooksProvider(_uid!)).valueOrNull ?? const <Book>[];
          logs =
              r.watch(userReadingLogsProvider(_uid!)).valueOrNull ??
              const <ReadingLog>[];
        }
        return _LibraryTab(
          books: books,
          logs: logs,
          initialStatus: initialStatus,
          isOwner: _isOwner,
          viewedUserId: _uid,
          onAddBook: () => ctx.push(AppConstants.routeSearch),
        );
      },
    );
  }

  Widget _buildOverviewTab(UserProfileData? viewerData) {
    return Consumer(
      builder: (ctx, r, _) {
        final List<Book> books;
        final List<ReadingLog> logs;
        final AnalyticsState? analytics;
        if (_isOwner) {
          books = r.watch(libraryProvider);
          logs = kUseMock
              ? mockReadingLogs
              : r.watch(readingLogsProvider).valueOrNull ??
                    const <ReadingLog>[];
          analytics = r.watch(analyticsProvider).valueOrNull;
        } else {
          books =
              r.watch(userBooksProvider(_uid!)).valueOrNull ?? const <Book>[];
          logs =
              r.watch(userReadingLogsProvider(_uid!)).valueOrNull ??
              const <ReadingLog>[];
          analytics = r.watch(userAnalyticsProvider(_uid!)).valueOrNull;
        }

        final quotes = _overviewQuotes(viewerData);
        final sentenceItems = _sentenceItems(books, quotes);
        final overlaps = _isOwner
            ? r.watch(followOverlapProvider).valueOrNull ??
                  const <FollowOverlap>[]
            : const <FollowOverlap>[];
        return _WatchaLibraryOverview(
          books: books,
          logs: logs,
          analytics: analytics,
          quotes: quotes,
          isOwner: _isOwner,
          userId: _uid,
          onAddBook: () => ctx.push(AppConstants.routeSearch),
          onOpenStatus: (status) {
            HapticFeedback.selectionClick();
            _showShelfSheetFor(ctx, status: status);
          },
          onOpenSentences: () {
            HapticFeedback.selectionClick();
            _showSentencesSheet(ctx, sentenceItems);
          },
          overlaps: overlaps,
          onOpenOverlaps: () {
            HapticFeedback.selectionClick();
            _showOverlapSheet(ctx, overlaps);
          },
          onOpenStats: () {
            HapticFeedback.selectionClick();
            ctx.push(AppConstants.routeTasteAnalysis, extra: _uid);
          },
          onOpenHabits: () {
            HapticFeedback.selectionClick();
            if (_isOwner) {
              ctx.push(AppConstants.routeAnalytics);
            } else {
              ctx.push(AppConstants.routeReadingHistory, extra: _uid);
            }
          },
          onOpenCalendar: () {
            HapticFeedback.selectionClick();
            ctx.push(AppConstants.routeReadingHistory, extra: _uid);
          },
        );
      },
    );
  }

  List<_LibraryQuote> _overviewQuotes(UserProfileData? viewerData) {
    if (_isOwner) {
      final state = ref.watch(choseoListProvider);
      return state.items
          .map(
            (e) => (
              content: e.content,
              bookTitle: e.bookTitle,
              bookAuthor: e.bookAuthor,
            ),
          )
          .toList();
    }
    return (viewerData?.sentences ?? const [])
        .map(
          (s) => (
            content: s.content,
            bookTitle: s.bookTitle,
            bookAuthor: s.bookAuthor,
          ),
        )
        .toList();
  }

  List<_LibraryQuote> _sentenceItems(
    List<Book> books,
    List<_LibraryQuote> quotes,
  ) {
    return [
      ...quotes,
      for (final book in books)
        for (final sentence in book.savedSentences)
          (content: sentence, bookTitle: book.title, bookAuthor: book.author),
    ];
  }

  void _showShelfSheetFor(BuildContext context, {ReadingStatus? status}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (_, controller) => _ShelfSheet(
          title: status == null ? '전체 서재' : status.label,
          child: _buildShelfTab(initialStatus: status),
        ),
      ),
    );
  }

  void _showSentencesSheet(
    BuildContext context,
    List<_LibraryQuote> sentences,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.94,
        builder: (_, controller) =>
            _SentenceSheet(sentences: sentences, scrollController: controller),
      ),
    );
  }

  void _showOverlapSheet(BuildContext context, List<FollowOverlap> overlaps) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, controller) =>
            _OverlapSheet(overlaps: overlaps, scrollController: controller),
      ),
    );
  }
}

class _ShelfSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const _ShelfSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const ChorokSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: context.appTextSecondary,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceSheet extends StatelessWidget {
  final List<_LibraryQuote> sentences;
  final ScrollController scrollController;

  const _SentenceSheet({
    required this.sentences,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const ChorokSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '기록한 문장',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${sentences.length}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: context.appTextSecondary,
                ),
              ],
            ),
          ),
          Expanded(
            child: sentences.isEmpty
                ? Center(
                    child: Text(
                      '아직 기록한 문장이 없어요',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: sentences.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _SentenceSheetItem(item: sentences[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SentenceSheetItem extends StatelessWidget {
  final _LibraryQuote item;

  const _SentenceSheetItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 10,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.content,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: context.appTextTertiary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  item.bookAuthor.isEmpty
                      ? item.bookTitle
                      : '${item.bookTitle} · ${item.bookAuthor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverlapSheet extends StatelessWidget {
  final List<FollowOverlap> overlaps;
  final ScrollController scrollController;

  const _OverlapSheet({required this.overlaps, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 12),
          const ChorokSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '겹문장',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${overlaps.length}',
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: context.appTextSecondary,
                ),
              ],
            ),
          ),
          Expanded(
            child: overlaps.isEmpty
                ? Center(
                    child: Text(
                      '아직 발견한 겹문장이 없어요',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: overlaps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        OverlapCard(overlap: overlaps[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _WatchaLibraryOverview extends StatelessWidget {
  final List<Book> books;
  final List<ReadingLog> logs;
  final AnalyticsState? analytics;
  final List<({String content, String bookTitle, String bookAuthor})> quotes;
  final bool isOwner;
  final String? userId;
  final VoidCallback onAddBook;
  final ValueChanged<ReadingStatus> onOpenStatus;
  final VoidCallback onOpenSentences;
  final List<FollowOverlap> overlaps;
  final VoidCallback onOpenOverlaps;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenHabits;
  final VoidCallback onOpenCalendar;

  const _WatchaLibraryOverview({
    required this.books,
    required this.logs,
    required this.analytics,
    required this.quotes,
    required this.isOwner,
    required this.userId,
    required this.onAddBook,
    required this.onOpenStatus,
    required this.onOpenSentences,
    required this.overlaps,
    required this.onOpenOverlaps,
    required this.onOpenStats,
    required this.onOpenHabits,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final reading = books
        .where((b) => b.status == ReadingStatus.reading)
        .length;
    final completed = books
        .where((b) => b.status == ReadingStatus.completed)
        .length;
    final sentenceCount = books.fold<int>(
      quotes.length,
      (sum, b) => sum + b.savedSentences.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReadingNowCard(books: books, isOwner: isOwner, onAddBook: onAddBook),
        const SizedBox(height: 16),
        _StatTilesRow(
          reading: reading,
          completed: completed,
          sentenceCount: sentenceCount,
          overlapCount: overlaps.length,
          onOpenStatus: onOpenStatus,
          onOpenSentences: onOpenSentences,
          onOpenOverlaps: onOpenOverlaps,
        ),
        _MonthCalendarCard(logs: logs, onTap: onOpenCalendar),
        _ReadingHabitPreview(
          logs: logs,
          analytics: analytics,
          onTap: onOpenHabits,
        ),
        _TasteAnalysisPreview(
          userId: isOwner ? null : userId,
          onTap: onOpenStats,
        ),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _HeroProgressBar extends StatelessWidget {
  final double value;

  const _HeroProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: context.appProgressTrack,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: context.appReadingGradient,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 읽고 있는 책 카드 ─────────────────────────────────────────────────────
class _ReadingNowCard extends StatelessWidget {
  final List<Book> books;
  final bool isOwner;
  final VoidCallback onAddBook;

  const _ReadingNowCard({
    required this.books,
    required this.isOwner,
    required this.onAddBook,
  });

  @override
  Widget build(BuildContext context) {
    final reading = books
        .where((b) => b.status == ReadingStatus.reading)
        .toList();
    return _SectionBand(
      title: '읽고 있는 책',
      child: ForestAccentCard(
        radius: 8,
        padding: const EdgeInsets.all(14),
        child: reading.isEmpty
            ? _ReadingNowEmpty(isOwner: isOwner, onAddBook: onAddBook)
            : Column(
                children: [
                  for (var i = 0; i < reading.length; i++) ...[
                    DecoratedBox(
                      decoration: AppTheme.smoothBox(
                        color: context.appCard,
                        radius: 8,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: _ReadingNowRow(book: reading[i]),
                      ),
                    ),
                    if (i != reading.length - 1) const SizedBox(height: 7),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ReadingNowEmpty extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onAddBook;

  const _ReadingNowEmpty({required this.isOwner, required this.onAddBook});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 62,
          alignment: Alignment.center,
          decoration: AppTheme.smoothBox(
            color: context.primaryBg(0.08),
            radius: 6,
          ),
          child: Icon(
            Icons.auto_stories_rounded,
            size: 22,
            color: context.appPrimaryAccent,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            isOwner ? '지금 읽고 있는 책을 담아보세요' : '읽고 있는 책이 없어요',
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextSecondary,
              letterSpacing: 0,
            ),
          ),
        ),
        if (isOwner)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onAddBook();
            },
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: AppTheme.smoothBox(
                color: context.appPrimaryAccent,
                radius: 8,
              ),
              child: Icon(
                Icons.add_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadingNowRow extends StatelessWidget {
  final Book book;

  const _ReadingNowRow({required this.book});

  @override
  Widget build(BuildContext context) {
    final progress = book.readingProgress.clamp(0.0, 1.0);
    final remaining = book.totalPages > 0
        ? (book.totalPages - book.currentPage)
        : 0;
    return Semantics(
      label: '${book.title}, ${book.author}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeBookDetail, extra: book.id);
        },
        child: Row(
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              gradientIndex: book.title.hashCode.abs(),
              width: 52,
              height: 72,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyMedium.copyWith(
                      color: context.appTextPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _HeroProgressBar(value: progress)),
                      if (remaining > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          '완독까지 $remaining'
                          'P',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 책 현황 4타일 ──────────────────────────────────────────────────────────
class _StatTilesRow extends StatelessWidget {
  final int reading;
  final int completed;
  final int sentenceCount;
  final int overlapCount;
  final ValueChanged<ReadingStatus> onOpenStatus;
  final VoidCallback onOpenSentences;
  final VoidCallback onOpenOverlaps;

  const _StatTilesRow({
    required this.reading,
    required this.completed,
    required this.sentenceCount,
    required this.overlapCount,
    required this.onOpenStatus,
    required this.onOpenSentences,
    required this.onOpenOverlaps,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <({String label, int value, VoidCallback onTap})>[
      (
        label: '독서중',
        value: reading,
        onTap: () => onOpenStatus(ReadingStatus.reading),
      ),
      (
        label: '완독',
        value: completed,
        onTap: () => onOpenStatus(ReadingStatus.completed),
      ),
      (label: '문장·생각', value: sentenceCount, onTap: onOpenSentences),
      (label: '겹문장', value: overlapCount, onTap: onOpenOverlaps),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: _StatTile(item: tiles[i])),
            if (i != tiles.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final ({String label, int value, VoidCallback onTap}) item;

  const _StatTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.label} ${item.value}',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          item.onTap();
        },
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 8,
            side: BorderSide(color: context.appBorderSubtle),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${item.value}',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 월 캘린더 카드 (표지 표시) ──────────────────────────────────────────────
class _MonthCalendarCard extends StatefulWidget {
  final List<ReadingLog> logs;
  final VoidCallback onTap;

  const _MonthCalendarCard({required this.logs, required this.onTap});

  @override
  State<_MonthCalendarCard> createState() => _MonthCalendarCardState();
}

class _MonthCalendarCardState extends State<_MonthCalendarCard> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _prev() {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month - 1));
  }

  void _next() {
    final now = DateTime.now();
    final next = DateTime(_month.year, _month.month + 1);
    if (next.isAfter(DateTime(now.year, now.month))) return;
    HapticFeedback.selectionClick();
    setState(() => _month = next);
  }

  Map<int, _CalendarDaySummary> _summariesByDay(List<ReadingLog> monthLogs) {
    final logsByDay = <int, List<ReadingLog>>{};
    for (final log in monthLogs) {
      logsByDay.putIfAbsent(log.date.day, () => []).add(log);
    }

    return logsByDay.map((day, dayLogs) {
      final byBook = <String, List<ReadingLog>>{};
      for (final log in dayLogs) {
        final key = '${log.bookTitle}\u0000${log.bookAuthor}';
        byBook.putIfAbsent(key, () => []).add(log);
      }

      late ReadingLog representative;
      var representativeMinutes = -1;
      var representativeLatestAt = DateTime.fromMillisecondsSinceEpoch(0);
      for (final bookLogs in byBook.values) {
        final totalMinutes = bookLogs.fold<int>(
          0,
          (sum, log) => sum + log.minutes,
        );
        final latestLog = bookLogs.reduce(
          (latest, log) => log.date.isAfter(latest.date) ? log : latest,
        );
        if (totalMinutes > representativeMinutes ||
            (totalMinutes == representativeMinutes &&
                latestLog.date.isAfter(representativeLatestAt))) {
          representative = latestLog;
          representativeMinutes = totalMinutes;
          representativeLatestAt = latestLog.date;
        }
      }

      return MapEntry(day, (
        representative: representative,
        bookCount: byBook.length,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLogs = widget.logs
        .where(
          (l) => l.date.year == _month.year && l.date.month == _month.month,
        )
        .toList();
    final byDay = _summariesByDay(monthLogs);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final cells = List<int?>.filled(firstWeekday, null, growable: true)
      ..addAll(List.generate(daysInMonth, (i) => i + 1));
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        24,
        AppTheme.screenPadding,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 8,
          side: BorderSide.none,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CalNavArrow(icon: Icons.chevron_left_rounded, onTap: _prev),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '${_month.month}월',
                    style: AppTheme.headingSmall.copyWith(
                      color: context.appPrimaryAccent,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _CalNavArrow(icon: Icons.chevron_right_rounded, onTap: _next),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: AppConstants.weekdaysSunFirst
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.74,
                mainAxisSpacing: 6,
                crossAxisSpacing: 5,
              ),
              itemBuilder: (_, index) {
                final day = cells[index];
                if (day == null) return const SizedBox.shrink();
                final summary = byDay[day];
                final isToday = isCurrentMonth && day == now.day;
                return GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: DecoratedBox(
                    decoration: AppTheme.smoothBox(
                      color: context.appCardElevated,
                      radius: 4,
                      side: isToday
                          ? BorderSide(color: context.appPrimaryAccent)
                          : BorderSide.none,
                    ),
                    child: summary != null
                        ? Semantics(
                            label: summary.bookCount > 1
                                ? '$day일, ${summary.bookCount}권 읽음'
                                : '$day일, 1권 읽음',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: BookCover(
                                    coverUrl: summary.representative.coverUrl,
                                    gradientIndex:
                                        summary.representative.gradientIndex,
                                    radius: 3,
                                  ),
                                ),
                                if (summary.bookCount > 1)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                        minHeight: 20,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.78,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.72,
                                          ),
                                          width: 0.7,
                                        ),
                                      ),
                                      child: Text(
                                        '+${summary.bookCount - 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w400,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : Center(
                            child: Text(
                              '$day',
                              style: AppTheme.captionSmall.copyWith(
                                color: isToday
                                    ? context.appPrimaryAccent
                                    : context.appTextTertiary.withValues(
                                        alpha: 0.48,
                                      ),
                                fontSize: 12,
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CalNavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalNavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: context.appTextSecondary, size: 22),
      ),
    );
  }
}

class _DetailLink extends StatelessWidget {
  final VoidCallback onTap;

  const _DetailLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '자세히 보기',
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextTertiary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: context.appTextTertiary,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ReadingHabitPreview extends StatelessWidget {
  final List<ReadingLog> logs;
  final AnalyticsState? analytics;
  final VoidCallback onTap;

  const _ReadingHabitPreview({
    required this.logs,
    required this.analytics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackTotalMinutes = logs.fold<int>(
      0,
      (sum, log) => sum + log.minutes,
    );
    final totalMinutes = (analytics?.yearTotalSeconds ?? 0) > 0
        ? analytics!.yearTotalSeconds ~/ 60
        : fallbackTotalMinutes;
    final activeDays = (analytics?.yearReadDays ?? 0) > 0
        ? analytics!.yearReadDays
        : _logDays(logs);
    final averageMinutes = activeDays == 0 ? 0 : totalMinutes ~/ activeDays;
    final totalPages = logs.fold<int>(0, (sum, log) => sum + log.pages);
    final averagePages = activeDays == 0 ? 0 : totalPages ~/ activeDays;

    return _SectionBand(
      title: '나의 독서 습관',
      accentTitle: false,
      trailing: _DetailLink(onTap: onTap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InsightMetricRow(
            icon: Icons.schedule_rounded,
            label: '총 독서 시간',
            value: _formatMinutes(totalMinutes),
          ),
          const SizedBox(height: 8),
          _InsightMetricRow(
            icon: Icons.calendar_today_outlined,
            label: '독서한 날',
            value: '$activeDays일',
          ),
          const SizedBox(height: 8),
          _InsightMetricRow(
            icon: Icons.timelapse_rounded,
            label: '일일 평균 독서 시간',
            value: _formatMinutes(averageMinutes),
          ),
          const SizedBox(height: 8),
          _InsightMetricRow(
            icon: Icons.menu_book_outlined,
            label: '일일 평균 독서 분량',
            value: '$averagePages쪽',
          ),
        ],
      ),
    );
  }
}

class _TasteAnalysisPreview extends StatelessWidget {
  final String? userId;
  final VoidCallback onTap;

  const _TasteAnalysisPreview({required this.userId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SectionBand(
      title: '나의 독서 취향',
      accentTitle: false,
      trailing: _DetailLink(onTap: onTap),
      child: LibraryStatsView(userId: userId, embedded: true),
    );
  }
}

class _InsightMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightMetricRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: AppTheme.smoothBox(color: context.appCard, radius: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: context.appTextTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextSecondary,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            value,
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest분';
  if (rest == 0) return '$hours시간';
  return '$hours시간 $rest분';
}

class _SectionBand extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool accentTitle;

  const _SectionBand({
    required this.title,
    required this.child,
    this.trailing,
    this.accentTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        24,
        AppTheme.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTheme.headingSmall.copyWith(
                  color: accentTitle
                      ? context.appPrimaryAccent
                      : context.appTextPrimary,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

int _logDays(List<ReadingLog> logs) {
  return logs
      .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
      .toSet()
      .length;
}

// ════════════════════════════════════════════════════════════════════════════
// 서재 탭
// ════════════════════════════════════════════════════════════════════════════
class _LibraryTab extends StatefulWidget {
  final List<Book> books;
  final List<ReadingLog> logs;
  final ReadingStatus? initialStatus;
  final VoidCallback onAddBook;

  /// 내 서재 여부. false면 다른 사용자의 서재(읽기 전용 — 책 추가/이어읽기 숨김).
  final bool isOwner;

  /// 다른 사용자 보기일 때 그 사용자 id (통계 카드용).
  final String? viewedUserId;

  const _LibraryTab({
    required this.books,
    required this.logs,
    this.initialStatus,
    required this.onAddBook,
    this.isOwner = true,
    this.viewedUserId,
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
    if (widget.initialStatus != null) {
      _selectedStatus = widget.initialStatus!;
      return;
    }
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

    // books 1회 순회: 상태별 카운트 합산
    final statusCounts = <ReadingStatus, int>{
      for (final s in ReadingStatus.values) s: 0,
    };
    for (final b in widget.books) {
      statusCounts[b.status] = (statusCounts[b.status] ?? 0) + 1;
    }

    return CustomScrollView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // ── 이번 달 성과 ─────────────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: _MonthlyAchievementCard(userId: widget.viewedUserId),
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
                if (widget.isOwner)
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
              itemBuilder: (_, i) =>
                  _BookCard(book: _filteredBooks[i], isOwner: widget.isOwner),
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
              itemBuilder: (_, i) => _BookListTile(
                book: _filteredBooks[i],
                isOwner: widget.isOwner,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── 이번 달 독서 성과 뱃지 ──────────────────────────────────────────────────
class _MonthlyAchievementCard extends ConsumerWidget {
  /// null이면 내 통계. 값이 있으면 해당 사용자 통계(분석 화면 이동 비활성).
  final String? userId;

  const _MonthlyAchievementCard({this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = userId != null
        ? ref.watch(userAnalyticsProvider(userId!)).valueOrNull
        : ref.watch(analyticsProvider).valueOrNull;
    final books = userId != null
        ? (ref.watch(userBooksProvider(userId!)).valueOrNull ?? const <Book>[])
        : ref.watch(libraryProvider);
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
        onTap: userId != null
            ? null
            : () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeAnalytics);
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

  /// 내 서재 여부. false면 상세 화면 이동/이어읽기 비활성(읽기 전용).
  final bool isOwner;

  const _BookCard({required this.book, this.isOwner = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = book.status == ReadingStatus.completed;
    return GestureDetector(
      onTap: isOwner
          ? () {
              HapticFeedback.selectionClick();
              context.push(AppConstants.routeBookDetail, extra: book.id);
            }
          : null,
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
                    if (isOwner) ...[
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

  /// 내 서재 여부. false면 상세 화면 이동/이어읽기 비활성(읽기 전용).
  final bool isOwner;

  const _BookListTile({required this.book, this.isOwner = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;

    return Semantics(
      label: '${book.title}, ${book.author}',
      button: true,
      child: GestureDetector(
        onTap: isOwner
            ? () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeBookDetail, extra: book.id);
              }
            : null,
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
              // 이어읽기 버튼 (읽는 중, 내 서재 전용)
              if (isReading && isOwner) ...[
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

// ─── 다른 사용자 서재 헤더 (읽기 전용 + 팔로우 버튼) ───────────────────────
class _ViewerProfileHeader extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _ViewerProfileHeader({required this.profile});

  @override
  ConsumerState<_ViewerProfileHeader> createState() =>
      _ViewerProfileHeaderState();
}

class _ViewerProfileHeaderState extends ConsumerState<_ViewerProfileHeader> {
  FollowRelationship? _relationshipOverride;
  bool _busy = false;

  Future<void> _toggleFollow(FollowRelationship current) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      if (current.outgoing == FollowState.none) {
        final result = await repo.follow(widget.profile.id);
        if (!mounted) return;
        setState(
          () => _relationshipOverride = current.copyWith(outgoing: result),
        );
      } else {
        await repo.unfollow(widget.profile.id);
        if (!mounted) return;
        setState(
          () => _relationshipOverride = current.copyWith(
            outgoing: FollowState.none,
          ),
        );
      }
      ref.invalidate(userProfileProvider(widget.profile.id));
      ref.read(followMutationVersionProvider.notifier).state++;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('팔로우 상태를 변경하지 못했어요'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = ref.watch(userProfileProvider(p.id)).valueOrNull;
    final relationship =
        _relationshipOverride ?? data?.relationship ?? FollowRelationship.none;

    final label = followActionLabel(relationship);
    final filled = followActionIsFilled(relationship);

    Widget buttonChild() => _busy
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : context.appTextSecondary,
            ),
          )
        : Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        16,
        AppTheme.screenPadding,
        0,
      ),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 10,
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: isDark
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : context.primaryBg(0.14),
                backgroundImage:
                    (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                    ? NetworkImage(p.avatarUrl!)
                    : null,
                child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                    ? Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: context.appPrimaryAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: context.appTextPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${p.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (followRelationshipHint(relationship)
                        case final hint?) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appPrimaryAccent,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: filled
                    ? FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _toggleFollow(relationship),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.appPrimaryAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: context.appPrimaryAccent
                              .withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                          ),
                        ),
                        child: buttonChild(),
                      )
                    : TextButton(
                        onPressed: _busy
                            ? null
                            : () => _toggleFollow(relationship),
                        style: TextButton.styleFrom(
                          backgroundColor: context.appCardElevated,
                          foregroundColor: context.appTextSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD,
                            ),
                          ),
                        ),
                        child: buttonChild(),
                      ),
              ),
            ],
          ),
          if (p.bio != null && p.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                p.bio!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 비공개 서재 잠금 상태 ─────────────────────────────────────────────────
class _PrivateLibraryLock extends StatelessWidget {
  const _PrivateLibraryLock();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '비공개 계정이에요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '팔로우가 수락되면 서재를 볼 수 있어요',
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── 책 추가 바텀시트 ─────────────────────────────────────────────────────
