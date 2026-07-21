import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/overlap_group.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/utils/overlap_detector.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
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

/// 겹문장 UI.
///
/// 목록에서는 생각을 중심으로 보여주고, 카드를 누르면 해당 독자가 실제로
/// 기록한 전체 문장과 현재 문장에 겹치는 구간을 바텀시트에서 보여준다.
class SplitHighlightWidget extends StatefulWidget {
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
  State<SplitHighlightWidget> createState() => _SplitHighlightWidgetState();
}

class _SplitHighlightWidgetState extends State<SplitHighlightWidget> {
  static const _initialVisibleCount = 3;
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _OverlapThoughtCard(
        anchorText: widget.anchorText,
        recordedText: widget.anchorText,
        username: widget.collectorUsername,
        userId: widget.collectorUserId,
        rawUsername: widget.collectorUserHandle,
        displayName: widget.collectorUsername,
        thought: widget.collectorThought,
        isCollector: true,
      ),
      for (final match in widget.matches)
        _OverlapThoughtCard(
          anchorText: widget.anchorText,
          recordedText: match.content,
          username: match.displayName ?? match.username,
          userId: match.userId,
          rawUsername: match.username,
          displayName: match.displayName,
          avatarUrl: match.avatarUrl,
          thought: match.thought,
          isCollector: false,
        ),
    ];
    final visibleCards = _showAll
        ? cards
        : cards.take(_initialVisibleCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visibleCards.length; index++)
          if (index == visibleCards.length - 1)
            visibleCards[index]
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
              child: visibleCards[index],
            ),
        if (!_showAll && cards.length > _initialVisibleCount) ...[
          const SizedBox(height: AppTheme.spaceMD),
          Semantics(
            button: true,
            label: '서로 다른 생각 더 보기',
            child: GestureDetector(
              key: const ValueKey('overlap-thoughts-show-more'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showAll = true);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '서로 다른 생각 더 보기',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appPrimaryAccent,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceXS),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: context.appPrimaryAccent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OverlapThoughtCard extends StatelessWidget {
  final String anchorText;
  final String recordedText;
  final String username;
  final String? userId;
  final String? rawUsername;
  final String? displayName;
  final String? avatarUrl;
  final String? thought;
  final bool isCollector;

  const _OverlapThoughtCard({
    required this.anchorText,
    required this.recordedText,
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
    final profileTappable = userId != null && userId!.isNotEmpty;
    return Semantics(
      button: true,
      label: '$username님이 기록한 문장 보기',
      child: GestureDetector(
        key: ValueKey('overlap-thought-card-$username'),
        onTap: () {
          HapticFeedback.selectionClick();
          showRecordedSentenceDetails(
            context,
            anchorText: anchorText,
            recordedText: recordedText,
            username: username,
            thought: thought,
          );
        },
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          child: ChorokCard(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            showBorder: isCollector,
            borderColor: isCollector
                ? context.appPrimaryAccent.withValues(alpha: 0.35)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: profileTappable
                      ? () => _openProfile(
                          context,
                          userId: userId,
                          username: rawUsername ?? username,
                          displayName: displayName,
                          avatarUrl: avatarUrl,
                        )
                      : null,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      // 원형 아바타는 사용자 식별 렌더링 예외다.
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: isCollector
                            ? context.appPrimaryAccent.withValues(alpha: 0.15)
                            : context.appSurface,
                        backgroundImage:
                            (avatarUrl != null && avatarUrl!.isNotEmpty)
                            ? NetworkImage(avatarUrl!)
                            : null,
                        child: (avatarUrl == null || avatarUrl!.isEmpty)
                            ? Text(
                                username.isNotEmpty
                                    ? username[0].toUpperCase()
                                    : '?',
                                style: AppTheme.captionSmall.copyWith(
                                  color: isCollector
                                      ? context.appPrimaryAccent
                                      : context.appTextTertiary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: AppTheme.spaceSM),
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.captionLarge.copyWith(
                            color: isCollector
                                ? context.appPrimaryAccent
                                : context.appTextSecondary,
                          ),
                        ),
                      ),
                      if (rawUsername != null &&
                          rawUsername!.isNotEmpty &&
                          rawUsername != username) ...[
                        const SizedBox(width: AppTheme.spaceXS),
                        Flexible(
                          child: Text(
                            '@$rawUsername',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                if (thought != null && thought!.trim().isNotEmpty)
                  Text(
                    thought!.trim(),
                    style: AppTheme.bodySmall.copyWith(
                      color: context.appTextPrimary,
                      height: 1.6,
                    ),
                  )
                else
                  Text(
                    '아직 생각을 남기지 않았어요',
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                const SizedBox(height: AppTheme.spaceMD),
                Row(
                  children: [
                    Text(
                      '기록한 문장 보기',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.appTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showRecordedSentenceDetails(
  BuildContext context, {
  required String anchorText,
  required String recordedText,
  required String username,
  required String? thought,
}) {
  final result = OverlapDetector.compare(anchorText, recordedText);
  final highlight = result.highlightsB.isEmpty
      ? null
      : result.highlightsB.reduce(
          (longest, current) =>
              current.length > longest.length ? current : longest,
        );

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appBg.withValues(alpha: 0),
    builder: (sheetContext) => _RecordedSentenceSheet(
      recordedText: recordedText,
      highlight: highlight,
      username: username,
      thought: thought,
    ),
  );
}

class _RecordedSentenceSheet extends StatelessWidget {
  final String recordedText;
  final HighlightRange? highlight;
  final String username;
  final String? thought;

  const _RecordedSentenceSheet({
    required this.recordedText,
    required this.highlight,
    required this.username,
    required this.thought,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final textStyle = AppTheme.bodyMedium.copyWith(
      color: context.appTextPrimary,
      height: 1.7,
    );
    final validHighlight =
        highlight != null &&
        highlight!.start >= 0 &&
        highlight!.end > highlight!.start &&
        highlight!.end <= recordedText.length;

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: ChorokCard(
            backgroundColor: context.appBg,
            showBorder: false,
            padding: EdgeInsets.only(
              left: AppTheme.screenPadding,
              top: AppTheme.spaceMD,
              right: AppTheme.screenPadding,
              bottom: bottomInset + AppTheme.spaceLG,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ChorokSheetHandle(),
                  const SizedBox(height: AppTheme.spaceLG),
                  Text(
                    '$username님이 기록한 문장',
                    style: AppTheme.rowText.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  SizedBox(
                    width: double.infinity,
                    child: ChorokCard(
                      inner: true,
                      borderColor: context.appBorderSubtle,
                      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                      child: Text.rich(
                        TextSpan(
                          style: textStyle,
                          children: validHighlight
                              ? [
                                  TextSpan(
                                    text: recordedText.substring(
                                      0,
                                      highlight!.start,
                                    ),
                                  ),
                                  TextSpan(
                                    text: recordedText.substring(
                                      highlight!.start,
                                      highlight!.end,
                                    ),
                                    style: textStyle.copyWith(
                                      color: context.appPrimaryAccent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: recordedText.substring(
                                      highlight!.end,
                                    ),
                                  ),
                                ]
                              : [TextSpan(text: recordedText)],
                        ),
                      ),
                    ),
                  ),
                  if (thought != null && thought!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spaceLG),
                    Text(
                      '$username님의 생각',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    Text(
                      thought!.trim(),
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
