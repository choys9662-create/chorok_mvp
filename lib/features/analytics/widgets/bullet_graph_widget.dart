import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

/// 불릿 그래프 — 목표 독서 시간 달성도
class BulletGraphWidget extends StatelessWidget {
  final String label;
  final double currentHours;
  final double goalHours;

  const BulletGraphWidget({
    super.key,
    required this.label,
    required this.currentHours,
    required this.goalHours,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentHours / goalHours).clamp(0.0, 1.0);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.headingSmall.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                '${currentHours.toStringAsFixed(1)} / ${goalHours.toStringAsFixed(0)}시간',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          SizedBox(
            height: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: Stack(
                clipBehavior: Clip.antiAlias,
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1A1A)
                        : context.appBg,
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.greenGradient,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% 달성',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                '목표 ${goalHours.toStringAsFixed(0)}시간',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
