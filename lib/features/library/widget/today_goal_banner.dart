import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/chorok_card.dart';

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
    final isCompleted = todayMinutes >= goalMinutes;
    final progress = (todayMinutes / goalMinutes).clamp(0.0, 1.0);

    if (isCompleted) {
      // 달성 상태
      return ChorokCard(
        backgroundColor: context.primaryBg(0.10),
        borderColor: context.appPrimaryAccent.withValues(alpha: 0.34),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: AppTheme.spaceMD,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: ChorokCard(
                inner: true,
                showBorder: false,
                padding: EdgeInsets.zero,
                backgroundColor: context.primaryBg(0.14),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: AppTheme.spaceLG,
                  color: context.appPrimaryAccent,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppTheme.spaceXS,
                children: [
                  Text(
                    '오늘 목표 달성!',
                    style: AppTheme.rowText.copyWith(
                      color: context.appPrimaryAccent,
                    ),
                  ),
                  Text(
                    '${time_fmt.formatMinutes(todayMinutes)} 독서했어요 · 목표 $goalMinutes분',
                    style: AppTheme.caption.copyWith(
                      color: context.appPrimaryAccent,
                    ),
                  ),
                ],
              ),
            ),
            ChorokCard(
              inner: true,
              showBorder: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSM,
                vertical: AppTheme.spaceXS,
              ),
              backgroundColor: AppTheme.primary.withValues(alpha: 0.5),
              child: Text(
                '완료',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.primaryLight,
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
                    coverUrl: firstReadingBook!.coverUrl,
                    startPage: firstReadingBook!.currentPage,
                    totalPages: firstReadingBook!.totalPages,
                  ),
                );
              },
        child: ChorokCard(
          borderColor: context.appBorderSubtle,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLG,
            vertical: AppTheme.spaceMD,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: ChorokCard(
                  inner: true,
                  showBorder: false,
                  padding: EdgeInsets.zero,
                  child: Icon(
                    Icons.timer_outlined,
                    size: AppTheme.spaceLG,
                    color: context.appTextTertiary,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppTheme.spaceXS,
                  children: [
                    Text(
                      '오늘 독서를 시작해보세요',
                      style: AppTheme.rowText.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    Text(
                      '오늘 목표 $goalMinutes분',
                      style: AppTheme.caption.copyWith(
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
                  size: AppTheme.spaceXL,
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
                  coverUrl: firstReadingBook!.coverUrl,
                  startPage: firstReadingBook!.currentPage,
                  totalPages: firstReadingBook!.totalPages,
                ),
              );
            },
      child: ChorokCard(
        borderColor: context.appBorderSubtle,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: AppTheme.spaceMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppTheme.spaceSM,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ChorokCard(
                    inner: true,
                    showBorder: false,
                    padding: EdgeInsets.zero,
                    backgroundColor: context.primaryBg(0.12),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      size: AppTheme.sectionTitle.fontSize,
                      color: context.appPrimaryAccent,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppTheme.spaceXS,
                    children: [
                      Text(
                        '오늘 ${time_fmt.formatMinutes(todayMinutes)} 독서했어요',
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        '목표까지 ${time_fmt.formatMinutes(goalMinutes - todayMinutes)} 남았어요',
                        style: AppTheme.caption.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: AppTheme.supportingText.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                ),
              ],
            ),
            ChorokProgressBar(
              value: progress,
              trackColor: context.appCardElevated,
              valueColor: context.appPrimaryAccent,
            ),
          ],
        ),
      ),
    );
  }
}
