import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/forest_accent_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';
import 'package:smooth_corner/smooth_corner.dart';

class WeeklyStatusCard extends ConsumerWidget {
  const WeeklyStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final weeklyAsync = ref.watch(weeklyMinutesProvider);
    final dbWeekly = weeklyAsync.valueOrNull ?? List.filled(7, 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 오늘 요일 (월=0)
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    // 오늘 값: DB 누적 + 현재 실행 중인 타이머
    final dbTodayMin = dbWeekly.length > todayIndex ? dbWeekly[todayIndex] : 0;
    final todayMin = dbTodayMin + timer.seconds ~/ 60;

    const goalMin = 30;
    final weekTotal = List.generate(
      7,
      (i) => i == todayIndex ? todayMin : dbWeekly[i],
    ).fold<int>(0, (a, b) => a + b);
    final daysAchieved = List.generate(7, (i) {
      final m = i == todayIndex ? todayMin : dbWeekly[i];
      return m >= goalMin ? 1 : 0;
    }).fold<int>(0, (a, b) => a + b);
    final maxMin = List.generate(
      7,
      (i) => i == todayIndex ? todayMin : dbWeekly[i],
    ).fold<int>(goalMin, (a, b) => a > b ? a : b);

    final weekTotalText = weekTotal >= 60
        ? '${weekTotal ~/ 60}시간 ${weekTotal % 60}분'
        : '$weekTotal분';

    // 오늘 인사이트 (목업 mockup exitCount=0 기준)
    final insight = todayInsightText(todayMin, 0, goalMin);

    return ForestAccentCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 헤더: 라벨 + 뱃지 + 독서 시작 버튼 ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '이번 주',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: ShapeDecoration(
                  color: context.primaryBg(0.08),
                  shape: SmoothRectangleBorder(
                    smoothness: 0.6,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  '$daysAchieved일 달성',
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── 주간 총 시간 ──────────────────────────────────────
          GradientText(
            weekTotalText,
            style: AppTheme.displayLarge.copyWith(fontSize: 30),
            gradient: context.appReadingGradient,
          ),
          const SizedBox(height: 20),
          // ── 주간 바 차트 (풀 너비) ────────────────────────────
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.push(AppConstants.routeAnalytics);
            },
            child: SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final min = i == todayIndex ? todayMin : dbWeekly[i];
                  final ratio = maxMin > 0
                      ? (min / maxMin).clamp(0.0, 1.0)
                      : 0.0;
                  final isToday = i == todayIndex;
                  final isFuture = i > todayIndex;
                  final achieved = min >= goalMin;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: isFuture
                                    ? 0.08
                                    : (ratio < 0.08 ? 0.08 : ratio),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: isFuture
                                        ? context.appProgressTrack
                                        : null,
                                    gradient: isFuture
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: achieved
                                                ? [
                                                    isDark
                                                        ? AppTheme.primary
                                                        : context
                                                              .appPrimaryAccent
                                                              .withValues(
                                                                alpha: 0.50,
                                                              ),
                                                    context.appPrimaryAccent,
                                                  ]
                                                : [
                                                    context.appTextTertiary
                                                        .withValues(
                                                          alpha: 0.45,
                                                        ),
                                                    context.appTextTertiary
                                                        .withValues(
                                                          alpha: 0.24,
                                                        ),
                                                  ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppConstants.weekdaysMonFirst[i],
                            style: AppTheme.captionSmall.copyWith(
                              color: isToday
                                  ? context.appPrimaryAccent
                                  : context.appTextTertiary,
                              fontWeight: isToday
                                  ? FontWeight.w400
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // ── 오늘의 목표 현황 (인사이트 & 그래프) ──────────────────
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: ShapeDecoration(
              color: context.primaryBg(0.06),
              shape: SmoothRectangleBorder(
                smoothness: 0.6,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (insight.isNotEmpty) ...[
                  Text(
                    insight,
                    style: AppTheme.bodySmall.copyWith(
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // 프로그레스 바
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (todayMin / goalMin).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: context.appProgressTrack,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.appPrimaryAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 상세 텍스트 (ex. 12분 / 30분)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$todayMin분 읽음',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      '목표 $goalMin분',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
