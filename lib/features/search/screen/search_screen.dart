import 'dart:async';

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
import '../../../shared/utils/follow_relationship_text.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../controller/book_search_controller.dart';
import '../controller/user_search_controller.dart';
import '../util/add_book_flow.dart';
import '../model/aladin_book.dart';
import '../widget/add_to_library_sheet.dart';
import '../../../shared/widgets/book_cover.dart';

enum _SearchTab { book, author, user }

const _searchErrorMessage = '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';

// ─── 검색 화면 ───────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  final Book? replacingBook;

  const SearchScreen({super.key, this.replacingBook});

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
      final replacingBook = widget.replacingBook;
      if (replacingBook != null) {
        _controller.text = replacingBook.title;
        ref
            .read(bookSearchProvider.notifier)
            .search(replacingBook.title, type: BookSearchType.title);
      }
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

  Future<void> _onBookAdd(AladinBook book) async {
    HapticFeedback.selectionClick();

    final replacingBook = widget.replacingBook;
    if (replacingBook != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('책 버전 변경'),
          content: Text(
            '\'${replacingBook.title}\'을(를)\n\'${book.title}\' 버전으로 변경할까요?\n\n독서 진행과 기록은 유지됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('변경'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref
          .read(libraryProvider.notifier)
          .replaceBookVersion(
            replacingBook.id,
            book.toBook(replacingBook.status),
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.pop(book.title);
      return;
    }

    // 이미 서재에 있으면 삭제 — 파괴적 동작이므로 확인을 거친다.
    final lib = ref.read(libraryProvider);
    final existing = book.isbn13 != null && book.isbn13!.isNotEmpty
        ? lib.where((b) => b.isbn == book.isbn13).firstOrNull
        : lib
              .where((b) => b.title == book.title && b.author == book.author)
              .firstOrNull;
    if (existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('서재에서 제거'),
          content: Text(
            '\'${book.title}\'을(를) 서재에서 제거할까요?\n기록된 독서 데이터도 함께 삭제됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.warningColor,
              ),
              child: const Text('제거'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      ref.read(libraryProvider.notifier).deleteBook(existing.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '"${book.title}"을(를) 서재에서 삭제했어요'));
      return;
    }

    final status = await showAddToLibrarySheet(context, book);
    if (status == null || !mounted) return;

    final added = addBookAndFetchPages(ref, book, status);

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      chorokSnackBar(
        context,
        added
            ? '"${book.title}"을(를) ${readingStatusLabel(status)}에 추가했어요'
            : '"${book.title}"은(는) 이미 서재에 있어요',
        success: added,
      ),
    );
  }

  void _onBookNavigate(AladinBook book) {
    HapticFeedback.selectionClick();
    context.push(AppConstants.routeBookInfo, extra: book);
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
          const SizedBox(height: AppTheme.spaceMD),
          _TabBar(current: _tab, onChanged: _onTabChanged),
          if (_tab == _SearchTab.user) ...[
            const SizedBox(height: AppTheme.spaceSM),
            _UserScopeChips(
              current: _userScope,
              onChanged: _onUserScopeChanged,
            ),
          ],
          Expanded(
            child: _tab == _SearchTab.user
                ? _UserResultArea(query: _controller.text, scope: _userScope)
                : _BookResultArea(
                    query: _controller.text,
                    onAdd: _onBookAdd,
                    onNavigate: _onBookNavigate,
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: items.map((e) {
          final isSelected = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spaceSM),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: SizedBox(
                height: AppTheme.spaceXL + AppTheme.spaceMD,
                child: ChorokCard(
                  showBorder: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLG,
                  ),
                  backgroundColor: isSelected
                      ? context.appPrimaryAccent
                      : context.appCard,
                  child: Center(
                    child: Text(
                      e.$2,
                      style: AppTheme.supportingText.copyWith(
                        color: isSelected
                            ? AppTheme.darkBg
                            : context.appTextSecondary,
                      ),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: Row(
        children: items.map((e) {
          final isSelected = e.$1 == current;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spaceXS),
            child: GestureDetector(
              onTap: () => onChanged(e.$1),
              child: SizedBox(
                height: AppTheme.spaceXL + AppTheme.spaceXS,
                child: ChorokCard(
                  inner: true,
                  showBorder: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  backgroundColor: isSelected
                      ? context.appPrimaryAccent.withValues(alpha: 0.12)
                      : context.appBg,
                  child: Center(
                    child: Text(
                      e.$2,
                      style: AppTheme.supportingText.copyWith(
                        color: isSelected
                            ? context.appPrimaryAccent
                            : context.appTextSecondary,
                      ),
                    ),
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
  final Future<void> Function(AladinBook) onAdd;
  final void Function(AladinBook) onNavigate;

  const _BookResultArea({
    required this.query,
    required this.onAdd,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookSearchProvider);
    return state.when(
      loading: () => const _ShimmerList(),
      error: (_, _) => _ErrorView(
        message: _searchErrorMessage,
        onRetry: () => ref.read(bookSearchProvider.notifier).search(query),
      ),
      data: (books) {
        if (query.trim().isEmpty) return const _IdlePrompt();
        if (books.isEmpty) return _EmptyResult(query: query.trim());
        return _ResultList(books: books, onAdd: onAdd, onNavigate: onNavigate);
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
      error: (_, _) => _ErrorView(
        message: _searchErrorMessage,
        onRetry: () =>
            ref.read(userSearchProvider.notifier).search(query, scope: scope),
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
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceMD,
        AppTheme.screenPadding,
        AppTheme.sectionGap,
      ),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceSM),
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
  FollowRelationship? _relationship;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRelationship();
  }

  Future<void> _loadRelationship() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null || me == widget.profile.id) return;
    final relationship = await ref
        .read(followRepositoryProvider)
        .relationshipWith(widget.profile.id);
    if (!mounted) return;
    setState(() => _relationship = relationship);
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      final current = _relationship ?? FollowRelationship.none;
      if (current.outgoing != FollowState.none) {
        await repo.unfollow(widget.profile.id);
        if (!mounted) return;
        setState(
          () => _relationship = current.copyWith(outgoing: FollowState.none),
        );
      } else {
        final result = await repo.follow(widget.profile.id);
        if (!mounted) return;
        setState(() => _relationship = current.copyWith(outgoing: result));
      }
      ref.read(followMutationVersionProvider.notifier).state++;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final me = Supabase.instance.client.auth.currentUser?.id;
    final isMe = me == p.id;
    final hint = followRelationshipHint(
      _relationship ?? FollowRelationship.none,
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppConstants.routeUserProfile, extra: p);
      },
      child: ChorokCard(
        child: ChorokListRow(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: context.appCardElevated,
            backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
                ? NetworkImage(p.avatarUrl!)
                : null,
            child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
                ? Icon(
                    Icons.person_rounded,
                    color: context.appTextTertiary,
                    size: 22,
                  )
                : null,
          ),
          title: Text(
            p.displayName,
            style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          supporting: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${p.username}',
                style: AppTheme.supportingText.copyWith(
                  color: context.appTextTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hint != null) ...[
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  hint,
                  style: AppTheme.supportingText.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (p.bio != null && p.bio!.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  p.bio!,
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
          trailing: isMe
              ? null
              : _FollowButton(
                  relationship: _relationship ?? FollowRelationship.none,
                  loaded: _relationship != null,
                  busy: _busy,
                  onTap: _toggleFollow,
                ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final FollowRelationship relationship;
  final bool loaded;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.relationship,
    required this.loaded,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SizedBox(width: 72, height: 32);
    }
    final label = followActionLabel(relationship);
    final filled = followActionIsFilled(relationship);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 32,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
            backgroundColor: filled
                ? context.appPrimaryAccent
                : context.appCardElevated,
            child: Center(
              child: Text(
                label,
                style: AppTheme.supportingText.copyWith(
                  color: filled ? AppTheme.darkBg : context.appTextSecondary,
                ),
              ),
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
          Icon(
            Icons.people_outline_rounded,
            color: context.appTextTertiary,
            size: 48,
          ),
          const SizedBox(height: AppTheme.spaceLG),
          Text(
            '유저를 검색해보세요',
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '닉네임 · 사용자 이름으로 찾을 수 있어요',
            style: AppTheme.supportingText.copyWith(
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
        query.isEmpty ? '관심 있는 사용자를 팔로우해보세요' : '팔로잉 중에서 결과가 없어요',
      ),
      UserSearchScope.followers => (
        query.isEmpty ? '아직 팔로워가 없어요' : '"$query"',
        query.isEmpty ? '활동을 통해 팔로워를 모아보세요' : '팔로워 중에서 결과가 없어요',
      ),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.sectionGap),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: context.appTextTertiary,
              size: 48,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              title,
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              sub,
              style: AppTheme.supportingText.copyWith(
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
      padding: const EdgeInsets.only(
        left: AppTheme.screenPadding,
        top: AppTheme.spaceSM,
        right: AppTheme.screenPadding,
      ),
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
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: context.appTextSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceXS),

          // 검색 필드
          Expanded(
            child: SizedBox(
              height: 48,
              child: ChorokCard(
                showBorder: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLG,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: context.appTextTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: onChanged,
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '제목, 저자, 키워드 검색',
                          hintStyle: AppTheme.rowText.copyWith(
                            color: context.appTextTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceSM,
                            horizontal: AppTheme.spaceSM,
                          ),
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
                            padding: const EdgeInsets.only(
                              left: AppTheme.spaceSM,
                            ),
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
          ),
          if (onBarcode != null) ...[
            const SizedBox(width: AppTheme.spaceSM),
            Semantics(
              button: true,
              label: 'ISBN 바코드 스캔',
              child: GestureDetector(
                onTap: onBarcode,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: ChorokCard(
                    showBorder: false,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: context.appTextSecondary,
                        size: 22,
                      ),
                    ),
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
  final Future<void> Function(AladinBook) onAdd;
  final void Function(AladinBook) onNavigate;

  const _ResultList({
    required this.books,
    required this.onAdd,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.screenPadding,
        AppTheme.screenPadding,
        AppTheme.sectionGap,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: books.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMD),
      itemBuilder: (_, index) =>
          _BookCard(book: books[index], onAdd: onAdd, onNavigate: onNavigate),
    );
  }
}

// ─── 책 결과 카드 ─────────────────────────────────────────────────────────────

class _BookCard extends ConsumerWidget {
  final AladinBook book;
  final Future<void> Function(AladinBook) onAdd;
  final void Function(AladinBook) onNavigate;

  const _BookCard({
    required this.book,
    required this.onAdd,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInLibrary = ref.watch(
      libraryProvider.select((books) {
        if (book.isbn13 != null && book.isbn13!.isNotEmpty) {
          return books.any((b) => b.isbn == book.isbn13);
        }
        return books.any(
          (b) => b.title == book.title && b.author == book.author,
        );
      }),
    );

    return Semantics(
      label: '${book.title}, ${book.author}',
      child: GestureDetector(
        onTap: () => onNavigate(book),
        child: ChorokCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 표지 이미지
              _CoverImage(coverUrl: book.coverUrl, title: book.title),
              const SizedBox(width: AppTheme.spaceLG),

              // 책 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppTheme.spaceXS,
                  children: [
                    Text(
                      book.title,
                      style: AppTheme.rowText.copyWith(
                        color: context.appTextPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.author,
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      book.publisher,
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),

              // + / ✓ 아이콘 버튼
              _AddButton(isInLibrary: isInLibrary, onTap: () => onAdd(book)),
            ],
          ),
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
    final url = normalizedCoverUrl(coverUrl);
    return SizedBox(
      width: 72,
      height: 104,
      child: ChorokCard(
        inner: true,
        showBorder: false,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.appPrimaryAccent, context.appAccentColor],
        ),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _PlaceholderCover(title: title),
              )
            : _PlaceholderCover(title: title),
      ),
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  final String title;

  const _PlaceholderCover({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceSM),
      child: Text(
        title.length > 6 ? '${title.substring(0, 6)}...' : title,
        style: AppTheme.supportingText.copyWith(color: context.appTextPrimary),
        maxLines: 4,
        overflow: TextOverflow.clip,
      ),
    );
  }
}

// ─── 서재 추가 버튼 (아이콘 전용) ────────────────────────────────────────────

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
    final isIn = widget.isInLibrary;

    return Semantics(
      button: true,
      label: isIn ? '서재에서 삭제' : '서재에 추가',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: SizedBox(
              key: ValueKey(isIn),
              width: 34,
              height: 34,
              child: ChorokCard(
                inner: true,
                showBorder: false,
                padding: EdgeInsets.zero,
                backgroundColor: isIn ? context.appCardElevated : null,
                gradient: isIn ? null : AppTheme.greenGradient,
                child: Icon(
                  isIn ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                  color: isIn ? context.appPrimaryAccent : AppTheme.darkBg,
                ),
              ),
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
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.screenPadding,
            AppTheme.screenPadding,
            AppTheme.sectionGap,
          ),
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMD),
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
    return SizedBox(
      height: 136,
      child: ChorokCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 표지 플레이스홀더
            _ShimmerBox(
              width: 72,
              height: 104,
              opacity: opacity,
              radius: AppTheme.radiusSM,
            ),
            const SizedBox(width: AppTheme.spaceLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    width: double.infinity,
                    height: 16,
                    opacity: opacity,
                    radius: AppTheme.radiusOuter,
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  _ShimmerBox(
                    width: 120,
                    height: 13,
                    opacity: opacity,
                    radius: AppTheme.radiusOuter,
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  _ShimmerBox(
                    width: 80,
                    height: 12,
                    opacity: opacity,
                    radius: AppTheme.radiusOuter,
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ShimmerBox(
                      width: 88,
                      height: 32,
                      opacity: opacity,
                      radius: AppTheme.radiusSM,
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
    return SizedBox(
      width: width,
      height: height,
      child: ChorokCard(
        inner: true,
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: context.appCardElevated.withValues(alpha: opacity),
        child: const SizedBox.expand(),
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
          const SizedBox(height: AppTheme.spaceLG),
          Text(
            '읽고 싶은 책을 검색해보세요',
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '제목, 저자, 키워드로 찾을 수 있어요',
            style: AppTheme.supportingText.copyWith(
              color: context.appTextTertiary,
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
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: context.appTextTertiary,
              size: 48,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              '"$query"',
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              '검색 결과가 없어요\n다른 키워드로 찾아보세요',
              style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
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
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: context.appTextTertiary,
              size: 48,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              '검색에 실패했어요',
              style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              message,
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.spaceXL),
            Semantics(
              button: true,
              label: '다시 시도',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onRetry();
                },
                child: SizedBox(
                  height: 48,
                  child: ChorokCard(
                    showBorder: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXL,
                    ),
                    gradient: AppTheme.greenGradient,
                    child: Center(
                      child: Text(
                        '다시 시도',
                        style: AppTheme.rowText.copyWith(
                          color: AppTheme.darkBg,
                        ),
                      ),
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
