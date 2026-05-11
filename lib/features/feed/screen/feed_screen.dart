import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/overlap_group.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/utils/overlap_detector.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';
import '../controller/feed_provider.dart';
import 'sentence_detail_screen.dart';


// ─── 트렌딩 책 ───────────────────────────────────────────────────────────────
typedef _TrendingBook = ({
  String title,
  String author,
  String? coverUrl,
  int sentenceCount,
  int gradientIndex,
});

const List<_TrendingBook> _kMockTrendingBooks = [
  (title: '채식주의자', author: '한강', coverUrl: 'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg', sentenceCount: 142, gradientIndex: 0),
  (title: '파친코', author: '이민진', coverUrl: 'https://image.aladin.co.kr/product/29496/39/cover500/s382931339_2.jpg', sentenceCount: 98, gradientIndex: 2),
  (title: '아몬드', author: '손원평', coverUrl: 'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg', sentenceCount: 87, gradientIndex: 4),
  (title: '소년이 온다', author: '한강', coverUrl: 'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg', sentenceCount: 76, gradientIndex: 3),
  (title: '82년생 김지영', author: '조남주', coverUrl: 'https://image.aladin.co.kr/product/9476/48/cover500/8937473135_1.jpg', sentenceCount: 61, gradientIndex: 1),
];

List<_TrendingBook> _trendingFromSentences(List<FeedSentence> sentences) {
  final counts = <String, ({String author, int count})>{};
  for (final s in sentences) {
    final existing = counts[s.bookTitle];
    counts[s.bookTitle] = (
      author: s.bookAuthor,
      count: (existing?.count ?? 0) + 1,
    );
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.count.compareTo(a.value.count));
  return sorted.take(5).toList().asMap().entries.map((e) => (
        title: e.value.key,
        author: e.value.value.author,
        coverUrl: null,
        sentenceCount: e.value.value.count,
        gradientIndex: e.key,
      )).toList();
}

/// 피드 스크린: 소식(소셜 활동) & 발견(문장 탐색)
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

enum _FeedFilter { latest, popular, overlap }

// ─── 목업 문장 (USE_MOCK=true 전용) ──────────────────────────────────────────
List<FeedSentence> _kMockSentences() {
  final now = DateTime.now();
  return [
    FeedSentence(
      id: '1',
      content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      thought: '거부의 시작이 꿈이라는 건, 의지가 아닌 무의식의 선택이라는 뜻. 영혜의 저항은 논리가 아니라 본능에서 왔다.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      coverUrl: 'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg',
      username: 'reader_jin',
      savedAt: now.subtract(const Duration(minutes: 23)),
      empathyCount: 42,
      commentCount: 3,
    ),
    FeedSentence(
      id: '6',
      content: '나는 채식주의자가 되기로 했다. 꿈 때문에. 어떤 꿈이었을까.',
      thought: '꿈이 현실을 바꾸는 순간. 우리도 설명할 수 없는 감각으로 삶을 바꾼 적이 있지 않나.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      coverUrl: 'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg',
      username: 'leafy_reader',
      savedAt: now.subtract(const Duration(minutes: 45)),
      empathyCount: 28,
      commentCount: 1,
    ),
    FeedSentence(
      id: '7',
      content: '채식주의자가 되기로 했다... 꿈 때문에',
      thought: '채식이 곧 저항이고, 꿈이 곧 각성이다.',
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      coverUrl: 'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg',
      username: 'green_pages',
      savedAt: now.subtract(const Duration(hours: 2)),
      empathyCount: 15,
    ),
    FeedSentence(
      id: '2',
      content: '사람이 사람을 사랑한다는 것은 서로의 상처를 보듬는 일이다.',
      thought: '사랑의 정의가 이렇게 아플 수 있다니. 지영이의 상처를 "보듬는" 사람은 결국 아무도 없었다는 게 더 아프다.',
      bookTitle: '82년생 김지영',
      bookAuthor: '조남주',
      coverUrl: 'https://image.aladin.co.kr/product/9476/48/cover500/8937473135_1.jpg',
      username: 'bookworm_su',
      savedAt: now.subtract(const Duration(hours: 1)),
      empathyCount: 87,
      commentCount: 5,
      isLiked: true,
    ),
    FeedSentence(
      id: '3',
      content: '나는 괴물이 아니에요. 그냥 달라요.',
      thought: '"다름"과 "틀림"의 경계에서 선재가 내뱉은 이 한마디가 소설 전체를 관통한다.',
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      coverUrl: 'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg',
      username: 'seoulreader',
      savedAt: now.subtract(const Duration(hours: 3)),
      empathyCount: 156,
      commentCount: 8,
    ),
    FeedSentence(
      id: '4',
      content: '우리는 모두 서로의 별빛을 먹고 산다.',
      thought: '외로움의 반대가 사랑이 아니라 "연결"이라는 걸 이 문장이 증명한다.',
      bookTitle: '밤을 걷는 선비',
      bookAuthor: '이지운',
      coverUrl: 'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg',
      username: 'midnight_books',
      savedAt: now.subtract(const Duration(hours: 5)),
      empathyCount: 23,
    ),
    FeedSentence(
      id: '5',
      content: '책은 단지 읽히는 것이 아니라, 느껴지는 것이다.',
      thought: '헤세가 이 말을 했을 때, 그는 분명 데미안을 쓰면서 자기 자신을 느끼고 있었을 것이다.',
      bookTitle: '독서의 기쁨',
      bookAuthor: '헤르만 헤세',
      coverUrl: 'https://image.aladin.co.kr/product/29496/39/cover500/s382931339_2.jpg',
      username: 'hesse_lover',
      savedAt: now.subtract(const Duration(hours: 8)),
      empathyCount: 64,
      commentCount: 2,
    ),
  ];
}

