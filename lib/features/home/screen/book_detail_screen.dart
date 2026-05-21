import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';

// ─── 네비게이션 데이터 ────────────────────────────────────────────────────

class BookDetailExtra {
  final String bookId;
  final String title;
  final String author;
  final int currentPage;
  final int totalPages;
  final String lastRead;
  final String? coverUrl;
  final int gradientIndex;
  final List<String> savedSentences;

  const BookDetailExtra({
    required this.bookId,
    required this.title,
    required this.author,
    required this.currentPage,
    required this.totalPages,
    required this.lastRead,
    this.coverUrl,
    required this.gradientIndex,
    this.savedSentences = const [],
  });

  double get progress => totalPages > 0 ? currentPage / totalPages : 0.0;
}

// ─── 내부 모델 ────────────────────────────────────────────────────────────

class _SocialThought {
  final String username;
  final String thought;
  final DateTime createdAt;

  const _SocialThought({
    required this.username,
    required this.thought,
    required this.createdAt,
  });
}

class _CollectedSentence {
  final String id;
  final String content;
  final int page;
  final DateTime collectedAt;
  final String? myNote;
  final int socialCount;
  final List<_SocialThought> socialThoughts;

  const _CollectedSentence({
    required this.id,
    required this.content,
    required this.page,
    required this.collectedAt,
    this.myNote,
    this.socialCount = 0,
    this.socialThoughts = const [],
  });
}

class _ReadingMemo {
  final String content;
  final DateTime createdAt;

  const _ReadingMemo({required this.content, required this.createdAt});
}

/// 다른 독자가 같은 책에서 수집한 문장 + 생각
class _OtherReaderSentence {
  final String id;
  final String content;
  final int page;
  final String username;
  final String? thought;
  final int empathyCount;
  final DateTime savedAt;

  const _OtherReaderSentence({
    required this.id,
    required this.content,
    required this.page,
    required this.username,
    this.thought,
    this.empathyCount = 0,
    required this.savedAt,
  });
}

// ─── 목업 데이터 ──────────────────────────────────────────────────────────

