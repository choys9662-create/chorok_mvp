import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/passive_aggro_engine.dart';

const _kFont = AppTheme.fontFamily;

class EscapeAttackOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const EscapeAttackOverlay({super.key, required this.onDismiss});

  @override
  State<EscapeAttackOverlay> createState() => _EscapeAttackOverlayState();
}

class _EscapeAttackOverlayState extends State<EscapeAttackOverlay> {
  // 부모(세션 화면)가 타이머 틱마다 리빌드되므로, 문구는 오버레이가
  // 나타날 때 한 번만 뽑아 고정한다 (build에서 뽑으면 매번 바뀜).
  late final String _message = _pickMessage();

  String _pickMessage() => PassiveAggroEngine.messageFor(
    AggroTrigger.sessionEscape,
    const AggroContext(),
  );

  @override
  Widget build(BuildContext context) {
    final message = _message;

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
                  // 구조상 예외: 몰입 이탈-방지 오버레이 전용 디스플레이 문구.
                  // 동적 메시지 길이·1.6 줄간격에 맞춘 값으로 6단계 스케일
                  // (18/30) 중 어느 쪽으로 스냅해도 등거리라 임의 결정 대신 유지.
                  style: const TextStyle(
                    fontFamily: _kFont,
                    fontSize: 24,
                    color: Colors.white,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceLG,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
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
                        fontSize: AppTheme.fsRowText,
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
