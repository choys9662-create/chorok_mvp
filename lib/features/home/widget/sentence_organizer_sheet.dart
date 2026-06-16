import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../core/theme/app_theme.dart';

/// OCR로 인식한 텍스트를 문장 단위로 끊어 보여주고,
/// 사용자가 여러 문장을 골라 하나로 합치거나(문단) 따로 둘 수 있게 하는 시트.
///
/// 합치기는 저장 전 클라이언트 합성이라 추가 비용/네트워크가 없다.
/// 결과로 최종 블록 목록(`List<String>`)을 pop 한다. 각 블록이 곧 저장 1행.
class SentenceOrganizerSheet extends StatefulWidget {
  final String rawText;

  const SentenceOrganizerSheet({super.key, required this.rawText});

  @override
  State<SentenceOrganizerSheet> createState() => _SentenceOrganizerSheetState();
}

class _SentenceOrganizerSheetState extends State<SentenceOrganizerSheet> {
  /// 문단 사이 줄바꿈은 살리고, 종결부호(. ! ? 등)를 보존해 문장 단위로 끊는다.
  /// SentenceNormalizer.tokenize는 부호를 떼어내 합칠 때 가독성이 떨어지므로 별도 분리.
  static List<String> _split(String text) {
    final result = <String>[];
    final sentence = RegExp(r'[^.!?。！？…\n]+[.!?。！？…]*');
    for (final line in text.split('\n')) {
      for (final m in sentence.allMatches(line)) {
        final s = m.group(0)!.trim();
        if (s.isNotEmpty) result.add(s);
      }
    }
    // 부호가 전혀 없어 분리되지 않으면 통째로 한 블록.
    if (result.isEmpty) {
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) result.add(trimmed);
    }
    return result;
  }

  late final List<String> _initial = _split(widget.rawText);
  late List<String> _blocks = List.of(_initial);
  final Set<int> _selected = <int>{};
  int _justMergedCount = 0;

  static const _red = Color(0xFFE5484D);

  String get _headerText {
    if (_selected.isNotEmpty) return '${_selected.length}개의 문장을 선택했어요';
    if (_justMergedCount > 0) return '$_justMergedCount개의 문장을 합쳤어요';
    return '${_blocks.length}개의 문장을 찾았어요';
  }

  void _toggle(int index) {
    setState(() {
      _justMergedCount = 0;
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _merge() {
    if (_selected.length < 2) return;
    final indices = _selected.toList()..sort();
    final merged = indices.map((i) => _blocks[i]).join(' ');
    final insertAt = indices.first;
    setState(() {
      for (final i in indices.reversed) {
        _blocks.removeAt(i);
      }
      _blocks.insert(insertAt, merged);
      _justMergedCount = indices.length;
      _selected.clear();
    });
  }

  void _reset() {
    setState(() {
      _blocks = List.of(_initial);
      _selected.clear();
      _justMergedCount = 0;
    });
  }

  void _confirm() {
    Navigator.pop(context, List<String>.from(_blocks));
  }

  @override
  Widget build(BuildContext context) {
    final canMerge = _selected.length >= 2;
    return Material(
      color: context.appBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Handle(),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _headerText,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextTertiary,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      tooltip: '닫기',
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.appTextTertiary,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: _blocks.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _SentenceCard(
                    text: _blocks[i],
                    selected: _selected.contains(i),
                    onTap: () => _toggle(i),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _CircleAction(
                    icon: Icons.refresh_rounded,
                    color: _red,
                    tooltip: '되돌리기',
                    onTap: _blocks.length == _initial.length ? null : _reset,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MergeButton(
                      enabled: canMerge,
                      onTap: canMerge ? _merge : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CircleAction(
                    icon: Icons.check_rounded,
                    color: context.appPrimaryAccent,
                    tooltip: '문장 기록하기',
                    filled: true,
                    onTap: _confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _SentenceCard({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimaryAccent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
        decoration: ShapeDecoration(
          color: selected
              ? accent.withValues(alpha: 0.10)
              : context.appCard.withValues(alpha: 0.78),
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? accent : context.appBorderSubtle,
              width: selected ? 1.6 : 1.2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Checkbox(selected: selected),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextPrimary,
                  height: 1.6,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool selected;

  const _Checkbox({required this.selected});

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimaryAccent;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: selected ? accent : Colors.transparent,
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: selected ? accent : context.appTextTertiary,
            width: 1.5,
          ),
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.black)
          : null,
    );
  }
}

class _MergeButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;

  const _MergeButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? context.appTextPrimary : context.appTextTertiary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: context.appCardElevated.withValues(alpha: enabled ? 0.9 : 0.5),
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: enabled
                  ? context.appPrimaryAccent.withValues(alpha: 0.5)
                  : context.appBorderSubtle,
              width: 1.2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_rounded, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              '문장 합치기',
              style: AppTheme.bodyMedium.copyWith(
                color: fg,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final bool filled;
  final VoidCallback? onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = filled
        ? color.withValues(alpha: enabled ? 1 : 0.4)
        : color.withValues(alpha: enabled ? 0.16 : 0.06);
    final fg = filled ? Colors.black : color.withValues(alpha: enabled ? 1 : 0.4);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: bg,
            shape: SmoothRectangleBorder(
              smoothness: 0.6,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 24, color: fg),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
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
