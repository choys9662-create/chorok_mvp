import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/utils/passive_aggro_engine.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

/// 홈 수동공격 카드 (트리거 2/3/4)
///
/// [PassiveAggroEngine.selectTrigger]로 지금 띄울 공격이 있는지 판정하고,
/// 있으면 죄책감 톤 메시지를 카드로 노출한다. 없으면 렌더링하지 않는다.
///
/// 데이터 소스는 [readingStreakProvider]·[weeklyMinutesProvider]를 재사용하므로
/// mock(디자인 앱)/real(테스트 앱)이 provider 레벨에서 자동 분기된다.
/// 이웃 비교(neighborCompare)는 실데이터 provider가 아직 없어 mock에서만 노출된다.
class PassiveAggroCard extends ConsumerWidget {
  const PassiveAggroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(readingStreakProvider).valueOrNull ?? 0;

    final today = DateTime.now();
    final todayIndex = (today.weekday - 1).clamp(0, 6);
    final weekly =
        ref.watch(weeklyMinutesProvider).valueOrNull ??
        (kUseMock ? kWeeklyMinutes : const [0, 0, 0, 0, 0, 0, 0]);
    final readToday = weekly.length > todayIndex
        ? weekly[todayIndex] > 0
        : false;

    // 마지막 독서일로부터의 경과 일수 — 이번 주 분 데이터에서 추정
    final idleDays = _idleDaysFrom(weekly, todayIndex);

    // 이웃 비교는 실데이터 미연동 → mock 환경에서만 후보로 둔다
    final neighborName = kUseMock ? '준석' : null;

    final ctx = AggroContext(
      readToday: readToday,
      idleDays: idleDays,
      streakDays: streak,
      neighborName: neighborName,
    );

    final trigger = PassiveAggroEngine.selectTrigger(
      ctx,
      lastShownAt: null, // 빈도 제한은 알림 채널(후속)에서 영속화. 카드는 매 진입 판정.
      now: today,
    );

    if (trigger == null) return const SizedBox.shrink();

    final message = PassiveAggroEngine.messageFor(trigger, ctx);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: 14,
        ),
        decoration: ShapeDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.08),
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
            side: BorderSide(
              color: AppTheme.warningColor.withValues(alpha: 0.24),
            ),
          ),
        ),
        child: Row(
          children: [
            // 이모지 장식 — 24→18 스냅(§3)
            const Text(
              '🦉',
              style: TextStyle(fontSize: AppTheme.fsSectionTitle),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Text(
                message,
                style: AppTheme.supportingText.copyWith(
                  color: AppTheme.warningColor,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warningColor,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                context.go(AppConstants.routeLibrary);
              },
              child: const Text('읽을게요', style: AppTheme.supportingText),
            ),
          ],
        ),
      ),
    );
  }

  /// 이번 주 분 데이터에서 마지막으로 읽은 날 이후 경과 일수를 추정한다.
  /// 오늘 읽었으면 0, 어제 읽었으면 1 ...
  static int _idleDaysFrom(List<int> weeklyMinutes, int todayIndex) {
    for (var back = 0; back <= todayIndex; back++) {
      final idx = todayIndex - back;
      if (idx >= 0 && idx < weeklyMinutes.length && weeklyMinutes[idx] > 0) {
        return back;
      }
    }
    // 이번 주 내내 기록이 없으면 최소 방치 임계치를 넘긴 것으로 본다
    return todayIndex + 1;
  }
}
