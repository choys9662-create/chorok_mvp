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

List<BoxShadow>? _feedCardShadow(BuildContext context) {
  if (Theme.of(context).brightness == Brightness.dark) return null;
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
  FeedScope _scope = FeedScope.friends;
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    ref.invalidate(feedActivityProvider(_scope));
    ref.invalidate(followOverlapProvider);
    await ref
        .read(feedActivityProvider(_scope).future)
        .catchError((_) => <FeedActivity>[]);
    if (mounted) setState(() => _isRefreshing = false);
  }

  void _setScope(FeedScope scope) {
    if (_scope == scope) return;
    HapticFeedback.selectionClick();
    setState(() => _scope = scope);
  }

  /// 오늘(자정 이후) 문장을 기록한 친구 수.
  int _recordersToday(List<FeedActivity> activities) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final names = <String>{};
    for (final a in activities) {
      if (a.type == FeedActivityType.sentenceBatch &&
          a.occurredAt.isAfter(todayStart)) {
        names.add(a.username);
      }
    }
    return names.length;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(feedActivityProvider(_scope));
    final activities = async.valueOrNull ?? const <FeedActivity>[];
    final isLoading = async.isLoading;
    final scrollCtrl = ref.read(tabScrollControllersProvider)[1];
    final topPad = MediaQuery.of(context).padding.top;
    final canGoBack = Navigator.of(context).canPop();

    // 겹문장(나 ∩ 팔로잉, 같은 책) — 친구 피드에서만 의미가 있다.
    final overlaps = ref.watch(followOverlapProvider).valueOrNull ?? const [];
    final showOverlapSection =
        _scope == FeedScope.friends &&
        !isLoading &&
        !async.hasError &&
        overlaps.isNotEmpty;
    final recordersToday = _recordersToday(activities);

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          SizedBox(height: topPad + 8),
          // ─── 친구 / 전체 토글 (고정) ─────────────────────
          _ScopeToggle(
            scope: _scope,
            onChanged: _setScope,
            busy: _isRefreshing,
            showBack: canGoBack,
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
                  else if (activities.isEmpty && overlaps.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(scope: _scope),
                    )
                  else ...[
                    // ── 겹문장 알림 섹션 ──────────────────────
                    if (showOverlapSection) ...[
                      SliverToBoxAdapter(
                        child: _SectionHeader(
                          title: '겹문장',
                          subtitle: '팔로우한 독자와 같은 문장에 멈췄어요',
                          trailing: '${overlaps.length}건',
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          activities.isEmpty ? 24 : 8,
                        ),
                        sliver: SliverList.separated(
                          itemCount: overlaps.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _OverlapNotificationCard(overlap: overlaps[i]),
                        ),
                      ),
                    ],
                    // ── 친구의 초서 섹션 ──────────────────────
                    if (activities.isNotEmpty) ...[
                      if (_scope == FeedScope.friends)
                        SliverToBoxAdapter(
                          child: _SectionHeader(
                            title: '친구의 초서',
                            subtitle: recordersToday > 0
                                ? '오늘 $recordersToday명이 문장을 기록했어요'
                                : null,
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          _scope == FeedScope.friends ? 0 : 12,
                          16,
                          24,
                        ),
                        sliver: SliverList.separated(
                          itemCount: activities.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) =>
                              _ActivityCard(activity: activities[i]),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 친구 / 전체 토글 ────────────────────────────────────────────────────────
class _ScopeToggle extends StatelessWidget {
  final FeedScope scope;
  final ValueChanged<FeedScope> onChanged;
  final bool busy;
  final bool showBack;
  final VoidCallback onBack;

  const _ScopeToggle({
    required this.scope,
    required this.onChanged,
    required this.busy,
    required this.showBack,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Center(
            child: Container(
              width: 132,
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: AppTheme.smoothPill(
                color: context.appCard,
                side: BorderSide(color: context.appBorderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ScopeTab(
                      label: '친구',
                      selected: scope == FeedScope.friends,
                      onTap: () => onChanged(FeedScope.friends),
                    ),
                  ),
                  Expanded(
                    child: _ScopeTab(
                      label: '전체',
                      selected: scope == FeedScope.all,
                      onTap: () => onChanged(FeedScope.all),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showBack)
          Positioned(
            left: AppTheme.screenPadding,
            child: Semantics(
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
          ),
        if (busy)
          Positioned(
            right: 20,
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.appPrimaryAccent,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScopeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: AppTheme.smoothPill(
          color: selected
              ? context.appPrimaryAccent.withValues(alpha: 0.14)
              : Colors.transparent,
          side: selected
              ? BorderSide(color: context.appPrimaryAccent, width: 1)
              : BorderSide.none,
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: selected
                ? context.appPrimaryAccent
                : context.appTextTertiary,
            fontWeight: FontWeight.w400,
          ),
        ),
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
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorderSubtle),
        shadows: _feedCardShadow(context),
      ),
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
          const SizedBox(height: 12),
          _SentenceBatchBody(activity: activity),
        ];
      case FeedActivityType.sessionComplete:
        return [
          const SizedBox(height: 14),
          _MetricRow(
            icon: Icons.schedule_rounded,
            value: activity.formattedDuration,
          ),
        ];
      case FeedActivityType.bookComplete:
        return [
          const SizedBox(height: 14),
          _MetricRow(
            icon: Icons.check_circle_outline_rounded,
            value: '${activity.progressPercent}%',
          ),
        ];
    }
  }
}

// ─── 섹션 헤더 (겹문장 / 친구의 초서) ──────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  const _SectionHeader({required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTheme.captionLarge.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
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
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          color: context.appTextSecondary,
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
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
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
                  width: 38,
                  height: 50,
                  radius: 8,
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
      color: context.appTextSecondary,
      height: 1.35,
    );
    final name = base.copyWith(
      color: context.appTextPrimary,
      fontWeight: FontWeight.w400,
    );
    final accent = base.copyWith(
      color: context.appPrimaryAccent,
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
    }

    final showHandle =
        a.handle != null && a.handle!.isNotEmpty && a.handle != a.username;
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: a.username, style: name),
          if (showHandle)
            TextSpan(
              text: ' @${a.handle}',
              style: base.copyWith(color: context.appTextTertiary),
            ),
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
      radius: 18,
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
        Icon(icon, size: 22, color: context.appTextSecondary),
        const SizedBox(width: 8),
        Text(
          value,
          style: AppTheme.headingMedium.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w400,
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
              color: context.appCardElevated,
              radius: AppTheme.radiusMD,
              side: BorderSide(color: context.appBorderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.pageNumber != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '${s.pageNumber}',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
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
                s.thought!,
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextPrimary,
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
  final FeedScope scope;
  const _EmptyState({required this.scope});

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
            scope == FeedScope.friends
                ? '팔로우한 친구의 독서 활동이 여기 모여요'
                : '아직 보여줄 활동이 없어요',
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
