import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/services/screen_time_detox_service.dart';
import '../../../features/timer/controller/timer_controller.dart';
import 'escape_attack_overlay.dart';

class ForestLockLayer extends ConsumerStatefulWidget {
  final Widget child;

  const ForestLockLayer({super.key, required this.child});

  @override
  ConsumerState<ForestLockLayer> createState() => _ForestLockLayerState();
}

class _ForestLockLayerState extends ConsumerState<ForestLockLayer> {
  bool _showAttack = false;
  bool _restoringDetox = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreDetoxIfNeeded(),
    );
  }

  void _onEscapeAttempt() {
    setState(() => _showAttack = true);
  }

  void _dismissAttack() {
    setState(() => _showAttack = false);
  }

  Future<void> _restoreDetoxIfNeeded() async {
    if (kUseMock || _restoringDetox || ref.read(timerProvider).isIdle) return;
    _restoringDetox = true;
    final enabled = await ScreenTimeDetoxService.instance.isDetoxEnabled();
    if (!enabled) {
      await ScreenTimeDetoxService.instance.startDetox();
    }
    _restoringDetox = false;
  }

  @override
  Widget build(BuildContext context) {
    final isSessionActive = !ref.watch(timerProvider).isIdle;
    ref.listen<TimerData>(timerProvider, (previous, next) {
      if (previous != null && !previous.isIdle && next.isIdle) {
        ScreenTimeDetoxService.instance.stopDetox();
      }
    });

    return PopScope(
      canPop: !isSessionActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSessionActive) {
          _onEscapeAttempt();
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_showAttack)
            Positioned.fill(
              child: EscapeAttackOverlay(onDismiss: _dismissAttack),
            ),
        ],
      ),
    );
  }
}
