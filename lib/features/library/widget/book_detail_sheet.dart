import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/page_slider_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
import 'manual_reading_log_sheet.dart';

void showBookDetail(BuildContext context, Book book) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appCard,
    shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.book.currentPage;
  }

  @override
  void didUpdateWidget(BookDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book.currentPage != widget.book.currentPage) {
      setState(() => _currentPage = widget.book.currentPage);
    }
  }

  void _savePage(BuildContext context, int page) {
    HapticFeedback.heavyImpact();
    setState(() => _currentPage = page);
    ref.read(libraryProvider.notifier).updateCurrentPage(widget.book.id, page);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.book.title} — $_currentPage쪽으로 업데이트했어요',
          style: AppTheme.supportingText.copyWith(
            color: context.appTextPrimary,
          ),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
        margin: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.spaceLG,
        ),
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
    ref
        .read(libraryProvider.notifier)
        .updateTotalPages(widget.book.id, newTotal);
    if (_currentPage > newTotal) {
      setState(() => _currentPage = newTotal);
    }
  }

  Future<void> _deleteBook(BuildContext context) async {
    HapticFeedback.selectionClick();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서재에서 제거'),
        content: Text(
          '\'${widget.book.title}\'을(를) 서재에서 제거할까요?\n기록된 독서 데이터도 함께 삭제됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
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
          style: AppTheme.supportingText.copyWith(
            color: context.appTextPrimary,
          ),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
        margin: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.spaceLG,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 라이브러리 상태와 동기화 — 페이지 수 수정 시 즉시 반영되도록
    final book = ref
        .watch(libraryProvider)
        .firstWhere((b) => b.id == widget.book.id, orElse: () => widget.book);
    final isReading = book.status == ReadingStatus.reading;
    final isCompleted = book.status == ReadingStatus.completed;
    final progress = _currentPage / (book.totalPages > 0 ? book.totalPages : 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChorokSheetHandle(),
          const SizedBox(height: AppTheme.spaceXL),
          // ── 책 정보 ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                coverUrl: book.coverUrl,
                gradientIndex:
                    book.title.hashCode.abs() % AppTheme.coverGradients.length,
                width: 64,
                height: 88,
                radius: AppTheme.radiusOuter,
              ),
              const SizedBox(width: AppTheme.spaceLG),
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
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      book.author,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    ChorokCard(
                      inner: true,
                      showBorder: false,
                      backgroundColor: isCompleted
                          ? context.primaryBg(0.12)
                          : isReading
                          ? context.appPrimaryAccent.withValues(
                              alpha: isDark ? 0.12 : 0.15,
                            )
                          : context.appCardElevated,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceSM,
                        vertical: AppTheme.spaceXS,
                      ),
                      child: Text(
                        book.status.label,
                        style: AppTheme.caption.copyWith(
                          color: isCompleted || isReading
                              ? context.appPrimaryAccent
                              : context.appTextTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXL),
          // ── 통계 ──────────────────────────────────────────────
          ChorokCard(
            inner: true,
            showBorder: false,
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
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
            const SizedBox(height: AppTheme.spaceXL),
            Text(
              '수집한 문장',
              style: AppTheme.sectionTitle.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            ...book.savedSentences
                .take(3)
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                    child: ChorokCard(
                      inner: true,
                      showBorder: false,
                      padding: const EdgeInsets.all(AppTheme.spaceMD),
                      child: Text(
                        '"$s"',
                        style: AppTheme.bodyMedium.copyWith(
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
            const SizedBox(height: AppTheme.spaceXL),
            ChorokProgressBar(
              value: progress,
              trackColor: context.appBorder,
              valueColor: context.appPrimaryAccent,
            ),
            // ── 현재 페이지 업데이트 (슬라이더) ─────────────────
            const SizedBox(height: AppTheme.spaceLG),
            PageSliderCard(
              key: ValueKey(book.totalPages),
              initialPage: _currentPage,
              totalPages: book.totalPages,
              saveLabel: '저장',
              onPageChanged: (p) => setState(() => _currentPage = p),
              onSave: (page) async => _savePage(context, page),
              trailing: TextButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.appBg.withValues(alpha: 0),
                    builder: (_) => ManualReadingLogSheet(book: book),
                  );
                },
                icon: const Icon(Icons.history_edu_rounded, size: 16),
                label: Text('수동 기록', style: AppTheme.supportingText),
                style: TextButton.styleFrom(
                  foregroundColor: context.appPrimaryAccent,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSM,
                    vertical: AppTheme.spaceXS,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spaceXL),
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
                    foregroundColor: AppTheme.primaryLight,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceMD,
                    ),
                    shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              IconButton(
                onPressed: () => _deleteBook(context),
                icon: const Icon(Icons.delete_outline_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: context.appTextTertiary,
                  backgroundColor: context.appCardElevated,
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
        ],
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
      spacing: AppTheme.spaceXS,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: AppTheme.bodyLarge.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppTheme.spaceXS),
              Icon(
                Icons.edit_rounded,
                size: 12,
                color: context.appTextTertiary,
              ),
            ],
          ],
        ),
        Text(
          label,
          style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
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
