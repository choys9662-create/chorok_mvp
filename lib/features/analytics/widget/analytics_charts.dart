import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import 'package:flutter/foundation.dart';

class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int highlightIndex;
  final String labelSuffix;

  const BarChart({
    super.key,
    required this.labels,
    required this.values,
    required this.highlightIndex,
    this.labelSuffix = '',
  });

  // 바 최대 높이 고정 — LayoutBuilder 없이 비율 기반 계산
  static const double _kBarMaxH = 100.0;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(labels.length, (i) {
        final ratio = maxVal == 0 ? 0.0 : values[i] / maxVal;
        final isHighlight = i == highlightIndex;
        final mins = values[i];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHighlight && mins > 0)
                  Text(
                    mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m',
                    style: AppTheme.captionSmall.copyWith(
                      color: AppTheme.accent,
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: _kBarMaxH * ratio,
                  decoration: BoxDecoration(
                    color: isHighlight
                        ? context.appPrimaryAccent
                        : AppTheme.primary.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${labels[i]}$labelSuffix',
                  style: AppTheme.captionSmall.copyWith(
                    fontSize: labels.length > 8 ? 10 : null,
                    color: isHighlight
                        ? context.appPrimaryAccent
                        : context.appTextTertiary,
                    fontWeight: isHighlight
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class LineRhythmChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int highlightIndex;

  const LineRhythmChart({
    super.key,
    required this.labels,
    required this.values,
    required this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final highlightMins = values[highlightIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: const Size(double.infinity, 120),
            painter: LineRhythmPainter(
              values: values,
              highlightIndex: highlightIndex,
              maxVal: maxVal,
              lineColor: AppTheme.primary.withValues(alpha: 0.35),
              accentColor: context.appPrimaryAccent,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) {
            final isHighlight = i == highlightIndex;
            return Expanded(
              child: Column(
                children: [
                  if (isHighlight)
                    Text(
                      highlightMins >= 60
                          ? '${highlightMins ~/ 60}h ${highlightMins % 60}m'
                          : '${highlightMins}m',
                      style: AppTheme.captionSmall.copyWith(
                        color: AppTheme.accent,
                      ),
                    )
                  else
                    const SizedBox(height: 14),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppTheme.captionSmall.copyWith(
                      color: isHighlight
                          ? context.appPrimaryAccent
                          : context.appTextTertiary,
                      fontWeight: isHighlight
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class LineRhythmPainter extends CustomPainter {
  final List<int> values;
  final int highlightIndex;
  final int maxVal;
  final Color lineColor;
  final Color accentColor;

  const LineRhythmPainter({
    required this.values,
    required this.highlightIndex,
    required this.maxVal,
    required this.lineColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (maxVal == 0 || n < 2) return;
    final xStep = size.width / (n - 1);
    const topPad = 12.0;
    const botPad = 8.0;
    final availH = size.height - topPad - botPad;

    final points = List<Offset>.generate(
      n,
      (i) => Offset(i * xStep, topPad + availH * (1 - values[i] / maxVal)),
    );

    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo((n - 1) * xStep, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < n; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = lineColor;
    final ringPaint = Paint()..color = accentColor.withValues(alpha: 0.2);
    final accentPaint = Paint()..color = accentColor;
    final innerPaint = Paint()..color = Colors.white;
    for (int i = 0; i < n; i++) {
      final p = points[i];
      if (i == highlightIndex) {
        canvas.drawCircle(p, 7, ringPaint);
        canvas.drawCircle(p, 5, accentPaint);
        canvas.drawCircle(p, 2.5, innerPaint);
      } else {
        canvas.drawCircle(p, 3.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(LineRhythmPainter old) =>
      old.highlightIndex != highlightIndex ||
      old.maxVal != maxVal ||
      old.lineColor != lineColor ||
      old.accentColor != accentColor ||
      !listEquals(old.values, values);
}

class TimeOfDayChart extends StatelessWidget {
  final List<({String label, String range, int minutes})> slots;

  const TimeOfDayChart({super.key, required this.slots});

  @override
  Widget build(BuildContext context) {
    final maxMins = slots.map((s) => s.minutes).reduce((a, b) => a > b ? a : b);
    final total = slots.fold(0, (sum, s) => sum + s.minutes);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        children: List.generate(slots.length, (i) {
          final s = slots[i];
          final ratio = maxMins == 0 ? 0.0 : s.minutes / maxMins;
          final pct = total == 0 ? 0 : (s.minutes / total * 100).round();
          final isLast = i == slots.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.label,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      Text(
                        s.range,
                        style: AppTheme.captionSmall.copyWith(
                          fontSize: 10,
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(
                        ratio >= 0.8
                            ? context.appPrimaryAccent
                            : ratio >= 0.4
                            ? AppTheme.accent
                            : AppTheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: AppTheme.captionSmall.copyWith(
                      color: ratio >= 0.8
                          ? context.appPrimaryAccent
                          : context.appTextTertiary,
                      fontWeight: ratio >= 0.8
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class GenreChart extends StatelessWidget {
  final List<({String name, int count, Color color})> genres;

  const GenreChart({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    final total = genres.fold(0, (sum, g) => sum + g.count);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        children: List.generate(genres.length, (i) {
          final g = genres[i];
          final ratio = total == 0 ? 0.0 : g.count / total;
          final isLast = i == genres.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: g.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(
                    g.name,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(g.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${g.count}권',
                    textAlign: TextAlign.right,
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class YearMonthDials extends StatelessWidget {
  final List<int> values; // 12 months, reading minutes each
  final int highlightIndex; // current month index (0–11)

  const YearMonthDials({
    super.key,
    required this.values,
    required this.highlightIndex,
  });

  static const _monthLabels = [
    '1월',
    '2월',
    '3월',
    '4월',
    '5월',
    '6월',
    '7월',
    '8월',
    '9월',
    '10월',
    '11월',
    '12월',
  ];

  @override
  Widget build(BuildContext context) {
    final maxVal = values
        .where((v) => v > 0)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppTheme.spaceMD,
          crossAxisSpacing: AppTheme.spaceSM,
          childAspectRatio: 0.88,
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          final mins = values[i];
          final isFuture = i > highlightIndex;
          final isCurrent = i == highlightIndex;
          final ratio = isFuture ? 0.0 : (mins / maxVal).clamp(0.0, 1.0);

          final dialColor = isCurrent
              ? context.appPrimaryAccent
              : mins > 0
              ? context.appAccentColor.withValues(alpha: 0.4 + 0.6 * ratio)
              : context.appBorder.withValues(alpha: 0.4);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: isCurrent ? 5.0 : 3.5,
                      backgroundColor: context.appBorder.withValues(
                        alpha: 0.35,
                      ),
                      valueColor: AlwaysStoppedAnimation(dialColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      _monthLabels[i],
                      style: AppTheme.captionSmall.copyWith(
                        fontSize: 10,
                        fontWeight: isCurrent
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isCurrent
                            ? context.appPrimaryAccent
                            : isFuture
                            ? context.appTextTertiary.withValues(alpha: 0.5)
                            : context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                isFuture || mins == 0
                    ? '—'
                    : mins >= 60
                    ? '${mins ~/ 60}h'
                    : '${mins}m',
                style: AppTheme.captionSmall.copyWith(
                  fontSize: 10,
                  color: isCurrent ? AppTheme.accent : context.appTextTertiary,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ReadingDensityCard extends StatelessWidget {
  final int readDays;
  final int totalDays;
  final int maxStreak;
  final String streakDescription;

  const ReadingDensityCard({
    super.key,
    required this.readDays,
    required this.totalDays,
    required this.maxStreak,
    required this.streakDescription,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = readDays / totalDays;
    final pct = (ratio * 100).round();

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '독서한 날',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GradientText(
                          '$readDays',
                          style: AppTheme.displaySmall,
                          gradient: AppTheme.greenGradientVertical,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            '/ $totalDays일',
                            style: AppTheme.headingSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '최장 연속',
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$maxStreak일',
                    style: AppTheme.headingSmall.copyWith(
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '$pct%의 날을 책과 함께했어요',
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: AppTheme.smoothBox(
              color: AppTheme.primary.withValues(alpha: 0.2),
            side: BorderSide.none,
              radius: AppTheme.radiusMD,
            ),
            child: Text(
              streakDescription,
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GoalProgressCard extends StatelessWidget {
  final int current;
  final int goal;

  const GoalProgressCard({
    super.key,
    required this.current,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final remaining = goal - current;
    final pct = (progress * 100).round();

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '연간 독서 목표',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GradientText(
                          '$current',
                          style: AppTheme.displaySmall,
                          gradient: AppTheme.greenGradientVertical,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            '/ $goal권',
                            style: AppTheme.headingSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: AppTheme.smoothPill(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  side: BorderSide.none,
                ),
                child: Text(
                  '$pct%',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.appBorder,
              valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            remaining > 0
                ? '목표까지 $remaining권 남았어요. 이 속도라면 충분히 달성할 수 있어요!'
                : '올해 목표를 달성했어요! 정말 대단해요!',
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
