import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../controller/weekly_minutes_provider.dart';
import 'home_helpers.dart';

class StreakBanner extends ConsumerWidget {
  const StreakBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(readingStreakProvider);
    return streak.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (days) {
        if (days < 2) return const SizedBox.shrink();
        final today = DateTime.now();
        final todayIndex = (today.weekday - 1).clamp(0, 6);
        final dbWeekly =
            ref.watch(weeklyMinutesProvider).valueOrNull ??
            (kUseMock ? kWeeklyMinutes : const [0, 0, 0, 0, 0, 0, 0]);
        final todayMin = dbWeekly.length > todayIndex
            ? dbWeekly[todayIndex]
            : 0;
        final hasReadToday = todayMin > 0;
        if (!hasReadToday) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLG,
              vertical: AppTheme.spaceMD,
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
                  '🔥',
                  style: TextStyle(fontSize: AppTheme.fsSectionTitle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$days일 연속 독서 중',
                    style: AppTheme.supportingText.copyWith(
                      color: AppTheme.warningColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
