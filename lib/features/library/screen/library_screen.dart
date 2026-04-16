import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../controller/choseo_list_controller.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/profile_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/stacked_area_chart_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

// ─── 서재 통계 목업 ─────────────────────────────────────────────────────────
// TODO: Isar 연동 시 Repository/Provider로 교체

const _kTreemapItems = <({String title, double hours})>[
  (title: '채식주의자',         hours: 12.4),
  (title: '파친코',             hours: 8.2),
  (title: '아몬드',             hours: 6.7),
  (title: '지구 끝의 온실',     hours: 4.6),
  (title: '82년생 김지영',      hours: 3.1),
  (title: '달러구트 꿈 백화점', hours: 2.8),
];

const _kWaffleItems = <({String name, Color color, int cells})>[
  (name: '소설',     color: AppTheme.primaryLight,   cells: 60),
  (name: '문학',     color: Color(0xFF1D9E75),        cells: 22),
  (name: '인문',     color: Color(0xFF0F6E56),        cells: 11),
  (name: '자기계발', color: Color(0xFF3BC49A),        cells: 7),
];

const _kGenreWeekLabels = <String>[
  '2/3', '2/10', '2/17', '2/24', '3/3', '3/10', '3/17', '3/24',
];

final _kGenreSeries = <({String name, Color color, List<double> values})>[
  (name: '소설',     color: AppTheme.primaryLight,   values: [3.0, 4.5, 2.0, 5.0, 6.0, 3.5, 4.0, 7.0]),
  (name: '문학',     color: const Color(0xFF1D9E75), values: [1.5, 2.0, 1.0, 2.5, 2.0, 1.5, 3.0, 2.0]),
  (name: '인문',     color: const Color(0xFF0F6E56), values: [0.5, 1.0, 0.5, 1.0, 1.5, 0.5, 1.0, 1.5]),
  (name: '자기계발', color: const Color(0xFF3BC49A), values: [0.0, 0.5, 1.0, 0.5, 0.5, 1.0, 0.5, 0.5]),
];

// ─── 독서 기록 목업 (캘린더용) ────────────────────────────────────────────
typedef _ReadingLog = ({
  DateTime date,
  String bookTitle,
  String bookAuthor,
  int minutes,
  int pages,
});

