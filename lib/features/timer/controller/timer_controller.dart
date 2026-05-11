import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/session_goal.dart';

/// 타이머 상태 enum
enum TimerState { idle, running, paused }

/// 타이머 데이터 클래스
class TimerData {
  final int seconds;
  final TimerState timerState;
  final SessionGoal? goal;

  const TimerData({required this.seconds, required this.timerState, this.goal});

  factory TimerData.initial() =>
      const TimerData(seconds: 0, timerState: TimerState.idle);

  TimerData copyWith({
    int? seconds,
    TimerState? timerState,
    SessionGoal? goal,
  }) {
    return TimerData(
      seconds: seconds ?? this.seconds,
      timerState: timerState ?? this.timerState,
      goal: goal ?? this.goal,
    );
  }

  /// 시간 목표 대비 진행률 (0.0 ~ 1.0+), 목표 없으면 null
  double? get goalProgress {
    if (goal == null || goal!.type != SessionGoalType.time) return null;
    return goal!.timeProgress(seconds);
  }

  /// 시간 목표까지 남은 초, 목표 없으면 null
  int? get remainingSeconds {
    if (goal == null || goal!.type != SessionGoalType.time) return null;
    final rem = goal!.targetSeconds - seconds;
    return rem > 0 ? rem : 0;
  }

  /// 목표 달성 여부
  bool get goalReached {
    if (goal == null || goal!.type == SessionGoalType.free) return false;
    if (goal!.type == SessionGoalType.time) {
      return seconds >= goal!.targetSeconds;
    }
    return false; // 페이지 목표는 외부에서 판단
  }

  /// 시간 포맷: 항상 hh:mm:ss
  String get formattedTime {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 읽은 시간 요약 (예: 1시간 23분)
  String get summaryText {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '$seconds초';
  }

  bool get isRunning => timerState == TimerState.running;
  bool get isPaused => timerState == TimerState.paused;
  bool get isIdle => timerState == TimerState.idle;
}

/// 독서 타이머 컨트롤러
class TimerNotifier extends Notifier<TimerData> {
  Timer? _timer;

  @override
  TimerData build() {
    // 프로바이더 소멸 시 타이머 정리
    ref.onDispose(() => _timer?.cancel());
    return TimerData.initial();
  }

  void start({SessionGoal? goal}) {
    if (state.isRunning) return;
    state = state.copyWith(timerState: TimerState.running, goal: goal);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(seconds: state.seconds + 1);
    });
  }

  void pause() {
    if (!state.isRunning) return;
    _timer?.cancel();
    state = state.copyWith(timerState: TimerState.paused);
  }

  void updateGoal(SessionGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void resume() {
    if (!state.isPaused) return;
    start();
  }

  void stop() {
    _timer?.cancel();
    state = TimerData.initial();
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerData>(
  TimerNotifier.new,
);
