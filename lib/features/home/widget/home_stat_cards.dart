import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

const _goalMin = 30;
const _cardRadius = 8.0;
const _weekCardColor = Color(0xFFF0F0F0);

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
    final streakAsync = ref.watch(readingStreakProvider);

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
    final fallbackStreak = calcReadStreak(todayIndex, perDay);
    final dbStreak = streakAsync.valueOrNull;
    final streak = dbStreak != null && dbStreak > 0
        ? dbStreak
        : (kUseMock ? 50 : fallbackStreak);
    final weekSeconds = (weekTotal - todayMin) * 60 + todaySeconds;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _TodayCard(streak: streak, todaySeconds: todaySeconds),
          const SizedBox(height: 10),
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
  final int streak;
  final int todaySeconds;
  const _TodayCard({required this.streak, required this.todaySeconds});

  String get _message {
    if (streak >= 2) return '연독 $streak일 째, 쭉 이어가자고';
    if (todaySeconds >= _goalMin * 60) return '오늘 목표 달성, 멋져요';
    if (todaySeconds > 0) return '잘 시작했어요, 계속 가볼까요';
    return '오늘 첫 독서를 시작해볼까요';
  }

  @override
  Widget build(BuildContext context) {
    return ForestAccentCard(
      radius: _cardRadius,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '오늘',
            style: AppTheme.headingMedium.copyWith(
              fontSize: 16,
              color: AppTheme.primaryLight,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              _message,
              style: AppTheme.captionLarge.copyWith(
                fontSize: 13,
                color: AppTheme.primaryLight.withValues(alpha: 0.78),
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatSeconds(todaySeconds),
            style: AppTheme.displayMedium.copyWith(
              color: AppTheme.primaryLight,
              fontSize: 30,
              letterSpacing: 0,
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
      child: ForestAccentCard(
        radius: _cardRadius,
        darkBorderColor: _weekCardColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '이번 주',
              style: AppTheme.headingMedium.copyWith(
                fontSize: 16,
                color: _weekCardColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Row(
                children: List.generate(7, (i) {
                  final achieved = perDay[i] > 0;
                  final isFuture = i > todayIndex;
                  return Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
                    child: _DayDot(achieved: achieved, dim: isFuture),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatSeconds(weekSeconds),
              style: AppTheme.displayMedium.copyWith(
                color: _weekCardColor,
                fontSize: 30,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
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
    final color = _weekCardColor.withValues(
      alpha: achieved ? 1.0 : (dim ? 0.5 : 0.75),
    );
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: achieved ? color : Colors.transparent,
        shape: BoxShape.circle,
        border: achieved ? null : Border.all(color: color, width: 1.5),
      ),
    );
  }
}

String _formatSeconds(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}
