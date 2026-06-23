import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/models/overlap_group.dart';
import '../../../shared/utils/sentence_normalizer.dart';
import '../../../shared/repositories/comment_repository.dart';
import '../controller/overlap_provider.dart';
import '../widget/split_highlight_widget.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;

// ─── 네비게이션 데이터 ────────────────────────────────────────────────────

class SentenceDetailExtra {
  final String sentenceContent;
  final String bookTitle;
  final String bookAuthor;
  final int? page;
  final String? collectorUsername; // 원 수집자 (표시명)
  final String? collectorUserHandle; // 원 수집자 @핸들 (동명이인 구분용)
  final String? collectorUserId; // 원 수집자 id (프로필 이동용)
  final String? collectorThought; // 원 수집자의 생각
  final String? sentenceId; // 실데이터 댓글 연결용 (Supabase sentences.id)
  final String? overlapCommonPhrase;
  final HighlightRange? overlapHighlight;
  final String? bookId;
  final String? globalBookId;

  const SentenceDetailExtra({
    required this.sentenceContent,
    required this.bookTitle,
    required this.bookAuthor,
    this.page,
    this.collectorUsername,
    this.collectorUserHandle,
    this.collectorUserId,
    this.collectorThought,
    this.sentenceId,
    this.overlapCommonPhrase,
    this.overlapHighlight,
    this.bookId,
    this.globalBookId,
  });

  bool get isOverlapGroup =>
      overlapCommonPhrase != null && overlapCommonPhrase!.trim().isNotEmpty;
}

// ─── 내부 모델 ────────────────────────────────────────────────────────────

class _ReaderThought {
  final String? id; // 실데이터 댓글 id (mock이면 null)
  final String? userId; // 작성자 id (프로필 이동용)
  final String username;
  final String? handle; // @아이디 (동명이인 구분용)
  final String thought;
  final DateTime createdAt;
  final int empathyCount; // 내 좋아요를 제외한 수 (표시 = empathyCount + isLiked)
  bool isLiked;

  _ReaderThought({
    this.id,
    this.userId,
    required this.username,
    this.handle,
    required this.thought,
    required this.createdAt,
    this.empathyCount = 0,
    this.isLiked = false,
  });
}

// ─── 목업 데이터 ──────────────────────────────────────────────────────────

List<_ReaderThought> _buildMockThoughts() => [
  _ReaderThought(
    username: 'reader_jin',
    thought: '거부의 시작이 꿈이라는 건, 의지가 아닌 무의식의 선택이라는 뜻. 영혜의 저항은 논리가 아니라 본능에서 왔다.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    empathyCount: 42,
  ),
  _ReaderThought(
    username: 'bookworm_su',
    thought: '꿈이 현실을 바꾸는 순간. 우리도 설명할 수 없는 감각으로 삶을 바꾼 적이 있지 않나.',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    empathyCount: 28,
    isLiked: true,
  ),
  _ReaderThought(
    username: 'midnight_books',
    thought: '"꿈 때문에"라는 짧은 이유가 오히려 강렬해요. 이유를 길게 설명하지 않는 게 영혜의 방식이다.',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    empathyCount: 56,
  ),
  _ReaderThought(
    username: 'seoulreader',
    thought: '채식이 곧 저항이고, 꿈이 곧 각성이다. 한강은 이 한 문장에 소설 전체를 압축했다.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    empathyCount: 91,
  ),
  _ReaderThought(
    username: 'hesse_lover',
    thought: '데미안에서 "새는 알에서 나오려고 투쟁한다"와 같은 결의 문장. 각성은 항상 고통을 수반한다.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    empathyCount: 34,
  ),
  _ReaderThought(
    username: 'leafy_reader',
    thought: '이 문장을 처음 읽었을 때 "왜?"라고 물었다. 마지막에 다시 읽었을 때 더 이상 묻지 않았다.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    empathyCount: 67,
  ),
];

// ─── 메인 스크린 ──────────────────────────────────────────────────────────

class SentenceDetailScreen extends ConsumerStatefulWidget {
  final SentenceDetailExtra data;

  const SentenceDetailScreen({super.key, required this.data});

  @override
  ConsumerState<SentenceDetailScreen> createState() =>
      _SentenceDetailScreenState();
}

