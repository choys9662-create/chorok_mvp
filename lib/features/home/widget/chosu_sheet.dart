import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/widgets/sheet_handle.dart';

/// 초서 바텀시트 — 문장 수집 + 내 생각 입력 UI
class ChosuSheet extends StatefulWidget {
  /// OCR / STT로 인식된 텍스트를 미리 채울 때 사용
  final String initialText;
  final String bookTitle;

  const ChosuSheet({super.key, this.initialText = '', this.bookTitle = ''});

  @override
  State<ChosuSheet> createState() => _ChosuSheetState();
}

class _ChosuSheetState extends State<ChosuSheet> {
  late final TextEditingController _sentenceCtrl;
  final _thoughtCtrl = TextEditingController();
  final _sentenceFocus = FocusNode();
  final _thoughtFocus = FocusNode();
  bool _isWritingThought = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _sentenceCtrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _sentenceCtrl.dispose();
    _thoughtCtrl.dispose();
    _sentenceFocus.dispose();
    _thoughtFocus.dispose();
    super.dispose();
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
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight =
        media.size.height - keyboardInset - media.padding.top - 12;
    final maxSheetHeight = availableHeight
        .clamp(320.0, media.size.height * 0.92)
        .toDouble();
    final bottomPadding = keyboardInset > 0 ? 20.0 : media.padding.bottom + 20;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: ShapeDecoration(
          color: context.appCard,
          shape: const SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius.vertical(
              top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.6),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ChorokSheetHandle(),
                const SizedBox(height: 20),

                // 헤더
                Row(
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      color: context.appPrimaryAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '문장 수집',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.bookTitle.isNotEmpty)
                      Text(
                        widget.bookTitle,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _StepHeader(isWritingThought: _isWritingThought),
                const SizedBox(height: 18),

                if (_isWritingThought)
                  _ThoughtStep(
                    sentence: _sentenceCtrl.text.trim(),
                    thoughtCtrl: _thoughtCtrl,
                    thoughtFocus: _thoughtFocus,
                    saved: _saved,
                    canSave: _sentenceCtrl.text.trim().isNotEmpty,
                    onBack: () => setState(() => _isWritingThought = false),
                    onSave: _save,
                  )
                else
                  _SentenceStep(
                    sentenceCtrl: _sentenceCtrl,
                    sentenceFocus: _sentenceFocus,
                    saved: _saved,
                    onChanged: (_) => setState(() {}),
                    onContinue: _openThoughtStep,
                    onSave: _save,
                  ),
              ],
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
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: context.appBorder,
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
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: active ? context.appPrimaryAccent : context.appCardElevated,
            shape: const StadiumBorder(),
          ),
          child: Text(
            number,
            style: AppTheme.captionSmall.copyWith(
              color: active ? Colors.black : context.appTextTertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTheme.captionLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SentenceStep extends StatelessWidget {
  final TextEditingController sentenceCtrl;
  final FocusNode sentenceFocus;
  final bool saved;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onSave;

  const _SentenceStep({
    required this.sentenceCtrl,
    required this.sentenceFocus,
    required this.saved,
    required this.onChanged,
    required this.onContinue,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasSentence = sentenceCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          icon: Icons.format_quote_rounded,
          label: '수집할 문장',
          color: context.appPrimaryAccent,
        ),
        const SizedBox(height: 8),
        _ChosuTextField(
          controller: sentenceCtrl,
          focusNode: sentenceFocus,
          hintText: '마음에 남은 문장을 입력하세요...',
          minLines: 7,
          maxLines: 9,
          italic: true,
          autofocus: true,
          cursorColor: context.appPrimaryAccent,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${sentenceCtrl.text.length}자',
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: hasSentence ? onContinue : null,
            style: _primaryButtonStyle(context),
            child: Text(
              '생각 쓰기',
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: hasSentence ? Colors.black : context.appTextTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
    );
  }
}

class _ThoughtStep extends StatelessWidget {
  final String sentence;
  final TextEditingController thoughtCtrl;
  final FocusNode thoughtFocus;
  final bool saved;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _ThoughtStep({
    required this.sentence,
    required this.thoughtCtrl,
    required this.thoughtFocus,
    required this.saved,
    required this.canSave,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: context.appCardElevated,
            shape: SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius(
                cornerRadius: 12,
                cornerSmoothing: 0.6,
              ),
              side: BorderSide.none,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _FieldLabel(
          icon: Icons.edit_note_rounded,
          label: '내 생각',
          color: context.appAccentColor,
          optional: true,
        ),
        const SizedBox(height: 8),
        _ChosuTextField(
          controller: thoughtCtrl,
          focusNode: thoughtFocus,
          hintText: '이 문장에서 무엇을 느꼈나요?',
          minLines: 6,
          maxLines: 8,
          cursorColor: context.appAccentColor,
          onChanged: (_) {},
        ),
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
    );
  }
}

class _ChosuTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool italic;
  final bool autofocus;
  final Color cursorColor;
  final ValueChanged<String> onChanged;

  const _ChosuTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    this.italic = false,
    this.autofocus = false,
    required this.cursorColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: context.appCardElevated,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 14,
            cornerSmoothing: 0.6,
          ),
          side: BorderSide(
            color: cursorColor.withValues(alpha: 0.65),
            width: 1.2,
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: minLines,
        maxLines: maxLines,
        autofocus: autofocus,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        cursorColor: cursorColor,
        style: AppTheme.bodyMedium.copyWith(
          color: context.appTextPrimary,
          height: 1.75,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.bodyMedium.copyWith(
            color: context.appTextTertiary,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

ButtonStyle _primaryButtonStyle(BuildContext context, {bool saved = false}) {
  return FilledButton.styleFrom(
    backgroundColor: saved ? context.appAccentColor : context.appPrimaryAccent,
    disabledBackgroundColor: context.appBorder,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: SmoothRectangleBorder(
      borderRadius: SmoothBorderRadius(cornerRadius: 12, cornerSmoothing: 0.6),
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
    final color = primary
        ? (enabled ? Colors.black : context.appTextTertiary)
        : context.appTextTertiary;

    if (!saved) {
      return Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
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
          style: AppTheme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
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
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTheme.captionLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '선택',
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
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
            borderRadius: SmoothBorderRadius(
              cornerRadius: 8,
              cornerSmoothing: 0.6,
            ),
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
