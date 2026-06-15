import 'dart:math' as math;

import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import 'web_keyboard_inset.dart';

const _chosuSheetPadding = 24.0;

/// 초서 바텀시트 — 문장 수집 + 내 생각 입력 UI
class ChosuSheet extends StatefulWidget {
  /// OCR / STT로 인식된 텍스트를 미리 채울 때 사용
  final String initialText;
  final String bookTitle;
  final bool autofocusSentence;

  const ChosuSheet({
    super.key,
    this.initialText = '',
    this.bookTitle = '',
    this.autofocusSentence = true,
  });

  @override
  State<ChosuSheet> createState() => _ChosuSheetState();
}

class _ChosuSheetState extends State<ChosuSheet> {
  late final TextEditingController _sentenceCtrl;
  final _thoughtCtrl = TextEditingController();
  final _pageCtrl = TextEditingController();
  final _sentenceFocus = FocusNode();
  final _thoughtFocus = FocusNode();
  bool _isWritingThought = false;
  bool _saved = false;
  late final WebKeyboardInsetController _webKeyboardInset;

  @override
  void initState() {
    super.initState();
    _sentenceCtrl = TextEditingController(text: widget.initialText);
    _webKeyboardInset = WebKeyboardInsetController()
      ..addListener(_handleWebKeyboardInsetChanged)
      ..start();
  }

  @override
  void dispose() {
    _webKeyboardInset
      ..removeListener(_handleWebKeyboardInsetChanged)
      ..dispose();
    _sentenceCtrl.dispose();
    _thoughtCtrl.dispose();
    _pageCtrl.dispose();
    _sentenceFocus.dispose();
    _thoughtFocus.dispose();
    super.dispose();
  }

  void _handleWebKeyboardInsetChanged() {
    if (mounted) setState(() {});
  }

  void _openThoughtStep() {
    if (_sentenceCtrl.text.trim().isEmpty) return;
    setState(() => _isWritingThought = true);
    _sentenceFocus.unfocus();
    Future.delayed(
      const Duration(milliseconds: 80),
      _thoughtFocus.requestFocus,
    );
  }