class _SentenceDetailScreenState extends ConsumerState<SentenceDetailScreen> {
  late final List<_ReaderThought> _thoughts;
  final _myThoughtController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _thoughts = kUseMock ? _buildMockThoughts() : [];
    if (!kUseMock && widget.data.sentenceId != null) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _myThoughtController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 실데이터: 문장 댓글을 불러와 _thoughts에 매핑.
  /// likeCount는 내 좋아요를 제외한 값으로 저장해 표시 공식(empathyCount + isLiked)을 맞춘다.
  Future<void> _loadComments() async {
    final sid = widget.data.sentenceId;
    if (sid == null) return;
    try {
      final comments = await ref
          .read(commentRepositoryProvider)
          .fetchComments(sid);
      if (!mounted) return;
      setState(() {
        _thoughts
          ..clear()
          ..addAll(
            comments.map(
              (c) => _ReaderThought(
                id: c.id,
                userId: c.userId,
                username: c.username,
                handle: c.handle,
                thought: c.content,
                createdAt: c.createdAt,
                empathyCount: c.likeCount - (c.likedByMe ? 1 : 0),
                isLiked: c.likedByMe,
              ),
            ),
          );
      });
    } catch (_) {
      // 댓글 로딩 실패 시 빈 상태 유지 (화면 핵심은 문장 자체)
    }
  }

