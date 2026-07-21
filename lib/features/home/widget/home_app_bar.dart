import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/library_provider.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final todayIndex = (now.weekday - 1).clamp(0, 6);
    final timer = ref.watch(timerProvider);
    final weekly =
        ref.watch(weeklyMinutesProvider).valueOrNull ??
        (kUseMock ? kWeeklyMinutes : List.filled(7, 0));
    final dbTodayMin = weekly.length > todayIndex ? weekly[todayIndex] : 0;
    final message = dailyHomeMessage(
      now: now,
      weeklyMinutes: weekly,
      todayMinutes: dbTodayMin + timer.seconds ~/ 60,
      books: ref.watch(libraryProvider),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.sectionGap,
        AppTheme.screenPadding,
        AppTheme.spaceSM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTheme.sectionTitle.copyWith(
                color: context.appTextSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          // 알림 버튼
          Semantics(
            label: '알림',
            button: true,
            child: SizedBox(
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeNotifications);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: context.appTextSecondary,
                      size: 32,
                    ),
                    Positioned(
                      top: 7,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
