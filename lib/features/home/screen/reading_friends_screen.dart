import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_back_button.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../controller/session_firefly_provider.dart';
import '../widget/reading_friends_section.dart';

/// 현재 독서 세션을 실행 중인 맞팔 친구 전체 목록.
class ReadingFriendsScreen extends ConsumerWidget {
  const ReadingFriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(sessionFireflyProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        foregroundColor: context.appTextPrimary,
        surfaceTintColor: context.appBg.withValues(alpha: 0),
        leading: ChorokBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
              return;
            }
            context.go(AppConstants.routeHome);
          },
        ),
        title: Text(
          '읽고 있는 친구',
          style: AppTheme.sectionTitle.copyWith(color: context.appTextPrimary),
        ),
      ),
      body: friends.when(
        loading: () => const _ReadingFriendsLoading(),
        error: (_, _) => _ReadingFriendsError(
          onRetry: () => ref.invalidate(sessionFireflyProvider),
        ),
        data: (data) {
          if (data.mutuals.isEmpty) {
            return const _ReadingFriendsEmpty();
          }
          return ListView(
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.screenPadding,
            ),
            children: [ReadingFriendsCard(mutuals: data.mutuals)],
          );
        },
      ),
    );
  }
}

class _ReadingFriendsLoading extends StatelessWidget {
  const _ReadingFriendsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppTheme.screenPadding),
      child: ChorokShimmer(
        width: double.infinity,
        height: AppTheme.spaceXL * 8,
        radius: AppTheme.radiusOuter,
      ),
    );
  }
}

class _ReadingFriendsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ReadingFriendsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '친구 목록을 불러오지 못했어요',
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _ReadingFriendsEmpty extends StatelessWidget {
  const _ReadingFriendsEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '지금 읽고 있는 친구가 없어요',
        style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
      ),
    );
  }
}
