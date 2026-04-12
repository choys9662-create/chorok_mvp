import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../controller/book_search_controller.dart';
import '../model/aladin_book.dart';
import '../widget/add_to_library_sheet.dart';

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
      ref.read(bookSearchProvider.notifier).clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(bookSearchProvider.notifier).search(value);
    });
  }

  void _onClear() {
    _controller.clear();
    ref.read(bookSearchProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  Future<void> _onBookTap(AladinBook book) async {
    HapticFeedback.selectionClick();
    final status = await showAddToLibrarySheet(context, book);
    if (status == null || !mounted) return;

    final added =
        ref.read(libraryProvider.notifier).addBook(book.toBook(status));

    if (!mounted) return;
    final label = status == ReadingStatus.reading ? '읽는 중' : '읽고 싶어요';
    final msg = added
        ? '"${book.title}"을(를) $label에 추가했어요'
        : '"${book.title}"은(는) 이미 서재에 있어요';

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      _buildSnackBar(msg, added),
    );
  }

  SnackBar _buildSnackBar(String message, bool success) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.info_rounded,
            color: success ? AppTheme.primaryLight : AppTheme.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.darkCardElevated,
      behavior: SnackBarBehavior.floating,
      shape: ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD * 1.35),
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(bookSearchProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── 검색 바 ──────────────────────────────────────────────
            _SearchBar(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              onClear: _onClear,
              onBarcode: () {
                HapticFeedback.selectionClick();
                context.push(AppConstants.routeBarcode);
              },
            ),

            // ── 결과 영역 ─────────────────────────────────────────────
            Expanded(
              child: searchState.when(
                loading: () => const _ShimmerList(),
                error: (error, _) => _ErrorView(
                  message: error.toString().replaceFirst('Exception: ', ''),
                  onRetry: () => ref
                      .read(bookSearchProvider.notifier)
                      .search(_controller.text),
                ),
                data: (books) {
                  if (_controller.text.trim().isEmpty) {
                    return const _IdlePrompt();
                  }
                  if (books.isEmpty) {
                    return _EmptyResult(query: _controller.text.trim());
                  }
                  return _ResultList(books: books, onTap: _onBookTap);
                },
              ),
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
  final VoidCallback onBarcode;

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
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textSecondary,
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
                color: AppTheme.darkCard,
                radius: AppTheme.radiusMD,
                side: BorderSide(color: AppTheme.darkBorder, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                      decoration: const InputDecoration(
                        hintText: '제목, 저자, 키워드 검색',
                        hintStyle: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textTertiary,
                          height: 1.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      cursorColor: AppTheme.primaryLight,
                    ),
                  ),
                  // 지우기 버튼
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (_, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: onClear,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.cancel_rounded,
                            color: AppTheme.textTertiary,
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
          const SizedBox(width: 8),

          // 바코드 스캔 버튼
          Semantics(
            button: true,
            label: 'ISBN 바코드 스캔',
            child: GestureDetector(
              onTap: onBarcode,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
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
            (b) =>
                (book.isbn13 != null && b.isbn == book.isbn13) ||
                (b.title == book.title && b.author == book.author),
          )),
    );

    return Semantics(
      label: '${book.title}, ${book.author}',
      child: Container(
        decoration: AppTheme.smoothBox(
          color: AppTheme.darkCard,
          radius: AppTheme.radiusLG,
          side: BorderSide(color: AppTheme.darkBorder, width: 1),
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
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.publisher,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textTertiary,
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
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
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
      return Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: AppTheme.smoothBox(
          color: AppTheme.darkCardElevated,
          radius: AppTheme.radiusSM,
          side: BorderSide(color: AppTheme.darkBorder, width: 1),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_rounded,
              color: AppTheme.primaryLight,
              size: 14,
            ),
            SizedBox(width: 4),
            Text(
              '서재에 있어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryLight,
                height: 1.4,
              ),
            ),
          ],
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
        color: AppTheme.darkCard,
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
        color: AppTheme.darkCardElevated.withValues(alpha: opacity),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, color: AppTheme.textTertiary, size: 48),
          SizedBox(height: 16),
          Text(
            '읽고 싶은 책을 검색해보세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '제목, 저자, 키워드로 찾을 수 있어요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.textTertiary,
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
            const Icon(
              Icons.search_off_rounded,
              color: AppTheme.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              '"$query"',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '검색 결과가 없어요\n다른 키워드로 찾아보세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
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
            const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.textTertiary,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              '검색에 실패했어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
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
