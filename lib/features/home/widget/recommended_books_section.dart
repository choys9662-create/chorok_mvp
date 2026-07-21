import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/profile_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../controller/recommended_books_provider.dart';

class RecommendedBooksSection extends ConsumerWidget {
  const RecommendedBooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendedBooksProvider);
    // 이름을 아직 못 불러왔으면 이름 없는 제목으로 먼저 보여준다.
    final myName = ref.watch(myDisplayNameProvider).valueOrNull;
    final title = myName != null ? '$myName님 맞춤 추천 책' : '맞춤 추천 책';

    return async.when(
      loading: () => _scaffold(context, title: title, child: _shimmer(context)),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) {
          return _scaffold(context, title: title, child: _emptyCard(context));
        }
        // 4열 × 2행 = 8권. 탐색 화면의 맞춤 추천 그리드와 같은 배치다.
        // 표지만 보이므로 제목·저자·추천 이유는 화살표를 눌러 시트에서 본다.
        return _scaffold(
          context,
          title: title,
          onShowAll: () => _showAll(context, title, books),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: books.length > 8 ? 8 : books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: AppTheme.recommendedBookGridGap,
                mainAxisSpacing: AppTheme.recommendedBookGridGap,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (_, i) => RecommendedBookCover(book: books[i]),
            ),
          ),
        );
      },
    );
  }

  Widget _scaffold(
    BuildContext context, {
    required String title,
    required Widget child,
    VoidCallback? onShowAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.sectionGap),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: title,
            trailing: onShowAll == null
                ? null
                : Semantics(
                    button: true,
                    label: '$title 전체 보기',
                    child: GestureDetector(
                      onTap: onShowAll,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: AppTheme.spaceXL,
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceLG),
        child,
      ],
    );
  }

  /// 그리드에는 표지만 나오므로, 제목·저자·추천 이유는 여기서 보여준다.
  void _showAll(
    BuildContext context,
    String title,
    List<RecommendedBook> books,
  ) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appCard,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusOuter),
        ),
      ),
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
                  0,
                  AppTheme.screenPadding,
                  AppTheme.spaceMD,
                ),
                child: ChorokSectionHeader(title: title),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    0,
                    AppTheme.screenPadding,
                    AppTheme.spaceLG,
                  ),
                  itemCount: books.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spaceMD),
                  itemBuilder: (_, i) {
                    final b = books[i];
                    return ChorokListRow(
                      leading: BookCover(
                        coverUrl: b.coverUrl.isEmpty ? null : b.coverUrl,
                        gradientIndex: b.gradientIndex,
                        width: 40,
                        height: 60,
                        radius: AppTheme.radiusInner,
                      ),
                      title: Text(
                        b.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                      supporting: Text(
                        '${b.author} · ${b.reason}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.supportingText.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      trailing: Text(
                        '${(b.matchScore * 100).round()}%',
                        style: AppTheme.supportingText.copyWith(
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: AppTheme.recommendedBookGridGap,
          mainAxisSpacing: AppTheme.recommendedBookGridGap,
          childAspectRatio: 0.66,
        ),
        itemBuilder: (_, _) => const ChorokCard(
          padding: EdgeInsets.zero,
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: ChorokCard(
        child: Text(
          '문장을 더 기록하면 취향에 맞는 책을 추천해드려요',
          style: AppTheme.supportingText.copyWith(
            color: context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

/// 맞춤 추천 그리드의 한 칸 — 표지 + 일치율 배지.
///
/// 4열 그리드에 들어가므로 폭은 그리드 칸이 정하고, 세로 비율만 표지가 맡는다.
class RecommendedBookCover extends StatelessWidget {
  final RecommendedBook book;
  const RecommendedBookCover({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final query = Uri.encodeQueryComponent('${book.title} ${book.author}');
        final url = Uri.parse(
          'https://www.aladin.co.kr/search/wsearchresult.aspx'
          '?SearchTarget=Book&SearchWord=$query',
        );
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Semantics(
        button: true,
        label: '${book.title} 알라딘에서 보기',
        child: BookCover(
          coverUrl: book.coverUrl.isEmpty ? null : book.coverUrl,
          gradientIndex: book.gradientIndex,
          width: double.infinity,
          radius: AppTheme.radiusOuter,
          child: Positioned(
            top: AppTheme.spaceXS,
            left: AppTheme.spaceXS,
            child: ChorokCard(
              inner: true,
              showBorder: false,
              backgroundColor: context.appSurface.withValues(alpha: 0.8),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXS,
                vertical: 2,
              ),
              child: Text(
                '${(book.matchScore * 100).round()}%',
                style: AppTheme.caption.copyWith(
                  color: context.appPrimaryAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
