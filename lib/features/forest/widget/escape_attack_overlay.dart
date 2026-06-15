import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/passive_aggro_engine.dart';

const _kFont = AppTheme.fontFamily;

enum EscapeAttackTrigger { escapeAttempt, backgroundReturn }

// 이탈 시도 문구는 PassiveAggroEngine(sessionEscape)로 일원화한다.
// 복귀 환영 문구는 공격이 아니라 환영 톤이므로 여기에 유지한다.
const _kReturnMessages = [
  '돌아왔군요. 계속 읽어봐요.',
  '다시 돌아왔어요. 잠깐이었길 바라요.',
  '독서로 돌아온 걸 환영해요.',
];

class EscapeAttackOverlay extends StatefulWidget {
  final EscapeAttackTrigger trigger;
  final int? absentSeconds;
  final VoidCallback onDismiss;

  const EscapeAttackOverlay({
    super.key,
    required this.trigger,
    this.absentSeconds,
    required this.onDismiss,
  });

  @override
  State<EscapeAttackOverlay> createState() => _EscapeAttackOverlayState();
}

class _EscapeAttackOverlayState extends State<EscapeAttackOverlay> {
  // 부모(세션 화면)가 타이머 틱마다 리빌드되므로, 문구는 오버레이가
  // 나타날 때 한 번만 뽑아 고정한다 (build에서 뽑으면 매번 바뀜).
  late final String _message = _pickMessage();

  String _pickMessage() {
    return switch (widget.trigger) {
      EscapeAttackTrigger.escapeAttempt => PassiveAggroEngine.messageFor(
        AggroTrigger.sessionEscape,
        const AggroContext(),
      ),
      EscapeAttackTrigger.backgroundReturn =>
        _kReturnMessages[Random().nextInt(_kReturnMessages.length)],
    };
  }

  String? _absentLabel() {
    final s = widget.absentSeconds;
    if (s == null || s < 5) return null;
    if (s < 60) return '$s초 동안 자리를 비웠어요.';
    final m = s ~/ 60;
    return '$m분 동안 자리를 비웠어요.';
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    final absentLabel = _absentLabel();

    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 24,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
                if (absentLabel != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    absentLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      widget.onDismiss();
                    },
                    child: const Text(
                      '계속 읽을게요',
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
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
