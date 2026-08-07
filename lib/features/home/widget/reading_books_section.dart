import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/utils/reading_insight_engine.dart';

import '../../search/util/book_info_navigation.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_shimmer.dart';

/// 최근에 추가하거나 읽은 책부터 보여준다.
int compareReadingBooks(Book a, Book b) {
  DateTime? latestActivity(Book book) {
    final addedAt = book.addedAt;
    final startedAt = book.lastSessionStartedAt;
    if (addedAt == null) return startedAt;
    if (startedAt == null) return addedAt;
    return addedAt.isAfter(startedAt) ? addedAt : startedAt;
  }

  final aActivity = latestActivity(a);
  final bActivity = latestActivity(b);
  if (aActivity == null && bActivity == null) return 0;
  if (aActivity == null) return 1;
  if (bActivity == null) return -1;
  return bActivity.compareTo(aActivity);
}

const readingBookCardWidth = 118.0;
const readingBookCardHeight = 180.0;
const readingBookCardGap = AppTheme.spaceSM;

class ReadingBooksSection extends ConsumerWidget {
  const ReadingBooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final isLoading =
        allBooks.isEmpty && ref.read(libraryProvider.notifier).isLoading;
    final readingBooks =
        allBooks.where((b) => b.status == ReadingStatus.reading).toList()
          ..sort(compareReadingBooks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: '읽고 있는 책',
            count: isLoading ? null : readingBooks.length,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: '책 추가하기',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      context.push(AppConstants.routeExplore);
                    },
                    child: Icon(
                      Icons.add_rounded,
                      size: AppTheme.spaceXL,
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── 로딩 중: shimmer 카드 ──────────────────────────────────
        if (isLoading) ...[
          const SizedBox(height: AppTheme.spaceMD),
          SizedBox(
            height: readingBookCardHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              children: const [
                ChorokShimmer(
                  width: readingBookCardWidth,
                  height: readingBookCardHeight,
                  radius: AppTheme.radiusOuter,
                ),
                SizedBox(width: readingBookCardGap),
                ChorokShimmer(
                  width: readingBookCardWidth,
                  height: readingBookCardHeight,
                  radius: AppTheme.radiusOuter,
                ),
              ],
            ),
          ),
          // ── 빈 상태: 책이 0권일 때 ─────────────────────────────────
        ] else if (readingBooks.isEmpty) ...[
          const SizedBox(height: AppTheme.spaceMD),
          const EmptyBooksState(),
        ] else ...[
          const SizedBox(height: AppTheme.spaceMD),
          // 가로 스크롤 카드 (마지막에 + 추가 카드)
          SizedBox(
            height: readingBookCardHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              itemCount: readingBooks.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == readingBooks.length - 1
                        ? 0
                        : readingBookCardGap,
                  ),
                  child: ReadingBookCard(book: readingBooks[index]),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class EmptyBooksState extends StatelessWidget {
  const EmptyBooksState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: ChorokCard(
                inner: true,
                padding: EdgeInsets.zero,
                borderColor: context.appCardElevated,
                child: Center(
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 28,
                    color: context.appPrimaryAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              '아직 등록된 책이 없어요',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              '첫 번째 책을 추가하고 독서를 시작해보세요',
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXL),
            Semantics(
              label: '책 검색해서 추가하기',
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(AppConstants.routeExplore);
                },
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: ChorokCard(
                    inner: true,
                    showBorder: false,
                    padding: EdgeInsets.zero,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: AppTheme.sectionTitle.fontSize,
                          color: context.appPrimaryAccent,
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        Text(
                          '책 검색해서 추가하기',
                          style: AppTheme.supportingText.copyWith(
                            color: context.appPrimaryAccent,
                          ),
                        ),
                      ],
                    ),
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

class InsightChip extends StatelessWidget {
  final ReadingInsight insight;

  const InsightChip({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      borderColor: context.appCardElevated,
      child: Row(
        children: [
          Icon(insight.icon, size: 16, color: context.appPrimaryAccent),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              insight.message,
              style: AppTheme.captionLarge.copyWith(
                color: context.appPrimaryAccent,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (insight.subMessage != null) ...[
            const SizedBox(width: AppTheme.spaceSM),
            Text(
              insight.subMessage!,
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ReadingBookCard extends ConsumerStatefulWidget {
  final Book book;
  const ReadingBookCard({super.key, required this.book});

  @override
  ConsumerState<ReadingBookCard> createState() => ReadingBookCardState();
}

class ReadingBookCardState extends ConsumerState<ReadingBookCard> {
  bool _isPressed = false;

  Future<void> _changeVersion() async {
    HapticFeedback.selectionClick();
    final changedTitle = await context.push<String>(
      AppConstants.routeSearch,
      extra: widget.book,
    );
    if (changedTitle == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$changedTitle 버전으로 변경했어요',
          style: AppTheme.supportingText.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
        margin: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.spaceLG,
        ),
      ),
    );
  }

  /// 서재에서 제거 (확인 후). book_detail_sheet의 삭제 플로우와 동일.
  Future<void> _confirmDelete() async {
    HapticFeedback.mediumImpact();
    final book = widget.book;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서재에서 제거'),
        content: Text(
          '\'${book.title}\'을(를) 서재에서 제거할까요?\n기록된 독서 데이터도 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref.read(libraryProvider.notifier).deleteBook(book.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${book.title}을(를) 서재에서 제거했어요',
          style: AppTheme.supportingText.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
        margin: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.spaceLG,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final progress = b.totalPages > 0 ? b.currentPage / b.totalPages : 0.0;

    return GestureDetector(
      onTap: () {
        pushBookInfo(context, b);
      },
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: BookCover(
          coverUrl: b.coverUrl,
          gradientIndex:
              b.title.hashCode.abs() % AppTheme.coverGradients.length,
          width: readingBookCardWidth,
          height: readingBookCardHeight,
          radius: AppTheme.radiusOuter,
          fallbackIcon: Positioned(
            right: -12,
            bottom: 32,
            child: Icon(
              Icons.menu_book_rounded,
              size: 72,
              color: AppTheme.textPrimary.withValues(alpha: 0.10),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 하단 제목/저자 가독성용 스크림
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 116,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primary.withValues(alpha: 0),
                        AppTheme.primary.withValues(alpha: 0.6),
                        AppTheme.primary.withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // 제목 · 저자 · 진행바
              Positioned(
                left: AppTheme.spaceSM,
                right: AppTheme.spaceSM,
                bottom: AppTheme.spaceMD,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.rowText.copyWith(
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      b.author,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.textPrimary.withValues(alpha: 0.75),
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    ChorokProgressBar(value: progress),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<_BookCardAction>(
                  tooltip: '책 편집',
                  padding: EdgeInsets.zero,
                  icon: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.52),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                  onSelected: (action) {
                    switch (action) {
                      case _BookCardAction.changeVersion:
                        _changeVersion();
                        return;
                      case _BookCardAction.delete:
                        _confirmDelete();
                        return;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _BookCardAction.changeVersion,
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 20),
                          SizedBox(width: 10),
                          Text('다른 버전으로 변경'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _BookCardAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: AppTheme.warningColor,
                          ),
                          SizedBox(width: 10),
                          Text(
                            '책 삭제',
                            style: AppTheme.supportingText.copyWith(
                              color: AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BookCardAction { changeVersion, delete }

/// 책 추가용 플레이스홀더 카드 (목록 끝의 "+").
class AddBookCard extends StatelessWidget {
  const AddBookCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '책 추가하기',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeExplore);
        },
        child: SizedBox(
          width: readingBookCardWidth,
          height: readingBookCardHeight,
          child: ChorokCard(
            padding: EdgeInsets.zero,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                size: 30,
                color: context.appTextTertiary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
