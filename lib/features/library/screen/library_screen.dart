import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../home/widget/session_goal_sheet.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/profile_header.dart';
import '../widget/library_calendar_view.dart';
import '../widget/library_stats_view.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

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
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      body: NestedScrollView(
          controller: ref.read(tabScrollControllersProvider)[3],
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: SizedBox(height: topPad)),
            // ── 프로필 + 설정 ───────────────────────────────────
            SliverToBoxAdapter(
              child: Consumer(
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
            ),

            // ── 수집한 문장 전체 보기 버튼 ──────────────────────
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, _) {
                  final choseoCount = ref.watch(choseoCountProvider);
                  final label = choseoCount.when(
                    data: (n) => '수집한 문장 전체 보기 ($n개)',
                    loading: () => '수집한 문장 전체 보기',
                    error: (_, _) => '수집한 문장 전체 보기',
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      8,
                      AppTheme.screenPadding,
                      0,
                    ),
                    child: Semantics(
                      label: label,
                      button: true,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push(AppConstants.routeChoseoList);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: ShapeDecoration(
                              color: context.appCard,
                              shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                  cornerRadius: 12,
                                  cornerSmoothing: 0.6,
                                ),
                                side: BorderSide(
                                  color: context.appAccentColor.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.format_quote_rounded,
                                  color: context.appAccentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'Pretendard',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: context.appTextPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.appTextTertiary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            // ── 세그먼트 토글 — 헤더와 함께 스크롤 ────────────
            SliverToBoxAdapter(
              child: Padding(
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
            ),
          ],
          body: IndexedStack(
            index: _viewIndex,
            children: [
              Consumer(
                builder: (ctx, r, _) {
                  final books = r.watch(libraryProvider);
                  return _LibraryTab(
                    books: books,
                    onAddBook: () => ctx.push(AppConstants.routeSearch),
                  );
                },
              ),
              LibraryStatsView(
                scrollController: ref.read(tabScrollControllersProvider)[5],
              ),
              LibraryCalendarView(
                logs: _useMock ? mockReadingLogs : const [],
                scrollController: ref.read(tabScrollControllersProvider)[4],
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
  final VoidCallback onAddBook;

  const _LibraryTab({
    required this.books,
    required this.onAddBook,
  });

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  ReadingStatus _selectedStatus = ReadingStatus.reading;
  _LibraryViewMode _viewMode = _LibraryViewMode.grid;
  _SortOption _sortOption = _SortOption.recent;

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
    final logs = _useMock ? mockReadingLogs : const <ReadingLog>[];
    final todayMinutes = logs
        .where(
          (l) =>
              l.date.year == now.year &&
              l.date.month == now.month &&
              l.date.day == now.day,
        )
        .fold<int>(0, (a, l) => a + l.minutes);
    final readingBooks = widget.books
        .where((b) => b.status == ReadingStatus.reading)
        .toList();

    return CustomScrollView(
      slivers: [
        // ── 이번 달 성과 뱃지 ──────────────────────────────────────
        if (_useMock)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding, 12,
              AppTheme.screenPadding, 0,
            ),
            child: const _MonthlyAchievementCard(),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── 섹션 헤더 ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: ChorokSectionHeader(
              title: '서재',
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 정렬 버튼
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
                              ? (isDark ? AppTheme.primaryLight : AppTheme.lightPrimaryAccent)
                              : context.appTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 뷰 전환 버튼
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
                  final count = widget.books
                      .where((b) => b.status == status)
                      .length;
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
                          side: BorderSide(
                            color: isSelected
                                ? context.appPrimaryAccent.withValues(alpha: 0.3)
                                : context.appBorder,
                          ),
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
                                fontFamily: 'Pretendard',
                                color: isSelected
                                    ? Colors.white
                                    : context.appTextTertiary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
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
                // 책 추가 동그란 버튼
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

        // ── 오늘의 독서 목표 배너 (읽는 중 탭에서만) ────────────────
        if (_selectedStatus == ReadingStatus.reading) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: _TodayGoalBanner(
                todayMinutes: todayMinutes,
                goalMinutes: 30,
                firstReadingBook: readingBooks.isEmpty
                    ? null
                    : readingBooks.first,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 4)),

        // ── 책 그리드 / 리스트 / 빈 상태 ─────────────────────────────
        if (_filteredBooks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyShelf(status: _selectedStatus),
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

        // ── 읽고 싶은 책 (wantToRead 탭 선택 시 중복 방지로 숨김) ──
        if (_selectedStatus != ReadingStatus.wantToRead) ...[
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceXL)),
          const SliverToBoxAdapter(child: _LibraryWishlistSection()),
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceXL)),
        ],
      ],
    );
  }
}

