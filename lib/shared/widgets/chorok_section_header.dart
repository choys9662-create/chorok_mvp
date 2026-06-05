import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 섹션 헤더 — 타이틀 + 선택적 서브타이틀 + trailing 위젯
class ChorokSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ChorokSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 3,
          height: subtitle == null ? 18 : 32,
          decoration: BoxDecoration(
            color: context.appPrimaryAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.headingMedium.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