  void _submitThought() {
    final text = _myThoughtController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final sid = widget.data.sentenceId;

    // mock 또는 sentenceId 부재: 기존 로컬 동작 유지
    if (kUseMock || sid == null) {
      setState(() {
        _thoughts.insert(
          0,
          _ReaderThought(
            username: '나',
            thought: text,
            createdAt: DateTime.now(),
            empathyCount: 0,
          ),
        );
        _myThoughtController.clear();
      });
      _focusNode.unfocus();
      return;
    }

    // 실데이터: Supabase에 저장
    setState(() => _isSubmitting = true);
    _focusNode.unfocus();
    ref
        .read(commentRepositoryProvider)
        .addComment(sid, text)
        .then((c) {
          if (!mounted) return;
          setState(() {
            _thoughts.insert(
              0,
              _ReaderThought(
                id: c.id,
                username: '나',
                thought: c.content,
                createdAt: c.createdAt,
                empathyCount: 0,
                isLiked: false,
              ),
            );
            _myThoughtController.clear();
            _isSubmitting = false;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('생각을 남기지 못했어요. 다시 시도해주세요'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
  }

  /// 댓글 좋아요 토글 (실데이터는 낙관적 + 실패 시 롤백).
  void _toggleThoughtLike(int index) {
    HapticFeedback.selectionClick();
    final t = _thoughts[index];
    if (kUseMock || t.id == null) {
      setState(() => t.isLiked = !t.isLiked);
      return;
    }
    final nowLiked = !t.isLiked;
    setState(() => t.isLiked = nowLiked);
    final repo = ref.read(commentRepositoryProvider);
    (nowLiked ? repo.likeComment(t.id!) : repo.unlikeComment(t.id!)).catchError(
      (_) {
        if (mounted) setState(() => t.isLiked = !nowLiked);
      },
    );
  }

  /// 생각 작성자의 프로필(서재)로 이동. id 없으면(내 임시 댓글 등) 무시.
  void _openReaderProfile(_ReaderThought t) {
    final uid = t.userId;
    if (uid == null || uid.isEmpty) return;
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeUserProfile,
      extra: UserProfile(
        id: uid,
        username: t.username,
        displayName: t.username,
      ),
    );
  }

  Widget _buildOverlapSection(BuildContext context, SentenceDetailExtra d) {
    if (kUseMock || d.isOverlapGroup) return const SizedBox.shrink();

    final normalizedText = SentenceNormalizer.normalize(d.sentenceContent);
    final overlapsAsync = ref.watch(
      overlappingSentencesProvider(normalizedText),
    );

    return overlapsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (allMatches) {
        // 수집자 본인 문장(= 지금 보고 있는 문장)은 상단 수집자 카드와 중복되므로
        // "다른 독자들의 생각"에서는 제외한다.
        final matches = widget.data.sentenceId != null
            ? allMatches
                  .where((m) => m.sentenceId != widget.data.sentenceId)
                  .toList()
            : allMatches;
        if (matches.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            0,
            AppTheme.screenPadding,
            AppTheme.spaceLG,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '같은 문장, 다른 생각',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${matches.length}명이 이 문장을 함께 수집했어요',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ),
              SplitHighlightWidget(
                anchorText: d.sentenceContent,
                collectorUsername: d.collectorUsername ?? '나',
                collectorUserHandle: d.collectorUserHandle,
                collectorUserId: d.collectorUserId,
                collectorThought: d.collectorThought,
                matches: matches,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final groupMatches = d.isOverlapGroup && !kUseMock
        ? ref
                  .watch(
                    overlapGroupProvider(
                      OverlapGroupQuery(
                        commonPhrase: d.overlapCommonPhrase!,
                        globalBookId: d.globalBookId,
                        bookId: d.bookId,
                      ),
                    ),
                  )
                  .valueOrNull ??
              const <OverlapMatch>[]
        : const <OverlapMatch>[];
    final recordThoughts = groupMatches
        .where((match) => match.thought?.trim().isNotEmpty == true)
        .map(
          (match) => _ReaderThought(
            userId: match.userId,
            username: match.displayName ?? match.username,
            handle: match.username,
            thought: match.thought!.trim(),
            createdAt: match.createdAt,
          ),
        )
        .toList();
    final collectorThought = d.collectorThought?.trim();
    if (d.isOverlapGroup &&
        collectorThought != null &&
        collectorThought.isNotEmpty &&
        !recordThoughts.any(
          (thought) =>
              thought.userId == d.collectorUserId &&
              thought.thought == collectorThought,
        )) {
      recordThoughts.insert(
        0,
        _ReaderThought(
          userId: d.collectorUserId,
          username: d.collectorUsername ?? '독자',
          handle: d.collectorUserHandle,
          thought: collectorThought,
          createdAt: DateTime.now(),
        ),
      );
    }
    final visibleThoughts = d.isOverlapGroup
        ? <_ReaderThought>[...recordThoughts, ..._thoughts]
        : _thoughts;
    final thoughtAuthorCount = visibleThoughts
        .map((thought) => thought.userId ?? thought.username)
        .toSet()
        .length;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // ── 스크롤 영역 ──────────────────────────────────
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: topPad)),

                // ── 네비 바 ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      8,
                      AppTheme.screenPadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label: '뒤로 가기',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.pop();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: AppTheme.smoothBox(
                                color: context.appSurface.withValues(
                                  alpha: 0.5,
                                ),
                                radius: AppTheme.radiusSM,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                size: 18,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.bookTitle,
                                style: AppTheme.bodySmall.copyWith(
                                  color: context.appPrimaryAccent,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                d.bookAuthor,
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 문장 히어로 ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.space2XL,
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 페이지 번호
                        if (d.page != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: AppTheme.smoothPill(
                                color: AppTheme.primary.withValues(alpha: 0.25),
                              ),
                              child: Text(
                                'p.${d.page}',
                                style: AppTheme.captionLarge.copyWith(
                                  color: context.appPrimaryAccent,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),

                        // 원문 인용
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.spaceLG),
                          decoration: BoxDecoration(
                            color: context.appCard,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _SentenceHeroText(data: d),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 수집 통계 ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      0,
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: AppTheme.smoothBox(
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                        radius: AppTheme.radiusMD,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 18,
                            color: context.appPrimaryAccent,
                          ),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              style: AppTheme.captionLarge.copyWith(
                                color: context.appTextSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: '$thoughtAuthorCount',
                                  style: AppTheme.captionLarge.copyWith(
                                    color: context.appPrimaryAccent,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const TextSpan(text: '명이 이 문장에 생각을 남겼어요'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 겹문장 섹션 ─────────────────────────────
                SliverToBoxAdapter(child: _buildOverlapSection(context, d)),

                // ── 구분선 ───────────────────────────────────
                // SliverToBoxAdapter(
                //   child: Divider(
                //     height: 1,
                //     color: context.appBorder,
                //     indent: AppTheme.screenPadding,
                //     endIndent: AppTheme.screenPadding,
                //   ),
                // ),

                // ── 다른 독자들의 생각 헤더 ───────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                      AppTheme.screenPadding,
                      AppTheme.spaceMD,
                    ),
                    child: Text(
                      '다른 독자들의 생각',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ),

                // ── 생각 목록 ────────────────────────────────
                if (visibleThoughts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '아직 남겨진 생각이 없어요\n첫 번째 생각을 남겨보세요!',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMedium.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.screenPadding,
                    ),
                    sliver: SliverList.separated(
                      itemCount: visibleThoughts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTheme.spaceMD),
                      itemBuilder: (context, index) {
                        final recordThoughtCount = d.isOverlapGroup
                            ? visibleThoughts.length - _thoughts.length
                            : 0;
                        final commentIndex = index - recordThoughtCount;
                        return _ThoughtCard(
                          thought: visibleThoughts[index],
                          formatTime: time_fmt.formatRelative,
                          onToggleLike: commentIndex >= 0
                              ? () => _toggleThoughtLike(commentIndex)
                              : null,
                          onOpenProfile: () =>
                              _openReaderProfile(visibleThoughts[index]),
                        );
                      },
                    ),
                  ),

                // ── 하단 여백 ────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // ── 입력 바 (하단 고정) ──────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              10,
              AppTheme.screenPadding,
              bottomPad + 10,
            ),
            decoration: BoxDecoration(color: context.appBg),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: AppTheme.smoothBox(
                      color: context.appCard,
                      radius: 10,
                      side: BorderSide.none,
                    ),
                    child: TextField(
                      controller: _myThoughtController,
                      focusNode: _focusNode,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '이 문장에 대한 나의 생각...',
                        hintStyle: AppTheme.bodySmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitThought(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: '생각 남기기',
                  button: true,
                  child: GestureDetector(
                    onTap: _submitThought,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        gradient: context.appReadingGradient,
                        radius: 10,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceHeroText extends StatelessWidget {
  final SentenceDetailExtra data;

  const _SentenceHeroText({required this.data});

  @override
  Widget build(BuildContext context) {
    final style = AppTheme.headingSmall.copyWith(
      fontStyle: FontStyle.italic,
      color: context.appTextPrimary,
      height: 1.7,
      fontWeight: FontWeight.w400,
    );
    final highlight = data.overlapHighlight;
    final content = data.sentenceContent;
    final hasHighlight =
        highlight != null &&
        highlight.start >= 0 &&
        highlight.end > highlight.start &&
        highlight.end <= content.length;

    if (!hasHighlight) return Text('"$content"', style: style);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '"${content.substring(0, highlight.start)}'),
          TextSpan(
            text: content.substring(highlight.start, highlight.end),
            style: style.copyWith(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: '${content.substring(highlight.end)}"'),
        ],
      ),
    );
  }
}

// ─── 생각 카드 ────────────────────────────────────────────────────────────

class _ThoughtCard extends StatelessWidget {
  final _ReaderThought thought;
  final String Function(DateTime) formatTime;
  final VoidCallback? onToggleLike;
  final VoidCallback onOpenProfile;

  const _ThoughtCard({
    required this.thought,
    required this.formatTime,
    required this.onToggleLike,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final t = thought;
    final tappable = t.userId != null && t.userId!.isNotEmpty;

    return GestureDetector(
      onTap: tappable ? onOpenProfile : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusLG,
          side: BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 유저 정보 + 시간 ────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: context.appPrimaryAccent.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    t.username[0].toUpperCase(),
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodySmall.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (t.handle != null &&
                          t.handle!.isNotEmpty &&
                          t.handle != t.username)
                        Text(
                          '@${t.handle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (tappable)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.appTextTertiary,
                    ),
                  ),
                Text(
                  formatTime(t.createdAt),
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 생각 내용 ──────────────────────────────────
            Text(
              t.thought,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
                height: 1.6,
              ),
            ),
            if (onToggleLike != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onToggleLike,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 16,
                      color: t.isLiked
                          ? AppTheme.empathyColor
                          : context.appTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${t.empathyCount + (t.isLiked ? 1 : 0)}',
                      style: AppTheme.captionLarge.copyWith(
                        color: t.isLiked
                            ? AppTheme.empathyColor
                            : context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
