import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../search/model/aladin_book.dart';
import '../../search/util/add_book_flow.dart';
import '../../search/widget/add_to_library_sheet.dart';


// ─── Data Model ──────────────────────────────────────────────────────────────

class _BookData {
  final String title;
  final String author;
  final String publisher;

  const _BookData({
    required this.title,
    required this.author,
    required this.publisher,
  });
}

// ─── Mock Data ──────────────────────────────────────────────────────────────

const List<_BookData> _kMockBooks = [
  _BookData(title: '채식주의자', author: '한강', publisher: '창비'),
  _BookData(title: '아몬드', author: '손원평', publisher: '창비'),
  _BookData(title: '82년생 김지영', author: '조남주', publisher: '민음사'),
  _BookData(title: '달러구트 꿈 백화점', author: '이미예', publisher: '팩토리나인'),
  _BookData(title: '파친코', author: '이민진', publisher: '인플루엔셜'),
  _BookData(title: '흰', author: '한강', publisher: '문학동네'),
  _BookData(title: '지구 끝의 온실', author: '김초엽', publisher: '자이언트북스'),
  _BookData(title: '소년이 온다', author: '한강', publisher: '창비'),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;
  List<_BookData> _allBooks = kUseMock ? _kMockBooks : const [];
  List<_BookData> _filteredBooks = kUseMock ? _kMockBooks : const [];
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
    if (!kUseMock && kIsWeb) _loadGlobalBooks();
  }

  Future<void> _loadGlobalBooks() async {
    try {
      final rows = await Supabase.instance.client
          .from('global_books')
          .select('title, author, publisher')
          .limit(50);
      if (!mounted) return;
      final books = (rows as List).map<_BookData>((r) => _BookData(
        title: r['title'] as String? ?? '',
        author: r['author'] as String? ?? '',
        publisher: r['publisher'] as String? ?? '',
      )).where((b) => b.title.isNotEmpty).toList();
      setState(() {
        _allBooks = books;
        _filteredBooks = books;
      });
    } catch (_) {}
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
        _filteredBooks = _allBooks;
      } else {
        _filteredBooks = _allBooks.where((b) {
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
    setState(() => _filteredBooks = _allBooks);
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
                : const _IdleSearchView(),
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
              onTap: () => HapticFeedback.selectionClick(),
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: '책, 작가, 유저 검색',
                hintStyle: AppTheme.bodyMedium.copyWith(
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

// ─── Idle State ───────────────────────────────────────────────────────────────

class _IdleSearchView extends StatelessWidget {
  const _IdleSearchView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 52, color: context.appTextTertiary),
          const SizedBox(height: 16),
          Text(
            '책, 작가, 유저를 검색해보세요',
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
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
            Icon(Icons.search_off_rounded, size: 52, color: context.appTextTertiary),
            const SizedBox(height: 16),
            Text(
              '검색 결과가 없어요',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '다른 제목이나 저자 이름으로 검색해보세요',
              style: AppTheme.bodySmall.copyWith(
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
        return _BookResultTile(book: books[index], rank: index + 1);
      },
    );
  }
}

// ─── Book Result Tile ─────────────────────────────────────────────────────────

class _BookResultTile extends ConsumerStatefulWidget {
  final _BookData book;
  final int rank;

  const _BookResultTile({required this.book, required this.rank});

  @override
  ConsumerState<_BookResultTile> createState() => _BookResultTileState();
}

class _BookResultTileState extends ConsumerState<_BookResultTile> {
  bool _isPressed = false;

  Future<void> _onAddToLibrary(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final aladinBook = AladinBook(
      title: widget.book.title,
      author: widget.book.author,
      publisher: widget.book.publisher,
    );

    final lib = ref.read(libraryProvider);
    final alreadyIn = lib.any((b) => b.title == aladinBook.title && b.author == aladinBook.author);
    if (alreadyIn) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(chorokSnackBar(
        context,
        '"${aladinBook.title}"은(는) 이미 서재에 있어요',
        success: false,
      ));
      return;
    }

    final status = await showAddToLibrarySheet(context, aladinBook);
    if (status == null || !context.mounted) return;

    addBookAndFetchPages(ref, aladinBook, status);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(chorokSnackBar(
      context,
      '"${aladinBook.title}"을(를) ${readingStatusLabel(status)}에 추가했어요',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = AppTheme.coverGradientByIndex(widget.rank - 1);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: 6,
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
          transform: Matrix4.diagonal3Values(
            _isPressed ? 0.98 : 1.0,
            _isPressed ? 0.98 : 1.0,
            1.0,
          ),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