  void _save() {
    if (_sentenceCtrl.text.trim().isEmpty) return;
    setState(() => _saved = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.pop(
          context,
          CollectedSentence(
            content: _sentenceCtrl.text.trim(),
            thought: _thoughtCtrl.text.trim(),
            pageNumber: int.tryParse(_pageCtrl.text.trim()),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = math.max(
      media.viewInsets.bottom,
      _webKeyboardInset.inset,
    );
    final bottomPadding =
        media.padding.bottom + 16 + (kIsWeb ? keyboardInset : 0);
    final isKeyboardOpen = keyboardInset > 0;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: kIsWeb ? 0 : keyboardInset),
      child: Material(
        color: context.appBg,
        // 빈 영역 탭 → 키보드 내림 (키보드가 열려 있는 동안 하단 버튼이 숨겨지므로,
        // 키보드를 내릴 수단이 없으면 저장 동선이 막힌다)
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _chosuSheetPadding,
                10,
                _chosuSheetPadding,
                bottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ChosuSheetHandle(),
                  const SizedBox(height: 34),

                  // 헤더
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: context.appPrimaryAccent,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '문장 수집',
                          style: AppTheme.headingLarge.copyWith(
                            color: context.appTextPrimary,
                            letterSpacing: 0,
                          ),
                        ),
                        const Spacer(),
                        if (widget.bookTitle.isNotEmpty)
                          Flexible(
                            child: Text(
                              widget.bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: AppTheme.bodySmall.copyWith(
                                color: context.appTextTertiary,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: IconButton(
                            tooltip: '닫기',
                            padding: EdgeInsets.zero,
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: context.appTextTertiary,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _StepHeader(isWritingThought: _isWritingThought),
                  const SizedBox(height: 26),

                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: _isWritingThought
                          ? _ThoughtStep(
                              key: const ValueKey('thought'),
                              sentence: _sentenceCtrl.text.trim(),
                              thoughtCtrl: _thoughtCtrl,
                              thoughtFocus: _thoughtFocus,
                              saved: _saved,
                              canSave: _sentenceCtrl.text.trim().isNotEmpty,
                              compactForKeyboard: isKeyboardOpen,
                              keyboardInset: keyboardInset,
                              onBack: () =>
                                  setState(() => _isWritingThought = false),
                              onSave: _save,
                            )
                          : _SentenceStep(
                              key: const ValueKey('sentence'),
                              sentenceCtrl: _sentenceCtrl,
                              pageCtrl: _pageCtrl,
                              sentenceFocus: _sentenceFocus,
                              saved: _saved,
                              onChanged: (_) => setState(() {}),
                              onContinue: _openThoughtStep,
                              onSave: _save,
                              autofocus: widget.autofocusSentence,
                              compactForKeyboard: isKeyboardOpen,
                              keyboardInset: keyboardInset,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final bool isWritingThought;

  const _StepHeader({required this.isWritingThought});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepBadge(number: '1', label: '문장', active: !isWritingThought),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.appPrimaryAccent.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        _StepBadge(number: '2', label: '생각', active: isWritingThought),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _StepBadge({
    required this.number,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? context.appPrimaryAccent : context.appTextTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: active
                ? context.appPrimaryAccent
                : context.appCardElevated.withValues(alpha: 0.62),
            shape: AppTheme.smoothShape(radius: 18),
          ),
          child: Text(
            number,
            style: AppTheme.bodySmall.copyWith(
              color: active ? Colors.black : context.appTextTertiary,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ChosuSheetHandle extends StatelessWidget {
  const _ChosuSheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 6,
        decoration: BoxDecoration(
          color: context.appPrimaryAccent.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _SentenceStep extends StatelessWidget {
  final TextEditingController sentenceCtrl;
  final TextEditingController pageCtrl;
  final FocusNode sentenceFocus;
  final bool saved;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onSave;
  final bool autofocus;
  final bool compactForKeyboard;
  final double keyboardInset;

  const _SentenceStep({
    super.key,
    required this.sentenceCtrl,
    required this.pageCtrl,
    required this.sentenceFocus,
    required this.saved,
    required this.onChanged,
    required this.onContinue,
    required this.onSave,
    required this.autofocus,
    required this.compactForKeyboard,
    required this.keyboardInset,
  });

  @override
  Widget build(BuildContext context) {
    final hasSentence = sentenceCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _FieldLabel(
                icon: Icons.format_quote_rounded,
                label: '수집할 문장',
                color: context.appPrimaryAccent,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'p.',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 86,
                  height: 48,
                  child: TextField(
                    controller: pageCtrl,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: '쪽',
                      hintStyle: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                        letterSpacing: 0,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      filled: true,
                      fillColor: context.appCardElevated.withValues(
                        alpha: 0.66,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.appBorderSubtle,
                          width: 1.2,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.appBorderSubtle,
                          width: 1.2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.55,
                          ),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _ChosuTextField(
            controller: sentenceCtrl,
            focusNode: sentenceFocus,
            hintText: '마음에 남은 문장을 입력하세요...',
            expands: true,
            italic: true,
            autofocus: autofocus,
            cursorColor: context.appPrimaryAccent,
            keyboardInset: keyboardInset,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 10),
        if (!compactForKeyboard) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${sentenceCtrl.text.length}자',
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: hasSentence ? onContinue : null,
              style: _primaryButtonStyle(context),
              child: Text(
                '생각 쓰기',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w400,
                  color: hasSentence ? Colors.black : context.appTextTertiary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: hasSentence ? onSave : null,
              child: _SavedButtonChild(
                saved: saved,
                label: '문장만 저장',
                enabled: hasSentence,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ThoughtStep extends StatelessWidget {
  final String sentence;
  final TextEditingController thoughtCtrl;
  final FocusNode thoughtFocus;
  final bool saved;
  final bool canSave;
  final bool compactForKeyboard;
  final double keyboardInset;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _ThoughtStep({
    super.key,
    required this.sentence,
    required this.thoughtCtrl,
    required this.thoughtFocus,
    required this.saved,
    required this.canSave,
    required this.compactForKeyboard,
    required this.keyboardInset,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compactForKeyboard) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: context.appCard.withValues(alpha: 0.78),
              shape: SmoothRectangleBorder(
                smoothness: 0.6,
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: context.appPrimaryAccent.withValues(alpha: 0.22),
                  width: 1.2,
                ),
              ),
            ),
            child: Text(
              sentence,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextSecondary,
                height: 1.6,
                fontStyle: FontStyle.italic,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.edit_rounded, size: 15),
              label: const Text('문장 수정'),
              style: TextButton.styleFrom(
                foregroundColor: context.appTextTertiary,
                textStyle: AppTheme.captionSmall.copyWith(
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _FieldLabel(
          icon: Icons.edit_note_rounded,
          label: '내 생각',
          color: context.appAccentColor,
          optional: true,
        ),
        const SizedBox(height: 8),
        // key 필수 — 키보드가 올라오며 compactForKeyboard가 바뀌면 앞쪽 위젯들이
        // 사라져 Column 내 위치가 밀리는데, key가 없으면 위치 매칭으로 입력란이
        // 재생성되어 텍스트 입력 연결이 끊긴다 (키보드가 올라오다 도로 내려감).
        Expanded(
          key: const ValueKey('thought-field'),
          child: _ChosuTextField(
            controller: thoughtCtrl,
            focusNode: thoughtFocus,
            hintText: '이 문장에서 무엇을 느꼈나요?',
            expands: true,
            cursorColor: context.appAccentColor,
            keyboardInset: keyboardInset,
            onChanged: (_) {},
          ),
        ),
        if (!compactForKeyboard) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave ? onSave : null,
              style: _primaryButtonStyle(context, saved: saved),
              child: _SavedButtonChild(
                saved: saved,
                label: '저장하기',
                enabled: canSave,
                primary: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChosuTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool expands;
  final bool italic;
  final bool autofocus;
  final Color cursorColor;
  final double keyboardInset;
  final ValueChanged<String> onChanged;

  const _ChosuTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.expands = false,
    this.italic = false,
    this.autofocus = false,
    required this.cursorColor,
    this.keyboardInset = 0,
    required this.onChanged,
  });

  @override
  State<_ChosuTextField> createState() => _ChosuTextFieldState();
}

class _ChosuTextFieldState extends State<_ChosuTextField> {
  static const _keyboardGap = 24.0;
  final _scrollCtrl = ScrollController();
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_scheduleCaretFollow);
    widget.focusNode.addListener(_scheduleCaretFollow);
  }

  @override
  void didUpdateWidget(covariant _ChosuTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleCaretFollow);
      widget.controller.addListener(_scheduleCaretFollow);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_scheduleCaretFollow);
      widget.focusNode.addListener(_scheduleCaretFollow);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_scheduleCaretFollow);
    widget.focusNode.removeListener(_scheduleCaretFollow);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scheduleCaretFollow() {
    if (!widget.focusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;

      final position = _scrollCtrl.position;
      final selection = widget.controller.selection;
      final textLength = widget.controller.text.length;
      final isEditingTail = selection.extentOffset >= textLength - 1;
      final isAlreadyNearBottom =
          position.maxScrollExtent - position.pixels < 80;

      if (!isEditingTail && !isAlreadyNearBottom) return;

      _scrollCtrl.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = math.max(
      MediaQuery.viewInsetsOf(context).bottom,
      widget.keyboardInset,
    );
    if (keyboardInset != _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
      _scheduleCaretFollow();
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: context.appCard.withValues(alpha: 0.78),
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: widget.cursorColor.withValues(alpha: 0.24),
            width: 1.2,
          ),
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        scrollController: _scrollCtrl,
        scrollPadding: EdgeInsets.only(
          bottom: keyboardInset > 0 ? keyboardInset + _keyboardGap : 20,
        ),
        expands: widget.expands,
        minLines: null,
        maxLines: widget.expands ? null : 1,
        textAlignVertical: TextAlignVertical.top,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const <String>[],
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        cursorColor: widget.cursorColor,
        style: AppTheme.bodyMedium.copyWith(
          color: context.appTextPrimary,
          height: 1.75,
          fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: context.appTextTertiary,
            fontStyle: widget.italic ? FontStyle.italic : FontStyle.normal,
            letterSpacing: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle(BuildContext context, {bool saved = false}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return FilledButton.styleFrom(
    backgroundColor: saved ? context.appAccentColor : context.appPrimaryAccent,
    disabledBackgroundColor: isDark
        ? const Color(0xFF2D5B22)
        : context.appPrimaryAccent.withValues(alpha: 0.24),
    foregroundColor: isDark ? Colors.black : Colors.white,
    disabledForegroundColor: context.appTextTertiary,
    minimumSize: const Size.fromHeight(58),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: SmoothRectangleBorder(
      smoothness: 0.6,
      borderRadius: BorderRadius.circular(10),
    ),
  );
}

class _SavedButtonChild extends StatelessWidget {
  final bool saved;
  final String label;
  final bool enabled;
  final bool primary;

  const _SavedButtonChild({
    required this.saved,
    required this.label,
    required this.enabled,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = primary
        ? (enabled
              ? (isDark ? Colors.black : Colors.white)
              : context.appTextTertiary)
        : context.appTextTertiary;

    if (!saved) {
      return Text(
        label,
        style: AppTheme.bodyMedium.copyWith(
          fontWeight: FontWeight.w400,
          color: color,
          letterSpacing: 0,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_rounded, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          '저장됐어요!',
          style: AppTheme.bodyMedium.copyWith(
            fontWeight: FontWeight.w400,
            color: color,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool optional;

  const _FieldLabel({
    required this.icon,
    required this.label,
    required this.color,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '선택',
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _InputTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InputTool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: ShapeDecoration(
          color: context.appCardElevated,
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.circular(10),
            side: BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: context.appPrimaryAccent),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTheme.captionSmall.copyWith(
                color: context.appPrimaryAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
