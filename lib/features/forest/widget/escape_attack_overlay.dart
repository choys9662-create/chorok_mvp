import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

const _kFont = '조선굴림체';

enum EscapeAttackTrigger { escapeAttempt, backgroundReturn }

const _kEscapeMessages = [
  '조금만 더 읽어봐요.\n지금 멈추기엔 너무 아까워요.',
  '지금 함께 읽고 있는 사람들이 있어요.\n혼자 나갈 건가요?',
  '오늘 기록이 완성되지 않아요.\n여기서 멈추면 안 돼요.',
];

const _kReturnMessages = [
  '돌아왔군요. 계속 읽어봐요.',
  '다시 돌아왔어요. 잠깐이었길 바라요.',
  '독서로 돌아온 걸 환영해요.',
];

class EscapeAttackOverlay extends StatelessWidget {
  final EscapeAttackTrigger trigger;
  final int? absentSeconds;
  final VoidCallback onDismiss;

  const EscapeAttackOverlay({
    super.key,
    required this.trigger,
    this.absentSeconds,
    required this.onDismiss,
  });

  String _pickMessage() {
    final rng = Random();
    return switch (trigger) {
      EscapeAttackTrigger.escapeAttempt =>
        _kEscapeMessages[rng.nextInt(_kEscapeMessages.length)],
      EscapeAttackTrigger.backgroundReturn =>
        _kReturnMessages[rng.nextInt(_kReturnMessages.length)],
    };
  }

  String? _absentLabel() {
    final s = absentSeconds;
    if (s == null || s < 5) return null;
    if (s < 60) return '$s초 동안 자리를 비웠어요.';
    final m = s ~/ 60;
    return '$m분 동안 자리를 비웠어요.';
  }

  @override
  Widget build(BuildContext context) {
    final message = _pickMessage();
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
                    fontSize: 20,
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
                      fontSize: 14,
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onDismiss();
                    },
                    child: const Text(
                      '계속 읽을게요',
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