// ─── 상태 ──────────────────────────────────────────────────────────────
class _FeedScreenState extends ConsumerState<FeedScreen> {
  _FeedFilter _filter = _FeedFilter.latest;
  bool _isRefreshing = false;

  // sentences 참조가 동일하면 overlap/trending 재계산 생략
  List<FeedSentence>? _derivedFromSentences;
  List<OverlapGroup> _cachedGroups = const [];
  Set<String> _cachedOverlapIds = const {};
  List<_TrendingBook> _cachedTrending = const [];

  void _ensureDerived(
    List<FeedSentence> sentences, {
    required List<_TrendingBook>? mockTrending,
  }) {
    if (identical(_derivedFromSentences, sentences)) return;
    _derivedFromSentences = sentences;

    final entries = sentences
        .map((s) => SentenceEntry(
              id: s.id,
              content: s.content,
              username: s.username,
              bookTitle: s.bookTitle,
              coverUrl: s.coverUrl,
            ))
        .toList();
    _cachedGroups = OverlapDetector.findGroups(entries);

    final ids = <String>{};
    for (final group in _cachedGroups) {
      for (final m in group.members) {
        ids.add(m.sentenceId);
      }
    }
    _cachedOverlapIds = ids;

    _cachedTrending = mockTrending ?? _trendingFromSentences(sentences);
  }

  List<FeedSentence> _filtered(List<FeedSentence> all) {
    switch (_filter) {
      case _FeedFilter.latest:
        return all;
      case _FeedFilter.popular:
        return [...all]..sort((a, b) => b.empathyCount.compareTo(a.empathyCount));
      case _FeedFilter.overlap:
        return [];
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    if (!kUseMock) {
      await ref.read(feedProvider.notifier).refresh();
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final sentences = kUseMock
        ? _kMockSentences()
        : (ref.watch(feedProvider).valueOrNull ?? const <FeedSentence>[]);
    _ensureDerived(
      sentences,
      mockTrending: kUseMock ? _kMockTrendingBooks : null,
    );
    final trendingBooks = _cachedTrending;
    final groups = _cachedGroups;
    final overlapIds = _cachedOverlapIds;
    final filtered = _filtered(sentences);
    final scrollCtrl = ref.read(tabScrollControllersProvider)[1];
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: topPad),
          // ─── 헤더 (고정) ──────────────────────────────────
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
            const _ActivityBanner(),
            const SizedBox(height: 10),
            Divider(height: 1, color: context.appBorder),

            // ─── 스크롤 영역 (필터 칩부터 전부) ──────────────
            Expanded(
              child: RefreshIndicator(
                color: context.appPrimaryAccent,
                backgroundColor: context.appCard,
                onRefresh: _onRefresh,
                child: CustomScrollView(
                  controller: scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.screenPadding, vertical: 8),
                          children: [
                            _FeedFilterChip(
                              label: '최신순',
                              isSelected: _filter == _FeedFilter.latest,
                              onTap: () =>
                                  setState(() => _filter = _FeedFilter.latest),
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
                              label:
                                  '겹문장 ${groups.isNotEmpty ? "(${groups.length})" : ""}',
                              isSelected: _filter == _FeedFilter.overlap,
                              onTap: () =>
                                  setState(() => _filter = _FeedFilter.overlap),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_filter != _FeedFilter.overlap) ...[
                      SliverToBoxAdapter(child: _TrendingBooksSection(books: trendingBooks)),
                      SliverToBoxAdapter(
                        child: Divider(height: 1, color: context.appBorder),
                      ),
                    ],
                    if (_filter == _FeedFilter.overlap)
                      groups.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.screenPadding,
                                vertical: AppTheme.spaceMD,
                              ),
                              sliver: SliverList.separated(
                                itemCount: groups.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppTheme.spaceMD),
                                itemBuilder: (_, i) =>
                                    _OverlapGroupCard(group: groups[i]),
                              ),
                            )
                    else
                      filtered.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            )
                          : SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.screenPadding,
                                vertical: AppTheme.spaceMD,
                              ),
                              sliver: SliverList.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: AppTheme.spaceMD),
                                itemBuilder: (_, i) => _SentenceCard(
                                  sentence: filtered[i],
                                  isOverlap:
                                      overlapIds.contains(filtered[i].id),
                                ),
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

