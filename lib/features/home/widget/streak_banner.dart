import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import 'package:figma_squircle/figma_squircle.dart';
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
        final dbWeekly = ref.watch(weeklyMinutesProvider).valueOrNull ??
            (kUseMock ? kWeeklyMinutes : const [0, 0, 0, 0, 0, 0, 0]);
        final todayMin = dbWeekly.length > todayIndex ? dbWeekly[todayIndex] : 0;
        final hasReadToday = todayMin > 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ShapeDecoration(
              color: hasReadToday
                  ? AppTheme.warningColor.withValues(alpha: 0.08)
                  : context.appCard,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AppTheme.radiusMD * 1.8,
                  cornerSmoothing: 0.6,
                ),
                side: BorderSide.none,
              ),
            ),
            child: Row(
              children: [
                Text(
                  hasReadToday ? '🔥' : '⏰',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasReadToday
                        ? '$days일 연속 독서 중'
                        : '오늘 아직 안 읽었어요. 스트릭이 끊길 수도 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasReadToday
                          ? AppTheme.warningColor
                          : context.appTextSecondary,
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
