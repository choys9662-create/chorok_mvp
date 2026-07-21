import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/overlap_group.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/providers/follow_overlap_provider.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_back_button.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../search/model/aladin_book.dart';
import '../controller/feed_activity_provider.dart';
import '../model/feed_activity.dart';
import 'sentence_detail_screen.dart';

/// 겹문장 알림과 활동 소식을 하나의 시간순 타임라인으로 합치기 위한 항목.
/// 정확히 [overlap], [activity] 중 하나만 채워진다.
typedef _FeedItem = ({
  DateTime time,
  FollowOverlap? overlap,
  FeedActivity? activity,
});

/// 피드 스크린: 친구·이웃의 독서 활동(소식) 피드.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  // 피드는 친구 범위만 보여준다. FeedScope.all 은 아직 쓰는 화면이 없다.
  static const _scope = FeedScope.friends;

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    ref.invalidate(feedActivityProvider(_scope));
    ref.invalidate(followOverlapProvider);
    await ref
        .read(feedActivityProvider(_scope).future)
        .catchError((_) => <FeedActivity>[]);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedActivityProvider(_scope));
    final activities = async.valueOrNull ?? const <FeedActivity>[];
    final isLoading = async.isLoading;
    final scrollCtrl = ref.read(tabScrollControllersProvider)[1];
    final topPad = MediaQuery.of(context).padding.top;
    final canGoBack = Navigator.of(context).canPop();

    // 겹문장(나 ∩ 팔로잉, 같은 책)
    final overlaps = ref.watch(followOverlapProvider).valueOrNull ?? const [];

    // 겹문장 알림 + 활동 소식을 하나의 타임라인으로 합쳐 최신순으로 보여준다.
    final feedItems = <_FeedItem>[
      for (final o in overlaps)
        (time: o.neighborCreatedAt, overlap: o, activity: null),
      for (final a in activities)
        (time: a.occurredAt, overlap: null, activity: a),
    ]..sort((a, b) => b.time.compareTo(a.time));

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          SizedBox(height: topPad + AppTheme.spaceSM),
          if (canGoBack)
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.screenPadding),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ChorokBackButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          const SizedBox(height: AppTheme.spaceSM),
          Expanded(
            child: RefreshIndicator(
              color: context.appPrimaryAccent,
              backgroundColor: context.appCard,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (isLoading)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.screenPadding,
                        AppTheme.spaceMD,
                        AppTheme.screenPadding,
                        AppTheme.spaceMD,
                      ),
                      sliver: SliverList.separated(
                        itemCount: 4,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTheme.spaceMD),
                        itemBuilder: (_, _) => const ChorokShimmer(
                          width: double.infinity,
                          height: 120,
                          radius: AppTheme.radiusLG,
                        ),
                      ),
                    )
                  else if (async.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        onRetry: () =>
                            ref.invalidate(feedActivityProvider(_scope)),
                      ),
                    )
                  else if (feedItems.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: const _EmptyState(),
                    )
                  else
                    // ── 겹문장 알림 + 활동 소식 (최신순 통합) ──────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.screenPadding,
                        AppTheme.spaceMD,
                        AppTheme.screenPadding,
                        AppTheme.spaceXL,
                      ),
                      sliver: SliverList.separated(
                        itemCount: feedItems.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTheme.spaceMD),
                        itemBuilder: (_, i) {
                          final item = feedItems[i];
                          return item.overlap != null
                              ? _OverlapNotificationCard(overlap: item.overlap!)
                              : _ActivityCard(activity: item.activity!);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 활동 카드 ────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final FeedActivity activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      borderColor: context.appBorderSubtle,
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActivityHeader(activity: activity),
          ..._buildBody(context),
        ],
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    switch (activity.type) {
      case FeedActivityType.sentenceBatch:
        return [
          const SizedBox(height: AppTheme.spaceMD),
          _SentenceBatchBody(activity: activity),
        ];
      case FeedActivityType.sessionComplete:
        return const [];
      case FeedActivityType.bookComplete:
        return const [];
      case FeedActivityType.wantToRead:
        return const [];
      case FeedActivityType.readingStart:
        return const [];
    }
  }
}

