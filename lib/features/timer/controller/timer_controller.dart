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
  final SessionExtra? session;

  const TimerData({
    required this.seconds,
    required this.timerState,
    this.goal,
    this.session,
  });

  factory TimerData.initial() =>
      const TimerData(seconds: 0, timerState: TimerState.idle);

  TimerData copyWith({
    int? seconds,
    TimerState? timerState,
    SessionGoal? goal,
    SessionExtra? session,
  }) {
    return TimerData(
      seconds: seconds ?? this.seconds,
      timerState: timerState ?? this.timerState,
      goal: goal ?? this.goal,
      session: session ?? this.session,
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
  DateTime? _runStartedAt;
  int _accumulatedSeconds = 0;

  @override
  TimerData build() {
    ref.onDispose(() => _timer?.cancel());
    return TimerData.initial();
  }

  int _computeSeconds() {
    if (_runStartedAt == null) return _accumulatedSeconds;
    return _accumulatedSeconds +
        DateTime.now().difference(_runStartedAt!).inSeconds;
  }

  void _startTicking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(seconds: _computeSeconds());
    });
  }

  void start({SessionGoal? goal, SessionExtra? session}) {
    if (state.isRunning) return;
    _accumulatedSeconds = 0;
    _runStartedAt = DateTime.now();
    state = state.copyWith(
      seconds: 0,
      timerState: TimerState.running,
      goal: goal,
      session: session,
    );
    _startTicking();
  }

  void pause() {
    if (!state.isRunning) return;
    _timer?.cancel();
    _accumulatedSeconds = _computeSeconds();
    _runStartedAt = null;
    state = state.copyWith(
      seconds: _accumulatedSeconds,
      timerState: TimerState.paused,
    );
  }

  void updateGoal(SessionGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void resume() {
    if (!state.isPaused) return;
    _runStartedAt = DateTime.now();
    state = state.copyWith(timerState: TimerState.running);
    _startTicking();
  }

  void stop() {
    _timer?.cancel();
    _accumulatedSeconds = 0;
    _runStartedAt = null;
    state = TimerData.initial();
  }

  /// 앱이 백그라운드에서 복귀했을 때 즉시 경과시간을 재계산해 UI에 반영
  void syncFromWallClock() {
    if (!state.isRunning) return;
    state = state.copyWith(seconds: _computeSeconds());
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerData>(
  TimerNotifier.new,
);
