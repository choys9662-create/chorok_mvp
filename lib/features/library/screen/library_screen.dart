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
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/profile_header.dart';
import '../widget/library_calendar_view.dart';
import '../widget/library_stats_view.dart';
import '../../../shared/widgets/book_cover.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/utils/follow_relationship_text.dart';
import '../../profile/controller/user_profile_provider.dart';

typedef _LibraryQuote = ({String content, String bookTitle, String bookAuthor});

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

final likedSentenceQuotesProvider =
    FutureProvider.family<List<_LibraryQuote>, String?>((
      ref,
      viewedUserId,
    ) async {
      if (kUseMock) return const [];
      final client = Supabase.instance.client;
      final targetUserId = viewedUserId ?? client.auth.currentUser?.id;
      if (targetUserId == null) return const [];

      final rows = await client
          .from('sentence_likes')
          .select(
            'created_at, '
            'sentences!inner(content, '
            'books(title, author), '
            'global_books(title, author))',
          )
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(50);

      return (rows as List)
          .map((row) {
            final sentence =
                (row as Map<String, dynamic>)['sentences']
                    as Map<String, dynamic>?;
            if (sentence == null) return null;
            final localBook = sentence['books'] as Map<String, dynamic>?;
            final globalBook =
                sentence['global_books'] as Map<String, dynamic>?;
            final book = globalBook ?? localBook;
            return (
              content: sentence['content'] as String? ?? '',
              bookTitle: book?['title'] as String? ?? '',
              bookAuthor: book?['author'] as String? ?? '',
            );
          })
          .whereType<_LibraryQuote>()
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
  int _viewIndex = 0; // 0: 서재, 1: 통계, 2: 캘린더

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
            else if (_viewIndex == 0)
              _buildOverviewTab(viewerData)
            else ...[
              _LibraryDetailHeader(
                title: _viewIndex == 1 ? '취향분석' : '캘린더',
                onBack: () {
                  HapticFeedback.selectionClick();
                  setState(() => _viewIndex = 0);
                },
              ),
              if (_viewIndex == 1)
                LibraryStatsView(scrollController: null, userId: _uid)
              else
                _buildCalendarTab(),
            ],
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

        final likedQuotes = r.watch(likedSentenceQuotesProvider(_uid));
        final quotes = kUseMock
            ? _overviewQuotes(viewerData)
            : likedQuotes.valueOrNull ?? const <_LibraryQuote>[];
        final sentenceItems = _sentenceItems(books, quotes);
        return _WatchaLibraryOverview(
          books: books,
          logs: logs,
          analytics: analytics,
          quotes: quotes,
          isOwner: _isOwner,
          onAddBook: () => ctx.push(AppConstants.routeSearch),
          onOpenStatus: (status) {
            HapticFeedback.selectionClick();
            _showShelfSheetFor(ctx, status: status);
          },
          onOpenSentences: () {
            HapticFeedback.selectionClick();
            _showSentencesSheet(ctx, sentenceItems);
          },
          onOpenStats: () {
            HapticFeedback.selectionClick();
            setState(() => _viewIndex = 1);
          },
          onOpenCalendar: () {
            HapticFeedback.selectionClick();
            setState(() => _viewIndex = 2);
          },
          onOpenQuotes: null,
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

  // ── 캘린더 탭 ─────────────────────────────────────────────────
  Widget _buildCalendarTab() {
    return Consumer(
      builder: (ctx2, r, child) {
        final List<Book> books;
        final List<ReadingLog> logs;
        if (_isOwner) {
          logs = kUseMock
              ? mockReadingLogs
              : r.watch(readingLogsProvider).valueOrNull ??
                    const <ReadingLog>[];
          books = r.watch(libraryProvider);
        } else {
          logs =
              r.watch(userReadingLogsProvider(_uid!)).valueOrNull ??
              const <ReadingLog>[];
          books =
              r.watch(userBooksProvider(_uid!)).valueOrNull ?? const <Book>[];
        }
        return LibraryCalendarView(
          logs: logs,
          books: books,
          scrollController: null,
        );
      },
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

class _LibraryDetailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _LibraryDetailHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        8,
        AppTheme.screenPadding,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: context.appTextSecondary,
            style: IconButton.styleFrom(
              backgroundColor: context.appCard,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextPrimary,
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
  final VoidCallback onAddBook;
  final ValueChanged<ReadingStatus> onOpenStatus;
  final VoidCallback onOpenSentences;
  final VoidCallback onOpenStats;
  final VoidCallback onOpenCalendar;
  final VoidCallback? onOpenQuotes;

  const _WatchaLibraryOverview({
    required this.books,
    required this.logs,
    required this.analytics,
    required this.quotes,
    required this.isOwner,
    required this.onAddBook,
    required this.onOpenStatus,
    required this.onOpenSentences,
    required this.onOpenStats,
    required this.onOpenCalendar,
    required this.onOpenQuotes,
  });

  @override
  Widget build(BuildContext context) {
    final readingBooks = books
        .where((b) => b.status == ReadingStatus.reading)
        .toList();
    final reading = books
        .where((b) => b.status == ReadingStatus.reading)
        .length;
    final completed = books
        .where((b) => b.status == ReadingStatus.completed)
        .length;
    final want = books
        .where((b) => b.status == ReadingStatus.wantToRead)
        .length;
    final sentenceCount = books.fold<int>(
      quotes.length,
      (sum, b) => sum + b.savedSentences.length,
    );
    final totalMinutes = logs.fold<int>(0, (sum, l) => sum + l.minutes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LibrarySessionHero(
          book: readingBooks.isNotEmpty
              ? readingBooks.first
              : (books.isNotEmpty ? books.first : null),
          completed: completed,
          sentenceCount: sentenceCount,
          totalMinutes: totalMinutes,
          isOwner: isOwner,
          onAddBook: onAddBook,
          onOpenStatus: onOpenStatus,
        ),
        _ShelfQuickSection(
          reading: reading,
          completed: completed,
          want: want,
          sentenceCount: sentenceCount,
          onOpenStatus: onOpenStatus,
          onOpenSentences: onOpenSentences,
        ),
        _ShelfRailSection(books: books, isOwner: isOwner, onAddBook: onAddBook),
        _TasteAnalysisPreview(
          books: books,
          logs: logs,
          analytics: analytics,
          onTap: onOpenStats,
        ),
        _LikesSection(books: books, quotes: quotes, onOpenQuotes: onOpenQuotes),
        _MonthCalendarPreview(logs: logs, onTap: onOpenCalendar),
        if (isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              4,
              AppTheme.screenPadding,
              28,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onAddBook,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('책 추가'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appTextPrimary,
                  foregroundColor: context.appBg,
                  shape: AppTheme.smoothShape(radius: 10),
                ),
              ),
            ),
          ),
        const SizedBox(height: 96),
      ],
    );
  }
}

class _LibrarySessionHero extends StatelessWidget {
  final Book? book;
  final int completed;
  final int sentenceCount;
  final int totalMinutes;
  final bool isOwner;
  final VoidCallback onAddBook;
  final ValueChanged<ReadingStatus> onOpenStatus;

  const _LibrarySessionHero({
    required this.book,
    required this.completed,
    required this.sentenceCount,
    required this.totalMinutes,
    required this.isOwner,
    required this.onAddBook,
    required this.onOpenStatus,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalMinutes ~/ 60;
    final currentBook = book;
    final progress = currentBook?.readingProgress.clamp(0.0, 1.0) ?? 0.0;
    final isReading = currentBook?.status == ReadingStatus.reading;
    final title = currentBook?.title ?? '아직 비어 있는 서재';
    final subtitle = currentBook == null
        ? '첫 책을 담으면 이곳에서 바로 이어 읽을 수 있어요'
        : (isReading ? '지금 읽는 책' : currentBook.status.label);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        16,
        AppTheme.screenPadding,
        0,
      ),
      child: ForestAccentCard(
        radius: 8,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appPrimaryAccent,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.headingLarge.copyWith(
                      color: context.appPrimaryAccent,
                      letterSpacing: 0,
                    ),
                  ),
                  if (currentBook != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      currentBook.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _HeroMetric(value: '$completed', label: '완독'),
                      const SizedBox(width: 8),
                      _HeroMetric(value: '$sentenceCount', label: '문장'),
                      const SizedBox(width: 8),
                      _HeroMetric(value: '$hours', label: '시간'),
                    ],
                  ),
                  if (currentBook != null && isReading) ...[
                    const SizedBox(height: 18),
                    _HeroProgressBar(value: progress),
                    const SizedBox(height: 6),
                    Text(
                      '${currentBook.currentPage}/${currentBook.totalPages}쪽 · ${(progress * 100).toInt()}%',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  if (currentBook != null || isOwner) ...[
                    const SizedBox(height: 16),
                    _HeroActionButton(
                      label: currentBook == null
                          ? '책 추가'
                          : (isReading && isOwner ? '이어 읽기' : '서재 보기'),
                      icon: currentBook == null
                          ? Icons.add_rounded
                          : (isReading && isOwner
                                ? Icons.play_arrow_rounded
                                : Icons.chevron_right_rounded),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (currentBook == null) {
                          onAddBook();
                          return;
                        }
                        if (isReading && isOwner) {
                          context.push(
                            AppConstants.routeSession,
                            extra: SessionExtra(
                              bookId: currentBook.id,
                              bookTitle: currentBook.title,
                              bookAuthor: currentBook.author,
                              coverUrl: currentBook.coverUrl,
                              startPage: currentBook.currentPage,
                              totalPages: currentBook.totalPages,
                            ),
                          );
                          return;
                        }
                        onOpenStatus(currentBook.status);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 18),
            if (currentBook == null)
              Container(
                width: 94,
                height: 138,
                alignment: Alignment.center,
                decoration: AppTheme.smoothBox(
                  color: context.primaryBg(0.08),
                  radius: 8,
                  side: BorderSide(color: context.appBorderSubtle),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: context.appPrimaryAccent,
                  size: 34,
                ),
              )
            else
              BookCover(
                coverUrl: currentBook.coverUrl,
                gradientIndex: currentBook.title.hashCode.abs(),
                width: 94,
                height: 138,
                radius: 8,
                shadows: [
                  BoxShadow(
                    color: context.appPrimaryAccent.withValues(alpha: 0.12),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: AppTheme.smoothBox(
          color: context.appCardElevated.withValues(alpha: 0.68),
          radius: 8,
          side: BorderSide(color: context.appBorderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
                letterSpacing: 0,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
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

class _HeroActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.black : Colors.white;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: AppTheme.smoothBox(
            color: context.appPrimaryAccent,
            radius: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(color: fg, letterSpacing: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfQuickSection extends StatelessWidget {
  final int reading;
  final int completed;
  final int want;
  final int sentenceCount;
  final ValueChanged<ReadingStatus> onOpenStatus;
  final VoidCallback onOpenSentences;

  const _ShelfQuickSection({
    required this.reading,
    required this.completed,
    required this.want,
    required this.sentenceCount,
    required this.onOpenStatus,
    required this.onOpenSentences,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        icon: Icons.auto_stories_outlined,
        label: '독서 중',
        meta: '이어갈 책',
        value: reading,
        onTap: () => onOpenStatus(ReadingStatus.reading),
      ),
      (
        icon: Icons.check_box_outlined,
        label: '완독',
        meta: '끝까지 읽은 책',
        value: completed,
        onTap: () => onOpenStatus(ReadingStatus.completed),
      ),
      (
        icon: Icons.bookmark_border_rounded,
        label: '읽고 싶음',
        meta: '다음 후보',
        value: want,
        onTap: () => onOpenStatus(ReadingStatus.wantToRead),
      ),
      (
        icon: Icons.notes_rounded,
        label: '문장',
        meta: '수집한 초서',
        value: sentenceCount,
        onTap: onOpenSentences,
      ),
    ];
    return _SectionBand(
      title: '서재 구조',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ShelfQuickTile(item: items[0], highlighted: true),
              ),
              const SizedBox(width: 10),
              Expanded(child: _ShelfQuickTile(item: items[1])),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ShelfQuickTile(item: items[2])),
              const SizedBox(width: 10),
              Expanded(child: _ShelfQuickTile(item: items[3])),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShelfQuickTile extends StatelessWidget {
  final ({
    IconData icon,
    String label,
    String meta,
    int value,
    VoidCallback onTap,
  })
  item;
  final bool highlighted;

  const _ShelfQuickTile({required this.item, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${item.label} ${item.value}',
      button: true,
      child: GestureDetector(
        onTap: item.onTap,
        child: Container(
          height: 96,
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.smoothBox(
            color: highlighted ? context.primaryBg(0.08) : context.appCard,
            radius: 8,
            side: BorderSide(
              color: highlighted
                  ? context.appPrimaryAccent.withValues(alpha: 0.36)
                  : context.appBorderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: AppTheme.smoothBox(
                      color: highlighted
                          ? context.appPrimaryAccent
                          : context.appCardElevated,
                      radius: 7,
                    ),
                    child: Icon(
                      item.icon,
                      size: 16,
                      color: highlighted
                          ? Colors.black
                          : context.appTextTertiary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${item.value}',
                    style: AppTheme.displaySmall.copyWith(
                      color: highlighted
                          ? context.appPrimaryAccent
                          : context.appTextPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextPrimary,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfRailSection extends StatelessWidget {
  final List<Book> books;
  final bool isOwner;
  final VoidCallback onAddBook;

  const _ShelfRailSection({
    required this.books,
    required this.isOwner,
    required this.onAddBook,
  });

  @override
  Widget build(BuildContext context) {
    final reading = books.where((b) => b.status == ReadingStatus.reading);
    final completed = books.where((b) => b.status == ReadingStatus.completed);
    final want = books.where((b) => b.status == ReadingStatus.wantToRead);
    final railBooks = [...reading, ...completed, ...want].take(8).toList();

    return _SectionBand(
      title: '최근 서가',
      child: SizedBox(
        height: 176,
        child: railBooks.isEmpty
            ? _ShelfRailEmpty(isOwner: isOwner, onAddBook: onAddBook)
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: railBooks.length + (isOwner ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == railBooks.length) {
                    return _ShelfRailAddCard(onTap: onAddBook);
                  }
                  return _ShelfRailBookCard(
                    book: railBooks[index],
                    isOwner: isOwner,
                  );
                },
              ),
      ),
    );
  }
}

class _ShelfRailEmpty extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onAddBook;

  const _ShelfRailEmpty({required this.isOwner, required this.onAddBook});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 8,
        side: BorderSide(color: context.appBorderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: AppTheme.smoothBox(
              color: context.primaryBg(0.08),
              radius: 8,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 24,
              color: context.appPrimaryAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isOwner ? '책을 담으면 서재가 여기서 자라나요' : '아직 공개된 책이 없어요',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextSecondary,
                letterSpacing: 0,
              ),
            ),
          ),
          if (isOwner) ...[
            const SizedBox(width: 12),
            _CompactIconButton(
              label: '책 추가',
              icon: Icons.add_rounded,
              onTap: onAddBook,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShelfRailBookCard extends StatelessWidget {
  final Book book;
  final bool isOwner;

  const _ShelfRailBookCard({required this.book, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final progress = book.readingProgress.clamp(0.0, 1.0);
    final isReading = book.status == ReadingStatus.reading;

    return Semantics(
      label: '${book.title}, ${book.author}',
      button: isOwner,
      child: GestureDetector(
        onTap: isOwner
            ? () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeBookDetail, extra: book.id);
              }
            : null,
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  BookCover(
                    coverUrl: book.coverUrl,
                    gradientIndex: book.title.hashCode.abs(),
                    width: 104,
                    height: 146,
                    radius: 8,
                  ),
                  Positioned(
                    left: 7,
                    top: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: AppTheme.smoothBox(
                        color: Colors.black.withValues(alpha: 0.68),
                        radius: 6,
                      ),
                      child: Text(
                        isReading
                            ? '${(progress * 100).toInt()}%'
                            : book.status.label,
                        style: AppTheme.captionSmall.copyWith(
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                  if (isReading)
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 8,
                      child: _HeroProgressBar(value: progress),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextPrimary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelfRailAddCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ShelfRailAddCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '책 추가',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 104,
          height: 146,
          alignment: Alignment.center,
          decoration: AppTheme.smoothBox(
            color: context.primaryBg(0.04),
            radius: 8,
            side: BorderSide(color: context.appBorderSubtle),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 28,
            color: context.appTextTertiary,
          ),
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CompactIconButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.black : Colors.white;
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: AppTheme.smoothBox(
            color: context.appPrimaryAccent,
            radius: 8,
          ),
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}

class _TasteAnalysisPreview extends StatelessWidget {
  final List<Book> books;
  final List<ReadingLog> logs;
  final AnalyticsState? analytics;
  final VoidCallback onTap;

  const _TasteAnalysisPreview({
    required this.books,
    required this.logs,
    required this.analytics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = books.where((b) => b.status == ReadingStatus.completed);
    final favoriteGenre = _topGenre(books);
    final score = analytics?.monthFocusScore ?? 0;
    final activeDays = analytics?.monthReadDays ?? _logDays(logs);
    final label = favoriteGenre == null
        ? '아직 취향을 읽는 중이에요.'
        : '$favoriteGenre 쪽으로 자주 손이 가는 독자예요.';
    final bars = _tasteBars(books, logs);

    return _SectionBand(
      title: '취향분석',
      trailing: _ChevronButton(onTap: onTap),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: AppTheme.smoothBox(
                color: AppTheme.empathyColor.withValues(alpha: 0.12),
                radius: 10,
              ),
              child: Text(
                '#취향분포',
                style: AppTheme.captionSmall.copyWith(
                  color: AppTheme.empathyColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 86,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.asMap().entries.map((entry) {
                  final selected = entry.key == bars.length - 3;
                  return Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: 18 + entry.value * 62,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: AppTheme.smoothBox(
                          color: selected
                              ? AppTheme.empathyColor
                              : AppTheme.empathyColor.withValues(alpha: 0.38),
                          radius: 5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            _AnalysisCta(
              text: '모든 분석 보기',
              meta: '${completed.length}권 완독 · $activeDays일 기록 · 집중 $score',
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _LikesSection extends StatelessWidget {
  final List<Book> books;
  final List<({String content, String bookTitle, String bookAuthor})> quotes;
  final VoidCallback? onOpenQuotes;

  const _LikesSection({
    required this.books,
    required this.quotes,
    required this.onOpenQuotes,
  });

  @override
  Widget build(BuildContext context) {
    final authors = _topAuthors(books).take(3).toList();
    final recentQuotes = quotes.take(4).toList();
    return _SectionBand(
      title: '좋아요',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowLink(title: '좋아한 작가', count: authors.length, onTap: null),
          const SizedBox(height: 14),
          if (authors.isEmpty)
            Text(
              '완독한 책이 쌓이면 자주 읽는 작가가 보여요.',
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextTertiary,
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: authors.length,
                separatorBuilder: (_, _) => const SizedBox(width: 18),
                itemBuilder: (_, index) =>
                    _AuthorBubble(author: authors[index]),
              ),
            ),
          const SizedBox(height: 18),
          _RowLink(title: '좋아한 문장', count: quotes.length, onTap: onOpenQuotes),
          const SizedBox(height: 12),
          if (recentQuotes.isEmpty)
            Text(
              '좋아요한 문장이 이곳에 모여요.',
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextTertiary,
              ),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentQuotes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) =>
                    _QuoteMiniCard(item: recentQuotes[index]),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthCalendarPreview extends StatelessWidget {
  final List<ReadingLog> logs;
  final VoidCallback onTap;

  const _MonthCalendarPreview({required this.logs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLogs = logs
        .where((l) => l.date.year == now.year && l.date.month == now.month)
        .toList();
    final byDay = <int, ReadingLog>{};
    for (final log in monthLogs) {
      byDay.putIfAbsent(log.date.day, () => log);
    }
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;
    final cells = List<int?>.filled(firstWeekday, null, growable: true)
      ..addAll(List.generate(daysInMonth, (i) => i + 1));
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return _SectionBand(
      title: '${now.month}월 캘린더',
      trailing: _ChevronButton(onTap: onTap),
      child: Column(
        children: [
          Row(
            children: const ['일', '월', '화', '수', '목', '금', '토']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
              childAspectRatio: 0.84,
              mainAxisSpacing: 8,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (_, index) {
              final day = cells[index];
              if (day == null) return const SizedBox.shrink();
              final log = byDay[day];
              final isToday = day == now.day;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (log != null)
                    BookCover(
                      coverUrl: log.coverUrl,
                      gradientIndex: log.gradientIndex,
                      width: 32,
                      height: 42,
                      radius: 4,
                    )
                  else
                    SizedBox(
                      height: 42,
                      child: Center(
                        child: Text(
                          '$day',
                          style: AppTheme.bodySmall.copyWith(
                            color: isToday
                                ? AppTheme.empathyColor
                                : context.appTextTertiary.withValues(
                                    alpha: 0.52,
                                  ),
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          _AnalysisCta(
            text: '캘린더 전체 보기',
            meta: '${monthLogs.length}개 기록',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _SectionBand extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionBand({required this.title, required this.child, this.trailing});

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
                  color: context.appPrimaryAccent,
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

class _ChevronButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChevronButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.chevron_right_rounded, size: 30),
      color: context.appTextTertiary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    );
  }
}

class _AnalysisCta extends StatelessWidget {
  final String text;
  final String meta;
  final VoidCallback onTap;

  const _AnalysisCta({
    required this.text,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: AppTheme.smoothBox(
          color: context.appCardElevated,
          radius: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Text(
              meta,
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: context.appTextTertiary),
          ],
        ),
      ),
    );
  }
}

class _RowLink extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onTap;

  const _RowLink({required this.title, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextTertiary,
              fontSize: 18,
            ),
          ),
          if (onTap != null) ...[
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextTertiary,
              size: 28,
            ),
          ],
        ],
      ),
    );
  }
}

class _AuthorBubble extends StatelessWidget {
  final String author;

  const _AuthorBubble({required this.author});

  @override
  Widget build(BuildContext context) {
    final initial = author.characters.isEmpty ? '?' : author.characters.first;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: context.appCardElevated,
            child: Text(
              initial,
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteMiniCard extends StatelessWidget {
  final ({String content, String bookTitle, String bookAuthor}) item;

  const _QuoteMiniCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextPrimary,
                height: 1.45,
              ),
            ),
          ),
          Text(
            item.bookTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

String? _topGenre(List<Book> books) {
  final counts = <String, int>{};
  for (final book in books) {
    final genre = book.genre?.trim();
    if (genre == null || genre.isEmpty) continue;
    counts[genre] = (counts[genre] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

List<String> _topAuthors(List<Book> books) {
  final counts = <String, int>{};
  for (final book in books) {
    final author = book.author.trim();
    if (author.isEmpty) continue;
    counts[author] = (counts[author] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((e) => e.key).toList();
}

int _logDays(List<ReadingLog> logs) {
  return logs
      .map((l) => DateTime(l.date.year, l.date.month, l.date.day))
      .toSet()
      .length;
}

List<double> _tasteBars(List<Book> books, List<ReadingLog> logs) {
  final seed = books.length + logs.length;
  if (seed == 0) return const [0.22, 0.32, 0.42, 0.48, 0.62, 0.92, 0.76, 0.36];
  return List.generate(8, (i) {
    final v = ((seed * (i + 3)) % 9 + 2) / 11;
    return v.clamp(0.18, 0.96);
  });
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
