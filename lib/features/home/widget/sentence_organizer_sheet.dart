import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../core/theme/app_theme.dart';

/// OCR로 인식한 텍스트를 문단→문장 구조로 보여주고,
/// 사용자가 같은 문단 안의 문장들을 골라 하나로 합칠 수 있게 하는 시트.
/// 최대 기록 단위는 한 문단 — 문단 경계를 넘는 합치기는 막는다.
///
/// 합치기는 저장 전 클라이언트 합성이라 추가 비용/네트워크가 없다.
/// 결과로 최종 블록 목록(`List<String>`)을 pop 한다. 각 블록이 곧 저장 1행.
/// 추가 촬영 1회의 OCR 결과. null이면 취소/실패(시트는 그대로 유지).
typedef OcrCapture = ({String text, List<List<String>>? paragraphs});

/// 시트 내부 블록: 문장 텍스트 + 소속 문단 번호.
typedef _Block = ({String text, int para});

class SentenceOrganizerSheet extends StatefulWidget {
  final String rawText;

  /// AI가 문단→문장 구조로 끊어 준 경우. 있으면 규칙 분리 대신 그대로 사용한다.
  final List<List<String>>? paragraphs;

  /// 다음 페이지를 추가로 촬영해 문장을 이어 붙일 때 호출. null이면 버튼을 숨긴다.
  final Future<OcrCapture?> Function()? onCapture;

  const SentenceOrganizerSheet({
    super.key,
    required this.rawText,
    this.paragraphs,
    this.onCapture,
  });

  @override
  State<SentenceOrganizerSheet> createState() => _SentenceOrganizerSheetState();
}

class _SentenceOrganizerSheetState extends State<SentenceOrganizerSheet> {
  /// 문단 사이 줄바꿈(한 줄 = 한 문단)을 살리고, 종결부호(. ! ? 등)를 보존해
  /// 문장 단위로 끊는다. SentenceNormalizer.tokenize는 부호를 떼어내
  /// 합칠 때 가독성이 떨어지므로 별도 분리.
  static List<_Block> _split(String text) {
    final result = <_Block>[];
    final sentence = RegExp(r'[^.!?。！？…\n]+[.!?。！？…]*');
    var para = 0;
    for (final line in text.split('\n')) {
      var added = false;
      for (final m in sentence.allMatches(line)) {
        final s = m.group(0)!.trim();
        if (s.isNotEmpty) {
          result.add((text: s, para: para));
          added = true;
        }
      }
      if (added) para++;
    }
    // 부호가 전혀 없어 분리되지 않으면 통째로 한 블록.
    if (result.isEmpty) {
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) result.add((text: trimmed, para: 0));
    }
    return result;
  }

  /// AI가 끊어 준 문단→문장 구조가 있으면 그대로, 없으면 규칙 분리로 폴백.
  /// [paraOffset]은 추가 촬영분이 기존 문단과 섞이지 않게 문단 번호를 밀어 준다.
  static List<_Block> _blocksFrom(
    String text,
    List<List<String>>? paragraphs, {
    int paraOffset = 0,
  }) {
    final blocks = (paragraphs != null && paragraphs.isNotEmpty)
        ? [
            for (final (p, sentences) in paragraphs.indexed)
              for (final s in sentences)
                if (s.trim().isNotEmpty) (text: s.trim(), para: p),
          ]
        : _split(text);
    return paraOffset == 0
        ? blocks
        : [
            for (final b in blocks) (text: b.text, para: b.para + paraOffset),
          ];
  }

  late List<_Block> _initial = _blocksFrom(widget.rawText, widget.paragraphs);
  late List<_Block> _blocks = List.of(_initial);
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

  /// 선택이 2개 이상이고 모두 같은 문단일 때만 합칠 수 있다(최대 단위 = 한 문단).
  bool get _canMerge =>
      _selected.length >= 2 &&
      _selected.map((i) => _blocks[i].para).toSet().length == 1;

  void _merge() {
    if (!_canMerge) return;
    final indices = _selected.toList()..sort();
    final merged = indices.map((i) => _blocks[i].text).join(' ');
    final insertAt = indices.first;
    final para = _blocks[insertAt].para;
    setState(() {
      for (final i in indices.reversed) {
        _blocks.removeAt(i);
      }
      _blocks.insert(insertAt, (text: merged, para: para));
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
    final added = _blocksFrom(
      capture.text,
      capture.paragraphs,
      // 새 촬영분의 문단은 기존 마지막 문단 다음부터 시작한다.
      paraOffset: _initial.isEmpty ? 0 : _initial.last.para + 1,
    );
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
      selectedBlocks
          .map((index) => _blocks[index].text)
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canMerge = _canMerge;
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
                  // 문단이 바뀌는 자리는 간격을 넓혀 문단 단위를 드러낸다.
                  separatorBuilder: (_, i) => SizedBox(
                    height: _blocks[i].para == _blocks[i + 1].para ? 12 : 28,
                  ),
                  itemBuilder: (_, i) => _SentenceCard(
                    text: _blocks[i].text,
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
                  // 같은 문단 여러 문장 선택 → 합치기, 그 외(한 문장·합친 뒤) → 추가.
                  Expanded(
                    child: canMerge
                        ? _MainButton(
                            icon: Icons.merge_rounded,
                            label: '문장 합치기',
                            enabled: true,
                            onTap: _merge,
                          )
                        : _MainButton(
                            icon: Icons.check_rounded,
                            label: '추가',
                            enabled: canConfirm,
                            onTap: canConfirm ? _confirm : null,
                          ),
                  ),
                  if (widget.onCapture != null) ...[
                    const SizedBox(width: 12),
                    _CircleAction(
                      icon: Icons.add_a_photo_outlined,
                      color: context.appPrimaryAccent,
                      tooltip: '추가 촬영',
                      filled: true,
                      onTap: _capturing ? null : _addCapture,
                    ),
                  ],
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

class _MainButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _MainButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

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
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
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
