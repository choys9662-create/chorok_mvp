import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

const _goalMin = 30;
const _cardRadius = 10.0;

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
    final dbWeekly = weeklyAsync.valueOrNull ?? List.filled(7, 0);

    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final dbTodayMin = dbWeekly.length > todayIndex ? dbWeekly[todayIndex] : 0;
    final todayMin = dbTodayMin + timer.seconds ~/ 60;

    final perDay = List.generate(
      7,
      (i) => i == todayIndex ? todayMin : (i < dbWeekly.length ? dbWeekly[i] : 0),
    );
    final weekTotal = perDay.fold<int>(0, (a, b) => a + b);
    final streak = calcReadStreak(todayIndex, perDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Column(
        children: [
          _TodayCard(
            streak: streak,
            todayMin: todayMin,
            readToday: todayMin > 0,
          ),
          const SizedBox(height: 12),
          _WeekCard(
            perDay: perDay,
            todayIndex: todayIndex,
            weekTotal: weekTotal,
            readToday: todayMin > 0,
          ),
        ],
      ),
    );
  }
}

/// "오늘" 카드 — 연독 메시지 + 오늘 읽은 분.
class _TodayCard extends StatelessWidget {
  final int streak;
  final int todayMin;
  final bool readToday;
  const _TodayCard({
    required this.streak,
    required this.todayMin,
    required this.readToday,
  });

  String get _message {
    if (streak >= 2) return '연독 $streak일 째, 쭉 이어가자고';
    if (todayMin >= _goalMin) return '오늘 목표 달성, 멋져요';
    if (todayMin > 0) return '잘 시작했어요, 계속 가볼까요';
    return '오늘 첫 독서를 시작해볼까요';
  }

  @override
  Widget build(BuildContext context) {
    // 단색 채움 시(읽은 날) 텍스트는 검정 계열로 대비 확보
    final onFill = Colors.black.withValues(alpha: 0.88);
    final onFillMuted = Colors.black.withValues(alpha: 0.55);

    return ForestAccentCard(
      radius: _cardRadius,
      fillColor: readToday ? AppTheme.primaryLight : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Row(
        children: [
          Text(
            '오늘',
            style: AppTheme.headingMedium.copyWith(
              fontSize: 20,
              color: readToday ? onFill : context.appTextPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _message,
              style: AppTheme.captionLarge.copyWith(
                fontSize: 13,
                color: readToday ? onFillMuted : context.appTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          if (readToday)
            Text(
              '$todayMin분',
              style: AppTheme.displayMedium.copyWith(color: onFill),
            )
          else
            GradientText(
              '$todayMin분',
              style: AppTheme.displayMedium,
              gradient: context.appReadingGradient,
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
  final int weekTotal;
  final bool readToday;
  const _WeekCard({
    required this.perDay,
    required this.todayIndex,
    required this.weekTotal,
    required this.readToday,
  });

  @override
  Widget build(BuildContext context) {
    final weekTotalText = weekTotal >= 60
        ? '${weekTotal ~/ 60}시간 ${weekTotal % 60}분'
        : '$weekTotal분';

    // 단색 채움 시(읽은 날) 회색 카드 — 텍스트·도트는 검정 계열로 대비 확보
    const fill = Color(0xFFE8EBE6);
    final onFill = Colors.black.withValues(alpha: 0.88);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.go(AppConstants.routeAnalytics);
      },
      child: ForestAccentCard(
        radius: _cardRadius,
        fillColor: readToday ? fill : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Row(
          children: [
            Text(
              '이번 주',
              style: AppTheme.headingMedium.copyWith(
                fontSize: 20,
                color: readToday ? onFill : context.appTextPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: List.generate(7, (i) {
                  final achieved = perDay[i] >= _goalMin;
                  final isFuture = i > todayIndex;
                  return Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 8 : 0),
                    child: _DayDot(
                      achieved: achieved,
                      dim: isFuture,
                      onFill: readToday,
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            if (readToday)
              Text(
                weekTotalText,
                style: AppTheme.displayMedium.copyWith(color: onFill),
              )
            else
              GradientText(
                weekTotalText,
                style: AppTheme.displayMedium,
                gradient: context.appReadingGradient,
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
  final bool onFill;
  const _DayDot({
    required this.achieved,
    required this.dim,
    this.onFill = false,
  });

  @override
  Widget build(BuildContext context) {
    // 회색 단색 카드 위에서는 검정 계열 도트로 대비 확보
    final Color color = onFill
        ? (achieved
            ? Colors.black.withValues(alpha: 0.85)
            : Colors.black.withValues(alpha: dim ? 0.20 : 0.35))
        : (achieved
            ? context.appPrimaryAccent
            : context.appTextTertiary.withValues(alpha: dim ? 0.25 : 0.4));
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