List<_ReadingLog> get _kReadingLogs {
  final now = DateTime.now();
  return [
    (
      date: DateTime(now.year, now.month, now.day),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 42,
      pages: 18,
    ),
    (
      date: DateTime(now.year, now.month, now.day),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 25,
      pages: 12,
    ),
    (
      date: now.subtract(const Duration(days: 1)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 55,
      pages: 24,
    ),
    (
      date: now.subtract(const Duration(days: 2)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 38,
      pages: 16,
    ),
    (
      date: now.subtract(const Duration(days: 3)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 20,
      pages: 8,
    ),
    (
      date: now.subtract(const Duration(days: 5)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 65,
      pages: 30,
    ),
    (
      date: now.subtract(const Duration(days: 6)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 30,
      pages: 14,
    ),
    (
      date: now.subtract(const Duration(days: 8)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 48,
      pages: 22,
    ),
    (
      date: now.subtract(const Duration(days: 10)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 35,
      pages: 15,
    ),
    (
      date: now.subtract(const Duration(days: 12)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 52,
      pages: 25,
    ),
    (
      date: now.subtract(const Duration(days: 12)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 18,
      pages: 7,
    ),
    (
      date: now.subtract(const Duration(days: 14)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 40,
      pages: 19,
    ),
    (
      date: now.subtract(const Duration(days: 15)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 28,
      pages: 13,
    ),
    (
      date: now.subtract(const Duration(days: 18)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 60,
      pages: 28,
    ),
    (
      date: now.subtract(const Duration(days: 20)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 33,
      pages: 16,
    ),
    (
      date: now.subtract(const Duration(days: 22)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 45,
      pages: 20,
    ),
    (
      date: now.subtract(const Duration(days: 25)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 50,
      pages: 24,
    ),
  ];
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

// ─── 목업 데이터 ──────────────────────────────────────────────────────────
final _kBooks = [
  Book(
    id: '1',
    title: '채식주의자',
    author: '한강',
    status: ReadingStatus.reading,
    totalPages: 300,
    currentPage: 186,
    totalReadingHours: 5.2,
    savedSentences: const ['나는 채식주의자가 되기로 했다.', '꿈 때문에.'],
  ),
  Book(
    id: '2',
    title: '82년생 김지영',
    author: '조남주',
    status: ReadingStatus.completed,
    totalPages: 190,
    currentPage: 190,
    totalReadingHours: 4.1,
  ),
  Book(
    id: '3',
    title: '아몬드',
    author: '손원평',
    status: ReadingStatus.completed,
    totalPages: 264,
    currentPage: 264,
    totalReadingHours: 6.3,
  ),
  Book(
    id: '4',
    title: '흰',
    author: '한강',
    status: ReadingStatus.wantToRead,
    totalPages: 160,
    currentPage: 0,
  ),
  Book(
    id: '5',
    title: '지구 끝의 온실',
    author: '김초엽',
    status: ReadingStatus.wantToRead,
    totalPages: 304,
    currentPage: 0,
  ),
  Book(
    id: '6',
    title: '파친코',
    author: '이민진',
    status: ReadingStatus.reading,
    totalPages: 688,
    currentPage: 234,
    totalReadingHours: 8.7,
  ),
];

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
    return Scaffold(
      backgroundColor: context.appSurface,
      body: SafeArea(
        child: Column(
          children: [
            // ── 프로필 + 설정 ─────────────────────────────────────
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
                    _showSettingsSheet(context);
                  },
                  streak: streak,
                );
              },
            ),

            // ── 수집한 문장 전체 보기 버튼 ──────────────────────
            Consumer(
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
                          decoration: BoxDecoration(
                            color: context.appCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                color: AppTheme.accent,
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
            const SizedBox(height: 12),

            // ── 세그먼트 토글 ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: _SegmentToggle(
                labels: const ['서재', '통계', '캘린더'],
                selectedIndex: _viewIndex,
                onChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _viewIndex = i);
                },
              ),
            ),
            const SizedBox(height: 4),

            // ── 콘텐츠 ──────────────────────────────────────────
            Expanded(
              child: IndexedStack(
                index: _viewIndex,
                children: [
                  _LibraryTab(
                    books: _kBooks,
                    onAddBook: () => _showAddBookSheet(context),
                    scrollController: ref.read(tabScrollControllersProvider)[3],
                  ),
                  _StatsView(
                    scrollController: ref.read(tabScrollControllersProvider)[5],
                  ),
                  _CalendarView(
                    logs: _kReadingLogs,
                    scrollController: ref.read(tabScrollControllersProvider)[4],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBookSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddBookSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 서재 탭
// ════════════════════════════════════════════════════════════════════════════
class _LibraryTab extends StatefulWidget {
  final List<Book> books;
  final VoidCallback onAddBook;
  final ScrollController? scrollController;

  const _LibraryTab({required this.books, required this.onAddBook, this.scrollController});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab> {
  ReadingStatus _selectedStatus = ReadingStatus.reading;

  List<Book> get _filteredBooks =>
      widget.books.where((b) => b.status == _selectedStatus).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: '서재',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: AppTheme.smoothBox(
                color: AppTheme.primary.withValues(alpha: 0.2),
                radius: 10,
              ),
              child: Text(
                '${widget.books.length}권',
                style: AppTheme.captionSmall.copyWith(color: AppTheme.accent),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 필터 칩
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: ReadingStatus.values.length,
            separatorBuilder: (_, i) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final status = ReadingStatus.values[i];
              final count = widget.books
                  .where((b) => b.status == status)
                  .length;
              final isSelected = status == _selectedStatus;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedStatus = status);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: AppTheme.smoothPill(
                    color: isSelected ? AppTheme.primary : context.appCard,
                    side: BorderSide(
                      color: isSelected
                          ? AppTheme.primaryLight.withValues(alpha: 0.3)
                          : context.appBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusIcon(status),
                        size: 14,
                        color: isSelected
                            ? AppTheme.primaryLight
                            : context.appTextTertiary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${status.label} $count',
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: isSelected
                              ? AppTheme.primaryLight
                              : context.appTextTertiary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        // 그리드
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _BookGrid(
              key: ValueKey(_selectedStatus),
              books: _filteredBooks,
              status: _selectedStatus,
              scrollController: widget.scrollController,
            ),
          ),
        ),

        // 하단 추가 버튼
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spaceMD,
            AppTheme.screenPadding,
            AppTheme.spaceLG,
          ),
          decoration: BoxDecoration(
            color: context.appSurface,
            border: Border(top: BorderSide(color: context.appBorder)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onAddBook();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('책 추가'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppTheme.smoothShape(radius: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 커버 플레이스홀더 ────────────────────────────────────────────────────
class _CoverPlaceholder extends StatelessWidget {
  final String bookId;
  const _CoverPlaceholder({required this.bookId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(
        alpha: 0.15 + (bookId.hashCode % 5) * 0.04,
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 40,
          color: AppTheme.primaryLight.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

// ─── 도서 그리드 ──────────────────────────────────────────────────────────
class _BookGrid extends StatelessWidget {
  final List<Book> books;
  final ReadingStatus status;
  final ScrollController? scrollController;

  const _BookGrid({super.key, required this.books, required this.status, this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return _EmptyShelf(status: status);

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceLG,
        AppTheme.screenPadding,
        AppTheme.spaceLG,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) => _BookCard(book: books[i]),
    );
  }
}

// ─── 도서 카드 ────────────────────────────────────────────────────────────
class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final isCompleted = book.status == ReadingStatus.completed;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showBookDetail(context, book);
      },
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 22,
          side: BorderSide(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(21),
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
                              color: AppTheme.primaryLight.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.format_quote_rounded,
                                size: 10,
                                color: AppTheme.primaryLight,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${book.savedSentences.length}',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryLight,
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
                        valueColor: const AlwaysStoppedAnimation(
                          AppTheme.primaryLight,
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
                            color: AppTheme.primaryLight,
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
                            color: AppTheme.primary.withValues(alpha: 0.5),
                            side: BorderSide(
                              color: AppTheme.primaryLight.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: const Text(
                            '이어 읽기',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryLight,
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
            style: AppTheme.bodyMedium.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            sub,
            style: AppTheme.captionLarge.copyWith(color: context.appTextTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── 책 추가 바텀시트 ─────────────────────────────────────────────────────
class _AddBookSheet extends StatefulWidget {
  const _AddBookSheet();

  @override
  State<_AddBookSheet> createState() => _AddBookSheetState();
}

class _AddBookSheetState extends State<_AddBookSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space2XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXL),
            Text(
              '책 추가',
              style: AppTheme.headingMedium.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            TextField(
              controller: _searchController,
              autofocus: true,
              style: AppTheme.bodyMedium.copyWith(color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: '책 제목, 저자, ISBN으로 검색',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: context.appTextTertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.appTextTertiary,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppTheme.accent,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('바코드 스캔 기능은 출시 예정이에요'),
                        backgroundColor: AppTheme.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                filled: true,
                fillColor: context.appCardElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryLight),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Center(
              child: Text(
                '알라딘 · 네이버 도서 검색 연동 (출시 예정)',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXL),
          ],
        ),
      ),
    );
  }
}

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

class _BookDetailSheet extends StatelessWidget {
  final Book book;
  final BuildContext outerContext;
  const _BookDetailSheet({required this.book, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 88,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppTheme.primaryLight.withValues(alpha: 0.5),
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
                            ? AppTheme.primaryLight.withValues(alpha: 0.12)
                            : isReading
                            ? AppTheme.accent.withValues(alpha: 0.12)
                            : context.appCardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        book.status.label,
                        style: AppTheme.captionSmall.copyWith(
                          color: isCompleted
                              ? AppTheme.primaryLight
                              : isReading
                              ? AppTheme.accent
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
                  value: '${(book.readingProgress * 100).toInt()}%',
                ),
                _DetailStat(
                  label: '페이지',
                  value: '${book.currentPage}/${book.totalPages}',
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
                        border: const Border(
                          left: BorderSide(
                            color: AppTheme.primaryLight,
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
          if (isReading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: book.readingProgress,
                backgroundColor: context.appBorder,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryLight),
                minHeight: 6,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context); // 시트 닫기
                    if (isReading || isCompleted) {
                      outerContext.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          bookId: book.id,
                          bookTitle: book.title,
                          bookAuthor: book.author,
                          startPage: book.currentPage,
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
                    foregroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: AppTheme.smoothShape(radius: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${book.title}을(를) 삭제했어요'),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      action: SnackBarAction(
                        label: '취소',
                        textColor: AppTheme.primaryLight,
                        onPressed: () {},
                      ),
                    ),
                  );
                },
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
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── 세그먼트 토글 ───────────────────────────────────────────────────────
class _SegmentToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentToggle({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 12,
        side: BorderSide(color: context.appBorder),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.6)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  style: AppTheme.captionLarge.copyWith(
                    fontFamily: 'Pretendard',
                    color: isSelected
                        ? AppTheme.primaryLight
                        : context.appTextTertiary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 캘린더 뷰
// ════════════════════════════════════════════════════════════════════════════

class _CalendarView extends StatefulWidget {
  final List<_ReadingLog> logs;
  final ScrollController? scrollController;
  const _CalendarView({required this.logs, this.scrollController});

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  // 해당 날짜의 로그 목록
  List<_ReadingLog> _logsFor(DateTime date) {
    return widget.logs
        .where(
          (l) =>
              l.date.year == date.year &&
              l.date.month == date.month &&
              l.date.day == date.day,
        )
        .toList();
  }

  // 해당 월에 독서한 날짜 set
  Set<int> get _activeDays {
    return widget.logs
        .where(
          (l) =>
              l.date.year == _focusedMonth.year &&
              l.date.month == _focusedMonth.month,
        )
        .map((l) => l.date.day)
        .toSet();
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = next;
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedLogs = _selectedDate != null
        ? _logsFor(_selectedDate!)
        : <_ReadingLog>[];
    final totalMin = selectedLogs.fold<int>(0, (a, l) => a + l.minutes);

    return CustomScrollView(
      controller: widget.scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── 월 네비게이션 ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              16,
              AppTheme.screenPadding,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: '이전 달',
                  button: true,
                  child: GestureDetector(
                    onTap: _prevMonth,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: context.appTextSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                  style: AppTheme.headingSmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Semantics(
                  label: '다음 달',
                  button: true,
                  child: GestureDetector(
                    onTap: _nextMonth,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: context.appTextSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 요일 헤더 ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        // ── 달력 그리드 ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: _CalendarGrid(
              month: _focusedMonth,
              activeDays: _activeDays,
              selectedDate: _selectedDate,
              onDayTap: (date) {
                HapticFeedback.selectionClick();
                setState(() => _selectedDate = date);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── 선택 날짜 독서 기록 ──────────────────────────────
        if (_selectedDate != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedDate!.month}월 ${_selectedDate!.day}일',
                    style: AppTheme.headingSmall.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (totalMin > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        totalMin >= 60
                            ? '${totalMin ~/ 60}시간 ${totalMin % 60}분'
                            : '$totalMin분',
                        style: AppTheme.captionSmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (selectedLogs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                  vertical: 24,
                ),
                child: Center(
                  child: Text(
                    '이 날은 독서 기록이 없어요',
                    style: AppTheme.bodyMedium.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    0,
                    AppTheme.screenPadding,
                    i < selectedLogs.length - 1 ? 8 : 24,
                  ),
                  child: _ReadingLogCard(log: selectedLogs[i]),
                ),
                childCount: selectedLogs.length,
              ),
            ),
        ],
      ],
    );
  }
}

// ─── 달력 그리드 ─────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> activeDays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.activeDays,
    required this.selectedDate,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 일=0
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[];
    // 앞쪽 빈칸
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    // 날짜 셀
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final isToday = date == today;
      final isSelected =
          selectedDate != null &&
          date.year == selectedDate!.year &&
          date.month == selectedDate!.month &&
          date.day == selectedDate!.day;
      final hasLog = activeDays.contains(d);
      final isFuture = date.isAfter(today);

      cells.add(
        GestureDetector(
          onTap: isFuture ? null : () => onDayTap(date),
          child: Container(
            decoration: AppTheme.smoothBox(
              color: isSelected
                  ? AppTheme.primary
                  : isToday
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : null,
              radius: 10,
              side: isToday && !isSelected
                  ? BorderSide(
                      color: AppTheme.primaryLight.withValues(alpha: 0.3),
                    )
                  : BorderSide.none,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isFuture
                        ? context.appTextTertiary.withValues(alpha: 0.3)
                        : isSelected
                        ? AppTheme.primaryLight
                        : isToday
                        ? AppTheme.primaryLight
                        : context.appTextPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                // 독서 인디케이터 점
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasLog
                        ? (isSelected
                              ? AppTheme.primaryLight
                              : AppTheme.primaryLight.withValues(alpha: 0.7))
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: cells,
    );
  }
}

// ─── 독서 기록 카드 ──────────────────────────────────────────────────────
class _ReadingLogCard extends StatelessWidget {
  final _ReadingLog log;
  const _ReadingLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 14,
        side: BorderSide(color: context.appBorder),
      ),
      child: Row(
        children: [
          // 책 아이콘
          Container(
            width: 44,
            height: 44,
            decoration: AppTheme.smoothBox(
              color: AppTheme.primary.withValues(alpha: 0.2),
              radius: 10,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: AppTheme.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          // 책 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.bookTitle,
                  style: AppTheme.bodySmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.bookAuthor,
                  style: AppTheme.captionSmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 독서 시간 + 페이지
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: AppTheme.primaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    log.minutes >= 60
                        ? '${log.minutes ~/ 60}h ${log.minutes % 60}m'
                        : '${log.minutes}분',
                    style: AppTheme.captionLarge.copyWith(
                      fontFamily: 'Pretendard',
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${log.pages}쪽 읽음',
                style: AppTheme.captionSmall.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 설정 시트 ────────────────────────────────────────────────────────

void _showSettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _notiFollow = true;
  bool _notiLike = true;
  bool _notiGoal = true;
  bool _notiOverlap = false;
  int _dailyGoalMinutes = 30;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  '설정',
                  style: AppTheme.headingMedium.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.appTextTertiary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _SettingsSection(
                  title: '화면',
                  children: [
                    Consumer(
                      builder: (context, ref, _) => _ToggleTile(
                        label: '다크 모드',
                        description: '어두운 배경으로 눈의 피로를 줄여요',
                        value: ref.watch(themeModeProvider) == ThemeMode.dark,
                        onChanged: (_) {
                          ref.read(themeModeProvider.notifier).toggle();
                        },
                        showDivider: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: '독서 목표',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '하루 목표',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: context.appTextPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$_dailyGoalMinutes분',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.primaryLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppTheme.primaryLight,
                              inactiveTrackColor: context.appBorder,
                              thumbColor: AppTheme.primaryLight,
                              overlayColor: AppTheme.primaryLight.withValues(
                                alpha: 0.12,
                              ),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _dailyGoalMinutes.toDouble(),
                              min: 10,
                              max: 120,
                              divisions: 11,
                              onChanged: (v) {
                                HapticFeedback.selectionClick();
                                setState(() => _dailyGoalMinutes = v.toInt());
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['10분', '30분', '60분', '120분']
                                .map(
                                  (l) => Text(
                                    l,
                                    style: AppTheme.captionSmall.copyWith(
                                      color: context.appTextTertiary,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: '알림',
                  children: [
                    _ToggleTile(
                      label: '팔로우 신청',
                      description: '누군가 나를 팔로우할 때',
                      value: _notiFollow,
                      onChanged: (v) => setState(() => _notiFollow = v),
                    ),
                    _ToggleTile(
                      label: '좋아요',
                      description: '내 문장에 좋아요가 달릴 때',
                      value: _notiLike,
                      onChanged: (v) => setState(() => _notiLike = v),
                    ),
                    _ToggleTile(
                      label: '목표 달성 알림',
                      description: '하루 독서 목표 달성 시',
                      value: _notiGoal,
                      onChanged: (v) => setState(() => _notiGoal = v),
                    ),
                    _ToggleTile(
                      label: '겹문장 알림',
                      description: '내 문장을 다른 사람도 기록할 때',
                      value: _notiOverlap,
                      onChanged: (v) => setState(() => _notiOverlap = v),
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: '앱 정보',
                  children: [
                    _SettingsMenuTile(
                      label: '버전 정보',
                      trailing: Text(
                        '1.0.0',
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ),
                    const _SettingsMenuTile(label: '개인정보 처리방침'),
                    const _SettingsMenuTile(label: '이용약관', showDivider: false),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: '계정',
                  children: [
                    _SettingsMenuTile(
                      label: '로그아웃',
                      labelColor: context.appTextSecondary,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('로그인 기능 활성화 후 사용 가능해요'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      showDivider: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: AppTheme.smoothBox(
            color: context.appCardElevated,
            radius: 14,
            side: BorderSide(color: context.appBorder),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const _ToggleTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  onChanged(v);
                },
                activeThumbColor: AppTheme.primaryLight,
                activeTrackColor: AppTheme.primaryLight.withValues(alpha: 0.25),
                inactiveTrackColor: context.appBorder,
                inactiveThumbColor: context.appTextTertiary,
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: context.appBorder, indent: 16),
      ],
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  final String label;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _SettingsMenuTile({
    required this.label,
    this.labelColor,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.bodyMedium.copyWith(
                      color: labelColor ?? context.appTextPrimary,
                    ),
                  ),
                ),
                trailing ??
                    (onTap != null
                        ? Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: context.appTextTertiary,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: context.appBorder, indent: 16),
      ],
    );
  }
}


// ════════════════════════════════════════════════════════════════════════════
// 통계 탭 — 장르 트렌드 · 책별 비중 · 장르 비율
// ════════════════════════════════════════════════════════════════════════════
class _StatsView extends StatelessWidget {
  final ScrollController? scrollController;

  const _StatsView({this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding, 16,
        AppTheme.screenPadding, 40,
      ),
      children: [
        const ChorokSectionHeader(title: '장르별 독서 트렌드'),
        const SizedBox(height: AppTheme.spaceMD),
        StackedAreaChartWidget(
          labels: _kGenreWeekLabels,
          series: _kGenreSeries,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '책별 독서 비중'),
        const SizedBox(height: AppTheme.spaceMD),
        const BookTreemapWidget(items: _kTreemapItems),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '장르 비율'),
        const SizedBox(height: AppTheme.spaceMD),
        const WaffleChartWidget(genres: _kWaffleItems),
      ],
    );
  }
}