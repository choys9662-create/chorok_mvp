import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';

class TodayGoalBanner extends StatelessWidget {
  final int todayMinutes;
  final int goalMinutes;
  final Book? firstReadingBook;

  const TodayGoalBanner({
    super.key,
    required this.todayMinutes,
    required this.goalMinutes,
    this.firstReadingBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = todayMinutes >= goalMinutes;
    final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);

    if (isCompleted) {
      // 달성 상태
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.smoothBox(
          color: context.appPrimaryAccent.withValues(alpha: 0.08),
          radius: AppTheme.radiusLG,
          side: BorderSide(color: context.appPrimaryAccent.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: AppTheme.smoothBox(
                color: context.appPrimaryAccent.withValues(alpha: 0.15),
                radius: 10,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: context.appPrimaryAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 목표 달성!',
                    style: AppTheme.bodySmall.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatMinutes(todayMinutes)} 독서했어요 · 목표 $goalMinutes분',
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appPrimaryAccent.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: AppTheme.smoothPill(
                color: isDark
                    ? AppTheme.primary.withValues(alpha: 0.5)
                    : AppTheme.lightPrimaryAccent,
                side: BorderSide(
                  color: context.appPrimaryAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '완료',
                style: AppTheme.captionSmall.copyWith(
                  color: isDark ? AppTheme.primaryLight : Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (todayMinutes == 0) {
      // 빈 상태 — 아직 시작 안 함
      return GestureDetector(
        onTap: firstReadingBook == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                context.push(
                  AppConstants.routeSession,
                  extra: SessionExtra(
                    bookId: firstReadingBook!.id,
                    bookTitle: firstReadingBook!.title,
                    bookAuthor: firstReadingBook!.author,
                    startPage: firstReadingBook!.currentPage,
                    totalPages: firstReadingBook!.totalPages,
                  ),
                );
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 14,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: AppTheme.smoothBox(
                  color: context.appCardElevated,
                  radius: 10,
                ),
                child: Icon(
                  Icons.timer_outlined,
                  size: 20,
                  color: context.appTextTertiary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘 독서를 시작해보세요',
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '오늘 목표 $goalMinutes분',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (firstReadingBook != null)
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: context.appPrimaryAccent,
                  size: 24,
                ),
            ],
          ),
        ),
      );
    }

    // 진행 중 상태
    return GestureDetector(
      onTap: firstReadingBook == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              context.push(
                AppConstants.routeSession,
                extra: SessionExtra(
                  bookId: firstReadingBook!.id,
                  bookTitle: firstReadingBook!.title,
                  bookAuthor: firstReadingBook!.author,
                  startPage: firstReadingBook!.currentPage,
                  totalPages: firstReadingBook!.totalPages,
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: 14,
          side: BorderSide(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: AppTheme.smoothBox(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    radius: 10,
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: context.appPrimaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘 ${_formatMinutes(todayMinutes)} 독서했어요',
                        style: AppTheme.bodySmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '목표까지 ${_formatMinutes(goalMinutes - todayMinutes)} 남았어요',
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.appBorder,
                valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '$h시간 $m분' : '$h시간';
    }
    return '$minutes분';
  }
}