// ─── 활동 배너 ────────────────────────────────────────────────────────────────
class _ActivityBanner extends StatelessWidget {
  const _ActivityBanner();

  @override
  Widget build(BuildContext context) {
    final seed = DateTime.now().day;
    final readers = 300 + (seed * 7) % 200;
    final overlaps = 8 + seed % 13;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding, 10,
        AppTheme.screenPadding, 0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusMD,
          side: BorderSide(color: context.appBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: context.appPrimaryAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.appPrimaryAccent.withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: '오늘 $readers명',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: '이 문장을 기록했어요 · '),
                    TextSpan(
                      text: '겹문장 $overlaps건',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w600,
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

// ─── 트렌딩 책 섹션 ───────────────────────────────────────────────────────────
class _TrendingBooksSection extends StatelessWidget {
  final List<_TrendingBook> books;
  const _TrendingBooksSection({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding, 16, AppTheme.screenPadding, 8,
          ),
          child: Text(
            '이번 주 화제의 책',
            style: AppTheme.captionLarge.copyWith(
              color: context.appTextTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            itemCount: books.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < books.length - 1 ? 10 : 0,
                ),
                child: _TrendingBookCard(book: books[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TrendingBookCard extends StatefulWidget {
  final _TrendingBook book;
  const _TrendingBookCard({required this.book});

  @override
  State<_TrendingBookCard> createState() => _TrendingBookCardState();
}

class _TrendingBookCardState extends State<_TrendingBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 196,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusMD,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              BookCover(
                coverUrl: b.coverUrl,
                gradientIndex: b.gradientIndex,
                width: 6,
                height: double.infinity,
                radius: 0,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: ShapeDecoration(
                    color: context.appPrimaryAccent.withValues(alpha: 0.08),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 6,
                        cornerSmoothing: 0.6,
                      ),
                    ),
                  ),
                  child: Text(
                    '${b.sentenceCount}개',
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
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


  @override
  Widget build(BuildContext context) {
    final s = widget.sentence;
    final overlap = widget.isOverlap;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(
          AppConstants.routeSentenceDetail,
          extra: SentenceDetailExtra(
            sentenceContent: s.content,
            bookTitle: s.bookTitle,
            bookAuthor: s.bookAuthor,
            collectorUsername: s.username,
            collectorThought: s.thought,
          ),
        );
      },
      child: Container(
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
                color: context.appPrimaryAccent.withValues(alpha: 0.1),
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
                    BookCover(
                      coverUrl: s.coverUrl,
                      gradientIndex: s.bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
                      width: 28,
                      height: 36,
                      radius: 4,
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
                      time_fmt.formatRelative(s.savedAt),
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
                    color: overlap
                        ? context.appPrimaryAccent.withValues(alpha: 0.07)
                        : context.appCardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: overlap
                          ? context.appPrimaryAccent.withValues(alpha: 0.35)
                          : context.appBorder,
                      width: 1,
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
                // ── 유저의 생각 ──────────────────────────────
                if (s.thought != null && s.thought!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spaceMD),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            context.appPrimaryAccent.withValues(alpha: 0.12),
                        child: Text(
                          s.username[0].toUpperCase(),
                          style: AppTheme.captionSmall
                              .copyWith(color: context.appPrimaryAccent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${s.username}의 생각',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              s.thought!,
                              style: AppTheme.bodySmall.copyWith(
                                color: context.appTextPrimary,
                                height: 1.5,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 생각이 없으면 유저 이름만 표시
                  const SizedBox(height: AppTheme.spaceSM),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor:
                            context.appPrimaryAccent.withValues(alpha: 0.12),
                        child: Text(
                          s.username[0].toUpperCase(),
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appPrimaryAccent,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s.username,
                        style: AppTheme.captionLarge
                            .copyWith(color: context.appTextTertiary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppTheme.spaceMD),

                // ── 좋아요 · 댓글 · 공유 ────────────────────────
                Row(
                  children: [
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
                    if (s.commentCount > 0) ...[
                      const SizedBox(width: AppTheme.spaceMD),
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 14,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '다른 생각 ${s.commentCount}',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              '공유 기능은 곧 지원돼요',
                              style: TextStyle(
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
      ),  // GestureDetector child end
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
              color: context.appPrimaryAccent.withValues(alpha: 0.1),
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
                    BookCover(
                      coverUrl: base.coverUrl,
                      gradientIndex: base.bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
                      width: 28,
                      height: 36,
                      radius: 4,
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
                    color: context.appPrimaryAccent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: context.appPrimaryAccent.withValues(alpha: 0.35),
                      width: 1,
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
                                      backgroundColor: context.appPrimaryAccent
                                          .withValues(alpha: 0.15),
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
                backgroundColor: context.appPrimaryAccent.withValues(alpha: 0.12),
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
