import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../controller/session_firefly_provider.dart';

const _sideMargin = AppTheme.screenPadding;

/// "읽고 있는 친구" + "읽고 있는 이웃" — 지금 함께 읽는 사람들.
///
/// 데이터: [sessionFireflyProvider] (mutuals + nearbyCount).
/// 맞팔(친구)이 0명이어도 주변 독자가 있으면 이웃 섹션은 보여준다.
class ReadingFriendsSection extends ConsumerWidget {
  const ReadingFriendsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionFireflyProvider);

    return async.when(
      loading: () => const _FriendsShimmer(),
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        final totalFriends = kUseMock ? d.mutuals.length : d.mutualCount;
        final visibleFriends = d.mutuals.take(3).toList();
        final nearbyCount = kUseMock ? 10 : d.nearbyCount;
        final showNeighbors = kUseMock && nearbyCount > 0;
        if (visibleFriends.isEmpty && !showNeighbors) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppTheme.sectionGap),
            if (visibleFriends.isNotEmpty) ...[
              _Header(title: '읽고 있는 친구', count: totalFriends),
              const SizedBox(height: AppTheme.spaceMD),
              ReadingFriendsCard(
                mutuals: visibleFriends,
                onShowAll: totalFriends > visibleFriends.length
                    ? () => context.push(AppConstants.routeReadingFriends)
                    : null,
              ),
            ],
            if (showNeighbors) ...[
              const SizedBox(height: AppTheme.sectionGap),
              _Header(title: '읽고 있는 이웃', count: nearbyCount, showChevron: true),
              const SizedBox(height: AppTheme.spaceMD),
              const _NeighborPreviewCard(),
            ],
          ],
        );
      },
    );
  }
}

class _ShowAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShowAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        height: AppTheme.spaceXL * 1.5,
        child: Center(
          child: Text(
            '전체보기',
            style: AppTheme.rowText.copyWith(color: context.appTextTertiary),
          ),
        ),
      ),
    );
  }
}

/// 섹션 헤더.
class _Header extends StatelessWidget {
  final String title;
  final int count;
  final bool showChevron;

  const _Header({
    required this.title,
    required this.count,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: ChorokSectionHeader(
        title: title,
        count: count,
        trailing: showChevron
            ? Icon(
                Icons.chevron_right_rounded,
                size: AppTheme.spaceXL,
                color: context.appTextTertiary,
              )
            : null,
      ),
    );
  }
}

class ReadingFriendsCard extends StatelessWidget {
  final List<UserProfile> mutuals;
  final VoidCallback? onShowAll;

  const ReadingFriendsCard({super.key, required this.mutuals, this.onShowAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        child: Column(
          children: [
            for (var i = 0; i < mutuals.length; i++) ...[
              _LiveReaderRow(profile: mutuals[i], index: i),
              if (i < mutuals.length - 1)
                Divider(height: AppTheme.space2XL, color: context.appDivider),
            ],
            if (onShowAll != null) ...[
              Divider(height: AppTheme.space2XL, color: context.appDivider),
              _ShowAllButton(onTap: onShowAll!),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveReaderRow extends StatelessWidget {
  final UserProfile profile;
  final int index;

  const _LiveReaderRow({required this.profile, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = _readerName(profile, index);
    return Semantics(
      label: '$name 독서 중',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeUserProfile, extra: profile);
        },
        child: SizedBox(
          height: 44,
          child: ChorokListRow(
            title: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveDot(index: index),
                const SizedBox(width: AppTheme.spaceLG),
                SizedBox(
                  width: AppTheme.space2XL * 4,
                  child: Text(
                    _readerDuration(profile, index),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: AppTheme.sectionTitle.copyWith(
                      color: context.appPrimaryAccent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  final int index;
  const _LiveDot({required this.index});

  @override
  Widget build(BuildContext context) {
    // 디자인 문서의 원형 상태 표식 예외다.
    final size = switch (index) {
      0 => 30.0,
      1 => 18.0,
      _ => 8.0,
    };
    return SizedBox(
      width: 34,
      height: 34,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.appPrimaryAccent.withValues(
              alpha: index == 0 ? 0.26 : 1,
            ),
          ),
          child: index == 0
              ? Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.appPrimaryAccent,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _NeighborPreviewCard extends StatelessWidget {
  const _NeighborPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: SizedBox(
        height: 82,
        child: ChorokCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPaddingMD,
          ),
          child: ChorokListRow(
            title: Text(
              '이명이 초록숲',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LiveDot(index: 0),
                const SizedBox(width: AppTheme.spaceLG),
                SizedBox(
                  width: AppTheme.space2XL * 4,
                  child: Text(
                    '00:20:25',
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: AppTheme.sectionTitle.copyWith(
                      color: context.appPrimaryAccent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _readerName(UserProfile profile, int index) {
  if (!kUseMock) return profile.displayName;
  const names = ['마고', '용성군', '온더그라운드'];
  if (index < names.length) return names[index];
  return profile.displayName;
}

String _readerDuration(UserProfile profile, int index) {
  if (kUseMock) {
    const values = ['00:30:25', '00:20:15', '00:05:45'];
    if (index < values.length) return values[index];
  }
  final seed = profile.id.hashCode.abs();
  final minutes = 5 + seed % 42;
  final seconds = seed % 60;
  return '00:${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// 로딩 스켈레톤 — 헤더 자리 + 리스트 카드.
class _FriendsShimmer extends StatelessWidget {
  const _FriendsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _sideMargin),
          child: ChorokShimmer(
            width: 140,
            height: 22,
            radius: AppTheme.radiusOuter,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _sideMargin),
          child: ChorokShimmer(
            width: double.infinity,
            height: 176,
            radius: AppTheme.radiusOuter,
          ),
        ),
      ],
    );
  }
}
