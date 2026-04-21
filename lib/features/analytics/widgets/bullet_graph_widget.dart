import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

/// 불릿 그래프 — 목표 독서 시간 달성도
/// 얇은 바(h 20) 안에 배경 트랙 → 현재 진행률 → 목표 마커 3개 레이어
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
    const goalMarkerRatio = 1.0;

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
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: 20,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. 배경 트랙
                      Container(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1A1A1A)
                            : AppTheme.lightDivider,
                      ),
                      // 2. 현재 진행률
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppTheme.greenGradient,
                          ),
                        ),
                      ),
                      // 3. 목표 마커 (흰색 세로선 2px)
                      Positioned(
                        left: constraints.maxWidth * goalMarkerRatio - 1,
                        top: 2,
                        bottom: 2,
                        width: 2,
                        child: Container(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).round()}% 달성',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
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
