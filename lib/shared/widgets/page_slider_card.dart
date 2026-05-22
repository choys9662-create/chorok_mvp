import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// 슬라이더 + 숫자 직접 입력으로 페이지를 선택하는 카드.
///
/// 슬라이더로 빠르게 조절하거나 숫자를 탭해 키보드로 직접 입력 가능.
/// [onPageChanged]는 값이 바뀔 때마다 호출되고 (선택적 실시간 동기화),
/// [onSave]는 저장 버튼을 탭할 때만 호출된다.
class PageSliderCard extends StatefulWidget {
  final int initialPage;
  final int totalPages;
  final String title;
  final String saveLabel;
  final bool isSaving;
  final Widget? trailing;
  final ValueChanged<int>? onPageChanged;
  final Future<void> Function(int page) onSave;

  const PageSliderCard({
    super.key,
    required this.initialPage,
    required this.totalPages,
    required this.onSave,
    this.title = '현재 페이지',
    this.saveLabel = '저장하기',
    this.isSaving = false,
    this.trailing,
    this.onPageChanged,
  });

  @override
  State<PageSliderCard> createState() => _PageSliderCardState();
}

class _PageSliderCardState extends State<PageSliderCard> {
  late int _page;
  late final TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage;
    _ctrl = TextEditingController(text: '$_page');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commitText();
    });
  }

  @override
  void didUpdateWidget(PageSliderCard old) {
    super.didUpdateWidget(old);
    if (widget.totalPages != old.totalPages && _page > widget.totalPages) {
      _setPage(widget.totalPages);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _max => widget.totalPages > 0 ? widget.totalPages : 9999;

  void _setPage(int value) {
    final clamped = value.clamp(0, _max);
    if (clamped == _page) return;
    setState(() {
      _page = clamped;
      _ctrl.text = '$clamped';
      _ctrl.selection = TextSelection.collapsed(offset: '$clamped'.length);
    });
    widget.onPageChanged?.call(clamped);
    HapticFeedback.selectionClick();
  }

  void _commitText() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed != null) {
      _setPage(parsed);
    } else {
      _ctrl.text = '$_page';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalPages;
    final sliderMax = total > 0 ? total.toDouble() : 100.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: 16,
        side: BorderSide(color: context.appBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          const SizedBox(height: 12),

          // 페이지 숫자 — 탭하면 키보드 열림
          GestureDetector(
            onTap: () {
              _focusNode.requestFocus();
              _ctrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _ctrl.text.length,
              );
            },
            child: Center(
              child: IntrinsicWidth(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onSubmitted: (_) {
                    _commitText();
                    _focusNode.unfocus();
                  },
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: context.appPrimaryAccent,
                    height: 1.1,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                    suffixIcon: Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: context.appTextTertiary,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      maxWidth: 20,
                      maxHeight: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (total > 0)
            Center(
              child: Text(
                '/ $total쪽',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove,
                onPressed: () => _setPage(_page - 1),
              ),
              _StepButton(
                icon: Icons.add,
                onPressed: () => _setPage(_page + 1),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: context.appPrimaryAccent,
              inactiveTrackColor: context.appBorder,
              thumbColor: context.appPrimaryAccent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: context.appPrimaryAccent.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _page.toDouble().clamp(0, sliderMax),
              min: 0,
              max: sliderMax,
              onChanged: (v) => _setPage(v.round()),
            ),
          ),

          const SizedBox(height: 4),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.isSaving
                  ? null
                  : () {
                      _commitText();
                      widget.onSave(_page);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                disabledBackgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.05,
                ),
                shape: AppTheme.smoothShape(radius: 8),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: widget.isSaving
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.appPrimaryAccent,
                      ),
                    )
                  : Text(
                      widget.saveLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: ShapeDecoration(
          color: context.appCard,
          shape: CircleBorder(side: BorderSide(color: context.appBorderSubtle)),
        ),
        child: Icon(icon, size: 16, color: context.appPrimaryAccent),
      ),
    );
  }
}
