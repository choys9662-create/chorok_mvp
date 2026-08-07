import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import 'reading_books_section.dart';

int compareWishlistBooks(Book a, Book b) {
  final aAdded = a.addedAt;
  final bAdded = b.addedAt;
  if (aAdded == null && bAdded == null) return 0;
  if (aAdded == null) return 1;
  if (bAdded == null) return -1;
  return bAdded.compareTo(aAdded);
}

class WishlistSection extends ConsumerWidget {
  const WishlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistBooks =
        ref
            .watch(libraryProvider)
            .where((book) => book.status == ReadingStatus.wantToRead)
            .toList()
          ..sort(compareWishlistBooks);

    if (wishlistBooks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.sectionGap),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: '읽고 싶은 책',
            count: wishlistBooks.length,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        SizedBox(
          height: readingBookCardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: wishlistBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == wishlistBooks.length - 1
                      ? 0
                      : readingBookCardGap,
                ),
                child: ReadingBookCard(book: wishlistBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
