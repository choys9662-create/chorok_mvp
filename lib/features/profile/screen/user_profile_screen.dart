import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../controller/user_profile_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  const UserProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  FollowState? _followOverride;
  bool _busy = false;

  Future<void> _toggleFollow(FollowState current) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      if (current == FollowState.none) {
        final result = await repo.follow(widget.profile.id);
        if (mounted) setState(() => _followOverride = result);
      } else {
        await repo.unfollow(widget.profile.id);
        if (mounted) setState(() => _followOverride = FollowState.none);
        ref.invalidate(userProfileProvider(widget.profile.id));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(userProfileProvider(p.id)),
        ),
        data: (data) {
          final followState = _followOverride ?? data.followState;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Header(
                profile: p,
                followState: followState,
                busy: _busy,
                onToggleFollow: () => _toggleFollow(followState),
              ),
              const SizedBox(height: 24),
              if (data.sentences.isEmpty)
                _EmptySentences(
                  isPrivate: p.isPrivate,
                  followState: followState,
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

class _Header extends StatelessWidget {
  final UserProfile profile;
  final FollowState followState;
  final bool busy;
  final VoidCallback onToggleFollow;

  const _Header({
    required this.profile,
    required this.followState,
    required this.busy,
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.bio!,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        _FollowButton(
          followState: followState,
          busy: busy,
          onTap: onToggleFollow,
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final FollowState followState;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.followState,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, filled) = switch (followState) {
      FollowState.none => ('팔로우', true),
      FollowState.accepted => ('팔로잉', false),
      FollowState.pending => ('요청됨', false),
    };
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        decoration: AppTheme.smoothBox(
          color: filled ? context.appPrimaryAccent : context.appCardElevated,
          radius: AppTheme.radiusMD,
          side: BorderSide.none,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
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
              fontWeight: FontWeight.w600,
              color: context.appPrimaryAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${s.content}"',
            style: TextStyle(
              fontSize: 14,
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
                fontSize: 13,
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLocked ? '팔로우가 수락되면 초서를 볼 수 있어요' : '이 유저가 초서를 남기면 여기 표시돼요',
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
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
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
