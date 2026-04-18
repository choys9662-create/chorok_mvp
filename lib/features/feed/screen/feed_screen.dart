import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/overlap_group.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/utils/overlap_detector.dart';

/// 피드 스크린: 소식(소셜 활동) & 발견(문장 탐색)
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

enum _FeedFilter { latest, popular, overlap }

// ─── 상태 ──────────────────────────────────────────────────────────────
class _FeedScreenState extends ConsumerState<FeedScreen> {
  _FeedFilter _filter = _FeedFilter.latest;
  bool _isRefreshing = false;

  // ── 목업 데이터: 겹문장 알고리즘 테스트를 위해 유사한 문장 포함 ────────
  List<FeedSentence> get _sentences => [
    FeedSentence(
      id: '1',
      content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      username: 'reader_jin',
      savedAt: DateTime.now().subtract(const Duration(minutes: 23)),
      empathyCount: 42,
    ),
    FeedSentence(
      id: '6',
      content: '나는 채식주의자가 되기로 했다. 꿈 때문에. 어떤 꿈이었을까.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      username: 'leafy_reader',
      savedAt: DateTime.now().subtract(const Duration(minutes: 45)),
      empathyCount: 28,
    ),
    FeedSentence(
      id: '7',
      content: '채식주의자가 되기로 했다... 꿈 때문에',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      username: 'green_pages',
      savedAt: DateTime.now().subtract(const Duration(hours: 2)),
      empathyCount: 15,
    ),
    FeedSentence(
      id: '2',
      content: '사람이 사람을 사랑한다는 것은 서로의 상처를 보듬는 일이다.',
      bookTitle: '82년생 김지영',
      bookAuthor: '조남주',
      username: 'bookworm_su',
      savedAt: DateTime.now().subtract(const Duration(hours: 1)),
      empathyCount: 87,
      isLiked: true,
    ),
    FeedSentence(
      id: '3',
      content: '나는 괴물이 아니에요. 그냥 달라요.',
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      username: 'seoulreader',
      savedAt: DateTime.now().subtract(const Duration(hours: 3)),
      empathyCount: 156,
    ),
    FeedSentence(
      id: '8',
      content: '나는 괴물이 아니에요. 그냥 달라요. 그뿐이에요.',
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      username: 'midnight_books',
      savedAt: DateTime.now().subtract(const Duration(hours: 4)),
      empathyCount: 34,
    ),
    FeedSentence(
      id: '4',
      content: '우리는 모두 서로의 별빛을 먹고 산다.',
      bookTitle: '밤을 걷는 선비',
      bookAuthor: '이지운',
      username: 'midnight_books',
      savedAt: DateTime.now().subtract(const Duration(hours: 5)),
      empathyCount: 23,
    ),
    FeedSentence(
      id: '5',
      content: '책은 단지 읽히는 것이 아니라, 느껴지는 것이다.',
      bookTitle: '독서의 기쁨',
      bookAuthor: '헤르만 헤세',
      username: 'hesse_lover',
      savedAt: DateTime.now().subtract(const Duration(hours: 8)),
      empathyCount: 64,
    ),
  ];

  // ── 겹문장 그룹 (OverlapDetector 알고리즘으로 동적 계산) ────────────
  List<OverlapGroup> get _overlapGroups {
    final entries = _sentences
        .map((s) => SentenceEntry(
              id: s.id,
              content: s.content,
              username: s.username,
              bookTitle: s.bookTitle,
            ))
        .toList();
    return OverlapDetector.findGroups(entries);
  }

  // ── 겹문장에 속한 문장 ID (개별 카드에서 겹문장 표시용) ────────────
  Set<String> get _overlapSentenceIds {
    final ids = <String>{};
    for (final group in _overlapGroups) {
      for (final m in group.members) {
        ids.add(m.sentenceId);
      }
    }
    return ids;
  }

