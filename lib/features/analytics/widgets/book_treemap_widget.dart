import 'dart:math' as math;
import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

/// 트리맵 — 독서 시간을 항목별 면적으로 표현
///
/// [items] 각 항목: (label, hours) — 시간 많을수록 primaryLight에 가까운 색상
class BookTreemapWidget extends StatelessWidget {
  final List<({String label, double hours})> items;
  final double height;
  final double? width;

  const BookTreemapWidget({
    super.key,
    required this.items,
    this.height = 260,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        width: width ?? double.infinity,
        child: ChorokCard(
          padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                '아직 독서 기록이 없어요',
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.spaceSM),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sorted = [...items]
                ..sort((a, b) => b.hours.compareTo(a.hours));
              final maxH = sorted.first.hours;
              final values = sorted.map((e) => e.hours).toList();
              final bounds = Rect.fromLTWH(
                0,
                0,
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final rects = _Squarify.compute(values, bounds);

              return Stack(
                children: List.generate(math.min(rects.length, sorted.length), (
                  i,
                ) {
                  final rect = rects[i];
                  final item = sorted[i];
                  final t = maxH > 0 ? item.hours / maxH : 0.0;
                  // 구조상 예외: 트리맵 강도 그라데이션의 저강도 끝값 —
                  // heatmap_calendar_widget.dart의 _kLv1과 동일 계열.
                  final color = Color.lerp(
                    const Color(0xFF0F6E56),
                    context.appPrimaryAccent,
                    t,
                  )!;
                  final showLabel = rect.width > 80 && rect.height > 50;
                  // 블록 크기에 비례한 폰트 — 장르가 적어 블록이 클 때 라벨이 작게 뜨는 문제 방지
                  final labelFontSize = (math.min(rect.width, rect.height) / 7)
                      .clamp(12.0, 28.0);
                  final hoursFontSize = (labelFontSize * 0.5).clamp(9.0, 15.0);

                  return Positioned(
                    left: rect.left + 1,
                    top: rect.top + 1,
                    width: rect.width - 2,
                    height: rect.height - 2,
                    child: SmoothClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                      smoothness: 0.6,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        color: color.withValues(alpha: 0.85),
                        child: showLabel
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.label,
                                      style: AppTheme.captionSmall.copyWith(
                                        fontSize: labelFontSize,
                                        color: Colors.black.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spaceXS),
                                  Text(
                                    '${item.hours.toStringAsFixed(1)}h',
                                    style: AppTheme.captionSmall.copyWith(
                                      fontSize: hoursFontSize,
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Squarify 알고리즘 ────────────────────────────────────────────────────

class _Squarify {
  static List<Rect> compute(List<double> values, Rect bounds) {
    if (values.isEmpty) return [];
    final total = values.fold(0.0, (a, b) => a + b);
    if (total == 0) return [];
    final area = bounds.width * bounds.height;
    final scaled = values.map((v) => v / total * area).toList();
    final result = <Rect>[];
    _recurse(scaled, bounds, result);
    return result;
  }

  static void _recurse(List<double> areas, Rect rect, List<Rect> result) {
    if (areas.isEmpty) return;
    if (areas.length == 1) {
      result.add(rect);
      return;
    }

    final horizontal = rect.width >= rect.height;
    final side = horizontal ? rect.height : rect.width;

    int rowEnd = 1;
    double rowArea = areas[0];
    double best = _worstAspect(areas.sublist(0, 1), side, rowArea);

    for (int i = 1; i < areas.length; i++) {
      final newArea = rowArea + areas[i];
      final ratio = _worstAspect(areas.sublist(0, i + 1), side, newArea);
      if (ratio > best) break;
      best = ratio;
      rowEnd = i + 1;
      rowArea = newArea;
    }

    final rowItems = areas.sublist(0, rowEnd);
    final rowDim = side > 0 ? rowArea / side : 0.0;
    double pos = horizontal ? rect.top : rect.left;

    for (final a in rowItems) {
      final span = rowArea > 0 ? a / rowArea * side : 0.0;
      if (horizontal) {
        result.add(Rect.fromLTWH(rect.left, pos, rowDim, span));
      } else {
        result.add(Rect.fromLTWH(pos, rect.top, span, rowDim));
      }
      pos += span;
    }

    final remaining = areas.sublist(rowEnd);
    if (remaining.isNotEmpty) {
      final newRect = horizontal
          ? Rect.fromLTWH(
              rect.left + rowDim,
              rect.top,
              rect.width - rowDim,
              rect.height,
            )
          : Rect.fromLTWH(
              rect.left,
              rect.top + rowDim,
              rect.width,
              rect.height - rowDim,
            );
      _recurse(remaining, newRect, result);
    }
  }

  static double _worstAspect(List<double> row, double side, double rowArea) {
    if (row.isEmpty || rowArea == 0 || side == 0) return double.infinity;
    final w = rowArea / side;
    double worst = 0.0;
    for (final a in row) {
      final h = a / rowArea * side;
      if (h == 0) continue;
      final ratio = math.max(w / h, h / w);
      if (ratio > worst) worst = ratio;
    }
    return worst;
  }
}
