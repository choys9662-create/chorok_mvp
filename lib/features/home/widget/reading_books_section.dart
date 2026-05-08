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
import 'package:figma_squircle/figma_squircle.dart';
import '../screen/book_detail_screen.dart';
import '../../../shared/models/session_goal.dart';

class ReadingBooksSection extends ConsumerWidget {
  const ReadingBooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final readingBooks =
        allBooks.where((b) => b.status == ReadingStatus.reading).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Text(
                '지금 읽는 책',
                style: AppTheme.headingSmall.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${readingBooks.length}권',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── 빈 상태: 책이 0권일 때 ─────────────────────────────────
        if (readingBooks.isEmpty) ...[
          const SizedBox(height: 12),
          const EmptyBooksState(),
        ] else ...[
          const SizedBox(height: 12),
          // 가로 스크롤 카드
          SizedBox(
            height: 240,
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
                    right: index < readingBooks.length - 1 ? 12 : 0,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
      ),
      child: ChorokCard(
        borderColor: context.appBorder,
        padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: ShapeDecoration(
                color: context.primaryBg(0.08),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 16,
                    cornerSmoothing: 0.6,
                  ),
                ),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                size: 28,
                color: context.appPrimaryAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '아직 등록된 책이 없어요',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '첫 번째 책을 추가하고 독서를 시작해보세요',
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Semantics(
              label: '책 검색해서 추가하기',
              button: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(AppConstants.routeExplore);
                },
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: AppTheme.smoothPill(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : AppTheme.lightPrimaryAccent,
                    side: BorderSide(
                      color: context.appPrimaryAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark
                            ? context.appPrimaryAccent
                            : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '책 검색해서 추가하기',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark
                              ? context.appPrimaryAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.smoothBox(
        color: context.appPrimaryAccent.withValues(alpha: 0.08),
        radius: AppTheme.radiusMD,
        side: BorderSide(color: context.appPrimaryAccent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(insight.icon, size: 16, color: context.appPrimaryAccent),
          const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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

class ReadingBookCard extends StatefulWidget {
  final Book book;
  const ReadingBookCard({super.key, required this.book});

  @override
  State<ReadingBookCard> createState() => ReadingBookCardState();
}

class ReadingBookCardState extends State<ReadingBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.book;
    final progress = b.totalPages > 0 ? b.currentPage / b.totalPages : 0.0;
    final gradColors = AppTheme.coverGradientFor(b.title);

    return GestureDetector(
      onTap: () {
        context.push(
          AppConstants.routeBookDetail,
          extra: BookDetailExtra(
            bookId: b.id,
            title: b.title,
            author: b.author,
            currentPage: b.currentPage,
            totalPages: b.totalPages,
            lastRead: '최근 읽음',
            gradientIndex: b.title.hashCode.abs() % AppTheme.coverGradients.length,
            savedSentences: b.savedSentences,
          ),
        );
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
        child: Container(
          width: 160,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusLG,
            side: BorderSide(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 표지
              Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 64,
                        color: context.primaryBg(0.08),
                      ),
                    ),
                    // 진행률 배지
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.75),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 책 정보
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${b.currentPage} / ${b.totalPages}쪽',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 이어 읽기 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Semantics(
                  label: '${b.title} 이어 읽기',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            bookId: b.id,
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: b.currentPage,
                            totalPages: b.totalPages,
                          ),
                        );
                    },
                    child: Container(
                      height: 36,
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
                        style: AppTheme.captionLarge.copyWith(
                          color: isDark
                              ? context.appPrimaryAccent
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double value;
  const ProgressBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: context.appBorder,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: context.appReadingGradient,
            ),
          ),
        ),
      ),
    );
  }
}