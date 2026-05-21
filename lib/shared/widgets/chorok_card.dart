import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 초록 표준 카드 컨테이너 — Apple-style smooth corner
class ChorokCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final bool elevated;
  final bool hasShadow;

  const ChorokCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.elevated = false,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = elevated ? context.appCardElevated : context.appCard;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: bg,
        radius: 16,
        side: BorderSide.none,
        shadows: hasShadow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : isDark
                ? null
                : AppTheme.lightCardShadows,
      ),
      child: child,
    );
  }
}
