import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 그라디언트 텍스트 — ShaderMask로 #00FF00 → #00CC6A 적용
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.gradient = AppTheme.greenGradient,
  });

  @override
  Widget build(BuildContext context) {
    // 라이트 모드에서는 네온 그라디언트 대신 딥 그린 단색 사용
    if (Theme.of(context).brightness == Brightness.light) {
      return Text(
        text,
        style: (style ?? const TextStyle()).copyWith(
          color: context.appPrimaryAccent,
        ),
      );
    }
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}

/// 그라디언트 아이콘
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Gradient gradient;

  const GradientIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.gradient = AppTheme.greenGradient,
  });

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.light) {
      return Icon(icon, size: size, color: context.appPrimaryAccent);
    }
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
