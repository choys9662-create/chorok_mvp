import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/moderation_repository.dart';
import '../../../shared/utils/follow_relationship_text.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../controller/user_profile_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  const UserProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  FollowRelationship? _relationshipOverride;
  bool _busy = false;

  Future<void> _toggleFollow(FollowRelationship current) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      if (current.outgoing == FollowState.none) {
        final result = await repo.follow(widget.profile.id);
        if (!mounted) return;
        setState(
          () => _relationshipOverride = current.copyWith(outgoing: result),
        );
        ref.invalidate(userProfileProvider(widget.profile.id));
        ref.read(followMutationVersionProvider.notifier).state++;
      } else {
        await repo.unfollow(widget.profile.id);
        if (!mounted) return;
        setState(
          () => _relationshipOverride = current.copyWith(
            outgoing: FollowState.none,
          ),
        );
        ref.invalidate(userProfileProvider(widget.profile.id));
        ref.read(followMutationVersionProvider.notifier).state++;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, '팔로우 상태를 변경하지 못했어요', success: false),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    HapticFeedback.mediumImpact();
    final repo = ref.read(moderationRepositoryProvider);
    try {
      if (currentlyBlocked) {
        await repo.unblock(widget.profile.id);
      } else {
        await repo.block(widget.profile.id);
      }
      if (!mounted) return;
      setState(() => _relationshipOverride = FollowRelationship.none);
      ref.invalidate(userProfileProvider(widget.profile.id));
      ref.read(blockMutationVersionProvider.notifier).state++;
      ref.read(followMutationVersionProvider.notifier).state++;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, currentlyBlocked ? '차단을 해제했어요' : '차단했어요'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, '처리하지 못했어요. 다시 시도해주세요', success: false),
      );
    }
  }

  Future<void> _reportUser() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 유저를 신고할까요?'),
        content: const Text('신고 내용은 운영팀이 확인 후 처리해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('신고'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .report(ReportTargetType.user, widget.profile.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '신고가 접수됐어요'));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, '신고를 접수하지 못했어요', success: false),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final async = ref.watch(userProfileProvider(p.id));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '@${p.username}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: context.appTextPrimary,
          ),
        ),
        actions: [
          async.whenOrNull(
                data: (data) => PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: context.appTextSecondary,
                  ),
                  onSelected: (value) {
                    if (value == 'block') _toggleBlock(data.isBlocked);
                    if (value == 'report') _reportUser();
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'block',
                      child: Text(data.isBlocked ? '차단 해제하기' : '차단하기'),
                    ),
                    const PopupMenuItem(value: 'report', child: Text('신고하기')),
                  ],
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(userProfileProvider(p.id)),
        ),
        data: (data) {
          final relationship = _relationshipOverride ?? data.relationship;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (data.isBlocked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BlockedBanner(
                    onUnblock: () => _toggleBlock(true),
                  ),
                ),
              _Header(
                profile: p,
                relationship: relationship,
                busy: _busy,
                showFollowButton: !data.isBlocked,
                onToggleFollow: () => _toggleFollow(relationship),
              ),
              const SizedBox(height: 24),
              if (data.sentences.isEmpty)
                _EmptySentences(
                  isPrivate: p.isPrivate,
                  followState: relationship.outgoing,
                )
              else
                ...data.sentences.map((s) => _SentenceTile(sentence: s)),
            ],
          );
        },
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  final VoidCallback onUnblock;
  const _BlockedBanner({required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.smoothBox(
        color: const Color(0xFFFF4F4F).withValues(alpha: 0.08),
        radius: AppTheme.radiusMD,
        side: BorderSide(color: const Color(0xFFFF4F4F).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, size: 18, color: Color(0xFFFF4F4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '차단한 유저예요',
              style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            ),
          ),
          TextButton(onPressed: onUnblock, child: const Text('차단 해제')),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  final FollowRelationship relationship;
  final bool busy;
  final bool showFollowButton;
  final VoidCallback onToggleFollow;

  const _Header({
    required this.profile,
    required this.relationship,
    required this.busy,
    this.showFollowButton = true,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: context.appCardElevated,
          backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
              ? NetworkImage(p.avatarUrl!)
              : null,
          child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
              ? Icon(
                  Icons.person_rounded,
                  color: context.appTextTertiary,
                  size: 40,
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          p.displayName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: context.appTextPrimary,
          ),
        ),
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.bio!,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        if (followRelationshipHint(relationship) case final hint?) ...[
          const SizedBox(height: 10),
          _RelationshipPill(label: hint),
        ],
        if (showFollowButton) ...[
          const SizedBox(height: 16),
          _FollowButton(
            relationship: relationship,
            busy: busy,
            onTap: onToggleFollow,
          ),
        ],
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final FollowRelationship relationship;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.relationship,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = followActionLabel(relationship);
    final filled = followActionIsFilled(relationship);
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: busy ? null : onTap,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              child: _FollowButtonLabel(label: label, busy: busy),
            )
          : TextButton(
              onPressed: busy ? null : onTap,
              style: TextButton.styleFrom(
                backgroundColor: context.appCardElevated,
                foregroundColor: context.appTextSecondary,
                disabledForegroundColor: context.appTextTertiary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              child: _FollowButtonLabel(label: label, busy: busy),
            ),
    );
  }
}

class _RelationshipPill extends StatelessWidget {
  final String label;
  const _RelationshipPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: AppTheme.radiusSM,
        side: BorderSide(
          color: context.appPrimaryAccent.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: context.appTextSecondary,
        ),
      ),
    );
  }
}

class _FollowButtonLabel extends StatelessWidget {
  final String label;
  final bool busy;

  const _FollowButtonLabel({required this.label, required this.busy});

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.appTextSecondary,
        ),
      );
    }
    return Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    );
  }
}

class _SentenceTile extends StatelessWidget {
  final FeedSentence sentence;
  const _SentenceTile({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final s = sentence;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.bookTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.appPrimaryAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${s.content}"',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: context.appTextPrimary,
              height: 1.6,
            ),
          ),
          if (s.thought != null && s.thought!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.thought!,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySentences extends StatelessWidget {
  final bool isPrivate;
  final FollowState followState;
  const _EmptySentences({required this.isPrivate, required this.followState});

  @override
  Widget build(BuildContext context) {
    final isLocked = isPrivate && followState != FollowState.accepted;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.menu_book_outlined,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isLocked ? '비공개 계정이에요' : '아직 공개된 초서가 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLocked ? '팔로우가 수락되면 초서를 볼 수 있어요' : '이 유저가 초서를 남기면 여기 표시돼요',
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '프로필을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenGradient,
                radius: AppTheme.radiusMD,
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.darkBg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
