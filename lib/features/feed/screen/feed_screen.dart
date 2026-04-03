import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';

/// 피드 스크린: 소식(소셜 활동) & 발견(문장 탐색)
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

enum _FeedFilter { latest, popular, overlap }

// ─── 상태 ──────────────────────────────────────────────────────────────
class _FeedScreenState extends State<FeedScreen> {
  _FeedFilter _filter = _FeedFilter.latest;
  bool _isRefreshing = false;

  // getter로 선언해 매번 현재 시각 기준으로 상대시간이 계산되도록 함
  List<FeedSentence> get _sentences => [
    FeedSentence(
      id: '1',
      content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      username: 'reader_jin',
      savedAt: DateTime.now().subtract(const Duration(minutes: 23)),
      empathyCount: 42,
      isOverlap: true,
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
      isOverlap: true,
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

  List<FeedSentence> get _filteredSentences {
    final all = _sentences;
    switch (_filter) {
      case _FeedFilter.latest:
        return all;
      case _FeedFilter.popular:
        return [...all]..sort((a, b) => b.empathyCount.compareTo(a.empathyCount));
      case _FeedFilter.overlap:
        return all.where((s) => s.isOverlap).toList();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    // 향후 API 호출 위치
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSentences;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── 헤더 ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding, 12,
                AppTheme.screenPadding, 12,
              ),
              child: Row(
                children: [
                  Text(
                    '피드',
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (_isRefreshing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.darkBorder),

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
                    onTap: () => setState(() => _filter = _FeedFilter.popular),
                  ),
                  const SizedBox(width: 8),
                  _FeedFilterChip(
                    label: '겹문장',
                    isSelected: _filter == _FeedFilter.overlap,
                    onTap: () => setState(() => _filter = _FeedFilter.overlap),
                  ),
                ],
              ),
            ),

            // ─── 문장 목록 ────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.format_quote_rounded,
                              size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 12),
                          Text('겹문장이 아직 없어요',
                              style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.primaryLight,
                      backgroundColor: AppTheme.darkCard,
                      onRefresh: _onRefresh,
                      child: _SentenceList(sentences: filtered),
                    ),
            ),
          ],
        ),
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
        decoration: AppTheme.smoothBox(
          color: isSelected ? AppTheme.accent : AppTheme.darkCard,
          radius: 20,
          side: BorderSide(
            color: isSelected ? AppTheme.accent : AppTheme.darkBorder,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.captionLarge.copyWith(
            color: isSelected ? AppTheme.darkSurface : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── 문장 목록 ────────────────────────────────────────────────────────
class _SentenceList extends StatelessWidget {
  final List<FeedSentence> sentences;
  const _SentenceList({required this.sentences});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spaceMD,
      ),
      itemCount: sentences.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMD),
      itemBuilder: (_, i) => _SentenceCard(sentence: sentences[i]),
    );
  }
}

class _SentenceCard extends StatefulWidget {
  final FeedSentence sentence;
  const _SentenceCard({required this.sentence});

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

    return Container(
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 16,
        side: BorderSide(
          color: s.isOverlap
              ? AppTheme.primaryLight.withValues(alpha: 0.35)
              : AppTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 겹문장 배너
          if (s.isOverlap)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.join_inner_rounded,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '겹문장 · 3명이 같이 수집했어요',
                    style: AppTheme.captionLarge.copyWith(
                      color: AppTheme.accent,
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
                      child: const Icon(
                        Icons.menu_book_rounded,
                        size: 14,
                        color: AppTheme.primaryLight,
                      ),
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
                              color: AppTheme.primaryLight,
                            ),
                          ),
                          Text(
                            s.bookAuthor,
                            style: AppTheme.captionLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatTime(s.savedAt),
                      style: AppTheme.captionSmall.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // 문장 내용
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(
                        color: s.isOverlap
                            ? AppTheme.primaryLight
                            : AppTheme.darkBorder,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    '"${s.content}"',
                    style: AppTheme.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textPrimary,
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
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                      child: Text(
                        s.username[0].toUpperCase(),
                        style: AppTheme.captionSmall.copyWith(
                          color: AppTheme.primaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.username,
                      style: AppTheme.captionLarge.copyWith(
                        color: AppTheme.textSecondary,
                      ),
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
                                : AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_empathyCount',
                            style: AppTheme.captionLarge.copyWith(
                              color: _isLiked
                                  ? const Color(0xFFFF6B6B)
                                  : AppTheme.textTertiary,
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
                          const SnackBar(
                            content: Text('공유 기능은 곧 지원돼요 🌿'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.share_outlined,
                          size: 16,
                          color: AppTheme.textTertiary,
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
