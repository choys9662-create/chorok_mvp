import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../home/controller/recommended_books_provider.dart';
import '../../search/model/aladin_book.dart';
import '../controller/discovery_provider.dart';

/// 검색 탭에서 검색어가 비어 있을 때 보여주는 디스커버리 랜딩.
/// 인기 책 · 인기 작가 · 맞춤 추천 책 세 섹션으로 구성된다.
class DiscoveryView extends ConsumerWidget {
  final void Function(AladinBook) onBookNavigate;
  final void Function(String author) onAuthorTap;
  final void Function(String title) onTitleTap;

  const DiscoveryView({
    super.key,
    required this.onBookNavigate,
    required this.onAuthorTap,
    required this.onTitleTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularBooks = ref.watch(popularBooksProvider);
    final popularAuthors = ref.watch(popularAuthorsProvider);
    final recommended = ref.watch(recommendedBooksProvider);
    final myName = ref.watch(myDisplayNameProvider).valueOrNull;

    final books = popularBooks.valueOrNull ?? const <AladinBook>[];
    final authors = popularAuthors.valueOrNull ?? const <PopularAuthor>[];
    final recs = recommended.valueOrNull ?? const <RecommendedBook>[];

    final hasContent =
        books.isNotEmpty || authors.isNotEmpty || recs.isNotEmpty;
    final isLoading =
        popularBooks.isLoading ||
        popularAuthors.isLoading ||
        recommended.isLoading;
    if (!hasContent && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: 52,
              color: context.appTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '책, 작가, 유저를 검색해보세요',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      children: [
        if (books.isNotEmpty) ...[
          const _SectionHeader(title: '지금 가장 많이 검색되는 책'),
          const SizedBox(height: 12),
          _PopularBooksRow(books: books, onTap: onBookNavigate),
          const SizedBox(height: 28),
        ],
        if (authors.isNotEmpty) ...[
          const _SectionHeader(title: '지금 가장 많이 검색되는 작가'),
          const SizedBox(height: 12),
          _PopularAuthorsCard(authors: authors, onTap: onAuthorTap),
          const SizedBox(height: 28),
        ],
        if (recs.isNotEmpty) ...[
          _SectionHeader(
            title: myName != null ? '$myName님 맞춤 추천 책' : '맞춤 추천 책',
          ),
          const SizedBox(height: 12),
          _RecommendedGrid(books: recs, onTap: onTitleTap),
        ],
      ],
    );
  }
}

// ─── 섹션 헤더 ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: context.appTextTertiary,
          ),
        ],
      ),
    );
  }
}

// ─── 인기 책 (가로 스크롤, 순위 뱃지) ────────────────────────────────────────

class _PopularBooksRow extends StatelessWidget {
  final List<AladinBook> books;
  final void Function(AladinBook) onTap;

  const _PopularBooksRow({required this.books, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
        itemCount: books.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _PopularBookItem(
          book: books[i],
          rank: i + 1,
          onTap: () => onTap(books[i]),
        ),
      ),
    );
  }
}

class _PopularBookItem extends StatelessWidget {
  final AladinBook book;
  final int rank;
  final VoidCallback onTap;

  const _PopularBookItem({
    required this.book,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              gradientIndex: rank - 1,
              width: 112,
              height: 160,
              radius: 10,
              child: Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: AppTheme.smoothShape(radius: 6),
                  ),
                  child: Text(
                    '$rank',
                    style: AppTheme.captionSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              book.title,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              book.author,
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 인기 작가 (카드 안 리스트) ──────────────────────────────────────────────

class _PopularAuthorsCard extends StatelessWidget {
  final List<PopularAuthor> authors;
  final void Function(String) onTap;

  const _PopularAuthorsCard({required this.authors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 10,
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < authors.length; i++) ...[
              _AuthorRow(
                author: authors[i],
                onTap: () => onTap(authors[i].name),
              ),
              if (i < authors.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: context.appTextTertiary.withValues(alpha: 0.1),
                ),
            ],
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Icon(
                Icons.more_vert_rounded,
                size: 18,
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final PopularAuthor author;
  final VoidCallback onTap;

  const _AuthorRow({required this.author, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Text(
              author.name,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                author.titles.join('  |  '),
                textAlign: TextAlign.right,
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 맞춤 추천 책 (커버 그리드) ──────────────────────────────────────────────

class _RecommendedGrid extends StatelessWidget {
  final List<RecommendedBook> books;
  final void Function(String) onTap;

  const _RecommendedGrid({required this.books, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: books.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.66,
        ),
        itemBuilder: (_, i) {
          final b = books[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap(b.title);
            },
            child: BookCover(
              coverUrl: b.coverUrl.isEmpty ? null : b.coverUrl,
              gradientIndex: b.gradientIndex,
              width: double.infinity,
              radius: 8,
            ),
          );
        },
      ),
    );
  }
}
