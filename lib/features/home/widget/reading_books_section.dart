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
import 'package:smooth_corner/smooth_corner.dart';

import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';

const _readingBookCardWidth = 118.0;
const _readingBookCardHeight = 180.0;
const _readingBookCardGap = 8.0;

class ReadingBooksSection extends ConsumerWidget {
  const ReadingBooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final isLoading =
        allBooks.isEmpty && ref.read(libraryProvider.notifier).isLoading;
    final readingBooks = allBooks
        .where((b) => b.status == ReadingStatus.reading)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Text(
                '읽고 있는 책',
                style: AppTheme.headingSmall.copyWith(
                  color: context.appTextTertiary,
                  fontWeight: FontWeight.w400,
                  fontSize: 20,
                  letterSpacing: 0,
                ),
              ),
              if (!isLoading) ...[
                const SizedBox(width: 8),
                Text(
                  '|',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextTertiary.withValues(alpha: 0.35),
                    fontSize: 20,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${readingBooks.length}',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextTertiary,
                    fontSize: 20,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const Spacer(),
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
                    size: 30,
                    color: context.appTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── 로딩 중: shimmer 카드 ──────────────────────────────────
        if (isLoading) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: _readingBookCardHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              children: const [
                ChorokShimmer(
                  width: _readingBookCardWidth,
                  height: _readingBookCardHeight,
                  radius: 8,
                ),
                SizedBox(width: _readingBookCardGap),
                ChorokShimmer(
                  width: _readingBookCardWidth,
                  height: _readingBookCardHeight,
                  radius: 8,
                ),
              ],
            ),
          ),
          // ── 빈 상태: 책이 0권일 때 ─────────────────────────────────
        ] else if (readingBooks.isEmpty) ...[
          const SizedBox(height: 12),
          const EmptyBooksState(),
        ] else ...[
          const SizedBox(height: 12),
          // 가로 스크롤 카드 (마지막에 + 추가 카드)
          SizedBox(
            height: _readingBookCardHeight,
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
                        : _readingBookCardGap,
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: ChorokCard(
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
                  smoothness: 0.6,
                  borderRadius: BorderRadius.circular(10),
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
                fontWeight: FontWeight.w400,
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
                    side: BorderSide.none,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: isDark ? context.appPrimaryAccent : Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '책 검색해서 추가하기',
                        style: AppTheme.bodySmall.copyWith(
                          color: isDark
                              ? context.appPrimaryAccent
                              : Colors.white,
                          fontWeight: FontWeight.w400,
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
        side: BorderSide.none,
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
    final b = widget.book;
    final progress = b.totalPages > 0 ? b.currentPage / b.totalPages : 0.0;

    return GestureDetector(
      onTap: () {
        context.push(AppConstants.routeBookDetail, extra: b.id);
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
          width: _readingBookCardWidth,
          height: _readingBookCardHeight,
          radius: 8,
          fallbackIcon: Positioned(
            right: -12,
            bottom: 32,
            child: Icon(
              Icons.menu_book_rounded,
              size: 72,
              color: Colors.white.withValues(alpha: 0.10),
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x99000000),
                        Color(0xE6000000),
                      ],
                    ),
                  ),
                ),
              ),
              // 제목 · 저자 · 진행바
              Positioned(
                left: 8,
                right: 8,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        height: 1.2,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    ProgressBar(value: progress),
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
        child: Container(
          width: _readingBookCardWidth,
          height: _readingBookCardHeight,
          alignment: Alignment.center,
          decoration: AppTheme.smoothBox(
            color: context.primaryBg(0.04),
            radius: 8,
            side: BorderSide(color: context.appBorderSubtle),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 30,
            color: context.appTextTertiary.withValues(alpha: 0.6),
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
          color: context.appProgressTrack,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: context.appReadingGradient,
            ),
          ),
        ),
      ),
    );
  }
}
