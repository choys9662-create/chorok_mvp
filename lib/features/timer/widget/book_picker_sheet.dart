import 'package:figma_squircle/figma_squircle.dart';
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

class BookPickerSheet extends ConsumerWidget {
  const BookPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final isLoading = allBooks.isEmpty &&
        ref.read(libraryProvider.notifier).isLoading;
    final readingBooks = allBooks
        .where((b) => b.status == ReadingStatus.reading)
        .toList();

    return Container(
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 24,
            cornerSmoothing: 0.6,
          ),
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
                '어떤 책을 읽을까요?',
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
          itemBuilder: (context, index) => _BookCard(book: books[index]),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
            context.push(AppConstants.routeSearch);
          },
          child: Text(
            '다른 책 검색',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 16,
            ),
          ),
        ),
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
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.smoothBox(color: context.appCardElevated, radius: 16),
        child: Row(
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              width: 44,
              height: 60,
              radius: 6,
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
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: context.appCard,
                        color: context.appPrimaryAccent,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.currentPage} / ${book.totalPages}p',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 12,
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
          ChorokShimmer(width: double.infinity, height: 80, radius: 16),
          const SizedBox(height: 8),
          ChorokShimmer(width: double.infinity, height: 80, radius: 16),
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
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 16,
            ),
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
              decoration: AppTheme.smoothBox(color: context.appActiveFill, radius: 12),
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
