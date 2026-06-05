import 'package:flutter/material.dart';
import '../../../shared/models/reading_session.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;

import '../../../shared/widgets/book_cover.dart';

// ─── 독서 기록 타입 ───────────────────────────────────────────────────────
typedef ReadingLog = ({
  DateTime date,
  String bookTitle,
  String bookAuthor,
  int minutes,
  int pages,
  String? coverUrl,
  int gradientIndex,
});

// ─── 독서 기록 목업 (USE_MOCK=true 전용) ────────────────────────────────────
List<ReadingLog> get mockReadingLogs {
  if (!kUseMock) return const [];
  final now = DateTime.now();
  const c1 =
      'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg'; // 채식주의자
  const c2 =
      'https://image.aladin.co.kr/product/29496/39/cover500/s382931339_2.jpg'; // 파친코
  const c3 =
      'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg'; // 소년이 온다
  const c4 =
      'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg'; // 아몬드
  return [
    (
      date: DateTime(now.year, now.month, now.day),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 42,
      pages: 18,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: DateTime(now.year, now.month, now.day),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 25,
      pages: 12,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: DateTime(now.year, now.month, now.day - 1),
      bookTitle: '소년이 온다',
      bookAuthor: '한강',
      minutes: 55,
      pages: 31,
      coverUrl: c3,
      gradientIndex: 3,
    ),
    (
      date: DateTime(now.year, now.month, now.day - 2),
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      minutes: 30,
      pages: 20,
      coverUrl: c4,
      gradientIndex: 4,
    ),
    (
      date: now.subtract(const Duration(days: 1)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 55,
      pages: 24,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 2)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 38,
      pages: 16,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 3)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 20,
      pages: 8,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 4)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 45,
      pages: 20,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 5)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 35,
      pages: 15,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 5)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 65,
      pages: 30,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 6)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 30,
      pages: 14,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 8)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 48,
      pages: 22,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 10)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 35,
      pages: 15,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 12)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 52,
      pages: 25,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 12)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 18,
      pages: 7,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 14)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 40,
      pages: 19,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 15)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 28,
      pages: 13,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 18)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 60,
      pages: 28,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 20)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 33,
      pages: 16,
      coverUrl: c2,
      gradientIndex: 1,
    ),
    (
      date: now.subtract(const Duration(days: 22)),
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      minutes: 45,
      pages: 20,
      coverUrl: c1,
      gradientIndex: 0,
    ),
    (
      date: now.subtract(const Duration(days: 25)),
      bookTitle: '파친코',
      bookAuthor: '이민진',
      minutes: 50,
      pages: 24,
      coverUrl: c2,
      gradientIndex: 1,
    ),
  ];
}

