import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';
import '../controller/friends_read_today_provider.dart';

const _sideMargin = AppTheme.screenPadding;

/// "오늘 읽은 친구" — 오늘 독서한 맞팔 친구들이 무슨 책을 얼마나 읽었는지.
/// 데이터: [friendsReadTodayProvider]. 아무도 없으면 섹션 숨김.
class FriendsReadTodaySection extends ConsumerWidget {
  const FriendsReadTodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(friendsReadTodayProvider);
    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (friends) {
        final visible = friends.take(3).toList();
        if (visible.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            _Header(count: friends.length),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: AppTheme.smoothBox(
                  color: context.appCard,
                  radius: 8,
                  side: BorderSide.none,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _FriendRow(item: visible[i]),
                      if (i < visible.length - 1)
                        Divider(
                          height: 22,
                          thickness: 1,
                          color: context.appDivider.withValues(alpha: 0.35),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  const _Header({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: Row(
        children: [
          Text(
            '오늘 읽은 친구',
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextTertiary,
              fontWeight: FontWeight.w400,
              fontSize: 20,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '|',
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextTertiary.withValues(alpha: 0.35),
              fontSize: 20,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: AppTheme.headingSmall.copyWith(
              color: context.appPrimaryAccent,
              fontSize: 20,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final FriendReadToday item;
  const _FriendRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${item.friend.displayName}, ${item.bookTitle} ${time_fmt.formatDurationSeconds(item.seconds)}',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeUserProfile, extra: item.friend);
        },
        child: SizedBox(
          height: 46,
          child: Row(
            children: [
              BookCover(
                coverUrl: item.coverUrl,
                gradientIndex: item.bookTitle.hashCode.abs(),
                width: 32,
                height: 44,
                radius: 4,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                time_fmt.formatDurationSeconds(item.seconds),
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appPrimaryAccent,
                  fontSize: 18,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
