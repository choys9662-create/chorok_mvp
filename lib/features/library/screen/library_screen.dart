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
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_sort_sheet.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../../home/widget/overlap_section.dart';
import '../../search/util/book_info_navigation.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/library_stats_view.dart';
import '../widget/profile_header.dart';
import '../widget/library_calendar_view.dart';
import '../../../shared/widgets/book_cover.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/moderation_repository.dart';
import '../../../shared/utils/follow_relationship_text.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../profile/controller/user_profile_provider.dart';
import '../util/completed_sort.dart';
import '../../../shared/widgets/chorok_refresh.dart';

typedef _LibraryQuote = ({String content, String bookTitle, String bookAuthor});
typedef _CalendarDaySummary = ({ReadingLog representative, int bookCount});

final readingLogsProvider = FutureProvider<List<ReadingLog>>((ref) async {
  if (kUseMock) return const [];
  // 원격 조회·매핑은 userReadingLogsProvider 하나로 통일. 내 서재는 내 userId.
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const [];
  return ref.watch(userReadingLogsProvider(userId).future);
});

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
  bool? _isBlockedOverride;

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    HapticFeedback.mediumImpact();
    if (kUseMock) {
      setState(() => _isBlockedOverride = !currentlyBlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, currentlyBlocked ? '차단을 해제했어요' : '차단했어요'),
      );
      return;
    }
    try {
      final repo = ref.read(moderationRepositoryProvider);
      if (currentlyBlocked) {
        await repo.unblock(_uid!);
      } else {
        await repo.block(_uid!);
      }
      if (!mounted) return;
      setState(() => _isBlockedOverride = !currentlyBlocked);
      ref.invalidate(userProfileProvider(_uid!));
      ref.invalidate(userBooksProvider(_uid!));
      ref.invalidate(userReadingLogsProvider(_uid!));
      ref.read(blockMutationVersionProvider.notifier).state++;
      ref.read(followMutationVersionProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, currentlyBlocked ? '차단을 해제했어요' : '차단했어요'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, '처리하지 못했어요. 다시 시도해주세요', success: false),
      );
    }
  }

  Future<void> _reportUser() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 유저를 신고할까요?'),
        content: const Text('신고 내용은 운영팀이 확인 후 처리해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('신고'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (kUseMock) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '신고가 접수됐어요'));
      return;
    }
    try {
      await ref
          .read(moderationRepositoryProvider)
          .report(ReportTargetType.user, _uid!);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '신고가 접수됐어요'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '신고를 접수하지 못했어요', success: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kUseMock && _isOwner) {
      ref.listen(readingLogsProvider, (_, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '독서 기록을 불러오지 못했어요',
                style: AppTheme.supportingText.copyWith(
                  color: context.appTextPrimary,
                ),
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
    final isBlocked = _isBlockedOverride ?? viewerData?.isBlocked ?? false;
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
                style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
              ),
              actions: [
                if (kUseMock || viewerData != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: context.appTextSecondary,
                    ),
                    onSelected: (value) {
                      if (value == 'block') _toggleBlock(isBlocked);
                      if (value == 'report') _reportUser();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'block',
                        child: Text(isBlocked ? '차단 해제하기' : '차단하기'),
                      ),
                      const PopupMenuItem(value: 'report', child: Text('신고하기')),
                    ],
                  ),
              ],
            ),
      body: Column(
        children: [
          if (_isOwner) SizedBox(height: topPad),
          // ── 프로필 헤더는 고정하고, 새로고침은 아래 콘텐츠에서만 연다. ──
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
            _ViewerProfileHeader(
              profile: widget.viewedUser!,
              isBlocked: isBlocked,
            ),
          Expanded(
            child: CustomScrollView(
              controller: _isOwner
                  ? ref.read(tabScrollControllersProvider)[3]
                  : null,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                ChorokSliverRefreshControl(onRefresh: _refresh),
                SliverToBoxAdapter(
                  child: isLocked
                      ? const _PrivateLibraryLock()
                      : _buildOverviewTab(viewerData),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    if (_isOwner) {
      ref.invalidate(readingLogsProvider);
      await Future.wait<void>([
        ref.read(libraryProvider.notifier).reload(),
        ref.read(readingLogsProvider.future).then<void>((_) {}),
      ]);
    } else {
      ref.invalidate(userProfileProvider(_uid!));
      ref.invalidate(userBooksProvider(_uid!));
      await Future.wait<void>([
        ref.read(userProfileProvider(_uid!).future).then<void>((_) {}),
        ref.read(userBooksProvider(_uid!).future).then<void>((_) {}),
      ]);
    }
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
            if (_isOwner && status == ReadingStatus.completed) {
              ctx.push(AppConstants.routeCompletedBooks);
              return;
            }
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
      backgroundColor: context.appCard,
      shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
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
      backgroundColor: context.appCard,
      shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
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
      backgroundColor: context.appCard,
      shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
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
          ChorokSheetHeader(
            title: title,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXL),
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
          ChorokSheetHeader(
            title: '기록한 문장',
            secondary: '${sentences.length}',
            onClose: () => Navigator.of(context).pop(),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.spaceMD,
                      AppTheme.screenPadding,
                      AppTheme.spaceXL,
                    ),
                    itemCount: sentences.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spaceSM),
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
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      showBorder: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceMD,
        children: [
          Text(
            item.content,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary,
              height: 1.45,
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 14,
                color: context.appTextTertiary,
              ),
              const SizedBox(width: AppTheme.spaceXS),
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
          ChorokSheetHeader(
            title: '겹문장',
            secondary: '${overlaps.length}',
            onClose: () => Navigator.of(context).pop(),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.spaceMD,
                      AppTheme.screenPadding,
                      AppTheme.spaceXL,
                    ),
                    itemCount: overlaps.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spaceSM),
                    itemBuilder: (_, index) =>
                        OverlapCard(overlap: overlaps[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class CompletedBooksScreen extends ConsumerStatefulWidget {
  const CompletedBooksScreen({super.key});

  @override
  ConsumerState<CompletedBooksScreen> createState() =>
      _CompletedBooksScreenState();
}

class _CompletedBooksScreenState extends ConsumerState<CompletedBooksScreen> {
  _LibraryViewMode _viewMode = _LibraryViewMode.list;
  CompletedSort _sort = CompletedSort.recent;

  Future<void> _showSortSheet() async {
    final picked = await showChorokSortSheet<CompletedSort>(
      context: context,
      title: '정렬',
      selected: _sort,
      options: [
        for (final sort in CompletedSort.values)
          ChorokSortOption(sort, sort.label),
      ],
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final books =
        ref
            .watch(libraryProvider)
            .where((book) => book.status == ReadingStatus.completed)
            .toList()
          ..sort((a, b) => compareCompletedBooks(_sort, a, b));

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceXL,
                  AppTheme.spaceXL,
                  AppTheme.spaceXL,
                  AppTheme.spaceXL,
                ),
                child: Row(
                  children: [
                    _CompletedIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      label: '뒤로',
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: '완독  '),
                          TextSpan(
                            text: '${books.length}',
                            style: AppTheme.screenTitle.copyWith(
                              color: context.appPrimaryAccent,
                            ),
                          ),
                        ],
                      ),
                      style: AppTheme.headingLarge.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: AppTheme.spaceXL),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceXL,
                  0,
                  AppTheme.spaceXL,
                  AppTheme.spaceSM,
                ),
                child: _CompletedViewSwitch(
                  mode: _viewMode,
                  sortLabel: _sort.label,
                  onSortTap: _showSortSheet,
                  onChanged: (mode) {
                    HapticFeedback.selectionClick();
                    setState(() => _viewMode = mode);
                  },
                ),
              ),
            ),
            if (books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CompletedEmpty(),
              )
            else if (_viewMode == _LibraryViewMode.list)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  0,
                  AppTheme.screenPadding,
                  AppTheme.spaceXL * 4 + AppTheme.spaceLG,
                ),
                sliver: SliverList.separated(
                  itemCount: books.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spaceSM),
                  itemBuilder: (_, index) => _CompletedListRow(
                    book: books[index],
                    muted: index % 3 == 2,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceXL,
                  0,
                  AppTheme.spaceXL,
                  AppTheme.spaceXL * 4 + AppTheme.spaceLG,
                ),
                sliver: SliverGrid.builder(
                  itemCount: books.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.44,
                    crossAxisSpacing: AppTheme.spaceSM,
                    mainAxisSpacing: AppTheme.sectionGap,
                  ),
                  itemBuilder: (_, index) =>
                      _CompletedGridTile(book: books[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompletedIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CompletedIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: context.appTextSecondary, size: 20),
        ),
      ),
    );
  }
}

