import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../../shared/widgets/book_cover.dart';

void showBookDetail(BuildContext context, Book book) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BookDetailSheet(book: book, outerContext: context),
  );
}

class BookDetailSheet extends ConsumerStatefulWidget {
  final Book book;
  final BuildContext outerContext;
  const BookDetailSheet({
    super.key,
    required this.book,
    required this.outerContext,
  });

  @override
  ConsumerState<BookDetailSheet> createState() => _BookDetailSheetState();
}

class _BookDetailSheetState extends ConsumerState<BookDetailSheet> {
  late int _currentPage;
  late TextEditingController _pageController;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.currentPage;
    _pageController = TextEditingController(text: '$_currentPage');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _adjustPage(int delta) {
    final newPage = (_currentPage + delta).clamp(0, widget.book.totalPages);
    setState(() {
      _currentPage = newPage;
      _pageController
        ..text = '$newPage'
        ..selection = TextSelection.collapsed(offset: '$newPage'.length);
    });
    HapticFeedback.selectionClick();
  }

  void _savePage(BuildContext context) {
    HapticFeedback.heavyImpact();
    ref
        .read(libraryProvider.notifier)
        .updateCurrentPage(widget.book.id, _currentPage);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.book.title} — $_currentPage쪽으로 업데이트했어요',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  Future<void> _editTotalPages(BuildContext context, int currentTotal) async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController(
      text: currentTotal > 0 ? '$currentTotal' : '',
    );
    final newTotal = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('총 페이지 수'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '예: 320',
            suffixText: '쪽',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed != null && parsed > 0 ? parsed : null);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (newTotal == null || !mounted) return;
    ref.read(libraryProvider.notifier).updateTotalPages(widget.book.id, newTotal);
    if (_currentPage > newTotal) {
      setState(() {
        _currentPage = newTotal;
        _pageController
          ..text = '$newTotal'
          ..selection = TextSelection.collapsed(offset: '$newTotal'.length);
      });
    }
  }

  Future<void> _deleteBook(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서재에서 제거'),
        content: Text('\'${widget.book.title}\'을(를) 서재에서 제거할까요?\n기록된 독서 데이터도 함께 삭제됩니다.'),
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
    ref.read(libraryProvider.notifier).deleteBook(widget.book.id);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.book.title}을(를) 서재에서 제거했어요',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 라이브러리 상태와 동기화 — 페이지 수 수정 시 즉시 반영되도록
    final book = ref.watch(libraryProvider).firstWhere(
          (b) => b.id == widget.book.id,
          orElse: () => widget.book,
        );
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;
    final progress = _currentPage / (book.totalPages > 0 ? book.totalPages : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChorokSheetHandle(),
          const SizedBox(height: 24),
          // ── 책 정보 ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                coverUrl: book.coverUrl,
                gradientIndex: book.title.hashCode.abs() % AppTheme.coverGradients.length,
                width: 64,
                height: 88,
                radius: 8,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: AppTheme.headingMedium.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book.author,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? context.primaryBg(0.12)
                            : isReading
                            ? context.appPrimaryAccent.withValues(alpha: isDark ? 0.12 : 0.15)
                            : context.appCardElevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        book.status.label,
                        style: AppTheme.captionSmall.copyWith(
                          color: isCompleted || isReading
                              ? context.appPrimaryAccent
                              : context.appTextTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── 통계 ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.smoothBox(
              color: context.appCardElevated,
              radius: 12,
            ),
            child: Row(
              children: [
                _DetailStat(
                  label: '진행률',
                  value: '${(progress * 100).toInt()}%',
                ),
                _DetailStat(
                  label: book.totalPages == 0 ? '페이지 (입력)' : '페이지',
                  value: book.totalPages == 0
                      ? '─'
                      : '$_currentPage/${book.totalPages}',
                  onTap: () => _editTotalPages(context, book.totalPages),
                ),
                if (book.totalReadingHours > 0)
                  _DetailStat(
                    label: '독서 시간',
                    value: '${book.totalReadingHours.toStringAsFixed(1)}h',
                  ),
                if (book.savedSentences.isNotEmpty)
                  _DetailStat(
                    label: '수집 문장',
                    value: '${book.savedSentences.length}개',
                  ),
              ],
            ),
          ),
          // ── 수집한 문장 ───────────────────────────────────────
          if (book.savedSentences.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              '수집한 문장',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...book.savedSentences
                .take(3)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.appCardElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: context.appPrimaryAccent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        '"$s"',
                        style: AppTheme.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                          color: context.appTextPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
          // ── 진행률 바 ─────────────────────────────────────────
          if (isReading) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: context.appBorder,
                valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                minHeight: 6,
              ),
            ),
            // ── 현재 페이지 빠른 업데이트 ────────────────────────
            const SizedBox(height: 20),
            Text(
              '현재 페이지 업데이트',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.smoothBox(
                color: context.appCardElevated,
                radius: 14,
                side: BorderSide(color: context.appBorder),
              ),
              child: Column(
                children: [
                  // 빠른 조절 버튼 행
                  Row(
                    children: [
                      _PageAdjustButton(
                        label: '-10',
                        onTap: () => _adjustPage(-10),
                      ),
                      const SizedBox(width: 8),
                      _PageAdjustButton(
                        label: '+10',
                        onTap: () => _adjustPage(10),
                      ),
                      const SizedBox(width: 8),
                      _PageAdjustButton(
                        label: '+50',
                        onTap: () => _adjustPage(50),
                      ),
                      const Spacer(),
                      // 직접 입력 필드
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _pageController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: AppTheme.bodyMedium.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: context.appCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: context.appPrimaryAccent,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null) {
                              setState(() {
                                _currentPage = parsed.clamp(0, book.totalPages);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '/ ${book.totalPages}쪽',
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _savePage(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: isDark ? AppTheme.primaryLight : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: AppTheme.smoothShape(radius: 10),
                      ),
                      child: const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          // ── 액션 버튼 ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    if (isReading || isCompleted) {
                      widget.outerContext.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          bookId: book.id,
                          bookTitle: book.title,
                          bookAuthor: book.author,
                          coverUrl: book.coverUrl,
                          startPage: _currentPage,
                          totalPages: book.totalPages,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    isReading
                        ? Icons.play_arrow_rounded
                        : isCompleted
                        ? Icons.replay_rounded
                        : Icons.add_rounded,
                  ),
                  label: Text(
                    isReading
                        ? '이어 읽기'
                        : isCompleted
                        ? '다시 읽기'
                        : '읽기',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: isDark ? AppTheme.primaryLight : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _deleteBook(context),
                icon: const Icon(Icons.delete_outline_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: context.appTextTertiary,
                  backgroundColor: context.appCardElevated,
                  padding: const EdgeInsets.all(14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PageAdjustButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PageAdjustButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label 페이지',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: AppTheme.smoothBox(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.primary.withValues(alpha: 0.15)
                : AppTheme.lightPrimaryAccent,
            radius: 10,
            side: BorderSide(
              color: context.appPrimaryAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: AppTheme.captionLarge.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.primaryLight
                  : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label, value;
  final VoidCallback? onTap;
  const _DetailStat({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: AppTheme.bodyLarge.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.edit_rounded,
                size: 12,
                color: context.appTextTertiary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.captionSmall.copyWith(
            color: context.appTextTertiary,
          ),
        ),
      ],
    );
    return Expanded(
      child: onTap != null
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: content,
            )
          : content,
    );
  }
}
