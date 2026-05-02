import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

const Color _kLv1   = Color(0xFF0F6E56);
const Color _kLv2   = Color(0xFF1D9E75);
const Color _kLv3   = Color(0xFF3BC49A);
const Color _kLabel = Color(0xFF7A8597);

const _kDays = ['월', '화', '수', '목', '금', '토', '일'];

/// 월간 독서 캘린더 히트맵 — 이전/다음 달 이동 가능
class HeatmapCalendarWidget extends StatefulWidget {
  final Map<DateTime, int> data;
  final int year;

  const HeatmapCalendarWidget({
    super.key,
    required this.data,
    required this.year,
  });

  @override
  State<HeatmapCalendarWidget> createState() => _HeatmapCalendarWidgetState();
}

class _HeatmapCalendarWidgetState extends State<HeatmapCalendarWidget> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prev() => setState(() => _month = DateTime(_month.year, _month.month - 1));
  void _next() => setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor = isDark ? const Color(0xFF2A2D2A) : const Color(0xFFE2EDE9);
    final lv4Color = context.appPrimaryAccent;

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthHeader(month: _month, onPrev: _prev, onNext: _next),
          const SizedBox(height: AppTheme.spaceMD),
          _DayOfWeekRow(),
          const SizedBox(height: 6),
          _MonthGrid(
            month: _month,
            data: widget.data,
            emptyColor: emptyColor,
            lv4Color: lv4Color,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _Legend(emptyColor: emptyColor, lv4Color: lv4Color),
        ],
      ),
    );
  }
}

// ─── 월 헤더 ────────────────────────────────────────────────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: _kLabel,
        ),
        Text(
          '${month.year}년 ${month.month}월',
          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          color: _kLabel,
        ),
      ],
    );
  }
}

// ─── 요일 헤더 행 ────────────────────────────────────────────────────────────

class _DayOfWeekRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: _kDays.map((d) => Expanded(
        child: Center(
          child: Text(
            d,
            style: AppTheme.captionSmall.copyWith(color: _kLabel, fontSize: 11),
          ),
        ),
      )).toList(),
    );
  }
}

// ─── 월 그리드 ───────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, int> data;
  final Color emptyColor;
  final Color lv4Color;

  const _MonthGrid({
    required this.month,
    required this.data,
    required this.emptyColor,
    required this.lv4Color,
  });

  @override
  Widget build(BuildContext context) {
    // 월 첫날 요일 오프셋 (월=0 … 일=6)
    final firstDay = DateTime(month.year, month.month, 1);
    final offset = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    final cells = <Widget>[];

    // 앞 빈칸
    for (int i = 0; i < offset; i++) {
      cells.add(const SizedBox.shrink());
    }

    // 날짜 셀
    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final key  = DateTime(date.year, date.month, date.day);
      final mins = data[key] ?? 0;
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;

      cells.add(_DayCell(
        day: d,
        color: _intensityColor(mins, emptyColor, lv4Color),
        isToday: isToday,
        minutes: mins,
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Color _intensityColor(int minutes, Color empty, Color lv4) {
    if (minutes == 0)   return empty;
    if (minutes < 30)   return _kLv1;
    if (minutes < 60)   return _kLv2;
    if (minutes < 120)  return _kLv3;
    return lv4;
  }
}

// ─── 날짜 셀 ────────────────────────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final Color color;
  final bool isToday;
  final int minutes; // added to determine emoji

  const _DayCell({required this.day, required this.color, required this.isToday, required this.minutes});

  @override
  Widget build(BuildContext context) {
    String content = '$day';
    double fontSize = 11;
    
    if (minutes > 0) {
      fontSize = 14;
      if (minutes < 30) {
        content = '🌱';
      } else if (minutes < 60) {
        content = '🌿';
      } else if (minutes < 120) {
        content = '🪴';
      } else {
        content = '🌳';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isToday
            ? Border.all(color: context.appPrimaryAccent, width: 1.5)
            : null,
      ),
      child: Center(
        child: Text(
          content,
          style: AppTheme.captionSmall.copyWith(
            fontSize: fontSize,
            color: color == const Color(0xFF2A2D2A) || color == const Color(0xFFE2EDE9)
                ? _kLabel
                : Colors.white,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── 범례 ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  final Color emptyColor;
  final Color lv4Color;

  const _Legend({required this.emptyColor, required this.lv4Color});

  @override
  Widget build(BuildContext context) {
    final levels = [
      (color: emptyColor, label: '없음', icon: ''),
      (color: _kLv1,      label: '~30분', icon: '🌱'),
      (color: _kLv2,      label: '~1h', icon: '🌿'),
      (color: _kLv3,      label: '~2h', icon: '🪴'),
      (color: lv4Color,   label: '2h+', icon: '🌳'),
    ];
    return Row(
      children: [
        Text('나만의 숲', style: AppTheme.captionSmall.copyWith(color: _kLabel)),
        const SizedBox(width: 8),
        ...levels.map((l) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Row(
            children: [
              if (l.icon.isNotEmpty) ...[
                Text(l.icon, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
              ] else ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: l.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 3),
              ],
              Text(
                l.label,
                style: AppTheme.captionSmall.copyWith(color: _kLabel, fontSize: 10),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
