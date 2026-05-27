import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 라이브 포레스트 정체성을 띈 강조형 카드 컨테이너.
///
/// 다크 그린 그라디언트 + 네온 그린 라디얼 글로우 + smooth corner + 네온 보더.
/// 라이트 모드에서도 일관된 정체성을 위해 동일 톤을 살짝 옅게 적용한다.
class ForestAccentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const ForestAccentCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppTheme.radiusLG,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 라이브 포레스트 원본 디자인: 배경과 동일한 단색 + 네온 그린 라인 보더만
    // → 카드가 fill 없이 "outline만 떠 있는" 느낌으로 라이브 포레스트 정체성 표현
    final Color bg = context.appBg;

    final BorderSide side = BorderSide(
      color: isDark
          ? AppTheme.fireflyColor.withValues(alpha: 0.55)
          : AppTheme.lightPrimaryAccent.withValues(alpha: 0.45),
      width: 1,
    );

    return DecoratedBox(
      decoration: AppTheme.smoothBox(
        color: bg,
        radius: radius,
        side: side,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.cardPaddingLG),
        child: child,
      ),
    );
  }
}