class _CompletedViewSwitch extends StatelessWidget {
  final _LibraryViewMode mode;
  final String sortLabel;
  final VoidCallback onSortTap;
  final ValueChanged<_LibraryViewMode> onChanged;

  const _CompletedViewSwitch({
    required this.mode,
    required this.sortLabel,
    required this.onSortTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isGrid = mode == _LibraryViewMode.grid;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Semantics(
            label: '정렬 기준: $sortLabel, 변경하려면 누르세요',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSortTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sortLabel,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextSecondary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXS),
                  Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: context.appTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _ViewSwitchButton(
            icon: Icons.view_module_rounded,
            selected: isGrid,
            onTap: () => onChanged(_LibraryViewMode.grid),
          ),
          _ViewSwitchButton(
            icon: Icons.view_list_rounded,
            selected: !isGrid,
            onTap: () => onChanged(_LibraryViewMode.list),
          ),
        ],
      ),
    );
  }
}

class _ViewSwitchButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ViewSwitchButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 24,
        child: Icon(
          icon,
          size: 22,
          color: selected
              ? context.appTextPrimary
              : context.appTextTertiary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _CompletedListRow extends StatelessWidget {
  final Book book;
  final bool muted;

  const _CompletedListRow({required this.book, required this.muted});

  @override
  Widget build(BuildContext context) {
    final checkColor = muted
        ? context.appTextTertiary.withValues(alpha: 0.65)
        : context.appPrimaryAccent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        pushBookInfo(context, book);
      },
      child: SizedBox(
        height: 88,
        child: ChorokCard(
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          showBorder: false,
          child: Row(
            children: [
              BookCover(
                coverUrl: book.coverUrl,
                gradientIndex: book.title.hashCode.abs(),
                width: 50,
                height: 68,
                radius: AppTheme.radiusInner,
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.rowText.copyWith(
                        color: context.appTextPrimary,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextSecondary,
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _shortDate(book.completedAt),
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: checkColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 17,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletedGridTile extends StatelessWidget {
  final Book book;

  const _CompletedGridTile({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        pushBookInfo(context, book);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.68,
            child: BookCover(
              coverUrl: book.coverUrl,
              gradientIndex: book.title.hashCode.abs(),
              radius: AppTheme.radiusInner,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.body.copyWith(
              color: context.appTextPrimary,
              height: 1.18,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            book.author,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextSecondary,
              height: 1.2,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedEmpty extends StatelessWidget {
  const _CompletedEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '아직 완독한 책이 없어요',
        style: AppTheme.bodyMedium.copyWith(color: context.appTextSecondary),
      ),
    );
  }
}

String _shortDate(DateTime? date) {
  if (date == null) return '';
  final yy = (date.year % 100).toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yy.$mm.$dd';
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
        _ReadingNowCard(
          books: books,
          isOwner: isOwner,
          onAddBook: onAddBook,
          onOpenAll: () => onOpenStatus(ReadingStatus.reading),
        ),
        const SizedBox(height: AppTheme.spaceLG),
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
        const SizedBox(height: AppTheme.spaceXL * 4),
      ],
    );
  }
}

class _HeroProgressBar extends StatelessWidget {
  final double value;

  const _HeroProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ChorokProgressBar(value: value);
  }
}

// ─── 읽고 있는 책 카드 ─────────────────────────────────────────────────────
class _ReadingNowCard extends StatelessWidget {
  final List<Book> books;
  final bool isOwner;
  final VoidCallback onAddBook;
  final VoidCallback onOpenAll;

  const _ReadingNowCard({
    required this.books,
    required this.isOwner,
    required this.onAddBook,
    required this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final reading = books
        .where((b) => b.status == ReadingStatus.reading)
        .toList();
    final visible = reading.take(3).toList();
    return _SectionBand(
      title: '읽고 있는 책',
      titleColor: context.appPrimaryAccent,
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.cardPaddingInner),
        showBorder: false,
        child: reading.isEmpty
            ? _ReadingNowEmpty(isOwner: isOwner, onAddBook: onAddBook)
            : Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    ChorokCard(
                      inner: true,
                      showBorder: false,
                      padding: const EdgeInsets.all(AppTheme.cardPaddingInner),
                      child: _ReadingNowRow(book: visible[i]),
                    ),
                    if (i != visible.length - 1)
                      const SizedBox(height: AppTheme.spaceSM),
                  ],
                  if (reading.length > visible.length) ...[
                    const SizedBox(height: AppTheme.spaceSM),
                    Semantics(
                      button: true,
                      label: '읽고 있는 책 전체보기',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpenAll,
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: Text(
                              '전체보기',
                              style: AppTheme.rowText.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
        SizedBox(
          width: 44,
          height: 62,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            backgroundColor: context.primaryBg(0.08),
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(
                Icons.auto_stories_rounded,
                size: 22,
                color: context.appPrimaryAccent,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMD),
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
            child: SizedBox(
              width: 38,
              height: 38,
              child: ChorokCard(
                showBorder: false,
                backgroundColor: context.appPrimaryAccent,
                padding: EdgeInsets.zero,
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
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
          pushBookInfo(context, book);
        },
        child: Row(
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              gradientIndex: book.title.hashCode.abs(),
              width: 52,
              height: 72,
              radius: AppTheme.radiusInner,
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.rowText.copyWith(
                      color: context.appTextPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    book.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextSecondary,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    children: [
                      Expanded(child: _HeroProgressBar(value: progress)),
                      if (remaining > 0) ...[
                        const SizedBox(width: AppTheme.spaceSM),
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
            const SizedBox(width: AppTheme.spaceSM),
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
    final tiles =
        <({String label, int value, VoidCallback onTap, bool active})>[
          (
            label: '완독',
            value: completed,
            onTap: () => onOpenStatus(ReadingStatus.completed),
            active: false,
          ),
          (
            label: '문장',
            value: sentenceCount,
            onTap: onOpenSentences,
            active: false,
          ),
          (
            label: '겹문장',
            value: overlapCount,
            onTap: onOpenOverlaps,
            active: false,
          ),
          (
            label: '모두의 문장',
            value: reading,
            onTap: () => onOpenStatus(ReadingStatus.reading),
            active: true,
          ),
        ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: _StatTile(item: tiles[i])),
            if (i != tiles.length - 1) const SizedBox(width: AppTheme.spaceSM),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final ({String label, int value, VoidCallback onTap, bool active}) item;

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
        child: SizedBox(
          height: 76,
          child: ChorokCard(
            backgroundColor: item.active
                ? context.appPrimaryAccent
                : context.appCard,
            borderColor: item.active
                ? context.appPrimaryAccent
                : context.appBorderSubtle,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: AppTheme.spaceMD,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppTheme.spaceSM,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(
                    color: item.active
                        ? AppTheme.primary
                        : context.appTextTertiary,
                    letterSpacing: 0,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${item.value}',
                    style: AppTheme.sectionTitle.copyWith(
                      color: item.active
                          ? AppTheme.primary
                          : context.appTextPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
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
        AppTheme.spaceXL,
        AppTheme.screenPadding,
        0,
      ),
      child: ChorokCard(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceMD,
          AppTheme.spaceMD,
          AppTheme.spaceLG,
        ),
        showBorder: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CalNavArrow(icon: Icons.chevron_left_rounded, onTap: _prev),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLG,
                  ),
                  child: Text(
                    '${_month.month}월',
                    style: AppTheme.sectionTitle.copyWith(
                      color: context.appPrimaryAccent,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                _CalNavArrow(icon: Icons.chevron_right_rounded, onTap: _next),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Row(
              children: AppConstants.weekdaysSunFirst
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTheme.caption.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.74,
                mainAxisSpacing: AppTheme.spaceXS,
                crossAxisSpacing: AppTheme.spaceXS,
              ),
              itemBuilder: (_, index) {
                final day = cells[index];
                if (day == null) return const SizedBox.shrink();
                final summary = byDay[day];
                final isToday = isCurrentMonth && day == now.day;
                return GestureDetector(
                  onTap: widget.onTap,
                  behavior: HitTestBehavior.opaque,
                  child: ChorokCard(
                    inner: true,
                    padding: EdgeInsets.zero,
                    showBorder: isToday,
                    borderColor: context.appPrimaryAccent,
                    child: summary != null
                        ? Semantics(
                            label: summary.bookCount > 1
                                ? '$day일, ${summary.bookCount}권 읽음'
                                : '$day일, 1권 읽음',
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(
                                    AppTheme.spaceXS,
                                  ),
                                  child: BookCover(
                                    coverUrl: summary.representative.coverUrl,
                                    gradientIndex:
                                        summary.representative.gradientIndex,
                                    radius: AppTheme.radiusInner,
                                  ),
                                ),
                                if (summary.bookCount > 1)
                                  Positioned(
                                    top: AppTheme.spaceXS,
                                    right: AppTheme.spaceXS,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth:
                                            AppTheme.spaceLG + AppTheme.spaceXS,
                                        minHeight:
                                            AppTheme.spaceLG + AppTheme.spaceXS,
                                      ),
                                      child: ChorokCard(
                                        inner: true,
                                        backgroundColor: AppTheme.primary
                                            .withValues(alpha: 0.78),
                                        borderColor: context.appTextPrimary
                                            .withValues(alpha: 0.72),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spaceXS,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+${summary.bookCount - 1}',
                                            style: AppTheme.caption.copyWith(
                                              color: context.appTextPrimary,
                                              height: 1,
                                            ),
                                          ),
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
                              style: AppTheme.supportingText.copyWith(
                                color: isToday
                                    ? context.appPrimaryAccent
                                    : context.appTextTertiary.withValues(
                                        alpha: 0.48,
                                      ),
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
          const SizedBox(width: AppTheme.spaceXS),
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
      trailing: _DetailLink(onTap: onTap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceSM,
        children: [
          _InsightMetricRow(
            icon: Icons.schedule_rounded,
            label: '총 독서 시간',
            value: _formatMinutes(totalMinutes),
          ),
          _InsightMetricRow(
            icon: Icons.calendar_today_outlined,
            label: '독서한 날',
            value: '$activeDays일',
          ),
          _InsightMetricRow(
            icon: Icons.timelapse_rounded,
            label: '일일 평균 독서 시간',
            value: _formatMinutes(averageMinutes),
          ),
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
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 70),
        child: ChorokCard(
          showBorder: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPaddingMD,
            vertical: AppTheme.spaceMD,
          ),
          child: ChorokListRow(
            leading: Icon(icon, size: 17, color: context.appTextTertiary),
            title: Text(
              label,
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
                letterSpacing: 0,
              ),
            ),
            trailing: Text(
              value,
              style: AppTheme.sectionTitle.copyWith(
                color: context.appTextPrimary,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
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
  final Color? titleColor;

  const _SectionBand({
    required this.title,
    required this.child,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.sectionGap,
        AppTheme.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceMD,
        children: [
          ChorokSectionHeader(
            title: title,
            trailing: trailing,
            titleColor: titleColor,
          ),
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

  Future<void> _showSortSheet(BuildContext context) async {
    final picked = await showChorokSortSheet<_SortOption>(
      context: context,
      title: '정렬',
      selected: _sortOption,
      options: [
        for (final opt in _SortOption.values)
          ChorokSortOption(opt, opt.label),
      ],
    );
    if (picked != null && mounted) setState(() => _sortOption = picked);
  }

  @override
  Widget build(BuildContext context) {
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
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceMD)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: _MonthlyAchievementCard(userId: widget.viewedUserId),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceLG)),

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
                  ChorokCard(
                    inner: true,
                    showBorder: false,
                    backgroundColor: context.appPrimaryAccent.withValues(
                      alpha: 0.1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSM,
                      vertical: AppTheme.spaceXS,
                    ),
                    child: Text(
                      '${widget.books.length}권',
                      style: AppTheme.caption.copyWith(
                        color: context.appPrimaryAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSM),
                  Semantics(
                    label: '정렬 방식 변경',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showSortSheet(context);
                      },
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          padding: EdgeInsets.zero,
                          backgroundColor: _sortOption != _SortOption.recent
                              ? AppTheme.primary.withValues(alpha: 0.3)
                              : context.appCardElevated,
                          child: Icon(
                            Icons.sort_rounded,
                            size: 16,
                            color: _sortOption != _SortOption.recent
                                ? AppTheme.primaryLight
                                : context.appTextTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXS),
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
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          padding: EdgeInsets.zero,
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
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceMD)),

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
                      right: status != ReadingStatus.values.last
                          ? AppTheme.spaceSM
                          : 0,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedStatus = status);
                      },
                      child: SizedBox(
                        height: 40,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          backgroundColor: isSelected
                              ? AppTheme.primary
                              : context.appCardElevated,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceLG,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(status),
                                size: 14,
                                color: isSelected
                                    ? context.appTextPrimary
                                    : context.appTextTertiary,
                              ),
                              const SizedBox(width: AppTheme.spaceXS),
                              Text(
                                '${status.label} $count',
                                style: AppTheme.caption.copyWith(
                                  color: isSelected
                                      ? context.appTextPrimary
                                      : context.appTextTertiary,
                                ),
                              ),
                            ],
                          ),
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
                        child: Icon(
                          Icons.add_rounded,
                          color: context.appTextPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceXS)),

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
                crossAxisSpacing: AppTheme.spaceMD,
                mainAxisSpacing: AppTheme.spaceMD,
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
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spaceSM),
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
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          backgroundColor: context.appPrimaryAccent.withValues(
                            alpha: 0.10,
                          ),
                          padding: EdgeInsets.zero,
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: context.appPrimaryAccent,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceSM),
                      Text(
                        item.value,
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXS),
                      Text(
                        item.label,
                        style: AppTheme.caption.copyWith(
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
                  const SizedBox(width: AppTheme.spaceXS),
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

  /// 내 서재 여부. false면 이어읽기 같은 소유자 전용 동작만 비활성한다.
  final bool isOwner;

  const _BookCard({required this.book, this.isOwner = true});

  @override
  Widget build(BuildContext context) {
    final isCompleted = book.status == ReadingStatus.completed;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        pushBookInfo(context, book);
      },
      child: ChorokCard(
        showBorder: false,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                  ),
                  // ── 완독 배지 ──────────────────────────────────
                  if (isCompleted)
                    Positioned(
                      top: AppTheme.spaceSM,
                      right: AppTheme.spaceSM,
                      child: Container(
                        padding: const EdgeInsets.all(AppTheme.spaceXS),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                  // ── 초서 수 뱃지 ──────────────────────────────
                  if (book.savedSentences.isNotEmpty)
                    Positioned(
                      bottom: AppTheme.spaceSM,
                      left: AppTheme.spaceSM,
                      child: ChorokCard(
                        inner: true,
                        showBorder: false,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.88,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSM,
                          vertical: AppTheme.spaceXS,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 10,
                              color: context.appTextPrimary,
                            ),
                            const SizedBox(width: AppTheme.spaceXS),
                            Text(
                              '${book.savedSentences.length}',
                              style: AppTheme.caption.copyWith(
                                color: context.appTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.rowText.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    book.author,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  if (book.status == ReadingStatus.reading) ...[
                    const SizedBox(height: AppTheme.spaceSM),
                    ChorokProgressBar(
                      value: book.readingProgress,
                      trackColor: context.appBorder,
                      valueColor: context.appPrimaryAccent,
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Row(
                      children: [
                        Text(
                          '${(book.readingProgress * 100).toInt()}%',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
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
                        padding: const EdgeInsets.only(top: AppTheme.spaceXS),
                        child: Text(
                          est,
                          style: AppTheme.caption.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ),
                    if (isOwner) ...[
                      const SizedBox(height: AppTheme.spaceSM),
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
                          child: SizedBox(
                            height: 48,
                            child: ChorokCard(
                              inner: true,
                              showBorder: false,
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.5,
                              ),
                              padding: EdgeInsets.zero,
                              child: Center(
                                child: Text(
                                  '이어 읽기  ${(book.readingProgress * 100).toInt()}%',
                                  style: AppTheme.rowText.copyWith(
                                    color: AppTheme.primaryLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (book.status == ReadingStatus.completed &&
                      book.totalReadingHours > 0) ...[
                    const SizedBox(height: AppTheme.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 11,
                          color: context.appTextTertiary,
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        Text(
                          '${book.totalReadingHours.toStringAsFixed(1)}시간',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                        if (book.savedSentences.isNotEmpty) ...[
                          const SizedBox(width: AppTheme.spaceSM),
                          Icon(
                            Icons.format_quote_rounded,
                            size: 11,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(width: AppTheme.spaceXS),
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

  /// 내 서재 여부. false면 이어읽기 같은 소유자 전용 동작만 비활성한다.
  final bool isOwner;

  const _BookListTile({required this.book, this.isOwner = true});

  @override
  Widget build(BuildContext context) {
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;

    return Semantics(
      label: '${book.title}, ${book.author}',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          pushBookInfo(context, book);
        },
        child: ChorokCard(
          showBorder: false,
          padding: const EdgeInsets.all(AppTheme.spaceMD),
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
                radius: AppTheme.radiusInner,
              ),
              const SizedBox(width: AppTheme.spaceMD),
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
                            style: AppTheme.body.copyWith(
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          const SizedBox(width: AppTheme.spaceXS),
                          Container(
                            padding: const EdgeInsets.all(AppTheme.spaceXS),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      book.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    if (isReading) ...[
                      ChorokProgressBar(
                        value: book.readingProgress,
                        trackColor: context.appBorder,
                        valueColor: context.appPrimaryAccent,
                      ),
                      const SizedBox(height: AppTheme.spaceXS),
                      Row(
                        children: [
                          Text(
                            '${(book.readingProgress * 100).toInt()}%',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceXS),
                          Text(
                            '${book.currentPage}/${book.totalPages}쪽',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                          if (_estimateCompletion(book) case final est?) ...[
                            const SizedBox(width: AppTheme.spaceXS),
                            Flexible(
                              child: Text(
                                '· $est',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.caption.copyWith(
                                  color: context.appTextTertiary,
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
                            const SizedBox(width: AppTheme.spaceXS),
                            Text(
                              '${book.totalReadingHours.toStringAsFixed(1)}시간',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
                          if (book.savedSentences.isNotEmpty) ...[
                            const SizedBox(width: AppTheme.spaceSM),
                            Icon(
                              Icons.format_quote_rounded,
                              size: 11,
                              color: context.appTextTertiary,
                            ),
                            const SizedBox(width: AppTheme.spaceXS),
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
                const SizedBox(width: AppTheme.spaceSM),
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
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: ChorokCard(
                        inner: true,
                        showBorder: false,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.5,
                        ),
                        padding: EdgeInsets.zero,
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: AppTheme.primaryLight,
                        ),
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

// ─── 다른 사용자 서재 헤더 (읽기 전용 + 팔로우 버튼) ───────────────────────
class _ViewerProfileHeader extends ConsumerStatefulWidget {
  final UserProfile profile;
  final bool isBlocked;

  const _ViewerProfileHeader({required this.profile, required this.isBlocked});

  @override
  ConsumerState<_ViewerProfileHeader> createState() =>
      _ViewerProfileHeaderState();
}

class _ViewerProfileHeaderState extends ConsumerState<_ViewerProfileHeader> {
  FollowRelationship? _relationshipOverride;
  bool _busy = false;

  @override
  void didUpdateWidget(_ViewerProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBlocked != widget.isBlocked) {
      _relationshipOverride = FollowRelationship.none;
    }
  }

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
              color: filled ? AppTheme.primary : context.appTextSecondary,
            ),
          )
        : Text(label, style: AppTheme.body);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceLG,
        AppTheme.screenPadding,
        0,
      ),
      child: ChorokCard(
        showBorder: false,
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
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
                const SizedBox(width: AppTheme.spaceLG),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.displayName,
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceXS),
                      Text(
                        '@${p.username}',
                        style: AppTheme.supportingText.copyWith(
                          color: context.appTextSecondary,
                          height: 1.4,
                        ),
                      ),
                      if (followRelationshipHint(relationship)
                          case final hint?) ...[
                        const SizedBox(height: AppTheme.spaceXS),
                        Text(
                          hint,
                          style: AppTheme.supportingText.copyWith(
                            color: context.appPrimaryAccent,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                if (!widget.isBlocked)
                  SizedBox(
                    height: 40,
                    child: filled
                        ? FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _toggleFollow(relationship),
                            style: FilledButton.styleFrom(
                              backgroundColor: context.appPrimaryAccent,
                              foregroundColor: AppTheme.primary,
                              disabledBackgroundColor: context.appPrimaryAccent
                                  .withValues(alpha: 0.45),
                              shape: AppTheme.smoothShape(
                                radius: AppTheme.radiusInner,
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
                              shape: AppTheme.smoothShape(
                                radius: AppTheme.radiusInner,
                              ),
                            ),
                            child: buttonChild(),
                          ),
                  ),
              ],
            ),
            if (p.bio != null && p.bio!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceMD),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  p.bio!,
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
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
      padding: const EdgeInsets.only(
        top: AppTheme.sectionGap * 2,
        left: AppTheme.spaceXL,
        right: AppTheme.spaceXL,
      ),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: AppTheme.spaceLG),
          Text(
            '비공개 계정이에요',
            style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '팔로우가 수락되면 서재를 볼 수 있어요',
            style: AppTheme.supportingText.copyWith(
              color: context.appTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── 책 추가 바텀시트 ─────────────────────────────────────────────────────
