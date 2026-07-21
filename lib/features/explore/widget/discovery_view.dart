import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../home/controller/recommended_books_provider.dart';
import '../../search/model/aladin_book.dart';
import '../controller/discovery_provider.dart';
import '../../../shared/widgets/chorok_refresh.dart';

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

  void _showPopularBooks(BuildContext context, List<AladinBook> books) {
    _showDiscoverySheet(
      context,
      title: '지금 가장 많이 검색되는 책',
      children: [
        for (var i = 0; i < books.length; i++)
          ListTile(
            onTap: () {
              Navigator.of(context).pop();
              onBookNavigate(books[i]);
            },
            leading: SizedBox(
              width: 38,
              child: Text(
                '${i + 1}',
                textAlign: TextAlign.center,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.accent),
              ),
            ),
            title: Text(books[i].title),
            subtitle: Text(books[i].author),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    );
  }

  void _showPopularAuthors(BuildContext context, List<PopularAuthor> authors) {
    _showDiscoverySheet(
      context,
      title: '지금 가장 많이 검색되는 작가',
      children: [
        for (final author in authors)
          ListTile(
            onTap: () {
              Navigator.of(context).pop();
              onAuthorTap(author.name);
            },
            title: Text(author.name),
            subtitle: Text(author.titles.join(' · ')),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    );
  }

  void _showRecommendations(
    BuildContext context,
    String title,
    List<RecommendedBook> books,
  ) {
    _showDiscoverySheet(
      context,
      title: title,
      children: [
        for (final book in books)
          ListTile(
            onTap: () {
              Navigator.of(context).pop();
              onTitleTap(book.title);
            },
            title: Text(book.title),
            subtitle: Text('${book.author} · ${book.reason}'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
      ],
    );
  }

  void _showDiscoverySheet(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusOuter),
        ),
      ),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  4,
                  AppTheme.screenPadding,
                  12,
                ),
                child: Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: sheetContext.appTextPrimary,
                  ),
                ),
              ),
              Flexible(child: ListView(children: children)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popularBooks = ref.watch(popularBooksProvider);
    final popularAuthors = ref.watch(popularAuthorsProvider);
    final recommended = ref.watch(recommendedBooksProvider);
    final myName = ref.watch(myDisplayNameProvider).valueOrNull;

    final books = popularBooks.valueOrNull ?? const <AladinBook>[];
    final authors = popularAuthors.valueOrNull ?? const <PopularAuthor>[];
    final recs = recommended.valueOrNull ?? const <RecommendedBook>[];
    final recommendationTitle = myName != null ? '$myName님 맞춤 추천 책' : '맞춤 추천 책';

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
          spacing: AppTheme.spaceLG,
          children: [
            Icon(
              Icons.search_rounded,
              size: 52,
              color: context.appTextTertiary,
            ),
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        ChorokSliverRefreshControl(
          onRefresh: () async {
            ref.invalidate(popularBooksProvider);
            ref.invalidate(popularAuthorsProvider);
            ref.invalidate(recommendedBooksProvider);
            await Future.wait<void>([
              ref.read(popularBooksProvider.future).then<void>((_) {}),
              ref.read(popularAuthorsProvider.future).then<void>((_) {}),
              ref.read(recommendedBooksProvider.future).then<void>((_) {}),
            ]);
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 4, bottom: 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (books.isNotEmpty) ...[
                _SectionHeader(
                  title: '지금 가장 많이 검색되는 책',
                  onTap: () => _showPopularBooks(context, books),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                _PopularBooksRow(books: books, onTap: onBookNavigate),
                const SizedBox(height: 28),
              ],
              if (authors.isNotEmpty) ...[
                _SectionHeader(
                  title: '지금 가장 많이 검색되는 작가',
                  onTap: () => _showPopularAuthors(context, authors),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                _PopularAuthorsCard(
                  authors: authors,
                  onTap: onAuthorTap,
                  onMoreTap: () => _showPopularAuthors(context, authors),
                ),
                const SizedBox(height: 28),
              ],
              if (recs.isNotEmpty) ...[
                _SectionHeader(
                  title: recommendationTitle,
                  onTap: () =>
                      _showRecommendations(context, recommendationTitle, recs),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                _RecommendedGrid(books: recs, onTap: onTitleTap),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── 섹션 헤더 ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _SectionHeader({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Semantics(
        label: '$title 전체 보기',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
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
          ),
        ),
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
              radius: AppTheme.radiusOuter,
              child: Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: AppTheme.smoothShape(radius: AppTheme.radiusInner),
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
            const SizedBox(height: AppTheme.spaceSM),
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
  final VoidCallback onMoreTap;

  const _PopularAuthorsCard({
    required this.authors,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: ChorokCard(
        showBorder: false,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
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
              child: Semantics(
                label: '인기 작가 전체 보기',
                button: true,
                child: IconButton(
                  onPressed: onMoreTap,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: context.appTextTertiary,
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
        child: Row(
          children: [
            Text(
              author.name,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
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
              radius: AppTheme.radiusOuter,
            ),
          );
        },
      ),
    );
  }
}
