import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 핵심 수치 강조 셀 — 값(크게) + 레이블(작게)
class ChorokStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const ChorokStatCell({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = valueColor ?? context.appPrimaryAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: AppTheme.headingMedium.copyWith(color: color),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
        ),
      ],
    );
  }
}
