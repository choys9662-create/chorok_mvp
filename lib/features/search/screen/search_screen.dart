import 'dart:async';

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../controller/book_search_controller.dart';
import '../controller/user_search_controller.dart';
import '../model/aladin_book.dart';
import '../widget/add_to_library_sheet.dart';

enum _SearchTab { book, author, user }

// ─── 검색 화면 ───────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  _SearchTab _tab = _SearchTab.book;
  UserSearchScope _userScope = UserSearchScope.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _clearActive();
      // 유저 탭의 팔로잉/팔로워는 빈 쿼리에서도 목록 노출
      if (_tab == _SearchTab.user && _userScope != UserSearchScope.all) {
        ref.read(userSearchProvider.notifier).search('', scope: _userScope);
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(value);
    });
  }

  void _runSearch(String q) {
    switch (_tab) {
      case _SearchTab.book:
        ref
            .read(bookSearchProvider.notifier)
            .search(q, type: BookSearchType.keyword);
      case _SearchTab.author:
        ref
            .read(bookSearchProvider.notifier)
            .search(q, type: BookSearchType.author);
      case _SearchTab.user:
        ref.read(userSearchProvider.notifier).search(q, scope: _userScope);
    }
  }

  void _clearActive() {
    if (_tab == _SearchTab.user) {
      ref.read(userSearchProvider.notifier).clear();
    } else {
      ref.read(bookSearchProvider.notifier).clear();
    }
  }

  void _onTabChanged(_SearchTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    // 두 컨트롤러 모두 초기화 후, 현재 입력 있으면 새 탭으로 재검색
    ref.read(bookSearchProvider.notifier).clear();
    ref.read(userSearchProvider.notifier).clear();
    final q = _controller.text.trim();
    if (q.isNotEmpty) {
      _runSearch(q);
    } else if (tab == _SearchTab.user && _userScope != UserSearchScope.all) {
      ref.read(userSearchProvider.notifier).search('', scope: _userScope);
    }
  }

  void _onUserScopeChanged(UserSearchScope scope) {
    if (scope == _userScope) return;
    HapticFeedback.selectionClick();
    setState(() => _userScope = scope);
    ref.read(userSearchProvider.notifier).setScope(scope);
  }

  void _onClear() {
    _controller.clear();
    _clearActive();
    _focusNode.requestFocus();
  }

  Future<void> _onBookTap(AladinBook book) async {
    HapticFeedback.selectionClick();

    // 이미 서재에 있으면 삭제
    final lib = ref.read(libraryProvider);
    final existing = book.isbn13 != null && book.isbn13!.isNotEmpty
        ? lib.where((b) => b.isbn == book.isbn13).firstOrNull
        : null;
    if (existing != null) {
      ref.read(libraryProvider.notifier).deleteBook(existing.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('"${book.title}"을(를) 서재에서 삭제했어요', true),
      );
      return;
    }

    final status = await showAddToLibrarySheet(context, book);
    if (status == null || !mounted) return;

    ref.read(libraryProvider.notifier).addBook(book.toBook(status));

    if (!mounted) return;
    final label = status == ReadingStatus.reading ? '읽는 중' : '읽고 싶어요';

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar('"${book.title}"을(를) $label에 추가했어요', true),
    );
  }

  SnackBar _buildSnackBar(String message, bool success) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_rounded,
            color: success ? context.appPrimaryAccent : context.appTextSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: context.appCardElevated,
      behavior: SnackBarBehavior.floating,
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius(cornerRadius: AppTheme.radiusMD, cornerSmoothing: 0.6),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          SizedBox(height: topPad),
          _SearchBar(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            onClear: _onClear,
            onBarcode: _tab == _SearchTab.user
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    context.push(AppConstants.routeBarcode);
                  },
          ),
          const SizedBox(height: 12),
          _TabBar(current: _tab, onChanged: _onTabChanged),
          if (_tab == _SearchTab.user) ...[
            const SizedBox(height: 8),
            _UserScopeChips(
              current: _userScope,
              onChanged: _onUserScopeChanged,
            ),
          ],
          Expanded(
            child: _tab == _SearchTab.user
                ? _UserResultArea(
                    query: _controller.text,
                    scope: _userScope,
                  )
                : _BookResultArea(
                    query: _controller.text,
                    onTap: _onBookTap,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 탭 바 ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final _SearchTab current;
  final ValueChanged<_SearchTab> onChanged;

  const _TabBar({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_SearchTab.book, '책'),
      (_SearchTab.author, '작가'),
      (_SearchTab.user, '유저'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((e) {
          final isSelected = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: AppTheme.smoothPill(
                  color: isSelected
                      ? context.appPrimaryAccent
                      : context.appCard,
                  side: BorderSide(
                    color: isSelected
                        ? context.appPrimaryAccent
                        : context.appBorder,
                  ),
                ),
                child: Text(
                  e.$2,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 유저 탭 하위 칩 (전체 / 팔로잉 / 팔로워) ──────────────────────────────

class _UserScopeChips extends StatelessWidget {
  final UserSearchScope current;
  final ValueChanged<UserSearchScope> onChanged;

  const _UserScopeChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (UserSearchScope.all, '전체'),
      (UserSearchScope.following, '팔로잉'),
      (UserSearchScope.followers, '팔로워'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: items.map((e) {
          final isSelected = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: AppTheme.smoothPill(
                  color: isSelected
                      ? context.appPrimaryAccent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  side: BorderSide(
                    color: isSelected
                        ? context.appPrimaryAccent
                        : context.appBorder,
                  ),
                ),
                child: Text(
                  e.$2,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? context.appPrimaryAccent
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── 책/작가 결과 영역 ────────────────────────────────────────────────────

class _BookResultArea extends ConsumerWidget {
  final String query;
  final Future<void> Function(AladinBook) onTap;

  const _BookResultArea({required this.query, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookSearchProvider);
    return state.when(
      loading: () => const _ShimmerList(),
      error: (error, _) => _ErrorView(
        message: error.toString().replaceFirst('Exception: ', ''),
        onRetry: () =>
            ref.read(bookSearchProvider.notifier).search(query),
      ),
      data: (books) {
        if (query.trim().isEmpty) return const _IdlePrompt();
        if (books.isEmpty) return _EmptyResult(query: query.trim());
        return _ResultList(books: books, onTap: onTap);
      },
    );
  }
}

// ─── 유저 결과 영역 ───────────────────────────────────────────────────────

class _UserResultArea extends ConsumerWidget {
  final String query;
  final UserSearchScope scope;

  const _UserResultArea({required this.query, required this.scope});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userSearchProvider);
    return state.when(
      loading: () => const _ShimmerList(),
      error: (error, _) => _ErrorView(
        message: error.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref
            .read(userSearchProvider.notifier)
            .search(query, scope: scope),
      ),
      data: (users) {
        if (users.isEmpty) {
          if (scope == UserSearchScope.all && query.trim().isEmpty) {
            return const _UserIdlePrompt();
          }
          return _UserEmptyResult(scope: scope, query: query.trim());
        }
        return _UserResultList(users: users);
      },
    );
  }
}

// ─── 유저 결과 리스트 ────────────────────────────────────────────────────

class _UserResultList extends StatelessWidget {
  final List<UserProfile> users;
  const _UserResultList({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _UserCard(profile: users[i]),
    );
  }
}

class _UserCard extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _UserCard({required this.profile});

  @override
  ConsumerState<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends ConsumerState<_UserCard> {
  bool? _isFollowing;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  Future<void> _loadFollowState() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null || me == widget.profile.id) return;
    final following =
        await ref.read(followRepositoryProvider).isFollowing(widget.profile.id);
    if (!mounted) return;
    setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      if (_isFollowing == true) {
        await repo.unfollow(widget.profile.id);
        if (!mounted) return;
        setState(() => _isFollowing = false);
      } else {
        await repo.follow(widget.profile.id);
        if (!mounted) return;
        setState(() => _isFollowing = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isMe = me == p.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: context.appCardElevated,
            backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                ? NetworkImage(p.avatarUrl!)
                : null,
            child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                ? Icon(Icons.person_rounded,
                    color: context.appTextTertiary, size: 22)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${p.username}',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: context.appTextTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.bio != null && p.bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.bio!,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      color: context.appTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 8),
            _FollowButton(
              isFollowing: _isFollowing ?? false,
              loaded: _isFollowing != null,
              busy: _busy,
              onTap: _toggleFollow,
            ),
          ],
        ],
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final bool loaded;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.isFollowing,
    required this.loaded,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SizedBox(width: 72, height: 32);
    }
    final label = isFollowing ? '팔로잉' : '팔로우';
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: AppTheme.smoothBox(
            color: isFollowing ? context.appCardElevated : context.appPrimaryAccent,
            radius: AppTheme.radiusSM,
            side: BorderSide(
              color: isFollowing ? context.appBorder : context.appPrimaryAccent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFollowing ? context.appTextSecondary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 유저 탭 빈 상태 ─────────────────────────────────────────────────────

class _UserIdlePrompt extends StatelessWidget {
  const _UserIdlePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded,
              color: context.appTextTertiary, size: 48),
          const SizedBox(height: 16),
          Text(
            '유저를 검색해보세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '닉네임 · 사용자 이름으로 찾을 수 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserEmptyResult extends StatelessWidget {
  final UserSearchScope scope;
  final String query;

  const _UserEmptyResult({required this.scope, required this.query});

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (scope) {
      UserSearchScope.all => (
          query.isEmpty ? '유저를 검색해보세요' : '"$query"',
          '검색 결과가 없어요',
        ),
      UserSearchScope.following => (
          query.isEmpty ? '아직 팔로우하는 유저가 없어요' : '"$query"',
          query.isEmpty
              ? '관심 있는 사용자를 팔로우해보세요'
              : '팔로잉 중에서 결과가 없어요',
        ),
      UserSearchScope.followers => (
          query.isEmpty ? '아직 팔로워가 없어요' : '"$query"',
          query.isEmpty
              ? '활동을 통해 팔로워를 모아보세요'
              : '팔로워 중에서 결과가 없어요',
        ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                color: context.appTextTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                color: context.appTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 검색 바 ─────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onBarcode;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.onBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // 뒤로가기
          Semantics(
            button: true,
            label: '뒤로가기',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 검색 필드
          Expanded(
            child: Container(
              height: 48,
              decoration: AppTheme.smoothBox(
                color: context.appCard,
                radius: AppTheme.radiusMD,
                side: BorderSide(color: context.appBorder, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: context.appTextTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: context.appTextPrimary,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '제목, 저자, 키워드 검색',
                        hintStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: context.appTextTertiary,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      cursorColor: context.appPrimaryAccent,
                    ),
                  ),
                  // 지우기 버튼
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (_, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: onClear,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.cancel_rounded,
                            color: context.appTextTertiary,
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (onBarcode != null) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'ISBN 바코드 스캔',
              child: GestureDetector(
                onTap: onBarcode,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: context.appCard,
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(cornerRadius: AppTheme.radiusMD, cornerSmoothing: 0.6),
                      side: BorderSide(color: context.appBorder),
                    ),
                  ),
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: context.appTextSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 결과 리스트 ──────────────────────────────────────────────────────────────

class _ResultList extends StatelessWidget {
  final List<AladinBook> books;
  final Future<void> Function(AladinBook) onTap;

  const _ResultList({required this.books, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) => _BookCard(
        book: books[index],
        onTap: onTap,
      ),
    );
  }
}

// ─── 책 결과 카드 ─────────────────────────────────────────────────────────────

class _BookCard extends ConsumerWidget {
  final AladinBook book;
  final Future<void> Function(AladinBook) onTap;

  const _BookCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInLibrary = ref.watch(
      libraryProvider.select((books) => books.any(
            (b) => book.isbn13 != null &&
                book.isbn13!.isNotEmpty &&
                b.isbn == book.isbn13,
          )),
    );

    return Semantics(
      label: '${book.title}, ${book.author}',
      child: Container(
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusLG,
          side: BorderSide(color: context.appBorder, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 표지 이미지
            _CoverImage(
              coverUrl: book.coverUrl,
              title: book.title,
            ),
            const SizedBox(width: 16),

            // 책 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: context.appTextSecondary,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.publisher,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: context.appTextTertiary,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // 서재 추가 버튼
                  Align(
                    alignment: Alignment.centerRight,
                    child: _AddButton(
                      isInLibrary: isInLibrary,
                      onTap: () => onTap(book),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 표지 이미지 ──────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  final String? coverUrl;
  final String title;

  const _CoverImage({required this.coverUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    final gradientIndex = title.codeUnitAt(0) % AppTheme.coverGradients.length;
    final colors = AppTheme.coverGradients[gradientIndex];

    return Container(
      width: 72,
      height: 104,
      decoration: AppTheme.smoothBox(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        radius: AppTheme.radiusSM,
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null && coverUrl!.isNotEmpty
          ? Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _PlaceholderCover(title: title),
            )
          : _PlaceholderCover(title: title),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final String title;

  const _PlaceholderCover({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        title.length > 6 ? '${title.substring(0, 6)}...' : title,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.appTextPrimary,
          height: 1.4,
        ),
        maxLines: 4,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

// ─── 서재 추가 버튼 ───────────────────────────────────────────────────────────

class _AddButton extends StatefulWidget {
  final bool isInLibrary;
  final VoidCallback onTap;

  const _AddButton({required this.isInLibrary, required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isInLibrary) {
      return Semantics(
        button: true,
        label: '서재에서 삭제',
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: AppTheme.smoothBox(
              color: context.appCardElevated,
              radius: AppTheme.radiusSM,
              side: BorderSide(color: context.appBorder, width: 1),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_rounded,
                  color: context.appPrimaryAccent,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  '서재에 있어요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.appPrimaryAccent,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '서재에 추가',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: AppTheme.smoothBox(
              gradient: AppTheme.greenGradient,
              radius: AppTheme.radiusSM,
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: AppTheme.darkBg, size: 14),
                SizedBox(width: 4),
                Text(
                  '서재에 추가',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.darkBg,
                    height: 1.4,
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

// ─── 로딩 shimmer ─────────────────────────────────────────────────────────────

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) {
        final opacity = 0.3 + _anim.value * 0.3;
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => _ShimmerCard(opacity: opacity),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double opacity;

  const _ShimmerCard({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 136,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 표지 플레이스홀더
          _ShimmerBox(width: 72, height: 104, opacity: opacity, radius: AppTheme.radiusSM),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(width: double.infinity, height: 16, opacity: opacity, radius: 4),
                const SizedBox(height: 8),
                _ShimmerBox(width: 120, height: 13, opacity: opacity, radius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(width: 80, height: 12, opacity: opacity, radius: 4),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ShimmerBox(width: 88, height: 32, opacity: opacity, radius: AppTheme.radiusSM),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double opacity;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.opacity,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appCardElevated.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── 초기 프롬프트 ────────────────────────────────────────────────────────────

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, color: context.appTextTertiary, size: 48),
          const SizedBox(height: 16),
          Text(
            '읽고 싶은 책을 검색해보세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.appTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '제목, 저자, 키워드로 찾을 수 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: context.appTextTertiary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 검색 결과 없음 ───────────────────────────────────────────────────────────

class _EmptyResult extends StatelessWidget {
  final String query;

  const _EmptyResult({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: context.appTextTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '"$query"',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '검색 결과가 없어요\n다른 키워드로 찾아보세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.appTextSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 에러 상태 ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.appTextTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '검색에 실패했어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: context.appTextSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: '다시 시도',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: AppTheme.smoothBox(
                    gradient: AppTheme.greenGradient,
                    radius: AppTheme.radiusMD,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkBg,
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
