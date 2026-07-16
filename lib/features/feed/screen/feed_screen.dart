import 'package:smooth_corner/smooth_corner.dart';
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
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../search/model/aladin_book.dart';
import '../controller/feed_activity_provider.dart';
import '../model/feed_activity.dart';
import 'sentence_detail_screen.dart';

// Figma(CHOROK-PITCH 피드, node 1557:1690) 매칭 색상 — AppTheme 토큰에 없는 강조 박스 전용 값.
const _kQuoteHighlightBg = Color(0xFF222422);
const _kThoughtBorder = Color(0xFF222422);

/// 겹문장 알림과 활동 소식을 하나의 시간순 타임라인으로 합치기 위한 항목.
/// 정확히 [overlap], [activity] 중 하나만 채워진다.
typedef _FeedItem = ({
  DateTime time,
  FollowOverlap? overlap,
  FeedActivity? activity,
});

List<BoxShadow>? _feedCardShadow(BuildContext context) {
  if (Theme.of(context).brightness == Brightness.dark) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.28),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ];
  }
  return [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

/// 피드 스크린: 친구·이웃의 독서 활동(소식) 피드.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  static const Color _feedBg = Colors.black;

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
      backgroundColor: _feedBg,
      body: Column(
        children: [
          SizedBox(height: topPad + 8),
          if (canGoBack)
            _FeedBackButton(
              onBack: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 8),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      sliver: SliverList.separated(
                        itemCount: 4,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: feedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
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

// ─── 뒤로가기 (push 로 열렸을 때만) ───────────────────────────────────────────
class _FeedBackButton extends StatelessWidget {
  final VoidCallback onBack;

  const _FeedBackButton({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: AppTheme.screenPadding),
          Semantics(
            label: '뒤로 가기',
            button: true,
            child: IconButton(
              onPressed: onBack,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: context.appTextSecondary,
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
    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 8,
        side: BorderSide(color: context.appBorderSubtle),
        shadows: _feedCardShadow(context),
      ),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 13),
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
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusLG,
          side: BorderSide(
            color: context.appPrimaryAccent.withValues(alpha: 0.55),
          ),
          shadows: _feedCardShadow(context),
        ),
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 — 누가, 어떤 책
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(username: o.neighborName, avatarUrl: o.neighborAvatar),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 3),
                      Text(
                        time_fmt.formatRelative(o.neighborCreatedAt),
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
                const SizedBox(width: 8),
                BookCover(
                  coverUrl: o.coverUrl,
                  gradientIndex:
                      o.bookTitle.hashCode.abs() %
                      AppTheme.coverGradients.length,
                  width: 38,
                  height: 50,
                  radius: 8,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MergedOverlapParagraph(
              content: o.mergedContent,
              highlight: o.mergedHighlight,
            ),
            if (o.neighborThought != null && o.neighborThought!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: ShapeDecoration(
                  color: context.appPrimaryAccent.withValues(alpha: 0.06),
                  shape: SmoothRectangleBorder(
                    smoothness: 0.6,
                    side: BorderSide(
                      color: context.appPrimaryAccent.withValues(alpha: 0.55),
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: AppTheme.radiusMD,
        side: BorderSide(color: context.appBorderSubtle),
      ),
      child: Text.rich(
        TextSpan(
          style: baseStyle,
          children: hasHighlight
              ? [
                  TextSpan(text: content.substring(0, highlight.start)),
                  TextSpan(
                    text: content.substring(highlight.start, highlight.end),
                    style: baseStyle.copyWith(
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
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
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _titleText(context, a),
              const SizedBox(height: 3),
              Text(
                time_fmt.formatRelative(a.occurredAt),
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              if (a.type == FeedActivityType.sessionComplete ||
                  a.type == FeedActivityType.bookComplete) ...[
                const SizedBox(height: 30),
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
        const SizedBox(width: 10),
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
                    const SizedBox(height: 2),
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
                const SizedBox(width: 8),
                BookCover(
                  coverUrl: a.coverUrl,
                  gradientIndex:
                      a.bookTitle.hashCode.abs() %
                      AppTheme.coverGradients.length,
                  width: 53,
                  height: 87,
                  radius: 4,
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
    final base = AppTheme.bodySmall.copyWith(
      fontSize: 14,
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
        const SizedBox(width: 4),
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
          if (i > 0) const SizedBox(height: 10),
          _SentencePreview(
            sentence: visibleSentences[i],
            onTap: () => _openSentence(context, visibleSentences[i]),
          ),
        ],
        if (hiddenCount > 0 && allSentences.length > 2) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label: _expanded ? '문장 접기' : '문장 $hiddenCount개 더보기',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _expanded = !_expanded);
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _expanded ? '접기' : '$hiddenCount개 더보기',
                  style: AppTheme.captionLarge.copyWith(
                    fontSize: 14,
                    color: context.appTextTertiary,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.smoothBox(
              color: _kQuoteHighlightBg,
              radius: 6,
              side: BorderSide(color: context.appTextSecondary),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.pageNumber != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '${s.pageNumber}',
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 14,
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    s.content,
                    style: AppTheme.bodySmall.copyWith(
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
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: context.appCard,
                shape: SmoothRectangleBorder(
                  smoothness: 0.6,
                  side: const BorderSide(color: _kThoughtBorder),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                s.thought!,
                style: AppTheme.bodySmall.copyWith(
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
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 12),
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
        children: [
          Text(
            '피드를 불러오지 못했어요',
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
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
