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
import '../../../shared/widgets/book_cover.dart';
import '../../search/model/aladin_book.dart';
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
  final String? coverUrl;
  final String? isbn13;

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
    this.coverUrl,
    this.isbn13,
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
  final List<_ReaderThought> replies; // 1단계 답글 (최상위 생각에만 채워짐)
  final String? recordedSentence; // 겹문장 기록 카드가 실제로 저장한 전체 문장

  _ReaderThought({
    this.id,
    this.userId,
    required this.username,
    this.handle,
    required this.thought,
    required this.createdAt,
    this.empathyCount = 0,
    this.isLiked = false,
    List<_ReaderThought>? replies,
    this.recordedSentence,
  }) : replies = replies ?? [];
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
  _ReaderThought? _replyingTo; // 답글 대상 (null이면 최상위 댓글 작성)

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
                replies: c.replies
                    .map(
                      (r) => _ReaderThought(
                        id: r.id,
                        userId: r.userId,
                        username: r.username,
                        handle: r.handle,
                        thought: r.content,
                        createdAt: r.createdAt,
                        empathyCount: r.likeCount - (r.likedByMe ? 1 : 0),
                        isLiked: r.likedByMe,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
      });
    } catch (_) {
      // 댓글 로딩 실패 시 빈 상태 유지 (화면 핵심은 문장 자체)
    }
  }

  /// 특정 생각에 답글 모드 진입 — 입력 바로 포커스 이동.
  void _startReply(_ReaderThought target) {
    HapticFeedback.selectionClick();
    setState(() => _replyingTo = target);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  void _submitThought() {
    final text = _myThoughtController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final sid = widget.data.sentenceId;
    final parent = _replyingTo;

    // mock 또는 sentenceId 부재: 기존 로컬 동작 유지
    if (kUseMock || sid == null) {
      setState(() {
        final created = _ReaderThought(
          username: '나',
          thought: text,
          createdAt: DateTime.now(),
          empathyCount: 0,
        );
        if (parent != null) {
          parent.replies.add(created); // 답글은 부모 아래 시간순(끝)에 추가
        } else {
          _thoughts.insert(0, created);
        }
        _myThoughtController.clear();
        _replyingTo = null;
      });
      _focusNode.unfocus();
      return;
    }

    // 실데이터: Supabase에 저장
    setState(() => _isSubmitting = true);
    _focusNode.unfocus();
    ref
        .read(commentRepositoryProvider)
        .addComment(sid, text, parentCommentId: parent?.id)
        .then((c) {
          if (!mounted) return;
          setState(() {
            final created = _ReaderThought(
              id: c.id,
              username: '나',
              thought: c.content,
              createdAt: c.createdAt,
              empathyCount: 0,
              isLiked: false,
            );
            if (parent != null) {
              parent.replies.add(created);
            } else {
              _thoughts.insert(0, created);
            }
            _myThoughtController.clear();
            _isSubmitting = false;
            _replyingTo = null;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                parent != null
                    ? '답글을 남기지 못했어요. 다시 시도해주세요'
                    : '생각을 남기지 못했어요. 다시 시도해주세요',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
  }

  /// 댓글·답글 좋아요 토글 (실데이터는 낙관적 + 실패 시 롤백).
  void _toggleThoughtLike(_ReaderThought t) {
    HapticFeedback.selectionClick();
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

  void _openBookInfo() {
    final d = widget.data;
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeBookInfo,
      extra: AladinBook(
        title: d.bookTitle,
        author: d.bookAuthor,
        publisher: '',
        coverUrl: d.coverUrl,
        isbn13: d.isbn13,
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
            recordedSentence: match.content,
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
          recordedSentence: d.sentenceContent,
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
                          child: Semantics(
                            label: '${d.bookTitle} 책 정보 보기',
                            button: true,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _openBookInfo,
                              child: Row(
                                children: [
                                  BookCover(
                                    coverUrl: d.coverUrl,
                                    gradientIndex:
                                        d.bookTitle.hashCode.abs() %
                                        AppTheme.coverGradients.length,
                                    width: 38,
                                    height: 52,
                                    radius: 7,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        const SizedBox(height: 2),
                                        Text(
                                          d.bookAuthor,
                                          style: AppTheme.captionSmall.copyWith(
                                            color: context.appTextTertiary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 22,
                                    color: context.appTextTertiary,
                                  ),
                                ],
                              ),
                            ),
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

                        // 수집자 본인 생각 — 문장과 함께 노출 (겹문장 그룹은
                        // 아래 목록에서 따로 보여주므로 여기선 제외).
                        if (!d.isOverlapGroup &&
                            (collectorThought?.isNotEmpty ?? false)) ...[
                          const SizedBox(height: 12),
                          _CollectorThought(
                            username: d.collectorUsername ?? '독자',
                            thought: collectorThought!,
                          ),
                        ],
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
                        // 겹문장 합성 카드(recordThoughts)는 댓글 row가 아니라
                        // 좋아요·답글이 없다. 실제 댓글에만 상호작용을 붙인다.
                        final isRealComment = index >= recordThoughtCount;
                        final t = visibleThoughts[index];
                        final isRecordedThought =
                            !isRealComment &&
                            t.recordedSentence?.trim().isNotEmpty == true;
                        return _ThoughtCard(
                          thought: t,
                          formatTime: time_fmt.formatRelative,
                          onToggleLike: isRealComment
                              ? () => _toggleThoughtLike(t)
                              : null,
                          onReply: isRealComment ? () => _startReply(t) : null,
                          onToggleReplyLike: _toggleThoughtLike,
                          onOpenProfile: isRecordedThought
                              ? null
                              : () => _openReaderProfile(t),
                          onOpenRecordedSentence: isRecordedThought
                              ? () => showRecordedSentenceDetails(
                                  context,
                                  anchorText: d.overlapCommonPhrase!,
                                  recordedText: t.recordedSentence!,
                                  username: t.username,
                                  thought: t.thought,
                                )
                              : null,
                          onOpenReplyProfile: _openReaderProfile,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── 답글 모드 배너 ──────────────────────────
                if (_replyingTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 15,
                          color: context.appPrimaryAccent,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_replyingTo!.username}님에게 답글 남기는 중',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _cancelReply,
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
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
                            hintText: _replyingTo != null
                                ? '${_replyingTo!.username}님에게 답글...'
                                : '이 문장에 대한 나의 생각...',
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 문장을 수집한 사람 본인의 생각. 히어로 문장 바로 아래에 함께 노출된다.
class _CollectorThought extends StatelessWidget {
  final String username;
  final String thought;

  const _CollectorThought({required this.username, required this.thought});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLG),
      decoration: AppTheme.smoothBox(
        color: context.appPrimaryAccent.withValues(alpha: 0.06),
        radius: 10,
        side: BorderSide(
          color: context.appPrimaryAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: context.appPrimaryAccent,
              ),
              const SizedBox(width: 6),
              Text(
                '$username의 생각',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            thought,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary,
              height: 1.6,
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
  final VoidCallback? onReply;
  final void Function(_ReaderThought) onToggleReplyLike;
  final void Function(_ReaderThought) onOpenReplyProfile;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenRecordedSentence;

  const _ThoughtCard({
    required this.thought,
    required this.formatTime,
    required this.onToggleLike,
    required this.onReply,
    required this.onToggleReplyLike,
    required this.onOpenReplyProfile,
    required this.onOpenProfile,
    required this.onOpenRecordedSentence,
  });

  @override
  Widget build(BuildContext context) {
    final t = thought;
    final profileTappable =
        onOpenProfile != null && t.userId != null && t.userId!.isNotEmpty;

    return GestureDetector(
      key: onOpenRecordedSentence == null
          ? null
          : ValueKey('recorded-thought-card-${t.username}'),
      onTap: onOpenRecordedSentence,
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
            // ── 유저 정보 + 생각 ───────────────────────────
            GestureDetector(
              onTap: profileTappable ? onOpenProfile : null,
              behavior: HitTestBehavior.opaque,
              child: _ThoughtContent(
                thought: t,
                formatTime: formatTime,
                avatarRadius: 14,
                showChevron: profileTappable || onOpenRecordedSentence != null,
              ),
            ),

            // ── 액션 행: 좋아요 + 답글 ───────────────────────
            if (onToggleLike != null || onReply != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onToggleLike != null)
                    _LikeToggle(thought: t, onTap: onToggleLike!),
                  if (onToggleLike != null && onReply != null)
                    const SizedBox(width: 18),
                  if (onReply != null)
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 15,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '답글',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            // ── 답글 목록 (1단계) ────────────────────────────
            if (t.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 8),
                child: Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: context.appBorder, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in t.replies)
                        Padding(
                          padding: EdgeInsets.only(
                            top: r == t.replies.first ? 0 : 14,
                          ),
                          child: GestureDetector(
                            onTap: (r.userId != null && r.userId!.isNotEmpty)
                                ? () => onOpenReplyProfile(r)
                                : null,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ThoughtContent(
                                  thought: r,
                                  formatTime: formatTime,
                                  avatarRadius: 11,
                                  showChevron:
                                      r.userId != null && r.userId!.isNotEmpty,
                                ),
                                if (r.id != null) ...[
                                  const SizedBox(height: 8),
                                  _LikeToggle(
                                    thought: r,
                                    onTap: () => onToggleReplyLike(r),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 생각/답글의 헤더(아바타·이름·시간) + 본문 텍스트. 카드와 답글에서 공용.
class _ThoughtContent extends StatelessWidget {
  final _ReaderThought thought;
  final String Function(DateTime) formatTime;
  final double avatarRadius;
  final bool showChevron;

  const _ThoughtContent({
    required this.thought,
    required this.formatTime,
    required this.avatarRadius,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final t = thought;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: context.appPrimaryAccent.withValues(alpha: 0.12),
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
            if (showChevron)
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
        Text(
          t.thought,
          style: AppTheme.bodyMedium.copyWith(
            color: context.appTextPrimary,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

/// 공감(좋아요) 토글 버튼 — 하트 + 카운트.
class _LikeToggle extends StatelessWidget {
  final _ReaderThought thought;
  final VoidCallback onTap;

  const _LikeToggle({required this.thought, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = thought;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            t.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color: t.isLiked ? AppTheme.empathyColor : context.appTextTertiary,
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
    );
  }
}
