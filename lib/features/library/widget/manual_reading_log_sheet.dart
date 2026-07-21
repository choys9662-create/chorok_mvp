import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';

import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../screen/library_screen.dart';

/// 세션 없이 읽은 독서 기록을 수동으로 추가하는 바텀 시트
class ManualReadingLogSheet extends ConsumerStatefulWidget {
  final Book book;

  const ManualReadingLogSheet({super.key, required this.book});

  @override
  ConsumerState<ManualReadingLogSheet> createState() =>
      _ManualReadingLogSheetState();
}

class _ManualReadingLogSheetState extends ConsumerState<ManualReadingLogSheet> {
  late TextEditingController _startPageCtrl;
  late TextEditingController _endPageCtrl;
  late TextEditingController _minutesCtrl;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startPageCtrl = TextEditingController(text: '${widget.book.currentPage}');
    _endPageCtrl = TextEditingController();
    _minutesCtrl = TextEditingController();
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _startPageCtrl.dispose();
    _endPageCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final startPage = int.tryParse(_startPageCtrl.text.trim());
    final endPage = int.tryParse(_endPageCtrl.text.trim());
    final minutes = int.tryParse(_minutesCtrl.text.trim());

    if (startPage == null || startPage < 0) return '시작 페이지를 올바르게 입력해 주세요.';
    if (endPage == null || endPage <= 0) return '종료 페이지를 올바르게 입력해 주세요.';
    if (endPage <= startPage) return '종료 페이지는 시작 페이지보다 커야 해요.';
    if (widget.book.totalPages > 0 && endPage > widget.book.totalPages) {
      return '종료 페이지가 총 페이지(${widget.book.totalPages})를 초과해요.';
    }
    if (minutes == null || minutes <= 0) return '독서 시간을 올바르게 입력해 주세요.';
    return null;
  }

  Future<void> _save(BuildContext context) async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: AppTheme.supportingText.copyWith(color: AppTheme.primary),
          ),
          backgroundColor: AppTheme.warningColor,
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
      return;
    }

    final endPage = int.parse(_endPageCtrl.text.trim());
    final minutes = int.parse(_minutesCtrl.text.trim());

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref
          .read(libraryProvider.notifier)
          .addManualReadingLog(
            bookId: widget.book.id,
            startPage: int.parse(_startPageCtrl.text.trim()),
            endPage: endPage,
            durationSeconds: minutes * 60,
            sessionDate: _selectedDate,
          );
      ref.invalidate(readingLogsProvider);
      ref.invalidate(readingStreakProvider);
      ref.invalidate(analyticsProvider);

      if (!context.mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '독서 기록이 추가됐어요 (+${endPage - int.parse(_startPageCtrl.text.trim())}쪽)',
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      locale: const Locale('ko'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '오늘';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return '어제';
    }
    return '${d.month}월 ${d.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ChorokCard(
        showBorder: false,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spaceLG,
              AppTheme.screenPadding,
              AppTheme.spaceLG,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ChorokSheetHandle(),
                const SizedBox(height: AppTheme.spaceXL),

                // ── 헤더 ─────────────────────────────────────────────
                Row(
                  children: [
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: ChorokCard(
                        inner: true,
                        showBorder: false,
                        backgroundColor: context.appPrimaryAccent.withValues(
                          alpha: 0.12,
                        ),
                        padding: EdgeInsets.zero,
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppTheme.spaceXS,
                        children: [
                          Text(
                            '독서 기록 직접 추가',
                            style: AppTheme.headingMedium.copyWith(
                              color: context.appTextPrimary,
                            ),
                          ),
                          Text(
                            widget.book.title,
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXL),

                // ── 날짜 선택 ──────────────────────────────────────────
                Text(
                  '읽은 날짜',
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Semantics(
                  label: '날짜 선택',
                  button: true,
                  child: GestureDetector(
                    onTap: () => _pickDate(context),
                    child: SizedBox(
                      height: 48,
                      child: ChorokCard(
                        inner: true,
                        showBorder: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.cardPaddingMD,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: context.appPrimaryAccent,
                            ),
                            const SizedBox(width: AppTheme.spaceMD),
                            Text(
                              _formatDate(_selectedDate),
                              style: AppTheme.body.copyWith(
                                color: context.appTextPrimary,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: context.appTextTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),

                // ── 페이지 범위 ────────────────────────────────────────
                Text(
                  '읽은 페이지',
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    Expanded(
                      child: _PageField(
                        controller: _startPageCtrl,
                        label: '시작',
                        hint: '예: ${widget.book.currentPage}',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD,
                      ),
                      child: Text(
                        '→',
                        style: AppTheme.bodyMedium.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _PageField(
                        controller: _endPageCtrl,
                        label: '종료',
                        hint: widget.book.totalPages > 0
                            ? '예: ${widget.book.totalPages}'
                            : '종료 쪽',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '쪽',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),

                // 읽은 쪽수 미리보기
                Builder(
                  builder: (_) {
                    final start = int.tryParse(_startPageCtrl.text);
                    final end = int.tryParse(_endPageCtrl.text);
                    if (start != null && end != null && end > start) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spaceSM),
                        child: Text(
                          '${end - start}쪽 읽었어요',
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: AppTheme.spaceSM);
                  },
                ),
                const SizedBox(height: AppTheme.spaceLG),

                // ── 독서 시간 ──────────────────────────────────────────
                Text(
                  '독서 시간',
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.cardPaddingMD,
                          ),
                          child: TextField(
                            controller: _minutesCtrl,
                            keyboardType: TextInputType.number,
                            style: AppTheme.body.copyWith(
                              color: context.appTextPrimary,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '예: 30',
                              hintStyle: AppTheme.body.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '분',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXL),

                // ── 안내 문구 ──────────────────────────────────────────
                ChorokCard(
                  inner: true,
                  showBorder: false,
                  backgroundColor: context.appPrimaryAccent.withValues(
                    alpha: 0.08,
                  ),
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: context.appPrimaryAccent,
                      ),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: Text(
                          '종료 페이지가 현재 페이지(${widget.book.currentPage}쪽)보다 크면 자동으로 업데이트돼요.',
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXL),

                // ── 저장 버튼 ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSaving ? null : () => _save(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: isDark
                          ? AppTheme.primaryLight
                          : AppTheme.lightSurface,
                      disabledBackgroundColor: AppTheme.primary.withValues(
                        alpha: 0.5,
                      ),
                      shape: AppTheme.smoothShape(radius: AppTheme.radiusMD),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark
                                  ? AppTheme.primaryLight
                                  : AppTheme.lightSurface,
                            ),
                          )
                        : Text(
                            '기록 추가하기',
                            style: AppTheme.bodyLarge.copyWith(
                              color: isDark
                                  ? AppTheme.primaryLight
                                  : AppTheme.lightSurface,
                            ),
                          ),
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

class _PageField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  const _PageField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppTheme.spaceXS,
      children: [
        Text(
          label,
          style: AppTheme.caption.copyWith(color: context.appTextTertiary),
        ),
        SizedBox(
          height: 48,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => onChanged(),
              style: AppTheme.body.copyWith(color: context.appTextPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: AppTheme.supportingText.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
