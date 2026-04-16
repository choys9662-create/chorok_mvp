import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

const Color _kLabel = Color(0xFF7A8597);

/// 스택드 에리어 차트 — 주간/월간 독서 시간을 장르별로 층층이 쌓기
///
/// [labels]  x축 레이블 (주 또는 날짜)
/// [series]  장르별 데이터: (name, color, values)
class StackedAreaChartWidget extends StatefulWidget {
  final List<String> labels;
  final List<({String name, Color color, List<double> values})> series;

  const StackedAreaChartWidget({
    super.key,
    required this.labels,
    required this.series,
  });

  @override
  State<StackedAreaChartWidget> createState() => _StackedAreaChartWidgetState();
}

class _StackedAreaChartWidgetState extends State<StackedAreaChartWidget> {
  late List<bool> _visible;

  @override
  void initState() {
    super.initState();
    _visible = List.filled(widget.series.length, true);
  }

  // 누적합 계산 (스택 효과)
  List<List<double>> _stackedValues() {
    final n = widget.labels.length;
    final result = <List<double>>[];
    final acc = List<double>.filled(n, 0);
    for (int s = 0; s < widget.series.length; s++) {
      final vals = widget.series[s].values;
      for (int i = 0; i < n; i++) {
        acc[i] += _visible[s] ? vals[i] : 0;
      }
      result.add(List<double>.from(acc));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final stacked = _stackedValues();
    final maxY = stacked.isEmpty
        ? 60.0
        : stacked.last.reduce((a, b) => a > b ? a : b) * 1.2;

    final lines = <LineChartBarData>[];
    // 위 레이어부터 아래로 그려서 하위 색상이 덮이지 않게
    for (int s = widget.series.length - 1; s >= 0; s--) {
      final sp = widget.series[s];
      final topVals = stacked[s];

      lines.add(LineChartBarData(
        spots: List.generate(
          widget.labels.length,
          (i) => FlSpot(i.toDouble(), topVals[i]),
        ),
        isCurved: true,
        curveSmoothness: 0.35,
        color: sp.color,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: sp.color.withValues(alpha: 0.25),
          applyCutOffY: false,
          spotsLine: BarAreaSpotsLine(show: false),
        ),
      ));
    }

    return ChorokCard(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD, AppTheme.cardPaddingLG,
        AppTheme.cardPaddingLG, AppTheme.cardPaddingLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (widget.labels.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.appBorder,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: maxY / 4,
                      getTitlesWidget: (v, _) => Text(
                        '${v.round()}h',
                        style: AppTheme.captionSmall.copyWith(
                          color: _kLabel,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) {
                        final idx = v.round();
                        if (idx < 0 || idx >= widget.labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          widget.labels[idx],
                          style: AppTheme.captionSmall.copyWith(
                            color: _kLabel,
                              fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A1A),
                    tooltipRoundedRadius: 9999,
                    getTooltipItems: (spots) => spots.map((s) {
                      final idx = widget.series.length - 1 - s.barIndex;
                      final name = idx >= 0 ? widget.series[idx].name : '';
                      return LineTooltipItem(
                        '$name ${s.y.round()}h',
                        AppTheme.captionSmall.copyWith(
                          color: s.bar.color,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: lines,
              ),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          // 범례
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(widget.series.length, (i) {
              final sp = widget.series[i];
              final active = _visible[i];
              return GestureDetector(
                onTap: () => setState(() => _visible[i] = !active),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: ShapeDecoration(
                    color: active
                        ? sp.color.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    shape: const StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: ShapeDecoration(
                          color: active ? sp.color : _kLabel,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sp.name,
                        style: AppTheme.captionSmall.copyWith(
                          color: active ? sp.color : _kLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
