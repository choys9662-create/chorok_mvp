import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key});

  String _subtext(TimerData timer, List<int> dbWeekly, int dbTodayMin) {
    final now = DateTime.now();
    final todayIndex = (now.weekday - 1).clamp(0, 6);
    final todayMin = dbTodayMin + timer.seconds ~/ 60;
    final isInSession = !timer.isIdle;
    const goalMin = 30;
    final seed = now.day;

    if (isInSession) return '지금 읽는 중이에요';

    if (todayMin >= goalMin) {
      return kGoalMessages[seed % kGoalMessages.length];
    }

    if (todayMin > 0) {
      final remain = goalMin - todayMin;
      return '$remain분만 더요, 거의 다 왔어요';
    }

    final streak = calcReadStreak(todayIndex, dbWeekly);
    if (streak >= 3) {
      final suffix = kStreakSuffix[seed % kStreakSuffix.length];
      return '$streak일 연속! $suffix';
    }

    final readYesterday =
        todayIndex > 0 && dbWeekly.length > todayIndex - 1 && dbWeekly[todayIndex - 1] >= goalMin;
    if (readYesterday) return '어제는 읽으셨는데, 오늘은요?';

    final daysSince = daysSinceLastRead(todayIndex, dbWeekly);
    if (daysSince >= 3) {
      return kSlackMessages[seed % kSlackMessages.length];
    }

    return kNudgeMessages[seed % kNudgeMessages.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final dbWeekly = ref.watch(weeklyMinutesProvider).valueOrNull ??
        (kUseMock ? kWeeklyMinutes : const [0, 0, 0, 0, 0, 0, 0]);
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    final dbTodayMin = dbWeekly.length > todayIndex ? dbWeekly[todayIndex] : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _subtext(timer, dbWeekly, dbTodayMin),
                style: AppTheme.headingLarge.copyWith(
                  color: context.appTextPrimary,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          // 검색 버튼
          Semantics(
            label: '책 검색',
            button: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeExplore);
                },
                child: Icon(
                  Icons.search_rounded,
                  color: context.appTextSecondary,
                  size: 24,
                ),
              ),
            ),
          ),
          // 알림 버튼
          Semantics(
            label: '알림',
            button: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeNotifications);
                },
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: context.appTextSecondary,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
