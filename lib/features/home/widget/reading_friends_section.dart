import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../controller/session_firefly_provider.dart';

// 좌우 여백 16px, 카드 간격 6px 로 통일
const _sideMargin = 16.0;
const _cardGap = 6.0;

/// "읽고 있는 친구" + "읽고 있는 주변" — 지금 함께 읽는 사람들을 반딧불 아바타로.
///
/// 데이터: [sessionFireflyProvider] (mutuals + nearbyCount).
/// 맞팔(친구)이 0명이면 섹션 전체를 숨긴다.
class ReadingFriendsSection extends ConsumerWidget {
  const ReadingFriendsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionFireflyProvider);

    return async.when(
      loading: () => const _FriendsShimmer(),
      error: (_, _) => const SizedBox.shrink(),
      data: (d) {
        if (d.mutuals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(title: '읽고 있는 친구', count: d.mutualCount),
            const SizedBox(height: 12),
            _FireflyRow(mutuals: d.mutuals),
            if (d.nearbyCount > 0) ...[
              const SizedBox(height: 24),
              _Header(title: '읽고 있는 주변', count: d.nearbyCount),
            ],
          ],
        );
      },
    );
  }
}

/// 섹션 헤더 — 굵은 타이틀 + 카운트 pill 뱃지.
class _Header extends StatelessWidget {
  final String title;
  final int count;
  const _Header({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.headingSmall.copyWith(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: AppTheme.smoothBox(
              color: context.appPrimaryAccent,
              radius: 3,
            ),
            alignment: Alignment.center,
            child: Text(
              '$count명',
              style: AppTheme.headingSmall.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 반딧불 아바타 가로 줄.
class _FireflyRow extends StatelessWidget {
  final List<UserProfile> mutuals;
  const _FireflyRow({required this.mutuals});

  /// 오늘 누적 독서 분 → 헤일로 겹 수 (30분당 1겹, 최대 2겹).
  /// 코어는 항상 표시되므로 0겹이면 코어만 보인다.
  static int layersForMinutes(int minutes) => (minutes ~/ 30).clamp(0, 2);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
      child: Row(
        children: List.generate(mutuals.length, (i) {
          // TODO: 실데이터 연동 시 친구별 오늘 독서 분으로 교체.
          // 현재는 이름 해시로 0/30/60분을 안정적으로 부여(데모).
          final demoMinutes = (mutuals[i].username.hashCode.abs() % 3) * 30;
          return Padding(
            padding: EdgeInsets.only(
              right: i < mutuals.length - 1 ? _cardGap : 0,
            ),
            child: _FireflyAvatar(
              name: mutuals[i].displayName,
              layers: layersForMinutes(demoMinutes),
              onTap: () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeUserProfile, extra: mutuals[i]);
              },
            ),
          );
        }),
      ),
    );
  }
}

/// 반딧불 글로우 + 이름.
/// [layers]는 독서 시간으로 누적되는 헤일로 겹 수(0~2).
/// 코어는 항상 표시되고, 겹이 늘수록 바깥 헤일로가 한 겹씩 추가된다.
class _FireflyAvatar extends StatelessWidget {
  final String name;
  final int layers;
  final VoidCallback onTap;
  const _FireflyAvatar({
    required this.name,
    required this.layers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimaryAccent;
    const core = 16.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        height: 118,
        child: Container(
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 10,
            side: const BorderSide(color: Color(0xFF8DFF54)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 2겹째: 가장 바깥 헤일로 (가장 옅고 넓게)
                    if (layers >= 2)
                      _Halo(size: 64, color: accent, alpha: 0.20),
                    // 1겹째: 안쪽 헤일로
                    if (layers >= 1)
                      _Halo(size: 40, color: accent, alpha: 0.40),
                    // 코어 (항상)
                    Container(
                      width: core,
                      height: core,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.fireflyColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 단색 반투명 원 — 겹이 쌓일수록 바깥 원이 추가됨.
class _Halo extends StatelessWidget {
  final double size;
  final Color color;
  final double alpha;
  const _Halo({required this.size, required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: alpha),
      ),
    );
  }
}

/// 로딩 스켈레톤 — 헤더 자리 + 아바타 4칸.
class _FriendsShimmer extends StatelessWidget {
  const _FriendsShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: _sideMargin),
          child: ChorokShimmer(width: 140, height: 22, radius: 10),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _sideMargin),
          child: Row(
            children: List.generate(
              4,
              (i) => Padding(
                padding: EdgeInsets.only(right: i < 3 ? _cardGap : 0),
                child: const ChorokShimmer(width: 88, height: 118, radius: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
