import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

/// 레이더 차트 — 독서 습관 5축 비교 (이번 달 vs 지난 달)
///
/// [current]  이번 달 값 리스트 (0.0 ~ 1.0, 5개)
/// [previous] 지난 달 값 리스트 (0.0 ~ 1.0, 5개)
class HabitRadarChartWidget extends StatelessWidget {
  final List<double> current;
  final List<double> previous;

  const HabitRadarChartWidget({
    super.key,
    required this.current,
    required this.previous,
  });

  static const _axes = ['독서시간', '초서수', '집중도', '완독률', '연속성'];
  static const _maxVal = 1.0;

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 5,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                radarBorderData: const BorderSide(color: Colors.transparent),
                gridBorderData: BorderSide.none,
                tickBorderData: BorderSide.none,
                titlePositionPercentageOffset: 0.15,
                titleTextStyle: AppTheme.captionSmall.copyWith(
                  color: context.appTextSecondary,
                  fontSize: AppTheme.fsSupporting,
                ),
                getTitle: (index, angle) {
                  return RadarChartTitle(
                    text: _axes[index % _axes.length],
                    angle: 0,
                  );
                },
                dataSets: [
                  // 지난 달 (뒤에 그려서 이번 달이 위에 보임)
                  // 구조상 예외: 이번 달(primaryAccent)과 대비되는 비교
                  // 시리즈 전용 중립 회색 — 6색 팔레트에 대응 역할 없음.
                  RadarDataSet(
                    fillColor: const Color(0xFF444444).withValues(alpha: 0.15),
                    borderColor: const Color(0xFF444444),
                    borderWidth: 1.5,
                    entryRadius: 0,
                    dataEntries: previous
                        .map((v) => RadarEntry(value: v * _maxVal * 5))
                        .toList(),
                  ),
                  // 이번 달
                  RadarDataSet(
                    fillColor: context.appPrimaryAccent.withValues(alpha: 0.3),
                    borderColor: context.appPrimaryAccent,
                    borderWidth: 2,
                    entryRadius: 3,
                    dataEntries: current
                        .map((v) => RadarEntry(value: v * _maxVal * 5))
                        .toList(),
                  ),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
              swapAnimationCurve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: context.appPrimaryAccent, label: '이번 달'),
              const SizedBox(width: AppTheme.spaceLG),
              // 구조상 예외: 위 비교 시리즈 색과 동일(지난 달 중립 회색).
              _LegendDot(color: const Color(0xFF444444), label: '지난 달'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.captionSmall.copyWith(
            color: context.appTextSecondary,
          ),
        ),
      ],
    );
  }
}
