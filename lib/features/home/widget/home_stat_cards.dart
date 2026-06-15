import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

const _cardRadius = 8.0;
const _summaryCardHeight = 78.0;

/// 홈 상단 통계 — "오늘" / "이번 주" 두 장의 pill 카드.
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
          const SizedBox(height: 12),
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
    return _SummaryCard(
      child: Row(
        children: [
          _SummaryLabel(label: '오늘'),
          const SizedBox(width: 40),
          Icon(
            Icons.check_rounded,
            size: 28,
            color: context.appTextTertiary.withValues(alpha: 0.20),
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: Text(
              _formatKoreanMinutes(todaySeconds ~/ 60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextSecondary,
                fontSize: 30,
                letterSpacing: 0,
                height: 1,
              ),
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
            _SummaryLabel(label: '이번 주', active: true),
            const SizedBox(width: 42),
            Row(
              children: List.generate(7, (i) {
                final achieved = perDay[i] > 0;
                final isFuture = i > todayIndex;
                return Padding(
                  padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
                  child: _DayDot(achieved: achieved, dim: isFuture),
                );
              }),
            ),
            const Spacer(),
            Expanded(
              flex: 3,
              child: Text(
                _formatKoreanMinutes(weekSeconds ~/ 60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextPrimary,
                  fontSize: 30,
                  letterSpacing: 0,
                  height: 1,
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

  const _SummaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _summaryCardHeight,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: _cardRadius,
        side: BorderSide.none,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _SummaryLabel extends StatelessWidget {
  final String label;
  final bool active;

  const _SummaryLabel({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTheme.headingSmall.copyWith(
        color: active ? context.appTextPrimary : context.appTextTertiary,
        fontSize: 20,
        letterSpacing: 0,
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  final bool achieved;
  final bool dim;
  const _DayDot({required this.achieved, required this.dim});

  @override
  Widget build(BuildContext context) {
    final color = context.appTextSecondary.withValues(
      alpha: achieved ? 0.92 : (dim ? 0.18 : 0.50),
    );
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