// ─── 세그먼트 토글 ────────────────────────────────────────────────────────
class SegmentToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const SegmentToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 12,
        side: BorderSide.none,
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = i == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.appPrimaryAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[i],
                  style: AppTheme.captionLarge.copyWith(
                    color: isSelected ? Colors.white : context.appTextTertiary,
                    fontWeight: isSelected ? FontWeight.w400 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── 캘린더 뷰 ────────────────────────────────────────────────────────────
class LibraryCalendarView extends StatefulWidget {
  final List<ReadingLog> logs;
  final List<Book> books;
  final ScrollController? scrollController;

  const LibraryCalendarView({
    super.key,
    required this.logs,
    required this.books,
    this.scrollController,
  });

  @override
  State<LibraryCalendarView> createState() => _LibraryCalendarViewState();
}

class _LibraryCalendarViewState extends State<LibraryCalendarView> {
  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  List<ReadingLog> _logsFor(DateTime date) {
    return widget.logs
        .where(
          (l) =>
              l.date.year == date.year &&
              l.date.month == date.month &&
              l.date.day == date.day,
        )
        .toList();
  }

  Set<int> get _activeDays {
    return widget.logs
        .where(
          (l) =>
              l.date.year == _focusedMonth.year &&
              l.date.month == _focusedMonth.month,
        )
        .map((l) => l.date.day)
        .toSet();
  }

  Set<int> get _completedDays {
    return widget.books
        .where(
          (b) =>
              b.status == ReadingStatus.completed &&
              b.completedAt != null &&
              b.completedAt!.year == _focusedMonth.year &&
              b.completedAt!.month == _focusedMonth.month,
        )
        .map((b) => b.completedAt!.day)
        .toSet();
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
      _selectedDate = null;
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _focusedMonth = next;
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedLogs = _selectedDate != null
        ? _logsFor(_selectedDate!)
        : <ReadingLog>[];
    final totalMin = selectedLogs.fold<int>(0, (a, l) => a + l.minutes);

    return CustomScrollView(
      controller: widget.scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              16,
              AppTheme.screenPadding,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  label: '이전 달',
                  button: true,
                  child: GestureDetector(
                    onTap: _prevMonth,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: context.appTextSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Text(
                  '${_focusedMonth.year}년 ${_focusedMonth.month}월',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Semantics(
                  label: '다음 달',
                  button: true,
                  child: GestureDetector(
                    onTap: _nextMonth,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: context.appTextSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Row(
              children: AppConstants.weekdaysSunFirst
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: _CalendarGrid(
              month: _focusedMonth,
              activeDays: _activeDays,
              completedDays: _completedDays,
              selectedDate: _selectedDate,
              onDayTap: (date) {
                HapticFeedback.selectionClick();
                setState(() => _selectedDate = date);
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        if (_selectedDate != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Row(
                children: [
                  Text(
                    '${_selectedDate!.month}월 ${_selectedDate!.day}일',
                    style: AppTheme.headingSmall.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (totalMin > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.appPrimaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        time_fmt.formatMinutes(totalMin),
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appPrimaryAccent,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (selectedLogs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                  vertical: 24,
                ),
                child: Center(
                  child: Text(
                    '이 날은 독서 기록이 없어요',
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    0,
                    AppTheme.screenPadding,
                    i < selectedLogs.length - 1 ? 8 : 24,
                  ),
                  child: _ReadingLogCard(log: selectedLogs[i]),
                ),
                childCount: selectedLogs.length,
              ),
            ),
        ],
      ],
    );
  }
}

// ─── 달력 그리드 ──────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> activeDays;
  final Set<int> completedDays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDayTap;

  const _CalendarGrid({
    required this.month,
    required this.activeDays,
    required this.completedDays,
    required this.selectedDate,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(month.year, month.month, d);
      final isToday = date == today;
      final isSelected =
          selectedDate != null &&
          date.year == selectedDate!.year &&
          date.month == selectedDate!.month &&
          date.day == selectedDate!.day;
      final hasLog = activeDays.contains(d);
      final isCompleted = completedDays.contains(d);
      final isFuture = date.isAfter(today);

      cells.add(
        GestureDetector(
          onTap: isFuture ? null : () => onDayTap(date),
          child: Container(
            decoration: AppTheme.smoothBox(
              color: isSelected
                  ? AppTheme.primary
                  : isToday
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : null,
              radius: 10,
              side: BorderSide.none,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w400 : FontWeight.w400,
                    color: isFuture
                        ? context.appTextTertiary.withValues(alpha: 0.3)
                        : isSelected
                        ? Colors.white
                        : isToday
                        ? context.appPrimaryAccent
                        : context.appTextPrimary,
                    height: 1.4,
                  ),
                ),
                if (isCompleted || hasLog) ...[
                  const SizedBox(height: 2),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : context.appPrimaryAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '완독',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : context.appPrimaryAccent,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.appPrimaryAccent.withValues(
                          alpha: isSelected ? 1.0 : 0.7,
                        ),
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: 1.0,
      children: cells,
    );
  }
}

// ─── 독서 기록 카드 ────────────────────────────────────────────────────────
class _ReadingLogCard extends StatelessWidget {
  final ReadingLog log;
  const _ReadingLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 14,
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          BookCover(
            coverUrl: log.coverUrl,
            gradientIndex: log.gradientIndex,
            width: 44,
            height: 44,
            radius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.bookTitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.bookAuthor,
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: context.appPrimaryAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    log.minutes >= 60
                        ? '${log.minutes ~/ 60}h ${log.minutes % 60}m'
                        : '${log.minutes}분',
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${log.pages}쪽 읽음',
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