// ─── 이번 달 독서 성과 뱃지 ──────────────────────────────────────────────────
class _MonthlyAchievementCard extends StatelessWidget {
  const _MonthlyAchievementCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.menu_book_rounded, value: '2권', label: '이번 달 완독'),
      (icon: Icons.local_fire_department_rounded, value: '5일', label: '최장 연속'),
      (icon: Icons.format_quote_rounded, value: '47개', label: '수집 문장'),
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
                          color: context.appPrimaryAccent.withValues(alpha: 0.10),
                          radius: AppTheme.radiusMD,
                          side: BorderSide(
                            color: context.appPrimaryAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(item.icon, size: 18, color: context.appPrimaryAccent),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: AppTheme.headingSmall.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: AppTheme.captionSmall.copyWith(
                          fontFamily: 'Pretendard',
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
                  Container(width: 1, height: 48, color: context.appBorder),
              ];
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── 읽고 싶은 책 섹션 ────────────────────────────────────────────────────────

class _LibraryWishlistSection extends ConsumerWidget {
  const _LibraryWishlistSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref
        .watch(libraryProvider)
        .where((b) => b.status == ReadingStatus.wantToRead)
        .toList();

    if (books.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChorokSectionHeader(
            title: '읽고 싶은 책',
            trailing: Text(
              '${books.length}권',
              style: AppTheme.captionLarge.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ChorokCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: books.asMap().entries.map((e) {
                final isLast = e.key == books.length - 1;
                return Column(
                  children: [
                    _WishlistListCard(book: e.value),
                    if (!isLast)
                      Divider(height: 1, color: context.appBorder, indent: 64),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistListCard extends StatefulWidget {
  final Book book;
  const _WishlistListCard({required this.book});

  @override
  State<_WishlistListCard> createState() => _WishlistListCardState();
}

class _WishlistListCardState extends State<_WishlistListCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors = AppTheme.coverGradients[
        b.id.hashCode.abs() % AppTheme.coverGradients.length];

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedOpacity(
        opacity: _isPressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPaddingMD,
            vertical: AppTheme.spaceMD,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradColors,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.author,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: '${b.title} 읽기 시작',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final goal = await showModalBottomSheet<SessionGoal>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SessionGoalSheet(
                          currentPage: 0,
                          totalPages: b.totalPages,
                          bookTitle: b.title,
                        ),
                      );
                      if (goal != null && context.mounted) {
                        context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            goal: goal,
                            bookId: b.id,
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: 0,
                            totalPages: b.totalPages,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: AppTheme.smoothBox(
                        color: context.appPrimaryAccent,
                        radius: AppTheme.radiusSM,
                      ),
                      child: Text(
                        '읽기 시작',
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

// ─── 커버 플레이스홀더 ────────────────────────────────────────────────────
class _CoverPlaceholder extends StatelessWidget {
  final String bookId;
  const _CoverPlaceholder({required this.bookId});

  @override
  Widget build(BuildContext context) {
    final gradColors = AppTheme
        .coverGradients[bookId.hashCode.abs() % AppTheme.coverGradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: Colors.white,
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
        _showBookDetail(context, book);
      },
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 30,
          side: BorderSide(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipPath(
                clipper: ShapeBorderClipper(
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius.only(
                      topLeft: const SmoothRadius(cornerRadius: 29, cornerSmoothing: 1.0),
                      topRight: const SmoothRadius(cornerRadius: 29, cornerSmoothing: 1.0),
                    ),
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ── 배경 (커버 or 그라디언트 플레이스홀더) ─────
                    if (book.coverUrl != null && book.coverUrl!.isNotEmpty)
                      Image.network(
                        book.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _CoverPlaceholder(bookId: book.id),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : _CoverPlaceholder(bookId: book.id),
                      )
                    else
                      _CoverPlaceholder(bookId: book.id),
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
                            side: BorderSide(
                              color: context.appPrimaryAccent.withValues(
                                alpha: 0.3,
                              ),
                            ),
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
                                  fontFamily: 'Pretendard',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
                      fontSize: 14,
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
                      borderRadius: BorderRadius.circular(3),
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
                            fontWeight: FontWeight.w600,
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
                              startPage: book.currentPage,
                              totalPages: book.totalPages,
                            ),
                          );
                        },
                        child: Container(
                          height: 32,
                          alignment: Alignment.center,
                          decoration: AppTheme.smoothPill(
                            color: isDark
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.lightPrimaryAccent,
                            side: BorderSide(
                              color: context.appPrimaryAccent.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            '이어 읽기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.primaryLight : Colors.white,
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

// ─── 오늘의 독서 목표 배너 ────────────────────────────────────────────────
class _TodayGoalBanner extends StatelessWidget {
  final int todayMinutes;
  final int goalMinutes;
  final Book? firstReadingBook;

  const _TodayGoalBanner({
    required this.todayMinutes,
    required this.goalMinutes,
    this.firstReadingBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = todayMinutes >= goalMinutes;
    final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);

    if (isCompleted) {
      // 달성 상태
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.smoothBox(
          color: context.appPrimaryAccent.withValues(alpha: 0.08),
          radius: AppTheme.radiusLG,
          side: BorderSide(color: context.appPrimaryAccent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: AppTheme.smoothBox(
                color: context.appPrimaryAccent.withValues(alpha: 0.15),
                radius: 10,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: context.appPrimaryAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 목표 달성!',
                    style: AppTheme.bodySmall.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatMinutes(todayMinutes)} 독서했어요 · 목표 $goalMinutes분',
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appPrimaryAccent.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: AppTheme.smoothPill(
                color: isDark
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : AppTheme.lightPrimaryAccent,
                side: BorderSide(
                  color: context.appPrimaryAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '완료',
                style: AppTheme.captionSmall.copyWith(
                  color: isDark ? AppTheme.primaryLight : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (todayMinutes == 0) {
      // 빈 상태 — 아직 시작 안 함
      return GestureDetector(
        onTap: firstReadingBook == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                context.push(
                  AppConstants.routeSession,
                  extra: SessionExtra(
                    bookId: firstReadingBook!.id,
                    bookTitle: firstReadingBook!.title,
                    bookAuthor: firstReadingBook!.author,
                    startPage: firstReadingBook!.currentPage,
                    totalPages: firstReadingBook!.totalPages,
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 14,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: AppTheme.smoothBox(
                  color: context.appCardElevated,
                  radius: 10,
                ),
                child: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: context.appTextTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘 독서를 시작해보세요',
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '오늘 목표 $goalMinutes분',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (firstReadingBook != null)
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: context.appPrimaryAccent,
                  size: 24,
                ),
            ],
          ),
        ),
      );
    }

    // 진행 중 상태
    return GestureDetector(
      onTap: firstReadingBook == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              context.push(
                AppConstants.routeSession,
                extra: SessionExtra(
                  bookId: firstReadingBook!.id,
                  bookTitle: firstReadingBook!.title,
                  bookAuthor: firstReadingBook!.author,
                  startPage: firstReadingBook!.currentPage,
                  totalPages: firstReadingBook!.totalPages,
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 14,
          side: BorderSide(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: AppTheme.smoothBox(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    radius: 10,
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: context.appPrimaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 ${_formatMinutes(todayMinutes)} 독서했어요',
                        style: AppTheme.bodySmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '목표까지 ${_formatMinutes(goalMinutes - todayMinutes)} 남았어요',
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.appBorder,
                valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '$h시간 $m분' : '$h시간';
    }
    return '$minutes분';
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
          _showBookDetail(context, book);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 커버 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 72,
                  child: book.coverUrl != null && book.coverUrl!.isNotEmpty
                      ? Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _CoverPlaceholder(bookId: book.id),
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                              ? child
                              : _CoverPlaceholder(bookId: book.id),
                        )
                      : _CoverPlaceholder(bookId: book.id),
                ),
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
                              fontFamily: 'Pretendard',
                              color: context.appTextPrimary,
                              fontWeight: FontWeight.w600,
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
                        borderRadius: BorderRadius.circular(3),
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
                              fontWeight: FontWeight.w600,
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
                        side: BorderSide(
                          color: context.appPrimaryAccent.withValues(alpha: 0.3),
                        ),
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
                onTap: () => onSelected(opt),
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
                    radius: 12,
                    side: BorderSide(
                      color: opt == current
                          ? context.appPrimaryAccent.withValues(alpha: 0.4)
                          : Colors.transparent,
                    ),
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
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (opt == current)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: isDark ? AppTheme.primaryLight : AppTheme.lightPrimaryAccent,
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

// ─── 책 추가 바텀시트 ─────────────────────────────────────────────────────

// ─── 책 상세 바텀시트 ─────────────────────────────────────────────────────
void _showBookDetail(BuildContext context, Book book) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _BookDetailSheet(book: book, outerContext: context),
  );
}

class _BookDetailSheet extends ConsumerStatefulWidget {
  final Book book;
  final BuildContext outerContext;
  const _BookDetailSheet({required this.book, required this.outerContext});

  @override
  ConsumerState<_BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends ConsumerState<_BookDetailSheet> {
  late int _currentPage;
  late TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.currentPage;
    _pageController = TextEditingController(text: '$_currentPage');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _adjustPage(int delta) {
    final newPage = (_currentPage + delta).clamp(0, widget.book.totalPages);
    setState(() {
      _currentPage = newPage;
      _pageController
        ..text = '$newPage'
        ..selection = TextSelection.collapsed(offset: '$newPage'.length);
    });
    HapticFeedback.selectionClick();
  }

  void _savePage(BuildContext context) {
    HapticFeedback.heavyImpact();
    ref
        .read(libraryProvider.notifier)
        .updateCurrentPage(widget.book.id, _currentPage);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.book.title} — $_currentPage쪽으로 업데이트했어요'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteBook(BuildContext context) {
    HapticFeedback.selectionClick();
    ref.read(libraryProvider.notifier).deleteBook(widget.book.id);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.book.title}을(를) 삭제했어요'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final book = widget.book;
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;
    final progress = _currentPage / (book.totalPages > 0 ? book.totalPages : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChorokSheetHandle(),
          const SizedBox(height: 24),
          // ── 책 정보 ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 88,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.lightPrimaryAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: AppTheme.headingMedium.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? context.primaryBg(0.12)
                            : isReading
                            ? context.appPrimaryAccent.withValues(alpha: isDark ? 0.12 : 0.15)
                            : context.appCardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        book.status.label,
                        style: AppTheme.captionSmall.copyWith(
                          color: isCompleted || isReading
                              ? context.appPrimaryAccent
                              : context.appTextTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── 통계 ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.smoothBox(
              color: context.appCardElevated,
              radius: 12,
            ),
            child: Row(
              children: [
                _DetailStat(
                  label: '진행률',
                  value: '${(progress * 100).toInt()}%',
                ),
                _DetailStat(
                  label: '페이지',
                  value: '$_currentPage/${book.totalPages}',
                ),
                if (book.totalReadingHours > 0)
                  _DetailStat(
                    label: '독서 시간',
                    value: '${book.totalReadingHours.toStringAsFixed(1)}h',
                  ),
                if (book.savedSentences.isNotEmpty)
                  _DetailStat(
                    label: '수집 문장',
                    value: '${book.savedSentences.length}개',
                  ),
              ],
            ),
          ),
          // ── 수집한 문장 ───────────────────────────────────────
          if (book.savedSentences.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '수집한 문장',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...book.savedSentences
                .take(3)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appCardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: context.appPrimaryAccent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        '"$s"',
                        style: AppTheme.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.appTextPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
          // ── 진행률 바 ─────────────────────────────────────────
          if (isReading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.appBorder,
                valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                minHeight: 6,
              ),
            ),
            // ── 현재 페이지 빠른 업데이트 ────────────────────────
            const SizedBox(height: 20),
            Text(
              '현재 페이지 업데이트',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.smoothBox(
                color: context.appCardElevated,
                radius: 14,
                side: BorderSide(color: context.appBorder),
              ),
              child: Column(
                children: [
                  // 빠른 조절 버튼 행
                  Row(
                    children: [
                      _PageAdjustButton(
                        label: '-10',
                        onTap: () => _adjustPage(-10),
                      ),
                      const SizedBox(width: 8),
                      _PageAdjustButton(
                        label: '+10',
                        onTap: () => _adjustPage(10),
                      ),
                      const SizedBox(width: 8),
                      _PageAdjustButton(
                        label: '+50',
                        onTap: () => _adjustPage(50),
                      ),
                      const Spacer(),
                      // 직접 입력 필드
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: context.appCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.appPrimaryAccent,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              setState(() {
                                _currentPage = parsed.clamp(0, book.totalPages);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ ${book.totalPages}쪽',
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _savePage(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: isDark ? AppTheme.primaryLight : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: AppTheme.smoothShape(radius: 10),
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // ── 액션 버튼 ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    if (isReading || isCompleted) {
                      widget.outerContext.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          bookId: book.id,
                          bookTitle: book.title,
                          bookAuthor: book.author,
                          startPage: _currentPage,
                          totalPages: book.totalPages,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isReading
                        ? Icons.play_arrow_rounded
                        : isCompleted
                        ? Icons.replay_rounded
                        : Icons.add_rounded,
                  ),
                  label: Text(
                    isReading
                        ? '이어 읽기'
                        : isCompleted
                        ? '다시 읽기'
                        : '읽기 시작',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: isDark ? AppTheme.primaryLight : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: AppTheme.smoothShape(radius: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _deleteBook(context),
                icon: const Icon(Icons.delete_outline_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: context.appTextTertiary,
                  backgroundColor: context.appCardElevated,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── 페이지 조절 버튼 ─────────────────────────────────────────────────────
class _PageAdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PageAdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label 페이지',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: AppTheme.smoothBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.lightPrimaryAccent,
            radius: 10,
            side: BorderSide(
              color: context.appPrimaryAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: AppTheme.captionLarge.copyWith(
              fontFamily: 'Pretendard',
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryLight
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label, value;
  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

