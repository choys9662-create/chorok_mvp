import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

// ─── 차트 전용 색상 ──────────────────────────────────────────────────────
const Color _kLv1    = Color(0xFF0F6E56);
const Color _kLv2    = Color(0xFF1D9E75);
const Color _kLv3    = Color(0xFF3BC49A);
const Color _kLv4    = Color(0xFF00FF00); // AppTheme.primaryLight
const Color _kLabel  = Color(0xFF7A8597);

/// 1년치 독서 기록 히트맵 — GitHub 잔디 형태
/// [data] DateTime(y,m,d) → 독서 분(minutes)
class HeatmapCalendarWidget extends StatelessWidget {
  final Map<DateTime, int> data;
  final int year;

  const HeatmapCalendarWidget({
    super.key,
    required this.data,
    required this.year,
  });

  @override
  Widget build(BuildContext context) {
    // 빈 셀: 다크 모드는 어두운 녹색, 라이트 모드는 연한 민트
    final emptyColor = context.appCard;
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeatmapPainterBox(data: data, year: year, emptyColor: emptyColor),
          const SizedBox(height: AppTheme.spaceMD),
          _Legend(emptyColor: emptyColor),
        ],
      ),
    );
  }
}

// ─── 캔버스 ──────────────────────────────────────────────────────────────

class _HeatmapPainterBox extends StatelessWidget {
  final Map<DateTime, int> data;
  final int year;
  final Color emptyColor;

  const _HeatmapPainterBox({
    required this.data,
    required this.year,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    const cellSize  = 11.0;
    const gap       = 3.0;
    const step      = cellSize + gap;
    const colCount  = 53;

    // 월 레이블 높이 + 그리드 높이
    final totalW = colCount * step - gap;
    final totalH = 16.0 + 4.0 + 7 * step - gap; // label + spacing + grid

    return SizedBox(
      width:  totalW,
      height: totalH,
      child: CustomPaint(
        painter: _HeatmapPainter(
          data: data,
          year: year,
          emptyColor: emptyColor,
        ),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Map<DateTime, int> data;
  final int year;
  final Color emptyColor;

  const _HeatmapPainter({
    required this.data,
    required this.year,
    required this.emptyColor,
  });

  static const _cellSize = 11.0;
  static const _gap      = 3.0;
  static const _step     = _cellSize + _gap;
  static const _labelH   = 16.0;
  static const _labelGap = 4.0;
  static const _gridTop  = _labelH + _labelGap;
  // 요일 레이블 너비 (월/수/금만 표시)
  static const _dayLabelW = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final start = DateTime(year, 1, 1);
    // 첫째 날 요일 오프셋 (월=0)
    final startWeekday = (start.weekday - 1) % 7;
    final isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    final totalDays = isLeap ? 366 : 365;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    const labelStyle = TextStyle(
      fontSize: 10,
      color: _kLabel,
      fontFamily: 'Pretendard',
    );

    // ── 월 레이블 ─────────────────────────────────────────────────
    const months = ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'];
    int prevMonth = -1;
    for (int d = 0; d < totalDays; d++) {
      final date = start.add(Duration(days: d));
      if (date.month != prevMonth) {
        prevMonth = date.month;
        final col = (d + startWeekday) ~/ 7;
        final x = _dayLabelW + col * _step;
        textPainter
          ..text = TextSpan(text: months[date.month - 1], style: labelStyle)
          ..layout();
        textPainter.paint(canvas, Offset(x, 0));
      }
    }

    // ── 요일 레이블 (월/수/금) ─────────────────────────────────────
    const dayLabels = ['월', '', '수', '', '금', '', ''];
    for (int row = 0; row < 7; row++) {
      if (dayLabels[row].isEmpty) continue;
      textPainter
        ..text = TextSpan(text: dayLabels[row], style: labelStyle)
        ..layout();
      final y = _gridTop + row * _step + (_cellSize - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(0, y));
    }

    // ── 셀 그리드 ──────────────────────────────────────────────────
    final paint  = Paint()..isAntiAlias = true;
    const radius = Radius.circular(3);

    for (int d = 0; d < totalDays; d++) {
      final date = start.add(Duration(days: d));
      final key  = DateTime(date.year, date.month, date.day);
      final mins = data[key] ?? 0;
      final col  = (d + startWeekday) ~/ 7;
      final row  = (d + startWeekday) % 7;

      final x = _dayLabelW + col * _step;
      final y = _gridTop + row * _step;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, _cellSize, _cellSize),
        radius,
      );

      paint.color = _intensityColor(mins);
      canvas.drawRRect(rect, paint);
    }
  }

  Color _intensityColor(int minutes) {
    if (minutes == 0)   return emptyColor;
    if (minutes < 30)   return _kLv1;
    if (minutes < 60)   return _kLv2;
    if (minutes < 120)  return _kLv3;
    return _kLv4;
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.data != data || old.year != year || old.emptyColor != emptyColor;
}

// ─── 범례 ─────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color emptyColor;

  const _Legend({required this.emptyColor});

  @override
  Widget build(BuildContext context) {
    final levels = [
      (color: emptyColor, label: '없음'),
      (color: _kLv1,      label: '~30분'),
      (color: _kLv2,      label: '~1h'),
      (color: _kLv3,      label: '~2h'),
      (color: _kLv4,      label: '2h+'),
    ];
    return Row(
      children: [
        Text(
          '독서량',
          style: AppTheme.captionSmall.copyWith(
            color: _kLabel,
          ),
        ),
        const SizedBox(width: 8),
        ...levels.map((l) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: l.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                l.label,
                style: AppTheme.captionSmall.copyWith(
                  color: _kLabel,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
