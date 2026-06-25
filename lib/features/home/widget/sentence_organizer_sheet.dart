import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../core/theme/app_theme.dart';

/// OCR로 인식한 텍스트를 문장 단위로 끊어 보여주고,
/// 사용자가 여러 문장을 골라 하나로 합치거나(문단) 따로 둘 수 있게 하는 시트.
///
/// 합치기는 저장 전 클라이언트 합성이라 추가 비용/네트워크가 없다.
/// 결과로 최종 블록 목록(`List<String>`)을 pop 한다. 각 블록이 곧 저장 1행.
/// 추가 촬영 1회의 OCR 결과. null이면 취소/실패(시트는 그대로 유지).
typedef OcrCapture = ({String text, List<String>? sentences});

class SentenceOrganizerSheet extends StatefulWidget {
  final String rawText;

  /// AI가 이미 문장 단위로 끊어 준 경우. 있으면 규칙 분리 대신 그대로 사용한다.
  final List<String>? sentences;

  /// 다음 페이지를 추가로 촬영해 문장을 이어 붙일 때 호출. null이면 버튼을 숨긴다.
  final Future<OcrCapture?> Function()? onCapture;

  const SentenceOrganizerSheet({
    super.key,
    required this.rawText,
    this.sentences,
    this.onCapture,
  });

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

  static List<String> _blocksFrom(String text, List<String>? sentences) =>
      (sentences != null && sentences.isNotEmpty)
      ? List.of(sentences)
      : _split(text);

  // AI가 끊어 준 문장이 있으면 그대로, 없으면 규칙 분리로 폴백.
  late List<String> _initial = _blocksFrom(widget.rawText, widget.sentences);
  late List<String> _blocks = List.of(_initial);
  final Set<int> _selected = <int>{};
  int _justMergedCount = 0;
  bool _capturing = false;

  static const _red = Color(0xFFE5484D);

  String get _headerText {
    if (_justMergedCount > 0) return '$_justMergedCount개의 문장을 합쳤어요';
    if (_selected.isNotEmpty) return '${_selected.length}개의 문장을 선택했어요';
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
      _selected
        ..clear()
        ..add(insertAt);
    });
  }

  void _reset() {
    setState(() {
      _blocks = List.of(_initial);
      _selected.clear();
      _justMergedCount = 0;
    });
  }

  // 다음 페이지를 촬영해 인식된 문장을 목록 끝에 이어 붙인다. 끝에 더하므로
  // 기존 인덱스가 안 밀려 선택·합치기 상태가 유지된다. _reset 기준선도 함께 늘린다.
  Future<void> _addCapture() async {
    if (_capturing || widget.onCapture == null) return;
    setState(() => _capturing = true);
    OcrCapture? capture;
    try {
      capture = await widget.onCapture!();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
    if (!mounted || capture == null) return;
    final added = _blocksFrom(capture.text, capture.sentences);
    if (added.isEmpty) return;
    setState(() {
      _initial = [..._initial, ...added];
      _blocks = [..._blocks, ...added];
      _justMergedCount = 0;
    });
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    final selectedBlocks = _selected.toList()
      ..sort();
    Navigator.pop(
      context,
      selectedBlocks.map((index) => _blocks[index]).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canMerge = _selected.length >= 2;
    final canConfirm = _selected.isNotEmpty;
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
                  if (widget.onCapture != null) ...[
                    const SizedBox(width: 12),
                    _CircleAction(
                      icon: Icons.add_a_photo_outlined,
                      color: context.appPrimaryAccent,
                      tooltip: '다음 페이지 추가 촬영',
                      onTap: _capturing ? null : _addCapture,
                    ),
                  ],
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
                    onTap: canConfirm ? _confirm : null,
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
