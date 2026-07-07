import 'dart:math' as math;

import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import 'web_keyboard_inset.dart';

const _chosuSheetPadding = 41.0;

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

  void _saveSentenceOnly() {
    _thoughtCtrl.clear();
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = math.max(
      media.viewInsets.bottom,
      _webKeyboardInset.inset,
    );

    // 카드 위치는 키보드와 무관하게 고정한다.
    // 키보드 높이에 따라 위치를 계산하면 키보드가 나타나거나 전환될 때마다
    // 카드가 아래위로 출렁이므로, 키보드가 열려도 가리지 않는 상단 고정 위치를 쓴다.
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = math.min(
                constraints.maxWidth - (_chosuSheetPadding * 2),
                360.0,
              );

              return Align(
                alignment: const Alignment(0, -0.18),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: SizedBox(
                    width: cardWidth,
                    height: _isWritingThought ? 270 : 238,
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
                              onSave: _saveSentenceOnly,
                              autofocus: widget.autofocusSentence,
                              keyboardInset: keyboardInset,
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
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
    required this.keyboardInset,
  });

  @override
  Widget build(BuildContext context) {
    final hasSentence = sentenceCtrl.text.trim().isNotEmpty;

    return _InputCard(
      child: Column(
        children: [
          SizedBox(
            height: 35,
            child: TextField(
              controller: pageCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              style: AppTheme.bodySmall.copyWith(
                color: context.appTextSecondary,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                hintText: '페이지 입력, p',
                hintStyle: AppTheme.bodySmall.copyWith(
                  color: context.appTextTertiary,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: context.appBorderSubtle.withValues(alpha: 0.36),
          ),
          Expanded(
            child: _ChosuTextField(
              controller: sentenceCtrl,
              focusNode: sentenceFocus,
              hintText: '',
              expands: true,
              autofocus: autofocus,
              cursorColor: context.appPrimaryAccent,
              keyboardInset: keyboardInset,
              onChanged: onChanged,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Wrap(
                spacing: 11,
                children: [
                  _CardIconButton(
                    tooltip: '생각 쓰기',
                    icon: Icons.chat_bubble_outline_rounded,
                    enabled: hasSentence,
                    primary: true,
                    saved: false,
                    onPressed: onContinue,
                  ),
                  _CardIconButton(
                    tooltip: '문장만 저장',
                    icon: saved ? Icons.check_rounded : Icons.add_rounded,
                    enabled: hasSentence,
                    primary: false,
                    saved: saved,
                    onPressed: onSave,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final Widget child;

  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(17, 14, 17, 15),
      decoration: ShapeDecoration(
        color: context.appCard.withValues(alpha: 0.96),
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(7),
          side: BorderSide.none,
        ),
      ),
      child: child,
    );
  }
}

class _CardIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final bool primary;
  final bool saved;
  final VoidCallback onPressed;

  const _CardIconButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.primary,
    required this.saved,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final background = primary || saved
        ? context.appPrimaryAccent
        : context.appTextTertiary;
    final foreground = primary || saved ? Colors.black : context.appBg;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            backgroundColor: enabled
                ? background
                : background.withValues(alpha: 0.36),
            foregroundColor: foreground,
            disabledForegroundColor: foreground.withValues(alpha: 0.52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _ThoughtStep extends StatelessWidget {
  final String sentence;
  final TextEditingController thoughtCtrl;
  final FocusNode thoughtFocus;
  final bool saved;
  final bool canSave;
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
    required this.keyboardInset,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _InputCard(
      child: Column(
        children: [
          SizedBox(
            height: 54,
            width: double.infinity,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              child: Text(
                sentence,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextTertiary,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: context.appBorderSubtle.withValues(alpha: 0.36),
          ),
          Expanded(
            key: const ValueKey('thought-field'),
            child: _ChosuTextField(
              controller: thoughtCtrl,
              focusNode: thoughtFocus,
              hintText: '생각 입력',
              expands: true,
              cursorColor: context.appAccentColor,
              keyboardInset: keyboardInset,
              onChanged: (_) {},
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: _CardIconButton(
                tooltip: '저장하기',
                icon: saved ? Icons.check_rounded : Icons.add_rounded,
                enabled: canSave,
                primary: true,
                saved: saved,
                onPressed: onSave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChosuTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool expands;
  final bool autofocus;
  final Color cursorColor;
  final double keyboardInset;
  final ValueChanged<String> onChanged;

  const _ChosuTextField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.expands = false,
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

    return TextField(
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
      style: AppTheme.bodySmall.copyWith(
        color: context.appTextPrimary,
        height: 1.55,
        letterSpacing: 0,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTheme.bodySmall.copyWith(
          color: context.appTextTertiary,
          letterSpacing: 0,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.only(top: 12),
      ),
      onChanged: widget.onChanged,
    );
  }
}
