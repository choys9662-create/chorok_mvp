import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_stat_cell.dart';
import '../../../shared/widgets/gradient_text.dart';

class SummaryCard extends StatelessWidget {
  final String mainValue;
  final String mainUnit;
  final List<({IconData icon, String label, String value, Color? color})> stats;

  const SummaryCard({super.key, 
    required this.mainValue,
    required this.mainUnit,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GradientText(mainValue,
                  style: AppTheme.displayLarge,
                  gradient: AppTheme.greenGradientVertical),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: GradientText(mainUnit,
                    style: AppTheme.headingMedium,
                    gradient: AppTheme.greenGradient),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: stats.asMap().entries.expand((e) => [
              Expanded(
                child: ChorokStatCell(
                  label: e.value.label,
                  value: e.value.value,
                  icon: e.value.icon,
                  valueColor: e.value.color,
                ),
              ),
              if (e.key < stats.length - 1)
                const SizedBox(width: AppTheme.spaceMD),
            ]).toList(),
          ),
        ],
      ),
    );
  }
}

class FocusCard extends StatelessWidget {
  final int score;
  final String label;
  final String description;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String stat3Label;
  final String stat3Value;

  const FocusCard({super.key, 
    required this.score,
    required this.label,
    required this.description,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.stat3Label,
    required this.stat3Value,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('$score',
                          style: AppTheme.displaySmall.copyWith(color: context.appPrimaryAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceXL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTheme.headingSmall.copyWith(color: context.appTextPrimary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: [
              Expanded(
                child: ChorokStatCell(
                  label: stat1Label, value: stat1Value, icon: Icons.timer_rounded),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: ChorokStatCell(
                  label: stat2Label, value: stat2Value,
                  valueColor: AppTheme.accent, icon: Icons.schedule_rounded),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: ChorokStatCell(
                  label: stat3Label, value: stat3Value,
                  valueColor: context.appPrimaryAccent, icon: Icons.speed_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}