import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_section_header.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// ─── Data Models ────────────────────────────────────────────────────────────

class _BookData {
  final String title;
  final String author;
  final String publisher;
  final int sentenceCount;
  final int readerCount;
  final String genre;

  const _BookData({
    required this.title,
    required this.author,
    required this.publisher,
    required this.sentenceCount,
    required this.readerCount,
    required this.genre,
  });
}

class _SentenceData {
  final String sentence;
  final String bookTitle;
  final String author;
  final int likeCount;

  const _SentenceData({
    required this.sentence,
    required this.bookTitle,
    required this.author,
    required this.likeCount,
  });
}

// ─── Mock Data ──────────────────────────────────────────────────────────────

const List<_BookData> _kMockBooks = [
  _BookData(title: '채식주의자', author: '한강', publisher: '창비', sentenceCount: 1247, readerCount: 3841, genre: '문학'),
  _BookData(title: '아몬드', author: '손원평', publisher: '창비', sentenceCount: 893, readerCount: 2917, genre: '문학'),
  _BookData(title: '82년생 김지영', author: '조남주', publisher: '민음사', sentenceCount: 756, readerCount: 2304, genre: '문학'),
  _BookData(title: '달러구트 꿈 백화점', author: '이미예', publisher: '팩토리나인', sentenceCount: 621, readerCount: 1988, genre: '에세이'),
  _BookData(title: '파친코', author: '이민진', publisher: '인플루엔셜', sentenceCount: 584, readerCount: 1742, genre: '문학'),
  _BookData(title: '흰', author: '한강', publisher: '문학동네', sentenceCount: 472, readerCount: 1501, genre: '시'),
  _BookData(title: '지구 끝의 온실', author: '김초엽', publisher: '자이언트북스', sentenceCount: 381, readerCount: 1203, genre: 'SF'),
  _BookData(title: '소년이 온다', author: '한강', publisher: '창비', sentenceCount: 349, readerCount: 987, genre: '문학'),
];

const List<_SentenceData> _kMockSentences = [
  _SentenceData(
    sentence: '나는 이제 채식주의자가 아니다. 식물이 되고 싶다.',
    bookTitle: '채식주의자',
    author: '한강',
    likeCount: 2847,
  ),
  _SentenceData(
    sentence: '감정을 모른다고 해서 감정이 없는 건 아니에요. 그냥 느끼는 방법을 배우지 못한 거죠.',
    bookTitle: '아몬드',
    author: '손원평',
    likeCount: 1934,
  ),
  _SentenceData(
    sentence: '역사는 패배자들의 이야기다. 살아남은 자들이 역사를 쓴다.',
    bookTitle: '파친코',
    author: '이민진',
    likeCount: 1572,
  ),
  _SentenceData(
    sentence: '모든 것들은 하얗다. 하얀 것들로 가득 찬 이 세계에서 나는 살아있다.',
    bookTitle: '흰',
    author: '한강',
    likeCount: 1289,
  ),
  _SentenceData(
    sentence: '우리는 모두 지구 끝에서 온실을 가꾸며 살아가고 있다.',
    bookTitle: '지구 끝의 온실',
    author: '김초엽',
    likeCount: 983,
  ),
];

const List<String> _kCategories = ['전체', '문학', '에세이', '인문', '자기계발', 'SF', '시', '역사'];

// ─── Cover Gradients ────────────────────────────────────────────────────────


