import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'package:figma_squircle/figma_squircle.dart';
typedef RecommendedBook = ({
  String title,
  String author,
  String reason,
  int gradientIndex,
  double matchScore,
});

const List<RecommendedBook> kRecommendedBooks = [
  (
    title: '소년이 온다',
    author: '한강',
    reason: '"채식주의자"에서 수집한 문장과 비슷한 감성',
    gradientIndex: 3,
    matchScore: 0.94,
  ),
  (
    title: '아몬드',
    author: '손원평',
    reason: '감정과 공감에 대한 문장을 자주 기록하셨어요',
    gradientIndex: 4,
    matchScore: 0.89,
  ),
  (
    title: '작별하지 않는다',
    author: '한강',
    reason: '"파친코"에서 저장한 가족 서사와 닮은 이야기',
    gradientIndex: 5,
    matchScore: 0.86,
  ),
  (
    title: '불편한 편의점',
    author: '김호연',
    reason: '따뜻한 일상 문장을 좋아하시는 취향에 맞춰',
    gradientIndex: 6,
    matchScore: 0.82,
  ),
];

class RecommendedBooksSection extends StatelessWidget {
  const RecommendedBooksSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: context.primaryBg(0.08),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: 8,
                      cornerSmoothing: 0.6,
                    ),
                    side: BorderSide(
                      color: context.appPrimaryAccent.withValues(alpha: 0.2),
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
        // 가로 스크롤 추천 카드
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: kRecommendedBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < kRecommendedBooks.length - 1 ? 12 : 0,
                ),
                child: RecommendedBookCard(book: kRecommendedBooks[index]),
              );
            },
          ),
        ),
      ],
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
    final gradColors = AppTheme.coverGradientByIndex(b.gradientIndex);

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
              style: AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
            ),
            backgroundColor: context.appCardElevated,
            behavior: SnackBarBehavior.floating,
            shape: AppTheme.smoothShape(
              radius: AppTheme.radiusMD,
              side: BorderSide(color: context.appBorder),
            ),
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
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              // 표지 썸네일
              Container(
                width: 88,
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
                      right: -8,
                      bottom: -8,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: context.primaryBg(0.08),
                      ),
                    ),
                    // 매칭 점수
                    Positioned(
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
                  ],
                ),
              ),
              // 책 정보
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
                      // 추천 이유
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          color: context.appPrimaryAccent.withValues(alpha: 0.06),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 0.6,
                            ),
                            side: BorderSide(
                              color: context.appPrimaryAccent.withValues(alpha: 0.15),
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
                      // 서재에 추가 버튼
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
                                shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
                                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                                  ? context.appPrimaryAccent.withValues(alpha: 0.15)
                                  : isDark
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : AppTheme.lightPrimaryAccent,
                              shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                  cornerRadius: 8,
                                  cornerSmoothing: 0.6,
                                ),
                                side: BorderSide(
                                  color: _isAdded
                                      ? context.appPrimaryAccent
                                      : context.appPrimaryAccent.withValues(
                                          alpha: 0.2,
                                        ),
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