import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 초서 바텀시트 — 문장 수집 입력 UI
class ChosuSheet extends StatefulWidget {
  const ChosuSheet({super.key});

  @override
  State<ChosuSheet> createState() => _ChosuSheetState();
}

class _ChosuSheetState extends State<ChosuSheet> {
  final _controller = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saved = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context, _controller.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              // 핸들
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 헤더
              Row(
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: AppTheme.primaryLight, size: 20),
                  const SizedBox(width: 8),
                  Text('초서하기',
                      style: AppTheme.headingSmall.copyWith(
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  Text('채식주의자 · 186쪽',
                      style: AppTheme.captionSmall.copyWith(
                          color: AppTheme.textTertiary)),
                ],
              ),
              const SizedBox(height: 16),

              // 텍스트 입력
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _controller.text.isNotEmpty
                        ? AppTheme.primaryLight.withValues(alpha: 0.4)
                        : AppTheme.darkBorder,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  autofocus: true,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                    height: 1.7,
                    fontStyle: FontStyle.italic,
                  ),
                  decoration: InputDecoration(
                    hintText: '마음에 남은 문장을 입력하세요...',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiary,
                        fontStyle: FontStyle.italic),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 12),

              // 입력 도구 버튼 행
              Row(
                children: [
                  _InputTool(
                    icon: Icons.camera_alt_outlined,
                    label: 'OCR',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('OCR 기능은 출시 예정이에요',
                              style: AppTheme.bodySmall),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  _InputTool(
                    icon: Icons.mic_outlined,
                    label: 'STT',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('음성 입력 기능은 출시 예정이에요',
                              style: AppTheme.bodySmall),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  // 글자 수
                  Text(
                    '${_controller.text.length}자',
                    style: AppTheme.captionSmall.copyWith(
                        color: AppTheme.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _controller.text.trim().isEmpty ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _saved
                        ? AppTheme.accent
                        : AppTheme.primaryLight,
                    disabledBackgroundColor: AppTheme.darkBorder,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saved
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 18),
                            const SizedBox(width: 6),
                            Text('저장됐어요!',
                                style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black)),
                          ],
                        )
                      : Text('저장하기',
                          style: AppTheme.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _controller.text.trim().isEmpty
                                  ? AppTheme.textTertiary
                                  : Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InputTool({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkCardElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.primaryLight),
            const SizedBox(width: 5),
            Text(label,
                style: AppTheme.captionSmall.copyWith(
                    color: AppTheme.primaryLight)),
          ],
        ),
      ),
    );
  }
}