// ─── 겹문장 알림 카드 ────────────────────────────────────────────────────────
class _OverlapNotificationCard extends StatelessWidget {
  final FollowOverlap overlap;
  const _OverlapNotificationCard({required this.overlap});

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: overlap.mergedContent,
        bookTitle: overlap.bookTitle,
        bookAuthor: overlap.bookAuthor,
        collectorUsername: overlap.neighborName,
        collectorUserHandle: overlap.neighborHandle,
        collectorUserId: overlap.neighborUserId,
        collectorThought: overlap.neighborThought,
        sentenceId: overlap.neighborSentenceId,
        overlapCommonPhrase: overlap.commonPhrase,
        overlapHighlight: overlap.mergedHighlight,
        bookId: overlap.bookId,
        globalBookId: overlap.globalBookId,
        coverUrl: overlap.coverUrl,
        isbn13: overlap.isbn13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = overlap;
    return GestureDetector(
      onTap: () => _open(context),
      child: ChorokCard(
        borderColor: context.appPrimaryAccent.withValues(alpha: 0.55),
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 — 누가, 어떤 책
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(username: o.neighborName, avatarUrl: o.neighborAvatar),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppTheme.spaceXS,
                    children: [
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextSecondary,
                            height: 1.35,
                          ),
                          children: [
                            TextSpan(
                              text: o.neighborName,
                              style: AppTheme.bodySmall.copyWith(
                                color: context.appTextPrimary,
                              ),
                            ),
                            if (o.neighborHandle != null &&
                                o.neighborHandle!.isNotEmpty &&
                                o.neighborHandle != o.neighborName)
                              TextSpan(
                                text: ' @${o.neighborHandle}',
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                            const TextSpan(text: '님과 같은 문장에 멈췄어요'),
                          ],
                        ),
                      ),
                      Text(
                        time_fmt.formatRelative(o.neighborCreatedAt),
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    '${o.bookTitle} · ${o.bookAuthor}',
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                BookCover(
                  coverUrl: o.coverUrl,
                  gradientIndex:
                      o.bookTitle.hashCode.abs() %
                      AppTheme.coverGradients.length,
                  width: 38,
                  height: 50,
                  radius: AppTheme.radiusInner,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _MergedOverlapParagraph(
              content: o.mergedContent,
              highlight: o.mergedHighlight,
            ),
            if (o.neighborThought != null && o.neighborThought!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSM),
              ChorokCard(
                inner: true,
                backgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.06,
                ),
                borderColor: context.appPrimaryAccent.withValues(alpha: 0.55),
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Text(
                  o.neighborThought!,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextPrimary,
                    height: 1.55,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MergedOverlapParagraph extends StatelessWidget {
  final String content;
  final HighlightRange highlight;

  const _MergedOverlapParagraph({
    required this.content,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final hasHighlight =
        highlight.start >= 0 &&
        highlight.end > highlight.start &&
        highlight.end <= content.length;
    final baseStyle = AppTheme.bodySmall.copyWith(
      color: context.appTextPrimary,
      height: 1.55,
    );

    return ChorokCard(
      inner: true,
      borderColor: context.appBorderSubtle,
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: hasHighlight
              ? [
                  TextSpan(text: content.substring(0, highlight.start)),
                  TextSpan(
                    text: content.substring(highlight.start, highlight.end),
                    style: baseStyle.copyWith(color: context.appPrimaryAccent),
                  ),
                  TextSpan(text: content.substring(highlight.end)),
                ]
              : [TextSpan(text: content)],
        ),
      ),
    );
  }
}

// ─── 카드 헤더 (행위자 + 책) ───────────────────────────────────────────────────
class _ActivityHeader extends StatelessWidget {
  final FeedActivity activity;
  const _ActivityHeader({required this.activity});

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(username: a.username, avatarUrl: a.avatarUrl),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleText(context, a),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                time_fmt.formatRelative(a.occurredAt),
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              if (a.type == FeedActivityType.sessionComplete ||
                  a.type == FeedActivityType.bookComplete) ...[
                const SizedBox(height: AppTheme.sectionGap),
                _MetricRow(
                  icon: a.type == FeedActivityType.sessionComplete
                      ? Icons.schedule_rounded
                      : Icons.check_circle_outline_rounded,
                  value: a.type == FeedActivityType.sessionComplete
                      ? a.formattedDuration
                      : '${a.progressPercent}%',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        Semantics(
          button: true,
          label: '${a.bookTitle} 책 정보 보기',
          child: GestureDetector(
            onTap: () => _openBook(context, a),
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  spacing: AppTheme.spaceXS,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 76),
                      child: Text(
                        a.bookTitle,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 76),
                      child: Text(
                        a.bookAuthor,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.spaceSM),
                BookCover(
                  coverUrl: a.coverUrl,
                  gradientIndex:
                      a.bookTitle.hashCode.abs() %
                      AppTheme.coverGradients.length,
                  width: 53,
                  height: 87,
                  radius: AppTheme.radiusInner,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openBook(BuildContext context, FeedActivity activity) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeBookInfo,
      extra: AladinBook(
        title: activity.bookTitle,
        author: activity.bookAuthor,
        publisher: '',
        coverUrl: activity.coverUrl,
        isbn13: activity.isbn13,
      ),
    );
  }

  Widget _titleText(BuildContext context, FeedActivity a) {
    final base = AppTheme.body.copyWith(
      color: context.appTextSecondary,
      height: 1.35,
    );
    final name = base.copyWith(
      color: context.appTextPrimary,
      fontWeight: FontWeight.w400,
    );
    final accent = base.copyWith(
      color: context.appTextPrimary,
      fontWeight: FontWeight.w400,
    );

    final List<InlineSpan> children;
    switch (a.type) {
      case FeedActivityType.sentenceBatch:
        children = [
          const TextSpan(text: '님이 문장을 '),
          TextSpan(text: '${a.sentenceCount}개', style: accent),
          const TextSpan(text: ' 기록했어요'),
        ];
        break;
      case FeedActivityType.sessionComplete:
        children = [const TextSpan(text: '님이 세션을 완료했어요')];
        break;
      case FeedActivityType.bookComplete:
        children = [const TextSpan(text: '님이 도서를 완독했어요')];
        break;
      case FeedActivityType.wantToRead:
        children = [const TextSpan(text: '님이 읽고 싶은 책으로 추가했어요')];
        break;
      case FeedActivityType.readingStart:
        children = [const TextSpan(text: '님이 책을 읽기 시작했어요')];
        break;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: a.username, style: name),
          ...children,
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  const _Avatar({required this.username, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 15,
      backgroundColor: context.appPrimaryAccent.withValues(alpha: 0.14),
      backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? NetworkImage(avatarUrl!)
          : null,
      child: (avatarUrl == null || avatarUrl!.isEmpty)
          ? Text(
              initial,
              style: AppTheme.bodySmall.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w400,
              ),
            )
          : null,
    );
  }
}

// ─── 세션/완독 메트릭 행 ────────────────────────────────────────────────────────
class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MetricRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.appTextSecondary),
        const SizedBox(width: AppTheme.spaceXS),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.headingMedium.copyWith(
                color: context.appTextSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 문장 기록 본문 ────────────────────────────────────────────────────────────
class _SentenceBatchBody extends StatefulWidget {
  final FeedActivity activity;
  const _SentenceBatchBody({required this.activity});

  @override
  State<_SentenceBatchBody> createState() => _SentenceBatchBodyState();
}

class _SentenceBatchBodyState extends State<_SentenceBatchBody> {
  bool _expanded = false;

  void _openSentence(BuildContext context, FeedActivitySentence s) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: s.content,
        bookTitle: widget.activity.bookTitle,
        bookAuthor: widget.activity.bookAuthor,
        page: s.pageNumber,
        collectorUsername: widget.activity.username,
        collectorUserHandle: widget.activity.handle,
        collectorThought: s.thought,
        sentenceId: s.id,
        coverUrl: widget.activity.coverUrl,
        isbn13: widget.activity.isbn13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allSentences = widget.activity.previewSentences;
    final visibleSentences = _expanded
        ? allSentences
        : allSentences.take(2).toList();
    final hiddenCount = (widget.activity.sentenceCount - 2).clamp(
      0,
      widget.activity.sentenceCount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < visibleSentences.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTheme.spaceSM),
          _SentencePreview(
            sentence: visibleSentences[i],
            onTap: () => _openSentence(context, visibleSentences[i]),
          ),
        ],
        if (hiddenCount > 0 && allSentences.length > 2) ...[
          const SizedBox(height: AppTheme.spaceSM),
          Semantics(
            button: true,
            label: _expanded ? '문장 접기' : '문장 $hiddenCount개 더보기',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceSM,
                  ),
                  child: Center(
                    child: Text(
                      _expanded ? '접기' : '$hiddenCount개 더보기',
                      style: AppTheme.body.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SentencePreview extends StatelessWidget {
  final FeedActivitySentence sentence;
  final VoidCallback onTap;
  const _SentencePreview({required this.sentence, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = sentence;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문장 (페이지 배지 + 본문)
          ChorokCard(
            inner: true,
            borderColor: context.appTextSecondary,
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.pageNumber != null) ...[
                  Text(
                    '${s.pageNumber}',
                    style: AppTheme.body.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                ],
                Expanded(
                  child: Text(
                    s.content,
                    style: AppTheme.bodyMedium.copyWith(
                      color: context.appTextPrimary,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 생각 (강조 박스)
          if (s.thought != null && s.thought!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSM),
            ChorokCard(
              inner: true,
              backgroundColor: context.appCard,
              borderColor: context.appBorder,
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Text(
                s.thought!,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appPrimaryAccent,
                  height: 1.55,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 빈 상태 ──────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppTheme.spaceMD,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: context.appTextTertiary,
          ),
          Text(
            '팔로우한 친구의 독서 활동이 여기 모여요',
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppTheme.spaceMD,
        children: [
          Text(
            '피드를 불러오지 못했어요',
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              '다시 시도',
              style: AppTheme.bodySmall.copyWith(
                color: context.appPrimaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