List<_CollectedSentence> _buildMockSentences() => [
  _CollectedSentence(
    id: '1',
    content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
    page: 23,
    collectedAt: DateTime.now().subtract(const Duration(days: 3)),
    myNote: '주인공의 결심이 단순한 선택이 아닌, 내면의 깊은 변화에서 비롯된 것임을 보여주는 첫 문장',
    socialCount: 3,
    socialThoughts: [
      _SocialThought(
        username: 'reader_jin',
        thought: '이 문장에서 시작되는 전환점이 소름 돋았어요',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      _SocialThought(
        username: 'bookworm_su',
        thought: '꿈이 현실을 바꾸는 순간, 그 무게감이 느껴집니다',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      _SocialThought(
        username: 'midnight_books',
        thought: '"꿈 때문에"라는 짧은 이유가 오히려 강렬해요',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ],
  ),
  _CollectedSentence(
    id: '2',
    content: '그녀의 눈에는 아무런 감정도 없었다. 그게 가장 무서웠다.',
    page: 45,
    collectedAt: DateTime.now().subtract(const Duration(days: 2)),
    socialCount: 1,
    socialThoughts: [
      _SocialThought(
        username: 'seoulreader',
        thought: '감정의 부재가 가장 큰 공포라는 걸 이 문장이 보여줘요',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ],
  ),
  _CollectedSentence(
    id: '3',
    content: '식물이 되고 싶었다. 뿌리를 내리고 햇빛을 먹고 살고 싶었다.',
    page: 78,
    collectedAt: DateTime.now().subtract(const Duration(days: 1)),
    myNote: '인간으로서의 존재를 거부하는 영혜의 욕망이 가장 직접적으로 드러나는 장면',
    socialCount: 5,
    socialThoughts: [
      _SocialThought(
        username: 'hesse_lover',
        thought: '자연으로 회귀하려는 본능적 욕구가 느껴져요',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      _SocialThought(
        username: 'reader_jin',
        thought: '이 문장을 읽고 한참을 멈췄습니다',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
    ],
  ),
  _CollectedSentence(
    id: '4',
    content: '아무도 나를 이해하지 못한다는 사실이, 오히려 자유였다.',
    page: 112,
    collectedAt: DateTime.now().subtract(const Duration(hours: 18)),
    myNote: '고독이 자유가 되는 역설. 사회적 단절이 주는 해방감',
    socialCount: 2,
    socialThoughts: [
      _SocialThought(
        username: 'midnight_books',
        thought: '이해받지 못하는 것이 해방이 될 수 있다니',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ],
  ),
  _CollectedSentence(
    id: '5',
    content: '나무가 되는 것은 죽는 것이 아니라, 다른 방식으로 사는 것이다.',
    page: 178,
    collectedAt: DateTime.now().subtract(const Duration(hours: 2)),
    myNote: '이 소설의 핵심 메시지. 변화는 소멸이 아니라 변환이다.',
    socialCount: 4,
    socialThoughts: [
      _SocialThought(
        username: 'seoulreader',
        thought: '끝이 아닌 시작으로 읽히는 문장이에요',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      _SocialThought(
        username: 'hesse_lover',
        thought: '헤세의 "나무들"이 떠오르는 구절',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
    ],
  ),
];

List<_ReadingMemo> _buildMockMemos() => [
  _ReadingMemo(
    content: '1부를 다 읽었다. 영혜의 거부가 단순한 식습관 변화가 아닌 존재론적 저항이라는 걸 느꼈다.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  _ReadingMemo(
    content: '2부 "몽고반점"에서 시선이 남편에서 형부로 바뀌면서 영혜를 바라보는 시선의 문제가 더 선명해진다.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  _ReadingMemo(
    content: '3부 시작. 언니의 시선에서 바라보는 영혜가 가장 아프다.',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
];

List<_OtherReaderSentence> _buildMockOtherReaders() => [
  _OtherReaderSentence(
    id: 'or1',
    content: '그녀는 아무것도 원하지 않았다. 그것이 그녀의 유일한 소원이었다.',
    page: 67,
    username: 'seoulreader',
    thought: '원하지 않는 것을 원한다는 역설. 이 한 문장에 영혜의 본질이 담겨 있다.',
    empathyCount: 89,
    savedAt: DateTime.now().subtract(const Duration(hours: 6)),
  ),
  _OtherReaderSentence(
    id: 'or2',
    content: '남편은 그녀의 변화를 이해하지 못했다. 이해하려고 하지도 않았다.',
    page: 34,
    username: 'bookworm_su',
    thought: '"이해하지 못했다"와 "하지도 않았다"의 차이가 이 소설의 핵심. 무관심이 폭력이다.',
    empathyCount: 124,
    savedAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
  _OtherReaderSentence(
    id: 'or3',
    content: '꿈에서 본 얼굴은 자신의 것이었다.',
    page: 12,
    username: 'midnight_books',
    thought: '자기 자신을 마주하는 꿈. 영혜의 변화는 외부가 아닌 내부에서 시작되었다.',
    empathyCount: 56,
    savedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  _OtherReaderSentence(
    id: 'or4',
    content: '피가 보이지 않는 음식만 먹겠다고 했다.',
    page: 28,
    username: 'hesse_lover',
    empathyCount: 43,
    savedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  _OtherReaderSentence(
    id: 'or5',
    content: '그녀는 점점 사라져 갔다. 아니, 변해 갔다.',
    page: 156,
    username: 'leafy_reader',
    thought: '"사라진다"와 "변한다"— 이 두 단어의 차이가 소설 전체의 시각을 결정한다.',
    empathyCount: 71,
    savedAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
];

// ─── 메인 스크린 ──────────────────────────────────────────────────────────

class BookDetailScreen extends ConsumerStatefulWidget {
  final BookDetailExtra book;

  const BookDetailScreen({super.key, required this.book});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _isCompleted = false;
  final Set<String> _expandedIds = {};
  late final List<_CollectedSentence> _sentences;
  late final List<_ReadingMemo> _memos;
  late final List<_OtherReaderSentence> _otherReaders;

  @override
  void initState() {
    super.initState();
    _sentences = kUseMock
        ? _buildMockSentences()
        : _savedToCollected(widget.book.savedSentences);
    _memos = kUseMock ? _buildMockMemos() : [];
    _otherReaders = kUseMock ? _buildMockOtherReaders() : [];
  }

  List<_CollectedSentence> _savedToCollected(List<String> saved) {
    return saved
        .asMap()
        .entries
        .map(
          (e) => _CollectedSentence(
            id: 'saved_${e.key}',
            content: e.value,
            page: 0,
            collectedAt: DateTime.now(),
          ),
        )
        .toList();
  }

  void _toggleExpansion(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  Future<void> _toggleCompletion() async {
    HapticFeedback.mediumImpact();
    if (_isCompleted) {
      setState(() => _isCompleted = false);
      await ref.read(libraryProvider.notifier).cancelCompletion(widget.book.bookId);
      return;
    }

    await _showCompletionDialog();
  }

  Future<void> _showCompletionDialog() async {
    HapticFeedback.heavyImpact();
    await ref.read(libraryProvider.notifier).markAsCompleted(widget.book.bookId);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompletionDialog(
        bookTitle: widget.book.title,
        onReflect: () {
          Navigator.of(context).pop();
          setState(() => _isCompleted = true);
          context.push(
            AppConstants.routeReflection,
            extra: Book(
              id: '', // 상세 데이터에 ID가 없는 경우 빈 문자열
              title: widget.book.title,
              author: widget.book.author,
              totalPages: widget.book.totalPages,
              currentPage: widget.book.totalPages,
              status: ReadingStatus.completed,
            ),
          );
        },
        onLater: () {
          Navigator.of(context).pop();
          setState(() => _isCompleted = true);
        },
      ),
    );
  }

  void _showMenu() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _MenuSheet(bookId: widget.book.bookId, bookTitle: widget.book.title),
    );
  }

  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    context.push(
      AppConstants.routeSession,
      extra: SessionExtra(
        bookId: widget.book.bookId,
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
        coverUrl: widget.book.coverUrl,
        startPage: widget.book.currentPage,
        totalPages: widget.book.totalPages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          // ── 히어로 ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroSection(
              book: book,
              topPadding: topPad,
              isCompleted: _isCompleted,
              onBack: () => context.pop(),
              onMenu: _showMenu,
              onToggleCompletion: _toggleCompletion,
              onStartSession: _startSession,
            ),
          ),

          // ── 독서 통계 ──────────────────────────────────────────
          if (kUseMock)
            SliverToBoxAdapter(
              child: _StatsRow(
                sessions: 12,
                totalHours: 12.4,
                avgMinutes: 62,
                sentenceCount: _sentences.length,
              ),
            ),

          // ── 수집 문장 헤더 ────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(title: '수집한 문장', count: _sentences.length),
          ),

          // ── 수집 문장 목록 ────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  index == 0 ? 0 : AppTheme.spaceSM,
                  AppTheme.screenPadding,
                  0,
                ),
                child: _SentenceCard(
                  sentence: _sentences[index],
                  isExpanded: _expandedIds.contains(_sentences[index].id),
                  onToggleExpand: () => _toggleExpansion(_sentences[index].id),
                ),
              ),
              childCount: _sentences.length,
            ),
          ),

          // ── 이 책의 인기 문장 (다른 독자) ───────────────────
          if (_otherReaders.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  AppTheme.space2XL,
                  AppTheme.screenPadding,
                  AppTheme.spaceMD,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline_rounded,
                      size: 20,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '이 책의 인기 문장',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: AppTheme.smoothPill(
                        color: context.appPrimaryAccent.withValues(alpha: 0.12),
                      ),
                      child: Text(
                        '${_otherReaders.length}명이 수집',
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appPrimaryAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.screenPadding,
                  ),
                  itemCount: _otherReaders.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                      right: index < _otherReaders.length - 1 ? 12 : 0,
                    ),
                    child: _OtherReaderCard(sentence: _otherReaders[index]),
                  ),
                ),
              ),
            ),
          ],

          // ── 메모 헤더 ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: '독서 메모',
              count: _memos.length,
              trailing: _AddMemoButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '메모 작성 기능은 곧 지원돼요',
                        style: AppTheme.bodySmall.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                      backgroundColor: context.appCardElevated,
                      behavior: SnackBarBehavior.floating,
                      shape: AppTheme.smoothShape(
                        radius: AppTheme.radiusMD,
                        side: BorderSide.none,
                      ),
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
          ),

          // ── 메모 목록 ──────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.screenPadding,
                  index == 0 ? 0 : AppTheme.spaceSM,
                  AppTheme.screenPadding,
                  0,
                ),
                child: _MemoCard(memo: _memos[index]),
              ),
              childCount: _memos.length,
            ),
          ),

          // ── 하단 여백 ──────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// ─── 히어로 섹션 ──────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final BookDetailExtra book;
  final double topPadding;
  final bool isCompleted;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onToggleCompletion;
  final VoidCallback onStartSession;

  const _HeroSection({
    required this.book,
    required this.topPadding,
    required this.isCompleted,
    required this.onBack,
    required this.onMenu,
    required this.onToggleCompletion,
    required this.onStartSession,
  });

  @override
  Widget build(BuildContext context) {
    final gradColors = AppTheme.coverGradientByIndex(book.gradientIndex);

    return Stack(
      children: [
        // ── 배경 글로우 ──────────────────────────────────────
        Positioned(
          top: -100,
          left: -100,
          right: -100,
          child: Container(
            height: 500,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  gradColors[0].withValues(alpha: 0.25),
                  context.appBg.withValues(alpha: 0.0),
                ],
                radius: 0.7,
              ),
            ),
          ),
        ),
        // ── 컨텐츠 ──────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            topPadding + 8,
            AppTheme.screenPadding,
            AppTheme.space2XL,
          ),
          child: Column(
            children: [
              // ── 네비게이션 ────────────────────────────────────────
              Row(
                children: [
                  _NavButton(
                    icon: Icons.arrow_back_ios_rounded,
                    onTap: onBack,
                    semanticsLabel: '뒤로 가기',
                  ),
                  const Spacer(),
                  _NavButton(
                    icon: Icons.more_horiz_rounded,
                    onTap: onMenu,
                    semanticsLabel: '메뉴',
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── 책 표지 ───────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: gradColors[0].withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: BookCover(
                  coverUrl: book.coverUrl,
                  gradientIndex: book.gradientIndex,
                  width: 120,
                  height: 168,
                  radius: 16,
                  fallbackIcon: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 40,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 제목 · 저자 ───────────────────────────────────────
              Text(
                book.title,
                style: AppTheme.headingLarge.copyWith(
                  color: context.appTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                book.author,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // ── 진행률 ────────────────────────────────────────────
              _ProgressSection(
                progress: book.progress,
                currentPage: book.currentPage,
                totalPages: book.totalPages,
                isCompleted: isCompleted,
                onToggleCompletion: onToggleCompletion,
              ),
              const SizedBox(height: 20),

              // ── 액션 버튼 ─────────────────────────────────────────
              Semantics(
                label: '${book.title} 이어 읽기',
                button: true,
                child: GestureDetector(
                  onTap: onStartSession,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: AppTheme.smoothBox(
                      gradient: context.appReadingGradient,
                      radius: AppTheme.radiusMD,
                    ),
                    child: Text(
                      '이어 읽기',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appBg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 네비게이션 버튼 ──────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;

  const _NavButton({
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: AppTheme.smoothBox(
                color: Colors.white.withValues(alpha: 0.06),
                radius: AppTheme.radiusSM,
                side: BorderSide.none,
              ),
              child: Icon(icon, size: 20, color: context.appTextPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 진행률 ───────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final double progress;
  final int currentPage;
  final int totalPages;
  final bool isCompleted;
  final VoidCallback onToggleCompletion;

  const _ProgressSection({
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.isCompleted,
    required this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$currentPage / $totalPages쪽',
              style: AppTheme.captionLarge.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: isCompleted ? '완독 취소' : '완독 체크',
                  button: true,
                  child: GestureDetector(
                    onTap: onToggleCompletion,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        color: isCompleted
                            ? context.appAccentColor.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.06),
                        radius: AppTheme.radiusMD,
                        side: BorderSide.none,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 15,
                            color: isCompleted
                                ? context.appAccentColor
                                : context.appTextTertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '완독',
                            style: AppTheme.bodySmall.copyWith(
                              color: isCompleted
                                  ? context.appAccentColor
                                  : context.appTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (_, c) => Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: c.maxWidth * progress.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: context.appReadingGradient,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── 독서 통계 ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int sessions;
  final double totalHours;
  final int avgMinutes;
  final int sentenceCount;

  const _StatsRow({
    required this.sessions,
    required this.totalHours,
    required this.avgMinutes,
    required this.sentenceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        0,
        AppTheme.screenPadding,
        AppTheme.spaceLG,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(value: '$sessions', label: '세션'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(value: '${totalHours}h', label: '누적 시간'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(value: '$avgMinutes분', label: '평균'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(value: '$sentenceCount', label: '문장'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: AppTheme.smoothBox(
        color: context.primaryBg(0.04),
        radius: AppTheme.radiusMD,
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.headingSmall.copyWith(
              color: context.appPrimaryAccent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.space2XL,
        AppTheme.screenPadding,
        AppTheme.spaceMD,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: AppTheme.smoothPill(
              color: context.appPrimaryAccent.withValues(alpha: 0.12),
            ),
            child: Text(
              '$count',
              style: AppTheme.captionSmall.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

// ─── 메모 추가 버튼 ──────────────────────────────────────────────────────

class _AddMemoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMemoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '메모 추가',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: AppTheme.smoothPill(
            color: AppTheme.primary.withValues(alpha: 0.3),
            side: BorderSide.none,
          ),
          child: Text(
            '+ 메모 추가',
            style: AppTheme.captionLarge.copyWith(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 수집 문장 카드 ──────────────────────────────────────────────────────

class _SentenceCard extends StatelessWidget {
  final _CollectedSentence sentence;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _SentenceCard({
    required this.sentence,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final s = sentence;
    final hasSocial = s.socialCount > 0;

    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 페이지 · 시간 ─────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: AppTheme.smoothPill(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                      child: Text(
                        'p.${s.page}',
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appPrimaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time_fmt.formatRelative(s.collectedAt),
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    if (hasSocial) ...[
                      const Spacer(),
                      Icon(
                        Icons.join_inner_rounded,
                        size: 14,
                        color: context.appAccentColor.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '겹 ${s.socialCount}',
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appAccentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ── 문장 본문 ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  decoration: BoxDecoration(
                    color: context.appCardElevated,
                    borderRadius: BorderRadius.circular(8),
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

                // ── 나의 생각 ──────────────────────────────────────
                if (s.myNote != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.myNote!,
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // ── 다른 사람의 생각 토글 ─────────────────────────
                if (hasSocial) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    label: '다른 사람의 생각 ${isExpanded ? "접기" : "펼치기"}',
                    button: true,
                    child: GestureDetector(
                      onTap: onToggleExpand,
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              size: 16,
                              color: context.appTextTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${s.socialCount}명의 생각',
                              style: AppTheme.captionLarge.copyWith(
                                color: context.appTextSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0.0,
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
              ],
            ),
          ),

          // ── 소셜 목록 (확장 시) ────────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: isExpanded && hasSocial
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.cardPaddingMD,
                      0,
                      AppTheme.cardPaddingMD,
                      AppTheme.cardPaddingMD,
                    ),
                    child: Column(
                      children: [
                        // Divider(height: 1, color: context.appBorder),
                        const SizedBox(height: 12),
                        ...s.socialThoughts.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spaceSM,
                            ),
                            child: _SocialThoughtTile(
                              thought: t,
                              timeLabel: time_fmt.formatRelative(t.createdAt),
                            ),
                          ),
                        ),
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

// ─── 소셜 생각 타일 ──────────────────────────────────────────────────────

class _SocialThoughtTile extends StatelessWidget {
  final _SocialThought thought;
  final String timeLabel;

  const _SocialThoughtTile({required this.thought, required this.timeLabel});

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
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                child: Text(
                  thought.username[0].toUpperCase(),
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  thought.username,
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                timeLabel,
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            thought.thought,
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 독서 메모 카드 ──────────────────────────────────────────────────────

class _MemoCard extends StatelessWidget {
  final _ReadingMemo memo;

  const _MemoCard({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time_fmt.formatDate(memo.createdAt),
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            memo.content,
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 메뉴 시트 ───────────────────────────────────────────────────────────

class _MenuSheet extends ConsumerWidget {
  final String bookId;
  final String bookTitle;

  const _MenuSheet({required this.bookId, required this.bookTitle});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서재에서 제거'),
        content: Text('\'$bookTitle\'을(를) 서재에서 제거할까요?\n기록된 독서 데이터도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('제거'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    ref.read(libraryProvider.notifier).deleteBook(bookId);
    Navigator.pop(context); // 시트 닫기
    if (!context.mounted) return;
    context.go(AppConstants.routeHome);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.screenPadding),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusXL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          _MenuTile(
            icon: Icons.edit_outlined,
            label: '책 정보 수정',
            onTap: () {
              Navigator.pop(context);
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '책 정보 수정 기능은 곧 지원돼요',
                    style: AppTheme.bodySmall.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  backgroundColor: context.appCardElevated,
                  behavior: SnackBarBehavior.floating,
                  shape: AppTheme.smoothShape(
                    radius: AppTheme.radiusMD,
                    side: BorderSide.none,
                  ),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.share_outlined,
            label: '공유하기',
            onTap: () {
              Navigator.pop(context);
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
                      side: BorderSide.none,
                  ),
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.delete_outline_rounded,
            label: '서재에서 제거',
            color: Theme.of(context).colorScheme.error,
            onTap: () => _confirmDelete(context, ref),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.appTextPrimary;

    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: c),
                const SizedBox(width: 12),
                Text(label, style: AppTheme.bodyMedium.copyWith(color: c)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 다른 독자의 문장 카드 ──────────────────────────────────────────────

class _OtherReaderCard extends StatelessWidget {
  final _OtherReaderSentence sentence;

  const _OtherReaderCard({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final s = sentence;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 페이지 번호 + 좋아요 ──────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: AppTheme.smoothPill(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                ),
                child: Text(
                  'p.${s.page}',
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.favorite_rounded,
                size: 12,
                color: AppTheme.empathyColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                '${s.empathyCount}',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── 인용 문장 ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.appCardElevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '"${s.content}"',
              style: AppTheme.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                color: context.appTextPrimary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── 유저의 생각 ─────────────────────────────────────
          if (s.thought != null && s.thought!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                s.thought!,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else
            const Spacer(),

          // ── 유저 정보 ──────────────────────────────────────
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.12,
                ),
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
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// ─── 완독 축하 다이얼로그 ─────────────────────────────────────────────

class _CompletionDialog extends StatelessWidget {
  final String bookTitle;
  final VoidCallback onReflect;
  final VoidCallback onLater;

  const _CompletionDialog({
    required this.bookTitle,
    required this.onReflect,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusXL,
          side: BorderSide.none,
          shadows: [
            BoxShadow(
              color: context.appPrimaryAccent.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: AppTheme.smoothBox(
                gradient: context.appReadingGradient,
                radius: AppTheme.radiusLG,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.darkBg,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '완독을 축하해요! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              '"$bookTitle"을(를)\n끝까지 읽으셨군요!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.appTextSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 감상 남기기
            Semantics(
              button: true,
              label: '감상 남기기',
              child: GestureDetector(
                onTap: onReflect,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: AppTheme.smoothBox(
                    gradient: context.appReadingGradient,
                    radius: AppTheme.radiusMD,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '감상 남기기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkBg,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 나중에
            Semantics(
              button: true,
              label: '나중에',
              child: GestureDetector(
                onTap: onLater,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.appTextTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
