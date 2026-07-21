import 'dart:async';

import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../search/controller/book_search_controller.dart';
import '../../search/controller/user_search_controller.dart';
import '../../search/model/aladin_book.dart';
import '../../search/util/add_book_flow.dart';
import '../../search/widget/add_to_library_sheet.dart';
import '../../../shared/widgets/book_cover.dart';
import '../widget/discovery_view.dart';

enum _ExploreSearchTab { book, author, user }

// ─── Main Screen ─────────────────────────────────────────────────────────────

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchFocused = false;
  _ExploreSearchTab _selectedTab = _ExploreSearchTab.book;
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
      ref.read(userSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(query);
    });
  }

  void _runSearch(String query) {
    switch (_selectedTab) {
      case _ExploreSearchTab.book:
        ref
            .read(bookSearchProvider.notifier)
            .search(query, type: BookSearchType.keyword);
      case _ExploreSearchTab.author:
        ref
            .read(bookSearchProvider.notifier)
            .search(query, type: BookSearchType.author);
      case _ExploreSearchTab.user:
        ref.read(userSearchProvider.notifier).search(query);
    }
  }

  void _onTabChanged(_ExploreSearchTab tab) {
    if (tab == _selectedTab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = tab);
    ref.read(bookSearchProvider.notifier).clear();
    ref.read(userSearchProvider.notifier).clear();
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _runSearch(query);
    }
  }

  void _dismissSearch() {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    _searchController.clear();
  }

  void _onBookNavigate(AladinBook book) {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    context.push(AppConstants.routeBookInfo, extra: book);
  }

  void _onUserNavigate(UserProfile profile) {
    HapticFeedback.selectionClick();
    _searchFocusNode.unfocus();
    context.push(AppConstants.routeUserProfile, extra: profile);
  }

  /// 디스커버리에서 항목을 탭하면 해당 탭으로 전환 후 즉시 검색한다.
  void _searchFromDiscovery(String query, _ExploreSearchTab tab) {
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = tab);
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _searchFocusNode.requestFocus();
    _debounce?.cancel();
    _runSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearchActive = _searchController.text.isNotEmpty;
    final topPad = MediaQuery.of(context).padding.top;
    final searchState = ref.watch(bookSearchProvider);
    final userState = ref.watch(userSearchProvider);

    return Scaffold(
      backgroundColor: context.appSurface,
      body: Column(
        children: [
          SizedBox(height: topPad),
          _AppBarArea(
            searchController: _searchController,
            focusNode: _searchFocusNode,
            isSearchFocused: _isSearchFocused,
            selectedTab: _selectedTab,
            onTabChanged: _onTabChanged,
            onDismiss: _dismissSearch,
          ),
          Expanded(
            child: isSearchActive
                ? _SearchResultsView(
                    tab: _selectedTab,
                    state: searchState,
                    userState: userState,
                    query: _searchController.text,
                    onNavigate: _onBookNavigate,
                    onUserNavigate: _onUserNavigate,
                  )
                : DiscoveryView(
                    onBookNavigate: _onBookNavigate,
                    onAuthorTap: (author) =>
                        _searchFromDiscovery(author, _ExploreSearchTab.author),
                    onTitleTap: (title) =>
                        _searchFromDiscovery(title, _ExploreSearchTab.book),
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
  final _ExploreSearchTab selectedTab;
  final ValueChanged<_ExploreSearchTab> onTabChanged;
  final VoidCallback onDismiss;

  const _AppBarArea({
    required this.searchController,
    required this.focusNode,
    required this.isSearchFocused,
    required this.selectedTab,
    required this.onTabChanged,
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
          // 탭 루트(쉘 브랜치)에서는 pop 대상이 없어 뒤로가기를 숨긴다.
          // 다른 화면에서 push로 진입했을 때만 노출.
          if (Navigator.of(context).canPop())
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
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: context.appTextPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          _SearchBar(
            controller: searchController,
            focusNode: focusNode,
            isSearchFocused: isSearchFocused,
            selectedTab: selectedTab,
            onDismiss: onDismiss,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          _SearchTabBar(current: selectedTab, onChanged: onTabChanged),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

// ─── Search Tabs ─────────────────────────────────────────────────────────────

class _SearchTabBar extends StatelessWidget {
  final _ExploreSearchTab current;
  final ValueChanged<_ExploreSearchTab> onChanged;

  const _SearchTabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_ExploreSearchTab.book, '책'),
      (_ExploreSearchTab.author, '작가'),
      (_ExploreSearchTab.user, '유저'),
    ];

    return Row(
      children: [
        for (final item in items) ...[
          _SearchTabChip(
            label: item.$2,
            isSelected: item.$1 == current,
            onTap: () => onChanged(item.$1),
          ),
          if (item != items.last) const SizedBox(width: AppTheme.spaceSM),
        ],
      ],
    );
  }
}

class _SearchTabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SearchTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label 검색',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 34,
          constraints: const BoxConstraints(minWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
          alignment: Alignment.center,
          decoration: AppTheme.smoothPill(
            color: context.appCard,
            side: BorderSide(
              color: isSelected
                  ? AppTheme.accent
                  : context.appTextTertiary.withValues(alpha: 0.18),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.captionSmall.copyWith(
              color: isSelected ? AppTheme.accent : context.appTextSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSearchFocused;
  final _ExploreSearchTab selectedTab;
  final VoidCallback onDismiss;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.isSearchFocused,
    required this.selectedTab,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final hintText = switch (selectedTab) {
      _ExploreSearchTab.book => '책 제목, 키워드 검색',
      _ExploreSearchTab.author => '작가 이름 검색',
      _ExploreSearchTab.user => '유저 이름 검색',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 48,
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusOuter,
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
          const SizedBox(width: AppTheme.spaceLG),
          Icon(
            Icons.search_rounded,
            size: 20,
            color: isSearchFocused ? AppTheme.accent : context.appTextTertiary,
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onTap: () => HapticFeedback.selectionClick(),
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: context.appTextTertiary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spaceSM,
                  horizontal: AppTheme.spaceMD,
                ),
              ),
            ),
          ),
          // 지우기 버튼 — 텍스트만 지우고 포커스는 유지한다(search_screen.dart와 동일 패턴).
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return Semantics(
                button: true,
                label: '검색어 지우기',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.clear();
                    focusNode.requestFocus();
                  },
                  child: Icon(
                    Icons.cancel_rounded,
                    color: context.appTextTertiary,
                    size: 18,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppTheme.spaceLG),
        ],
      ),
    );
  }
}

// ─── Search Results View ──────────────────────────────────────────────────────

class _SearchResultsView extends StatelessWidget {
  final _ExploreSearchTab tab;
  final AsyncValue<List<AladinBook>> state;
  final AsyncValue<List<UserProfile>> userState;
  final String query;
  final void Function(AladinBook) onNavigate;
  final void Function(UserProfile) onUserNavigate;

  const _SearchResultsView({
    required this.tab,
    required this.state,
    required this.userState,
    required this.query,
    required this.onNavigate,
    required this.onUserNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final books = state.value ?? const <AladinBook>[];
    final users = userState.value ?? const <UserProfile>[];
    final activeState = tab == _ExploreSearchTab.user ? userState : state;
    final activeResults = tab == _ExploreSearchTab.user ? users : books;
    final title = switch (tab) {
      _ExploreSearchTab.book => '책',
      _ExploreSearchTab.author => '작가',
      _ExploreSearchTab.user => '유저',
    };
    final emptyHint = switch (tab) {
      _ExploreSearchTab.book => '다른 책 제목이나 키워드로 검색해보세요',
      _ExploreSearchTab.author => '다른 작가 이름으로 검색해보세요',
      _ExploreSearchTab.user => '다른 닉네임이나 사용자 이름으로 검색해보세요',
    };

    if (activeState.isLoading && activeResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (activeState.hasError && activeResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            activeState.error.toString().replaceFirst('Exception: ', ''),
            style: AppTheme.bodySmall.copyWith(color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (activeResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: context.appTextTertiary,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              '검색 결과가 없어요',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              emptyHint,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 8, bottom: 48),
      children: [
        if (tab == _ExploreSearchTab.user) ...[
          _ResultSectionHeader(title: title, count: users.length),
          for (var i = 0; i < users.length; i++)
            _UserResultTile(profile: users[i], onNavigate: onUserNavigate),
        ] else ...[
          _ResultSectionHeader(title: title, count: books.length),
          for (var i = 0; i < books.length; i++)
            _BookResultTile(
              book: books[i],
              rank: i + 1,
              onNavigate: onNavigate,
            ),
        ],
      ],
    );
  }
}

class _ResultSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _ResultSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        12,
        AppTheme.screenPadding,
        6,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: AppTheme.captionSmall.copyWith(color: AppTheme.accent),
          ),
        ],
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  final UserProfile profile;
  final void Function(UserProfile) onNavigate;

  const _UserResultTile({required this.profile, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: 6,
      ),
      child: GestureDetector(
        onTap: () => onNavigate(profile),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusOuter,
            side: BorderSide.none,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.appCardElevated,
                backgroundImage:
                    profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                    ? NetworkImage(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null || profile.avatarUrl!.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        color: context.appTextTertiary,
                        size: 24,
                      )
                    : null,
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      '@${profile.username}',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceXS),
                      Text(
                        profile.bio!,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Icon(
                Icons.chevron_right_rounded,
                color: context.appTextTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Book Result Tile ─────────────────────────────────────────────────────────

class _BookResultTile extends ConsumerStatefulWidget {
  final AladinBook book;
  final int rank;
  final void Function(AladinBook) onNavigate;

  const _BookResultTile({
    required this.book,
    required this.rank,
    required this.onNavigate,
  });

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
        onTap: () => widget.onNavigate(widget.book),
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
            radius: AppTheme.radiusOuter,
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Row(
            children: [
              BookCover(
                coverUrl: widget.book.coverUrl,
                gradientIndex: widget.rank - 1,
                width: 44,
                height: 60,
                radius: AppTheme.radiusInner,
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppTheme.spaceXS,
                  children: [
                    Text(
                      widget.book.title,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
              const SizedBox(width: AppTheme.spaceSM),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD,
                      ),
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
                          smoothness: 0.6,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInner,
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
                                fontWeight: FontWeight.w400,
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
                                const SizedBox(width: AppTheme.spaceXS),
                                Text(
                                  '추가됨',
                                  style: AppTheme.captionSmall.copyWith(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '서재에 추가',
                              style: AppTheme.captionSmall.copyWith(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w400,
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
