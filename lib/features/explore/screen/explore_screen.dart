import 'dart:async';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../search/controller/book_search_controller.dart';
import '../../search/model/aladin_book.dart';
import '../../search/util/add_book_flow.dart';
import '../../search/widget/add_to_library_sheet.dart';
import '../../../shared/widgets/book_cover.dart';

// ─── Main Screen ─────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;
  late final FocusNode _searchFocusNode;
  Timer? _debounce;

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
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ref.read(bookSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(bookSearchProvider.notifier).search(query);
    });
  }

  void _dismissSearch() {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = _searchController.text.isNotEmpty;
    final topPad = MediaQuery.of(context).padding.top;
    final searchState = ref.watch(bookSearchProvider);

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
                ? _SearchResultsView(
                    state: searchState,
                    query: _searchController.text,
                  )
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
        side: BorderSide.none,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
  final AsyncValue<List<AladinBook>> state;
  final String query;

  const _SearchResultsView({required this.state, required this.query});

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: AppTheme.bodySmall.copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (books) {
        if (books.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 52,
                  color: context.appTextTertiary,
                ),
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
          itemBuilder: (context, index) =>
              _BookResultTile(book: books[index], rank: index + 1),
        );
      },
    );
  }
}

// ─── Book Result Tile ─────────────────────────────────────────────────────────

class _BookResultTile extends ConsumerStatefulWidget {
  final AladinBook book;
  final int rank;

  const _BookResultTile({required this.book, required this.rank});

  @override
  ConsumerState<_BookResultTile> createState() => _BookResultTileState();
}

class _BookResultTileState extends ConsumerState<_BookResultTile> {
  bool _isPressed = false;
  bool _btnPressed = false;

  Future<void> _onAddToLibrary(BuildContext context) async {
    HapticFeedback.mediumImpact();

    final lib = ref.read(libraryProvider);
    final alreadyIn =
        widget.book.isbn13 != null && widget.book.isbn13!.isNotEmpty
        ? lib.any((b) => b.isbn == widget.book.isbn13)
        : lib.any(
            (b) =>
                b.title == widget.book.title && b.author == widget.book.author,
          );

    if (alreadyIn) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(
          context,
          '"${widget.book.title}"은(는) 이미 서재에 있어요',
          success: false,
        ),
      );
      return;
    }

    final status = await showAddToLibrarySheet(context, widget.book);
    if (status == null || !context.mounted) return;

    addBookAndFetchPages(ref, widget.book, status);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      chorokSnackBar(
        context,
        '"${widget.book.title}"을(를) ${readingStatusLabel(status)}에 추가했어요',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final isAdded = widget.book.isbn13 != null && widget.book.isbn13!.isNotEmpty
        ? lib.any((b) => b.isbn == widget.book.isbn13)
        : lib.any(
            (b) =>
                b.title == widget.book.title && b.author == widget.book.author,
          );

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
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BookCover(
                coverUrl: widget.book.coverUrl,
                gradientIndex: widget.rank - 1,
                width: 44,
                height: 60,
                radius: 8,
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
                label: isAdded
                    ? '${widget.book.title} 서재에 추가됨'
                    : '${widget.book.title} 서재에 추가',
                button: true,
                child: GestureDetector(
                  onTapDown: isAdded
                      ? null
                      : (_) => setState(() => _btnPressed = true),
                  onTapUp: isAdded
                      ? null
                      : (_) {
                          setState(() => _btnPressed = false);
                          _onAddToLibrary(context);
                        },
                  onTapCancel: isAdded
                      ? null
                      : () => setState(() => _btnPressed = false),
                  child: AnimatedScale(
                    scale: _btnPressed ? 0.92 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: isAdded
                            ? AppTheme.accent.withValues(alpha: 0.1)
                            : _btnPressed
                            ? AppTheme.accent.withValues(alpha: 0.15)
                            : context.appCardElevated,
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 8,
                            cornerSmoothing: 0.6,
                          ),
                          side: BorderSide.none,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: 0,
                            child: Text(
                              '서재에 추가',
                              style: AppTheme.captionSmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isAdded)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: AppTheme.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '추가됨',
                                  style: AppTheme.captionSmall.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '서재에 추가',
                              style: AppTheme.captionSmall.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
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
