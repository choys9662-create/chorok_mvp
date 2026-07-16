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

  /// 지정 시 outline 스타일 대신 단색으로 가득 채운다 (보더 제거).
  /// 예: 오늘 독서 완료 → 네온 그린 단색 카드.
  final Color? fillColor;

  /// 다크 모드 테두리 색상 오버라이드. null이면 기본값(#8DFF54) 사용.
  final Color? darkBorderColor;

  const ForestAccentCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppTheme.radiusLG,
    this.fillColor,
    this.darkBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // fillColor 지정 시: 단색 채움 + 보더 없음
    if (fillColor != null) {
      return DecoratedBox(
        decoration: AppTheme.smoothBox(color: fillColor, radius: radius),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppTheme.cardPaddingLG),
          child: child,
        ),
      );
    }

    // 라이브 포레스트 원본 디자인: 배경과 동일한 단색 + 네온 그린 라인 보더만
    // → 카드가 fill 없이 "outline만 떠 있는" 느낌으로 라이브 포레스트 정체성 표현
    final Color bg = context.appBg;

    final BorderSide side = BorderSide(
      color: isDark
          ? (darkBorderColor ?? const Color(0xFF8DFF54))
          : AppTheme.lightPrimaryAccent.withValues(alpha: 0.45),
      width: 1,
    );

    return DecoratedBox(
      decoration: AppTheme.smoothBox(color: bg, radius: radius, side: side),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppTheme.cardPaddingLG),
        child: child,
      ),
    );
  }
}
