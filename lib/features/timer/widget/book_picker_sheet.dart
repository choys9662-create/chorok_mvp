import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart'; // AppThemeExt on BuildContext
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../home/widget/reading_books_section.dart' show compareReadingBooks;

// 책 카드 1장의 고정 높이(패딩 14*2 + 표지 64) — 진행바 유무와 무관하게 동일하다.
const double _bookCardHeight = 92;
const double _bookListGap = 8;
// 핸들+타이틀 영역 높이 근사값. 헤더 레이아웃이 바뀌면 같이 조정해야 한다.
const double _headerHeight = 12 + 4 + 16 + 22 + 8;
// 리스트-버튼 간격 + 검색 버튼 + 하단 여백 근사값.
const double _footerHeight = 8 + 40 + 8;
const double _threeBooksHeight =
    _headerHeight + 3 * _bookCardHeight + 2 * _bookListGap + _footerHeight;

class BookPickerSheet extends ConsumerWidget {
  const BookPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final isLoading =
        allBooks.isEmpty && ref.read(libraryProvider.notifier).isLoading;
    final readingBooks = allBooks
        .where((b) => b.status == ReadingStatus.reading)
        .toList()
      ..sort(compareReadingBooks);

    if (isLoading && readingBooks.isEmpty) {
      return _SheetShell(child: _LoadingState());
    }
    if (readingBooks.isEmpty) {
      return _SheetShell(child: _EmptyState());
    }
    if (readingBooks.length <= 3) {
      return _SheetShell(child: _BookList(books: readingBooks));
    }

    // 병렬 독서(4권 이상): 기본은 3권만 보여주고, 위로 스크롤하면 시트가 먼저
    // 확장된 뒤 이어서 나머지 책까지 리스트가 스크롤되도록 한다.
    final screenHeight = MediaQuery.of(context).size.height;
    final initialFraction = (_threeBooksHeight / screenHeight).clamp(0.3, 0.85);

    return _ExpandableBookSheet(
      books: readingBooks,
      initialFraction: initialFraction,
    );
  }
}

/// 3권 초과일 때 쓰는 확장형 시트.
/// 프레임워크 기본 [DraggableScrollableSheet.snap]은 일정한 속도로만 움직여
/// 밋밋하게 느껴지므로, 직접 컨트롤러로 이징 커브가 있는 애니메이션을 준다.
class _ExpandableBookSheet extends StatefulWidget {
  final List<Book> books;
  final double initialFraction;

  const _ExpandableBookSheet({
    required this.books,
    required this.initialFraction,
  });

  @override
  State<_ExpandableBookSheet> createState() => _ExpandableBookSheetState();
}

class _ExpandableBookSheetState extends State<_ExpandableBookSheet> {
  static const double _maxFraction = 0.9;
  static const double _triggerRatio = 0.2;

  final _controller = DraggableScrollableController();
  late double _extent = widget.initialFraction;
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle() {
    // 펼치기/접기 둘 다 전체 구간의 20%만 움직여도 전환되도록, 현재 상태를
    // 기준으로 기준선을 반대쪽 끝에서 20% 지점에 둔다(히스테리시스).
    final range = _maxFraction - widget.initialFraction;
    final threshold = _isExpanded
        ? _maxFraction - range * _triggerRatio
        : widget.initialFraction + range * _triggerRatio;
    final expand = _isExpanded ? _extent >= threshold : _extent > threshold;
    final target = expand ? _maxFraction : widget.initialFraction;
    _isExpanded = expand;
    if ((_extent - target).abs() < 0.001) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        _extent = notification.extent;
        return false;
      },
      child: Listener(
        onPointerUp: (_) => _settle(),
        child: DraggableScrollableSheet(
          controller: _controller,
          initialChildSize: widget.initialFraction,
          minChildSize: widget.initialFraction,
          maxChildSize: _maxFraction,
          // 기본값(true)이면 시트가 minChildSize(3권 상태)에 닿는 순간 모달
          // 전체가 닫힌다 — 여기선 그 지점이 그냥 "축소된 상태"여야 한다.
          shouldCloseOnMinExtent: false,
          expand: false,
          builder: (context, scrollController) => _SheetShell(
            expand: true,
            child: _BookList(
              books: widget.books,
              scrollController: scrollController,
            ),
          ),
        ),
      ),
    );
  }
}

/// 핸들+타이틀 헤더를 포함한 시트 공통 껍데기.
/// [expand]가 true면(=DraggableScrollableSheet용) 헤더는 [child] 안에 이미
/// 포함되어 있다고 보고 부모가 준 높이를 그대로 채운다 — 헤더까지 같은
/// 스크롤 영역이어야 헤더를 스와이프해도 시트가 확장/축소된다.
class _SheetShell extends StatelessWidget {
  final Widget child;
  final bool expand;

  const _SheetShell({required this.child, this.expand = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: SafeArea(
        top: false,
        child: expand
            ? child
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHeader(),
                  child,
                  const SizedBox(height: 8),
                ],
              ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const ChorokSheetHandle(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            '오늘은 어떤 책을 읽을까요?',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;
  final ScrollController? scrollController;

  const _BookList({required this.books, this.scrollController});

  @override
  Widget build(BuildContext context) {
    final searchButton = GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        context.push(AppConstants.routeSearch);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: AppTheme.smoothBox(
          color: context.appCardElevated,
          radius: 10,
          side: BorderSide(color: context.appBorderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 18, color: context.appTextSecondary),
            const SizedBox(width: 6),
            Text(
              '다른 책 검색',
              style: TextStyle(color: context.appTextSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    if (scrollController != null) {
      // 헤더까지 리스트 안에 넣어야 헤더 영역을 스와이프해도 시트가
      // 확장/축소된다 — 별도 GestureDetector 없이 같은 스크롤 영역으로 묶는다.
      return ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const _SheetHeader(),
          for (final book in books) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _BookCard(book: book),
            ),
            const SizedBox(height: 8),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: searchButton,
          ),
          const SizedBox(height: 8),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _BookCard(book: books[index]),
        ),
        const SizedBox(height: 8),
        searchButton,
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final progress = book.readingProgress;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
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
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 10,
          side: BorderSide(color: context.appBorderSubtle),
        ),
        child: Row(
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              width: 48,
              height: 64,
              radius: 10,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (book.totalPages > 0) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            Container(
                              height: 4,
                              width: double.infinity,
                              color: context.appProgressTrack,
                            ),
                            Container(
                              height: 4,
                              width:
                                  constraints.maxWidth * progress.clamp(0, 1),
                              color: context.appPrimaryAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.appTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          ChorokShimmer(width: double.infinity, height: 80, radius: 10),
          const SizedBox(height: 8),
          ChorokShimmer(width: double.infinity, height: 80, radius: 10),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: context.appTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            '읽는 중인 책이 없어요',
            style: TextStyle(color: context.appTextSecondary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
              context.go(AppConstants.routeLibrary);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: AppTheme.smoothBox(
                color: context.appActiveFill,
                radius: 10,
              ),
              child: Text(
                '라이브러리 가기',
                style: TextStyle(
                  color: context.appPrimaryAccent,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