  List<FeedSentence> get _filteredSentences {
    final all = _sentences;
    switch (_filter) {
      case _FeedFilter.latest:
        return all;
      case _FeedFilter.popular:
        return [...all]..sort(
            (a, b) => b.empathyCount.compareTo(a.empathyCount));
      case _FeedFilter.overlap:
        return []; // 겹문장 탭은 그룹 뷰 사용
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSentences;
    final groups = _overlapGroups;
    final overlapIds = _overlapSentenceIds;
    final scrollCtrl = ref.read(tabScrollControllersProvider)[1];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── 헤더 ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding, 20,
                AppTheme.screenPadding, 12,
              ),
              child: Row(
                children: [
                  if (context.canPop()) ...[
                    Semantics(
                      label: '뒤로 가기',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.pop();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: context.appCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.appBorder),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  Text(
                    '피드',
                    style: AppTheme.headingLarge.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_isRefreshing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appPrimaryAccent,
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: context.appBorder),

            // ─── 필터 칩 ──────────────────────────────────────
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.screenPadding, vertical: 8),
                children: [
                  _FeedFilterChip(
                    label: '최신순',
                    isSelected: _filter == _FeedFilter.latest,
                    onTap: () => setState(() => _filter = _FeedFilter.latest),
                  ),
                  const SizedBox(width: 8),
                  _FeedFilterChip(
                    label: '인기순',
                    isSelected: _filter == _FeedFilter.popular,
                    onTap: () =>
                        setState(() => _filter = _FeedFilter.popular),
                  ),
                  const SizedBox(width: 8),
                  _FeedFilterChip(
                    label: '겹문장 ${groups.isNotEmpty ? "(${groups.length})" : ""}',
                    isSelected: _filter == _FeedFilter.overlap,
                    onTap: () =>
                        setState(() => _filter = _FeedFilter.overlap),
                  ),
                ],
              ),
            ),

            // ─── 콘텐츠 ──────────────────────────────────────
            Expanded(
              child: _filter == _FeedFilter.overlap
                  ? _buildOverlapView(groups, scrollCtrl)
                  : filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: context.appPrimaryAccent,
                          backgroundColor: context.appCard,
                          onRefresh: _onRefresh,
                          child: _SentenceList(
                            sentences: filtered,
                            overlapIds: overlapIds,
                            controller: scrollCtrl,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlapView(List<OverlapGroup> groups, ScrollController ctrl) {
    if (groups.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: context.appPrimaryAccent,
      backgroundColor: context.appCard,
      onRefresh: _onRefresh,
      child: ListView.separated(
        controller: ctrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: AppTheme.spaceMD,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppTheme.spaceMD),
        itemBuilder: (_, i) => _OverlapGroupCard(group: groups[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.format_quote_rounded,
              size: 48, color: context.appTextTertiary),
          const SizedBox(height: 12),
          Text(
            '겹문장이 아직 없어요',
            style: AppTheme.bodyMedium
                .copyWith(color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── 필터 칩 ─────────────────────────────────────────────────────────────
class _FeedFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: AppTheme.smoothPill(
          color: isSelected ? AppTheme.accent : context.appCard,
          side: BorderSide(
            color: isSelected ? AppTheme.accent : context.appBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.captionLarge.copyWith(
            color:
                isSelected ? context.appSurface : context.appTextSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── 문장 목록 (최신/인기 필터용) ─────────────────────────────────────────
class _SentenceList extends StatelessWidget {
  final List<FeedSentence> sentences;
  final Set<String> overlapIds;
  final ScrollController? controller;

  const _SentenceList({
    required this.sentences,
    required this.overlapIds,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spaceMD,
      ),
      itemCount: sentences.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppTheme.spaceMD),
      itemBuilder: (_, i) => _SentenceCard(
        sentence: sentences[i],
        isOverlap: overlapIds.contains(sentences[i].id),
      ),
    );
  }
}

class _SentenceCard extends StatefulWidget {
  final FeedSentence sentence;
  final bool isOverlap;

  const _SentenceCard({
    required this.sentence,
    required this.isOverlap,
  });

  @override
  State<_SentenceCard> createState() => _SentenceCardState();
}

class _SentenceCardState extends State<_SentenceCard> {
  late bool _isLiked;
  late int _empathyCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.sentence.isLiked;
    _empathyCount = widget.sentence.empathyCount;
  }

  void _toggleLike() => setState(() {
        _isLiked = !_isLiked;
        _empathyCount += _isLiked ? 1 : -1;
      });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sentence;
    final overlap = widget.isOverlap;

    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 16,
        side: BorderSide(
          color: overlap
              ? context.appPrimaryAccent.withValues(alpha: 0.35)
              : context.appBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 겹문장 배너 (동적 감지)
          if (overlap)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: ShapeDecoration(
                color: AppTheme.primary.withValues(alpha: 0.4),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.only(
                    topLeft: SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.6),
                    topRight: SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.6),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.join_inner_rounded,
                      size: 16, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Text(
                    '겹문장 감지됨',
                    style: AppTheme.captionLarge
                        .copyWith(color: AppTheme.accent),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 책 정보
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          size: 14, color: context.appPrimaryAccent),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.bookTitle,
                            style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.appPrimaryAccent,
                            ),
                          ),
                          Text(
                            s.bookAuthor,
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(s.savedAt),
                      style: AppTheme.captionSmall
                          .copyWith(color: context.appTextTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // 문장 내용
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: context.appCardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: overlap
                            ? context.appPrimaryAccent
                            : context.appBorder,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    '"${s.content}"',
                    style: AppTheme.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: context.appTextPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // 유저 + 공감
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.3),
                      child: Text(
                        s.username[0].toUpperCase(),
                        style: AppTheme.captionSmall
                            .copyWith(color: context.appPrimaryAccent),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.username,
                      style: AppTheme.captionLarge
                          .copyWith(color: context.appTextSecondary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            _isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 16,
                            color: _isLiked
                                ? const Color(0xFFFF6B6B)
                                : context.appTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_empathyCount',
                            style: AppTheme.captionLarge.copyWith(
                              color: _isLiked
                                  ? const Color(0xFFFF6B6B)
                                  : context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              '공유 기능은 곧 지원돼요',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: context.appCardElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                              side: BorderSide(
                                color: context.appPrimaryAccent.withValues(alpha: 0.4),
                              ),
                            ),
                            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.share_outlined,
                            size: 16, color: context.appTextTertiary),
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

// ─── 겹문장 그룹 카드 (핵심 UI) ──────────────────────────────────────────

class _OverlapGroupCard extends StatefulWidget {
  final OverlapGroup group;

  const _OverlapGroupCard({required this.group});

  @override
  State<_OverlapGroupCard> createState() => _OverlapGroupCardState();
}

class _OverlapGroupCardState extends State<_OverlapGroupCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final base = g.baseMember;

    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(
          color: context.appPrimaryAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 겹문장 헤더 배너 ──────────────────────────────────
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.only(
                  topLeft: SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.6),
                  topRight: SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.6),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.join_inner_rounded,
                    size: 16, color: AppTheme.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '겹문장 · ${g.memberCount}명이 같은 문장을 수집했어요',
                    style: AppTheme.captionLarge
                        .copyWith(color: AppTheme.accent),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 책 정보 ──────────────────────────────────────
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          size: 14, color: context.appPrimaryAccent),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: Text(
                        base.bookTitle,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // ── 공통 문구 (하이라이트) ───────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: context.appCardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: context.appPrimaryAccent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '공통 문구',
                        style: AppTheme.captionSmall.copyWith(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${g.commonPhrase}"',
                        style: AppTheme.bodyMedium.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.appTextPrimary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // ── 수집자 목록 토글 ─────────────────────────────
                Semantics(
                  label:
                      '수집자 목록 ${_isExpanded ? "접기" : "펼치기"}',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          // 수집자 아바타 겹침 표시
                          SizedBox(
                            width: 24.0 + (g.memberCount - 1) * 16.0,
                            height: 24,
                            child: Stack(
                              children: [
                                for (int i = 0;
                                    i < g.memberCount && i < 4;
                                    i++)
                                  Positioned(
                                    left: i * 16.0,
                                    child: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: AppTheme.primary
                                          .withValues(alpha: 0.4),
                                      child: Text(
                                        g.members[i].username[0]
                                            .toUpperCase(),
                                        style:
                                            AppTheme.captionSmall.copyWith(
                                          color: context.appPrimaryAccent,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${g.memberCount}명의 기록',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 확장된 멤버 목록 (하이라이트 포함) ─────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.cardPaddingMD,
                      0,
                      AppTheme.cardPaddingMD,
                      AppTheme.cardPaddingMD,
                    ),
                    child: Column(
                      children: [
                        Divider(
                            height: 1, color: context.appBorder),
                        const SizedBox(height: 12),
                        ...g.members.map((m) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppTheme.spaceSM),
                              child: _OverlapMemberTile(
                                member: m,
                                commonPhrase: g.commonPhrase,
                              ),
                            )),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── 겹문장 그룹 내 개별 멤버 타일 ──────────────────────────────────────

class _OverlapMemberTile extends StatelessWidget {
  final OverlapMember member;
  final String commonPhrase;

  const _OverlapMemberTile({
    required this.member,
    required this.commonPhrase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: AppTheme.radiusMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 유저 정보
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                child: Text(
                  member.username[0].toUpperCase(),
                  style: AppTheme.captionSmall
                      .copyWith(color: context.appPrimaryAccent),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  member.username,
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: AppTheme.smoothPill(
                  color: context.appPrimaryAccent.withValues(alpha: 0.12),
                ),
                child: Text(
                  '${(member.overlapRatio * 100).round()}% 일치',
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 하이라이트된 문장
          _HighlightedText(
            text: member.content,
            highlights: member.highlights,
          ),
        ],
      ),
    );
  }
}

// ─── 하이라이트 텍스트 위젯 ──────────────────────────────────────────────
/// 겹문장의 공통 구간을 시각적으로 강조하는 RichText 위젯
class _HighlightedText extends StatelessWidget {
  final String text;
  final List<HighlightRange> highlights;

  const _HighlightedText({
    required this.text,
    required this.highlights,
  });

  @override
  Widget build(BuildContext context) {
    if (highlights.isEmpty || text.isEmpty) {
      return Text(
        '"$text"',
        style: AppTheme.bodySmall.copyWith(
          fontStyle: FontStyle.italic,
          color: context.appTextPrimary,
          height: 1.5,
        ),
      );
    }

    // 하이라이트 구간을 정렬하고 텍스트 범위 내로 클램프
    final sorted = highlights
        .map((h) => HighlightRange(
              h.start.clamp(0, text.length),
              h.end.clamp(0, text.length),
            ))
        .where((h) => h.start < h.end)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final spans = <InlineSpan>[];
    spans.add(const TextSpan(text: '"'));

    int lastEnd = 0;
    final baseStyle = AppTheme.bodySmall.copyWith(
      fontStyle: FontStyle.italic,
      color: context.appTextPrimary,
      height: 1.5,
    );
    final highlightStyle = baseStyle.copyWith(
      backgroundColor: context.appPrimaryAccent.withValues(alpha: 0.15),
      color: context.appPrimaryAccent,
      fontWeight: FontWeight.w600,
    );

    for (final hl in sorted) {
      if (hl.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, hl.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(hl.start, hl.end),
        style: highlightStyle,
      ));
      lastEnd = hl.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
    spans.add(TextSpan(text: '"', style: baseStyle));

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }
}
