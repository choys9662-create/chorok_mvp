import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/isar/isar_choseo.dart';
import 'controller/choseo_list_controller.dart';

// ─── 색상 토큰 ────────────────────────────────────────────────────────────────

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
          const SizedBox(height: 4),

          // ── 콘텐츠 ───────────────────────────────────────────────
          Expanded(
            child: state.isLoading
                ? const _LoadingShimmer()
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
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
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
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: context.appTextPrimary,
                            height: 1.3,
                          ),
                        ),
                        Text(
                          '총 $totalCount개',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.appTextTertiary,
                            height: 1.4,
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
    return Container(
      height: 40,
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppTheme.radiusMD,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 16,
          color: context.appTextPrimary,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: '문장 내용, 책 제목, 저자 검색',
          hintStyle: TextStyle(
            fontSize: 16,
            color: context.appTextTertiary,
            height: 1.4,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        cursorColor: context.appPrimaryAccent,
        cursorWidth: 1.5,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 44,
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(100),
        border: null,
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(100),
          border: null,
        ),
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.appTextSecondary,
        tabs: const [
          Tab(text: '책별'),
          Tab(text: '날짜순'),
        ],
      ),
    );
  }
}

// ─── 책별 탭 ─────────────────────────────────────────────────────────────────

class _ByBookTab extends StatelessWidget {
  final ChoseoListState state;
  const _ByBookTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final grouped = state.byBook;
    if (grouped.isEmpty) return const _EmptyView();

    final books = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final title = books[i];
        final items = grouped[title]!;
        return _BookGroup(title: title, items: items);
      },
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
    final colors = AppTheme.coverGradientFor(widget.title);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppTheme.radiusXL,
            cornerSmoothing: 0.6,
          ),
        ),
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    // 책 표지 썸네일
                    Container(
                      width: 44,
                      height: 56,
                      decoration: ShapeDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                        shape: SmoothRectangleBorder(
                          borderRadius: SmoothBorderRadius(
                            cornerRadius: 6,
                            cornerSmoothing: 0.6,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.title.isNotEmpty ? widget.title[0] : '?',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: context.appTextPrimary,
                              height: 1.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            author,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.appTextTertiary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 개수 뱃지
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.appCardElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.items.length}개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.appPrimaryAccent,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

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
                const SizedBox(height: 8),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─── 날짜순 탭 ────────────────────────────────────────────────────────────────

class _ByDateTab extends StatelessWidget {
  final ChoseoListState state;
  const _ByDateTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = state.filtered;
    if (items.isEmpty) return const _EmptyView();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ChoseoCard(item: items[i], showBookInfo: true),
    );
  }
}

// ─── 초서 카드 ────────────────────────────────────────────────────────────────

class _ChoseoCard extends StatelessWidget {
  final IsarChoseo item;
  final bool showBookInfo;

  const _ChoseoCard({required this.item, required this.showBookInfo});

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
    final colors = AppTheme.coverGradientFor(item.bookTitle);

    return Container(
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: AppTheme.radiusLG,
            cornerSmoothing: 0.6,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단: 책 정보 + 날짜 ─────────────────────────────────
          if (showBookInfo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  // 미니 책 표지
                  Container(
                    width: 28,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        item.bookTitle.isNotEmpty ? item.bookTitle[0] : '?',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.bookTitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: context.appTextPrimary,
                            height: 1.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.bookAuthor,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextTertiary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    _relativeDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (item.pageNumber != null)
                    Text(
                      'p. ${item.pageNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.appTextTertiary,
                        height: 1.4,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  Text(
                    _relativeDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextTertiary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

          // ── 인용구 ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: context.appTextPrimary,
                      height: 1.6,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // ── 내 생각 ──────────────────────────────────────────────
          if (item.myThought != null && item.myThought!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 13,
                    color: context.appTextTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.myThought!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: context.appTextSecondary,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),
        ],
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
          const SizedBox(height: 16),
          Text(
            '아직 기록한 문장이 없어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: context.appTextSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '독서 세션 중 마음에 드는 문장을\n저장해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextTertiary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 로딩 시머 ────────────────────────────────────────────────────────────────

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
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
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => AnimatedBuilder(
        animation: _anim,
        builder: (_, _) => Container(
          height: 110,
          decoration: ShapeDecoration(
            color: Color.lerp(
              context.appCard,
              context.appCardElevated,
              _anim.value,
            ),
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLG * 1.35),
              side: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
