import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

const _summaryCardHeight = 78.0;
const _summaryMarkerStart = 92.0;

/// 홈 상단 통계 — "오늘" / "이번 주" 두 장의 요약 카드.
///
/// 기존 [WeeklyStatusCard](바 차트 한 장)를 대체한다.
/// 데이터 소스는 [weeklyMinutesProvider] + 실행 중인 타이머(오늘 누적).
class HomeStatCards extends ConsumerWidget {
  const HomeStatCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final weeklyAsync = ref.watch(weeklyMinutesProvider);
    final dbWeekly =
        weeklyAsync.valueOrNull ??
        (kUseMock ? kWeeklyMinutes : List.filled(7, 0));

    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final dbTodayMin = dbWeekly.length > todayIndex ? dbWeekly[todayIndex] : 0;
    final todayMin = dbTodayMin + timer.seconds ~/ 60;
    final todaySeconds = dbTodayMin * 60 + timer.seconds;

    final perDay = List.generate(
      7,
      (i) =>
          i == todayIndex ? todayMin : (i < dbWeekly.length ? dbWeekly[i] : 0),
    );
    final weekTotal = perDay.fold<int>(0, (a, b) => a + b);
    final weekSeconds = (weekTotal - todayMin) * 60 + todaySeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Column(
        children: [
          _TodayCard(todaySeconds: todaySeconds),
          const SizedBox(height: AppTheme.spaceMD),
          _WeekCard(
            perDay: perDay,
            todayIndex: todayIndex,
            weekSeconds: weekSeconds,
          ),
        ],
      ),
    );
  }
}

/// "오늘" 카드 — 연독 메시지 + 오늘 읽은 분.
class _TodayCard extends StatelessWidget {
  final int todaySeconds;
  const _TodayCard({required this.todaySeconds});

  @override
  Widget build(BuildContext context) {
    final hasReadToday = todaySeconds > 0;
    final foreground = hasReadToday
        ? AppTheme.primary
        : context.appTextSecondary;

    return _SummaryCard(
      active: hasReadToday,
      child: Row(
        children: [
          _SummaryMarker(
            label: '오늘',
            labelColor: hasReadToday
                ? AppTheme.primary
                : context.appTextTertiary,
            marker: Icon(
              Icons.check_rounded,
              size: 30,
              color: hasReadToday
                  ? AppTheme.primary
                  : context.appTextTertiary.withValues(alpha: 0.20),
            ),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              _formatKoreanMinutes(todaySeconds ~/ 60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.displayMedium.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// "이번 주" 카드 — 요일 도트(목표 달성 표시) + 주간 총 분.
class _WeekCard extends StatelessWidget {
  final List<int> perDay;
  final int todayIndex;
  final int weekSeconds;
  const _WeekCard({
    required this.perDay,
    required this.todayIndex,
    required this.weekSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppConstants.routeAnalytics);
      },
      child: _SummaryCard(
        child: Row(
          children: [
            _SummaryMarker(
              label: '이번 주',
              labelColor: context.appTextPrimary,
              marker: Row(
                children: List.generate(7, (i) {
                  final achieved = perDay[i] > 0;
                  final isFuture = i > todayIndex;
                  return Padding(
                    padding: i < 6
                        ? const EdgeInsets.only(right: AppTheme.spaceXS)
                        : EdgeInsets.zero,
                    child: _DayDot(achieved: achieved, dim: isFuture),
                  );
                }),
              ),
            ),
            const Spacer(),
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _formatKoreanMinutes(weekSeconds ~/ 60),
                  maxLines: 1,
                  style: AppTheme.displayMedium.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Widget child;
  final bool active;

  const _SummaryCard({required this.child, this.active = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _summaryCardHeight,
      width: double.infinity,
      child: ChorokCard(
        backgroundColor: active ? context.appPrimaryAccent : null,
        borderColor: active ? context.appPrimaryAccent : null,
        child: Align(alignment: Alignment.center, child: child),
      ),
    );
  }
}

class _SummaryLabel extends StatelessWidget {
  final String label;
  final Color? color;

  const _SummaryLabel({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTheme.sectionTitle.copyWith(
        color: color ?? context.appTextTertiary,
      ),
    );
  }
}

class _SummaryMarker extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Widget marker;

  const _SummaryMarker({
    required this.label,
    required this.labelColor,
    required this.marker,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _summaryMarkerStart,
          child: _SummaryLabel(label: label, color: labelColor),
        ),
        marker,
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool achieved;
  final bool dim;
  const _DayDot({required this.achieved, required this.dim});

  @override
  Widget build(BuildContext context) {
    final color = achieved
        ? context.appTextPrimary
        : context.appTextSecondary.withValues(alpha: dim ? 0.18 : 0.50);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

String _formatKoreanMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h시간 $m분';
}
