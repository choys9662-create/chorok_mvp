import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../../../shared/widgets/book_cover.dart';
import '../controller/recommended_books_provider.dart';

class RecommendedBooksSection extends ConsumerWidget {
  const RecommendedBooksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recommendedBooksProvider);

    return async.when(
      loading: () => _scaffold(context, child: _shimmer(context)),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) {
          return _scaffold(context, child: _emptyCard(context));
        }
        return _scaffold(
          context,
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < books.length - 1 ? 12 : 0,
                  ),
                  child: RecommendedBookCard(book: books[index]),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _scaffold(BuildContext context, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 문장이 이끄는 책',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '기록한 문장을 분석해 취향에 맞는 책을 추천해요',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: context.primaryBg(0.08),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: 8,
                      cornerSmoothing: 0.6,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _shimmer(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
        ),
        itemCount: 2,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(right: index == 0 ? 12 : 0),
          child: Container(
            width: 240,
            decoration: AppTheme.smoothBox(
              color: context.appCard,
              radius: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.smoothBox(color: context.appCard, radius: 16),
        child: Text(
          '문장을 더 기록하면 취향에 맞는 책을 추천해드려요',
          style: AppTheme.bodySmall.copyWith(
            color: context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

class RecommendedBookCard extends StatefulWidget {
  final RecommendedBook book;
  const RecommendedBookCard({super.key, required this.book});

  @override
  State<RecommendedBookCard> createState() => RecommendedBookCardState();
}

class RecommendedBookCardState extends State<RecommendedBookCard> {
  bool _isPressed = false;
  bool _isAdded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.book;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${b.title} 상세 정보 (곧 지원)',
              style:
                  AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
            ),
            backgroundColor: context.appCardElevated,
            behavior: SnackBarBehavior.floating,
            shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          ),
        );
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 240,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(color: context.appCard, radius: 16),
          child: Row(
            children: [
              BookCover(
                coverUrl: b.coverUrl,
                gradientIndex: b.gradientIndex,
                width: 88,
                radius: 0,
                fallbackIcon: Positioned(
                  right: -8,
                  bottom: -8,
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: context.primaryBg(0.08),
                  ),
                ),
                child: Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: ShapeDecoration(
                      color: context.appSurface.withValues(alpha: 0.8),
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(
                          cornerRadius: 6,
                          cornerSmoothing: 0.6,
                        ),
                      ),
                    ),
                    child: Text(
                      '${(b.matchScore * 100).round()}%',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: AppTheme.bodySmall.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w700,
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
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.06,
                          ),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.format_quote_rounded,
                                size: 12,
                                color: context.appPrimaryAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                b.reason,
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Semantics(
                        label: _isAdded
                            ? '${b.title} 서재에서 제거'
                            : '${b.title} 서재에 추가',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            setState(() => _isAdded = !_isAdded);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _isAdded
                                      ? '${b.title}을(를) 읽고 싶은 책에 추가했어요'
                                      : '${b.title}을(를) 서재에서 제거했어요',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: AppTheme.smoothShape(
                                  radius: AppTheme.radiusMD,
                                ),
                                margin: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  16,
                                ),
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: _isAdded
                                  ? context.appPrimaryAccent
                                      .withValues(alpha: 0.15)
                                  : isDark
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : AppTheme.lightPrimaryAccent,
                              shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                  cornerRadius: 8,
                                  cornerSmoothing: 0.6,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isAdded
                                      ? Icons.check_rounded
                                      : Icons.add_rounded,
                                  size: 14,
                                  color: _isAdded
                                      ? context.appPrimaryAccent
                                      : isDark
                                          ? context.appPrimaryAccent
                                          : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isAdded ? '추가됨' : '서재에 추가',
                                  style: AppTheme.captionSmall.copyWith(
                                    color: _isAdded
                                        ? context.appPrimaryAccent
                                        : isDark
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
