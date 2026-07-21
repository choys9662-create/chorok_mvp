import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

/// 와플 차트 — 10×10 격자(100칸)로 장르 비율 표시
///
/// [genres] 각 항목: (name, color, cells) — cells 합계 = 100
class WaffleChartWidget extends StatelessWidget {
  final List<({String name, Color color, int cells})> genres;

  const WaffleChartWidget({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    // 빈 셀: 다크 모드는 어두운 녹색, 라이트 모드는 연한 민트
    final emptyColor = context.appCard;
    // 100칸 색상 배열 구성
    final cellColors = List<Color>.filled(100, emptyColor);
    int idx = 0;
    for (final g in genres) {
      for (int i = 0; i < g.cells && idx < 100; i++, idx++) {
        cellColors[idx] = g.color;
      }
    }

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 10×10 그리드
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: 100,
              itemBuilder: (_, i) => Container(
                decoration: BoxDecoration(
                  color: cellColors[i],
                  borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          // 장르별 범례 Pill
          Wrap(
            spacing: AppTheme.spaceSM,
            runSpacing: 6,
            children: genres.map((g) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: AppTheme.spaceXS,
                ),
                decoration: ShapeDecoration(
                  color: g.color.withValues(alpha: 0.15),
                  shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: g.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${g.name} ${g.cells}%',
                      style: AppTheme.captionSmall.copyWith(color: g.color),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
