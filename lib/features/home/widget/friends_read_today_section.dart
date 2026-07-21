import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_section_header.dart';
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
            const SizedBox(height: AppTheme.sectionGap),
            _Header(count: friends.length),
            const SizedBox(height: AppTheme.spaceMD),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
              child: ChorokCard(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _FriendRow(item: visible[i]),
                      if (i < visible.length - 1)
                        Divider(
                          height: AppTheme.space2XL,
                          color: context.appDivider,
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
      child: ChorokSectionHeader(title: '오늘 읽은 친구', count: count),
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
          child: ChorokListRow(
            leading: BookCover(
              coverUrl: item.coverUrl,
              gradientIndex: item.bookTitle.hashCode.abs(),
              width: 32,
              height: 44,
              radius: AppTheme.radiusInner,
            ),
            title: Text(
              item.friend.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            ),
            supporting: Text(
              item.bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.caption.copyWith(color: context.appTextSecondary),
            ),
            trailing: Text(
              time_fmt.formatDurationSeconds(item.seconds),
              style: AppTheme.sectionTitle.copyWith(
                color: context.appPrimaryAccent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
