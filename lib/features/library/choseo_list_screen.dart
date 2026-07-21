import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/isar/isar_choseo.dart';
import '../../shared/widgets/chorok_card.dart';
import '../../shared/widgets/chorok_list_row.dart';
import 'controller/choseo_list_controller.dart';
import '../../shared/widgets/chorok_refresh.dart';
import '../../shared/widgets/chorok_shimmer.dart';

// ─── 화면 ────────────────────────────────────────────────────────────────────

class ChoseoListScreen extends ConsumerStatefulWidget {
  const ChoseoListScreen({super.key});

  @override
  ConsumerState<ChoseoListScreen> createState() => _ChoseoListScreenState();
}

class _ChoseoListScreenState extends ConsumerState<ChoseoListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(choseoListProvider.notifier).search('');
      _focusNode.unfocus();
    } else {
      Future.delayed(
        const Duration(milliseconds: 100),
        _focusNode.requestFocus,
      );
    }
  }

  void _onSearchChanged(String value) {
    ref.read(choseoListProvider.notifier).search(value);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(choseoListProvider);

    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          SizedBox(height: topPad),
          // ── 상단 바 ──────────────────────────────────────────────
          _TopBar(
            searchActive: _searchActive,
            searchCtrl: _searchCtrl,
            focusNode: _focusNode,
            totalCount: state.items.length,
            onBack: () => Navigator.of(context).pop(),
            onToggleSearch: _toggleSearch,
            onSearchChanged: _onSearchChanged,
          ),

          // ── 탭 바 ─────────────────────────────────────────────────
          _ChoseoTabBar(controller: _tabCtrl),
          const SizedBox(height: AppTheme.spaceXS),

          // ── 콘텐츠 ───────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const _LoadingShimmer()
                : (state.hasError && state.items.isEmpty)
                ? _ErrorView(
                    onRetry: () => ref.read(choseoListProvider.notifier).load(),
                  )
                : TabBarView(
                    controller: _tabCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // 책별 탭
                      _ByBookTab(state: state),
                      // 날짜순 탭
                      _ByDateTab(state: state),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── 상단 바 ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool searchActive;
  final TextEditingController searchCtrl;
  final FocusNode focusNode;
  final int totalCount;
  final VoidCallback onBack;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearchChanged;

  const _TopBar({
    required this.searchActive,
    required this.searchCtrl,
    required this.focusNode,
    required this.totalCount,
    required this.onBack,
    required this.onToggleSearch,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceSM,
        AppTheme.spaceSM,
        AppTheme.spaceMD,
        AppTheme.spaceSM,
      ),
      child: Row(
        children: [
          // 뒤로가기
          Semantics(
            button: true,
            label: '뒤로가기',
            child: GestureDetector(
              onTap: onBack,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
              ),
            ),
          ),

          // 타이틀 or 검색 필드
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: searchActive
                  ? _SearchField(
                      key: const ValueKey('search'),
                      controller: searchCtrl,
                      focusNode: focusNode,
                      onChanged: onSearchChanged,
                    )
                  : Column(
                      key: const ValueKey('title'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '내 문장',
                          style: AppTheme.screenTitle.copyWith(
                            color: context.appTextPrimary,
                          ),
                        ),
                        Text(
                          '총 $totalCount개',
                          style: AppTheme.supportingText.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // 검색 토글
          Semantics(
            button: true,
            label: searchActive ? '검색 닫기' : '검색',
            child: GestureDetector(
              onTap: onToggleSearch,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    searchActive ? Icons.close_rounded : Icons.search_rounded,
                    key: ValueKey(searchActive),
                    color: searchActive
                        ? context.appPrimaryAccent
                        : context.appTextSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 검색 인풋 필드
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ChorokCard(
        inner: true,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
          decoration: InputDecoration(
            hintText: '문장 내용, 책 제목, 저자 검색',
            hintStyle: AppTheme.rowText.copyWith(
              color: context.appTextTertiary,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: AppTheme.spaceSM,
            ),
          ),
          cursorColor: context.appPrimaryAccent,
          cursorWidth: 1.5,
        ),
      ),
    );
  }
}

// ─── 탭 바 ───────────────────────────────────────────────────────────────────

class _ChoseoTabBar extends StatelessWidget {
  final TabController controller;
  const _ChoseoTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
      child: ChorokCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 44,
          child: TabBar(
            controller: controller,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const BoxDecoration(color: AppTheme.primary),
            dividerColor: Colors.transparent,
            labelStyle: AppTheme.rowText,
            unselectedLabelStyle: AppTheme.rowText,
            labelColor: context.appTextPrimary,
            unselectedLabelColor: context.appTextSecondary,
            tabs: const [
              Tab(text: '책별'),
              Tab(text: '날짜순'),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 책별 탭 ─────────────────────────────────────────────────────────────────

class _ByBookTab extends ConsumerWidget {
  final ChoseoListState state;
  const _ByBookTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = state.byBook;
    if (grouped.isEmpty) return const _EmptyView();

    final books = grouped.keys.toList();
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        ChorokSliverRefreshControl(
          onRefresh: () => ref.read(choseoListProvider.notifier).load(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spaceSM,
            AppTheme.screenPadding,
            AppTheme.sectionGap,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final title = books[i];
              final items = grouped[title]!;
              return _BookGroup(title: title, items: items);
            }, childCount: books.length),
          ),
        ),
      ],
    );
  }
}

class _BookGroup extends StatefulWidget {
  final String title;
  final List<IsarChoseo> items;

  const _BookGroup({required this.title, required this.items});

  @override
  State<_BookGroup> createState() => _BookGroupState();
}

class _BookGroupState extends State<_BookGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final author = widget.items.first.bookAuthor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: ChorokCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // ── 책 헤더 (탭으로 접기/펼치기) ─────────────────────────
            Semantics(
              button: true,
              label: '${widget.title} ${_expanded ? "접기" : "펼치기"}',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _expanded = !_expanded);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                  child: ChorokListRow(
                    leading: _LetterBookCover(
                      letter: widget.title.isNotEmpty ? widget.title[0] : '?',
                      width: 44,
                      height: 56,
                      textStyle: AppTheme.sectionTitle,
                    ),
                    title: Text(
                      widget.title,
                      style: AppTheme.rowText.copyWith(
                        color: context.appTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    supporting: Text(
                      author,
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChorokCard(
                          inner: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                            vertical: AppTheme.spaceXS,
                          ),
                          child: Text(
                            '${widget.items.length}개',
                            style: AppTheme.supportingText.copyWith(
                              color: context.appPrimaryAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        AnimatedRotation(
                          turns: _expanded ? 0 : -0.25,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: context.appTextTertiary,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 초서 카드 목록 ────────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeOutCubic,
              firstChild: Column(
                children: [
                  ...widget.items.map(
                    (c) => _ChoseoCard(item: c, showBookInfo: false),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 날짜순 탭 ────────────────────────────────────────────────────────────────

class _ByDateTab extends ConsumerWidget {
  final ChoseoListState state;
  const _ByDateTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = state.filtered;
    if (items.isEmpty) return const _EmptyView();

    // 검색 중에는 더 보기를 노출하지 않는다 — 검색은 이미 불러온 항목만 필터링하므로
    // 다음 페이지를 불러와도 검색 결과에 곧바로 반영되지 않아 혼란을 줄 수 있다.
    final canLoadMore = state.query.trim().isEmpty && state.hasMore;
    final itemCount = items.length + (canLoadMore ? 1 : 0);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        ChorokSliverRefreshControl(
          onRefresh: () => ref.read(choseoListProvider.notifier).load(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spaceSM,
            AppTheme.screenPadding,
            AppTheme.sectionGap,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, index) {
              if (index.isOdd) {
                return const SizedBox(height: AppTheme.spaceMD);
              }
              final itemIndex = index ~/ 2;
              if (itemIndex >= items.length) {
                return _LoadMoreRow(
                  isLoading: state.isLoadingMore,
                  onTap: () => ref.read(choseoListProvider.notifier).loadMore(),
                );
              }
              return _ChoseoCard(item: items[itemIndex], showBookInfo: true);
            }, childCount: itemCount * 2 - 1),
          ),
        ),
      ],
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;
  const _LoadMoreRow({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
        child: TextButton(onPressed: onTap, child: const Text('더 보기')),
      ),
    );
  }
}

// ─── 초서 카드 ────────────────────────────────────────────────────────────────

class _ChoseoCard extends StatelessWidget {
  final IsarChoseo item;
  final bool showBookInfo;

  const _ChoseoCard({required this.item, required this.showBookInfo});

  // 거터(페이지 번호 열) 폭 — 인용구와 생각 블록 들여쓰기를 맞춘다
  static const double _gutter = 26;
  static const double _gutterGap = AppTheme.spaceMD;

  bool get _hasThought =>
      item.myThought != null && item.myThought!.trim().isNotEmpty;

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    return '${dt.month}월 ${dt.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final quoteContent = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _gutter,
          child: Text(
            item.pageNumber?.toString() ?? '',
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(color: context.appTextSecondary),
          ),
        ),
        const SizedBox(width: _gutterGap),
        Expanded(
          child: Text(
            item.content,
            style: AppTheme.body.copyWith(
              height: 1.6,
              color: context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
    final quote = _hasThought
        ? ChorokCard(
            inner: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceMD,
            ),
            child: quoteContent,
          )
        : Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceMD,
            ),
            child: quoteContent,
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── 상단: 책 정보 + 날짜 (날짜순 탭 전용) ──────────────────
        if (showBookInfo) _bookHeader(context),

        // ── 인용구 (생각 있으면 하이라이트 박스) ────────────────────
        quote,

        // ── 내 생각 (초록색 블록) ──────────────────────────────────
        if (_hasThought) ...[
          const SizedBox(height: AppTheme.spaceSM),
          ChorokCard(
            inner: true,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceMD,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: _gutter + _gutterGap),
                Expanded(
                  child: Text(
                    item.myThought!,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                      color: context.appPrimaryAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── 좋아요 · 댓글 지표 ─────────────────────────────────────
        const SizedBox(height: AppTheme.spaceSM),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_rounded,
              size: 14,
              color: context.appPrimaryAccent,
            ),
            const SizedBox(width: AppTheme.spaceXS),
            Text(
              '${item.likeCount}',
              style: AppTheme.body.copyWith(color: context.appTextPrimary),
            ),
            const SizedBox(width: AppTheme.spaceXL),
            Icon(
              Icons.chat_bubble_rounded,
              size: 13,
              color: context.appTextSecondary,
            ),
            const SizedBox(width: AppTheme.spaceXS),
            Text(
              '${item.commentCount}',
              style: AppTheme.body.copyWith(color: context.appTextPrimary),
            ),
          ],
        ),
      ],
    );
    return showBookInfo
        ? ChorokCard(child: content)
        : Padding(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            child: content,
          );
  }

  // 날짜순 탭: 미니 책표지 + 제목·저자 + 상대 날짜
  Widget _bookHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      child: ChorokListRow(
        leading: _LetterBookCover(
          letter: item.bookTitle.isNotEmpty ? item.bookTitle[0] : '?',
          width: 28,
          height: 36,
          textStyle: AppTheme.supportingText,
        ),
        title: Text(
          item.bookTitle,
          style: AppTheme.supportingText.copyWith(
            color: context.appTextPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        supporting: Text(
          item.bookAuthor,
          style: AppTheme.supportingText.copyWith(
            color: context.appTextTertiary,
          ),
        ),
        trailing: Text(
          _relativeDate(item.createdAt),
          style: AppTheme.supportingText.copyWith(
            color: context.appTextTertiary,
          ),
        ),
      ),
    );
  }
}

/// 표지 이미지가 없는 초서 항목의 그라디언트 표지.
class _LetterBookCover extends StatelessWidget {
  final String letter;
  final double width;
  final double height;
  final TextStyle textStyle;

  const _LetterBookCover({
    required this.letter,
    required this.width,
    required this.height,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ChorokCard(
        showBorder: false,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.appPrimaryAccent, context.appAccentColor],
        ),
        child: Center(
          child: Text(
            letter,
            style: textStyle.copyWith(color: AppTheme.primary),
          ),
        ),
      ),
    );
  }
}

// ─── 빈 상태 ─────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: AppTheme.spaceLG),
          Text(
            '아직 기록한 문장이 없어요',
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '독서 세션 중 마음에 드는 문장을\n저장해보세요',
            textAlign: TextAlign.center,
            style: AppTheme.supportingText.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppTheme.spaceLG,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          Text(
            '초서를 불러오지 못했어요',
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

// ─── 로딩 시머 ────────────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceSM,
        AppTheme.screenPadding,
        AppTheme.sectionGap,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spaceMD),
      itemBuilder: (_, _) =>
          const ChorokShimmer(width: double.infinity, height: 110),
    );
  }
}