// ─── Main Screen ─────────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedCategoryIndex = 0;
  bool _isSearchFocused = false;
  List<_BookData> _filteredBooks = _useMock ? _kMockBooks : const [];
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _useMock ? _kMockBooks : const [];
      } else {
        _filteredBooks = (_useMock ? _kMockBooks : const <_BookData>[]).where((b) {
          return b.title.toLowerCase().contains(query) ||
              b.author.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _dismissSearch() {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() => _filteredBooks = _kMockBooks);
  }

  void _onCategorySelected(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedCategoryIndex = index);
  }

  List<_BookData> get _categoryFilteredBooks {
    if (!_useMock) return const [];
    if (_selectedCategoryIndex == 0) return _kMockBooks;
    final category = _kCategories[_selectedCategoryIndex];
    return _kMockBooks.where((b) => b.genre == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = _searchController.text.isNotEmpty;

    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appSurface,
      body: Column(
        children: [
          SizedBox(height: topPad),
          _AppBarArea(
            searchController: _searchController,
            focusNode: _searchFocusNode,
            isSearchFocused: _isSearchFocused,
            onDismiss: _dismissSearch,
          ),
          Expanded(
            child: isSearchActive
                ? _SearchResultsView(books: _filteredBooks)
                : _MainContentView(
                    selectedCategoryIndex: _selectedCategoryIndex,
                    onCategorySelected: _onCategorySelected,
                    filteredBooks: _categoryFilteredBooks,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── App Bar Area ────────────────────────────────────────────────────────────

class _AppBarArea extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode focusNode;
  final bool isSearchFocused;
  final VoidCallback onDismiss;

  const _AppBarArea({
    required this.searchController,
    required this.focusNode,
    required this.isSearchFocused,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        12,
        AppTheme.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Semantics(
                label: '뒤로가기',
                button: true,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: context.appTextPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              Text(
                '탐색',
                style: AppTheme.headingLarge.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SearchBar(
            controller: searchController,
            focusNode: focusNode,
            isSearchFocused: isSearchFocused,
            onDismiss: onDismiss,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearchFocused;
  final VoidCallback onDismiss;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearchFocused,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 48,
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 12,
        side: BorderSide(
          color: isSearchFocused ? AppTheme.accent : context.appBorder,
          width: isSearchFocused ? 1.5 : 1,
        ),
        shadows: isSearchFocused
            ? [
                BoxShadow(
                  color: context.appAccentColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: isSearchFocused ? AppTheme.accent : context.appTextTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: true,
              showCursor: false,
              onTap: () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeSearch);
              },
              style: AppTheme.bodyMedium.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '책, 작가, 유저 검색',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Main Content View ───────────────────────────────────────────────────────

class _MainContentView extends StatelessWidget {
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategorySelected;
  final List<_BookData> filteredBooks;

  const _MainContentView({
    required this.selectedCategoryIndex,
    required this.onCategorySelected,
    required this.filteredBooks,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCategoryFiltered = selectedCategoryIndex != 0;
    final bool hasBooks = filteredBooks.isNotEmpty;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _CategoryChips(
            selectedIndex: selectedCategoryIndex,
            onSelected: onCategorySelected,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        // 알라딘 책 검색 배너
        const SliverToBoxAdapter(child: _AladinSearchBanner()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // 카테고리 필터 중이고 결과 없을 때
        if (isCategoryFiltered && !hasBooks) ...[
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 52, color: context.appTextTertiary),
                  const SizedBox(height: 16),
                  Text(
                    '${_kCategories[selectedCategoryIndex]} 장르 결과가 없어요',
                    style: AppTheme.headingSmall.copyWith(
                        color: context.appTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '다른 장르를 선택해보세요',
                    style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
              child: ChorokSectionHeader(
                title: isCategoryFiltered
                    ? '${_kCategories[selectedCategoryIndex]} 인기 도서'
                    : '초록에서 가장 많이 기록된 책',
                subtitle: '독자들이 가장 많이 기록한 문장들',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _TrendingBooksSection(books: filteredBooks),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
              child: ChorokSectionHeader(
                title: '지금 읽히는 책',
                subtitle: '실시간 독서 중인 독자 수 기준',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= filteredBooks.length) return null;
                return _PopularBookTile(
                  book: filteredBooks[index],
                  rank: index + 1,
                );
              },
              childCount: filteredBooks.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
              child: ChorokSectionHeader(
                title: '이 책의 인기 문장',
                subtitle: '독자들이 가장 많이 좋아요 한 문장',
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _kMockSentences.length) return null;
                return _SentenceCard(sentence: _kMockSentences[index]);
              },
              childCount: _kMockSentences.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ],
    );
  }
}

// ─── Search Results View ──────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final List<_BookData> books;

  const _SearchResultsView({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: context.appTextTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없어요',
              style: AppTheme.headingSmall.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 제목이나 저자 이름으로 검색해보세요',
              style: AppTheme.bodySmall.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 48),
      itemCount: books.length,
      itemBuilder: (context, index) {
        return _PopularBookTile(book: books[index], rank: index + 1);
      },
    );
  }
}

// ─── Category Chips ──────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _CategoryChips({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
        itemCount: _kCategories.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: index < _kCategories.length - 1 ? 8 : 0),
            child: _CategoryChip(
              label: _kCategories[index],
              isSelected: isSelected,
              onTap: () => onSelected(index),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label 카테고리${isSelected ? ', 선택됨' : ''}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: AppTheme.smoothPill(
            color: isSelected ? AppTheme.accent : context.appCard,
            side: BorderSide(
              color: isSelected ? AppTheme.accent : context.appBorder,
            ),
            shadows: isSelected
                ? [
                    BoxShadow(
                      color: context.appAccentColor.withValues(alpha: 0.24),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTheme.captionLarge.copyWith(
              fontFamily: 'Pretendard',
              color: isSelected ? context.appSurface : context.appTextSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Trending Books Section ───────────────────────────────────────────────────

class _TrendingBooksSection extends StatelessWidget {
  final List<_BookData> books;
  const _TrendingBooksSection({required this.books});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
        itemCount: books.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < books.length - 1 ? 12 : 0),
            child: _TrendingBookCard(
              book: books[index],
              colorIndex: index,
            ),
          );
        },
      ),
    );
  }
}

class _TrendingBookCard extends StatefulWidget {
  final _BookData book;
  final int colorIndex;

  const _TrendingBookCard({
    required this.book,
    required this.colorIndex,
  });

  @override
  State<_TrendingBookCard> createState() => _TrendingBookCardState();
}

class _TrendingBookCardState extends State<_TrendingBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.coverGradients[widget.colorIndex % AppTheme.coverGradients.length];

    return Semantics(
      label: '${widget.book.title}, ${widget.book.author}, ${_formatCount(widget.book.sentenceCount)}개 문장 기록됨',
      button: true,
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: 140,
            height: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 160,
                  decoration: AppTheme.smoothBox(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    radius: 12,
                    side: BorderSide(color: context.appBorder),
                    shadows: [
                      BoxShadow(
                        color: gradientColors.last.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -12,
                        bottom: -12,
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 80,
                          color: context.appPrimaryAccent.withValues(alpha: 0.08),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            _SentenceBadge(count: widget.book.sentenceCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.book.title,
                  style: AppTheme.bodySmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.book.author,
                  style: AppTheme.captionSmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SentenceBadge extends StatelessWidget {
  final int count;

  const _SentenceBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: context.appSurface.withValues(alpha: 0.8),
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 0.6),
          side: BorderSide(color: context.appAccentColor.withValues(alpha: 0.4), width: 1),
        ),
      ),
      child: Text(
        '${_formatCount(count)}개 문장 기록됨',
        style: AppTheme.captionSmall.copyWith(
          fontFamily: 'Pretendard',
          color: AppTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PopularBookTile extends StatefulWidget {
  final _BookData book;
  final int rank;

  const _PopularBookTile({
    required this.book,
    required this.rank,
  });

  @override
  State<_PopularBookTile> createState() => _PopularBookTileState();
}

class _PopularBookTileState extends State<_PopularBookTile> {
  bool _isPressed = false;

  void _onAddToLibrary(BuildContext context) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '서재에 추가됐어요',
          style: AppTheme.bodySmall.copyWith(
            fontFamily: 'Pretendard',
            color: context.appTextPrimary,
          ),
        ),
        backgroundColor: context.appCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: 0.6),
          side: BorderSide(color: context.appBorder, width: 1),
        ),
        margin: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.coverGradients[(widget.rank - 1) % AppTheme.coverGradients.length];
    final isTopThree = widget.rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: 8,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.diagonal3Values(_isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${widget.rank}',
                  style: AppTheme.headingSmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: isTopThree ? AppTheme.accent : context.appTextTertiary,
                    fontWeight: isTopThree ? FontWeight.w700 : FontWeight.w400,
                    fontSize: isTopThree ? 17 : 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 60,
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradientColors,
                  ),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 0.6),
                    side: BorderSide(color: context.appBorder, width: 1),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: context.appPrimaryAccent.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.book.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.book.author} · ${widget.book.publisher}',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCount(widget.book.readerCount)}명 읽는 중',
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: '${widget.book.title} 서재에 추가',
                button: true,
                child: GestureDetector(
                  onTap: () => _onAddToLibrary(context),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: context.appCardElevated,
                      shape: SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius(cornerRadius: 8, cornerSmoothing: 0.6),
                        side: BorderSide(color: context.appBorder, width: 1),
                      ),
                    ),
                    child: Text(
                      '서재에 추가',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
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

class _SentenceCard extends StatefulWidget {
  final _SentenceData sentence;

  const _SentenceCard({required this.sentence});

  @override
  State<_SentenceCard> createState() => _SentenceCardState();
}

class _SentenceCardState extends State<_SentenceCard> {
  bool _isLiked = false;
  bool _isPressed = false;

  void _onLikeTap() {
    HapticFeedback.mediumImpact();
    setState(() => _isLiked = !_isLiked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        0,
        AppTheme.screenPadding,
        12,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          setState(() => _isPressed = true);
        },
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.diagonal3Values(_isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
            shadows: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: ShapeDecoration(
                    gradient: AppTheme.greenGradientVertical,
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius.only(
                        topLeft: SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.6),
                        bottomLeft: SmoothRadius(cornerRadius: 16, cornerSmoothing: 0.6),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${widget.sentence.sentence}"',
                          style: AppTheme.bodySmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextPrimary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.sentence.bookTitle,
                                    style: AppTheme.captionLarge.copyWith(
                                      fontFamily: 'Pretendard',
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.sentence.author,
                                    style: AppTheme.captionSmall.copyWith(
                                      fontFamily: 'Pretendard',
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Semantics(
                              label: '좋아요 ${_isLiked ? '취소' : ''}',
                              button: true,
                              child: GestureDetector(
                                onTap: _onLikeTap,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          _isLiked
                                              ? Icons.favorite_rounded
                                              : Icons.favorite_border_rounded,
                                          key: ValueKey(_isLiked),
                                          size: 18,
                                          color: _isLiked
                                              ? AppTheme.accent
                                              : context.appTextTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatCount(
                                          widget.sentence.likeCount + (_isLiked ? 1 : 0),
                                        ),
                                        style: AppTheme.captionSmall.copyWith(
                                          fontFamily: 'Pretendard',
                                          color: _isLiked
                                              ? AppTheme.accent
                                              : context.appTextTertiary,
                                          fontWeight: FontWeight.w500,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _formatCount(int count) {
  if (count >= 10000) {
    final val = (count / 1000).toStringAsFixed(1);
    return '${val}k';
  }
  if (count >= 1000) {
    final val = (count / 1000).toStringAsFixed(1);
    return '${val}k';
  }
  return count.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
}

// ─── 알라딘 책 검색 배너 ─────────────────────────────────────────────────────

class _AladinSearchBanner extends StatefulWidget {
  const _AladinSearchBanner();

  @override
  State<_AladinSearchBanner> createState() => _AladinSearchBannerState();
}

class _AladinSearchBannerState extends State<_AladinSearchBanner> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        button: true,
        label: '알라딘에서 책 검색하고 서재에 추가하기',
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            HapticFeedback.mediumImpact();
            context.push(AppConstants.routeSearch);
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              height: 72,
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenCardGradient,
                radius: AppTheme.radiusLG,
                side: BorderSide(
                  color: context.appPrimaryAccent.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: AppTheme.smoothBox(
                      gradient: AppTheme.greenGradient,
                      radius: AppTheme.radiusSM,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppTheme.darkBg,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '책 검색하고 서재에 추가',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          '알라딘 데이터베이스에서 책을 찾아보세요',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.appTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: context.appTextTertiary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
