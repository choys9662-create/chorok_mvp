import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart'; // AppThemeExt on BuildContext
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/cover_color_provider.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/sheet_handle.dart';

class BookPickerSheet extends ConsumerWidget {
  const BookPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final isLoading =
        allBooks.isEmpty && ref.read(libraryProvider.notifier).isLoading;
    final readingBooks = allBooks
        .where((b) => b.status == ReadingStatus.reading)
        .toList();

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChorokSheetHandle(),
            const SizedBox(height: 4),
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
            if (isLoading && readingBooks.isEmpty)
              _LoadingState()
            else if (readingBooks.isEmpty)
              _EmptyState()
            else
              _BookList(books: readingBooks),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;

  const _BookList({required this.books});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _BookCard(book: books[index], highlighted: index == 0),
        ),
        const SizedBox(height: 8),
        GestureDetector(
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
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BookCard extends ConsumerWidget {
  final Book book;
  final bool highlighted;

  const _BookCard({required this.book, this.highlighted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = book.readingProgress;

    // 표지에서 추출한 강조색 — 추출 전/실패 시 브랜드 초록으로 폴백
    final coverColor = ref.watch(coverColorProvider(book.coverUrl)).valueOrNull;
    final accent = coverColor ?? context.appPrimaryAccent;

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
          side: BorderSide(
            color: accent.withValues(alpha: highlighted ? 0.85 : 0.55),
            width: highlighted ? 1.4 : 1.2,
          ),
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
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    accent.withValues(alpha: 0.75),
                                    accent,
                                  ],
                                ),
                              ),
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
