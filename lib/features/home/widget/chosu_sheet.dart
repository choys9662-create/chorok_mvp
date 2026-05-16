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
    super.dispose();
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
    return Container(
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.vertical(
            top: SmoothRadius(cornerRadius: 24, cornerSmoothing: 0.6),
          ),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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

              // ── 문장 입력 ──────────────────────────────────────
              _FieldLabel(
                icon: Icons.format_quote_rounded,
                label: '수집할 문장',
                color: context.appPrimaryAccent,
              ),
              const SizedBox(height: 6),
              Container(
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
                child: TextField(
                  controller: _sentenceCtrl,
                  maxLines: 4,
                  autofocus: true,
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.appTextPrimary,
                    height: 1.7,
                    fontStyle: FontStyle.italic,
                  ),
                  decoration: InputDecoration(
                    hintText: '마음에 남은 문장을 입력하세요...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: context.appTextTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),

              // 글자 수 표시
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_sentenceCtrl.text.length}자',
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── 내 생각 입력 ───────────────────────────────────
              _FieldLabel(
                icon: Icons.edit_note_rounded,
                label: '내 생각',
                color: AppTheme.accent,
                optional: true,
              ),
              const SizedBox(height: 6),
              Container(
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
                child: TextField(
                  controller: _thoughtCtrl,
                  maxLines: 3,
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.appTextPrimary,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText: '이 문장에서 무엇을 느꼈나요?',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: context.appTextTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 16),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _sentenceCtrl.text.trim().isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _saved
                        ? AppTheme.accent
                        : context.appPrimaryAccent,
                    disabledBackgroundColor: context.appBorder,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 12,
                        cornerSmoothing: 0.6,
                      ),
                    ),
                  ),
                  child: _saved
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '저장됐어요!',
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '저장하기',
                          style: AppTheme.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _sentenceCtrl.text.trim().isEmpty
                                ? context.appTextTertiary
                                : Colors.black,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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
