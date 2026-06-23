import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../controller/overlap_provider.dart';

/// 작성자 프로필(서재)로 이동. id가 없으면 아무 동작도 하지 않는다.
void _openProfile(
  BuildContext context, {
  required String? userId,
  required String username,
  String? displayName,
  String? avatarUrl,
}) {
  if (userId == null || userId.isEmpty) return;
  HapticFeedback.selectionClick();
  context.push(
    AppConstants.routeUserProfile,
    extra: UserProfile(
      id: userId,
      username: username,
      displayName: (displayName != null && displayName.trim().isNotEmpty)
          ? displayName
          : username,
      avatarUrl: avatarUrl,
    ),
  );
}

/// 겹문장 UI — 상단에 기록자 카드, 하단에 다른 독자들 카드 목록
///
/// Anchor(공유 문장): Bold + appPrimaryAccent
/// Context(생각): FontWeight.w400 + appTextTertiary
class SplitHighlightWidget extends StatelessWidget {
  final String anchorText;
  final String collectorUsername;
  final String? collectorUserHandle;
  final String? collectorUserId;
  final String? collectorThought;
  final List<OverlapMatch> matches;

  const SplitHighlightWidget({
    super.key,
    required this.anchorText,
    required this.collectorUsername,
    this.collectorUserHandle,
    this.collectorUserId,
    this.collectorThought,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기록자 카드 (상단)
        _OverlapCard(
          anchorText: anchorText,
          username: collectorUsername,
          userId: collectorUserId,
          rawUsername: collectorUserHandle,
          displayName: collectorUsername,
          thought: collectorThought,
          isCollector: true,
        ),
        const SizedBox(height: 12),
        // 구분선
        Row(
          children: [
            Expanded(child: Divider(color: context.appBorder, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '다른 독자들의 생각',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.appBorder, height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        // 타인 카드 목록 (하단 나열)
        ...matches.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OverlapCard(
              anchorText: anchorText,
              username: m.displayName ?? m.username,
              userId: m.userId,
              rawUsername: m.username,
              displayName: m.displayName,
              avatarUrl: m.avatarUrl,
              thought: m.thought,
              isCollector: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlapCard extends StatelessWidget {
  final String anchorText;
  final String username;
  final String? userId;
  final String? rawUsername;
  final String? displayName;
  final String? avatarUrl;
  final String? thought;
  final bool isCollector;

  const _OverlapCard({
    required this.anchorText,
    required this.username,
    this.userId,
    this.rawUsername,
    this.displayName,
    this.avatarUrl,
    this.thought,
    required this.isCollector,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = userId != null && userId!.isNotEmpty;
    return GestureDetector(
      onTap: tappable
          ? () => _openProfile(
              context,
              userId: userId,
              username: rawUsername ?? username,
              displayName: displayName,
              avatarUrl: avatarUrl,
            )
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusLG,
          side: isCollector
              ? BorderSide(
                  color: context.appPrimaryAccent.withValues(alpha: 0.35),
                )
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Anchor — Bold + brand color
            RichText(
              text: TextSpan(
                text: '"$anchorText"',
                style: AppTheme.bodySmall.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 유저 정보 (탭하면 프로필)
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isCollector
                      ? context.appPrimaryAccent.withValues(alpha: 0.15)
                      : context.appSurface,
                  backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : '?',
                          style: AppTheme.captionSmall.copyWith(
                            color: isCollector
                                ? context.appPrimaryAccent
                                : context.appTextTertiary,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionLarge.copyWith(
                      color: isCollector
                          ? context.appPrimaryAccent
                          : context.appTextSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (rawUsername != null &&
                    rawUsername!.isNotEmpty &&
                    rawUsername != username) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '@$rawUsername',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                if (tappable) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: context.appTextTertiary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            // Context(생각) — Light + grey
            thought != null && thought!.isNotEmpty
                ? RichText(
                    text: TextSpan(
                      text: thought,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextTertiary,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                    ),
                  )
                : Text(
                    '아직 생각을 남기지 않았어요',
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
