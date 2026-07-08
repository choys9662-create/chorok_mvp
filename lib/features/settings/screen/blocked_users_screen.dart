import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/moderation_repository.dart';
import '../../../shared/widgets/chorok_snackbar.dart';

final _blockedUsersProvider = FutureProvider.autoDispose<List<UserProfile>>((
  ref,
) {
  return ref.read(moderationRepositoryProvider).getBlockedUsers();
});

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_blockedUsersProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.appTextPrimary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Text(
          '차단 유저 목록',
          style: AppTheme.headingSmall.copyWith(color: context.appTextPrimary),
        ),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            '불러오지 못했어요',
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                '차단한 유저가 없어요',
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
              vertical: AppTheme.spaceMD,
            ),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceSM),
            itemBuilder: (context, i) {
              final u = users[i];
              return _BlockedUserTile(
                profile: u,
                onUnblock: () async {
                  HapticFeedback.selectionClick();
                  await ref.read(moderationRepositoryProvider).unblock(u.id);
                  ref.invalidate(_blockedUsersProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(chorokSnackBar(context, '차단을 해제했어요'));
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onUnblock;
  const _BlockedUserTile({required this.profile, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.appCardElevated,
            backgroundImage:
                (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                ? Icon(
                    Icons.person_rounded,
                    color: context.appTextTertiary,
                    size: 18,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              profile.displayName,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
              ),
            ),
          ),
          TextButton(onPressed: onUnblock, child: const Text('차단 해제')),
        ],
      ),
    );
  }
}
