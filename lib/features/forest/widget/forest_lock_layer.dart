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

class _ForestLockLayerState extends ConsumerState<ForestLockLayer>
    with WidgetsBindingObserver {
  bool _showAttack = false;
  EscapeAttackTrigger _attackTrigger = EscapeAttackTrigger.escapeAttempt;
  DateTime? _backgroundedAt;
  int? _absentSeconds;
  bool _restoringDetox = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreDetoxIfNeeded(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timer = ref.read(timerProvider);
    if (state == AppLifecycleState.paused && timer.isRunning) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      if (backgroundedAt != null) {
        final seconds = DateTime.now().difference(backgroundedAt).inSeconds;
        _backgroundedAt = null;
        if (seconds >= 5) {
          setState(() {
            _absentSeconds = seconds;
            _attackTrigger = EscapeAttackTrigger.backgroundReturn;
            _showAttack = true;
          });
        }
      }
    }
  }

  void _onEscapeAttempt() {
    setState(() {
      _absentSeconds = null;
      _attackTrigger = EscapeAttackTrigger.escapeAttempt;
      _showAttack = true;
    });
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
              child: EscapeAttackOverlay(
                trigger: _attackTrigger,
                absentSeconds: _absentSeconds,
                onDismiss: _dismissAttack,
              ),
            ),
        ],
      ),
    );
  }
}
