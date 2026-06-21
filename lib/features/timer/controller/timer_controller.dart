import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/session_goal.dart';

const _timerSnapshotKey = 'live_forest_timer_snapshot_v1';

/// 타이머 상태 enum
enum TimerState { idle, running, paused }

/// 타이머 데이터 클래스
class TimerData {
  final int seconds;
  final TimerState timerState;
  final SessionGoal? goal;
  final SessionExtra? session;
  final DateTime? startedAt;

  const TimerData({
    required this.seconds,
    required this.timerState,
    this.goal,
    this.session,
    this.startedAt,
  });

  factory TimerData.initial() =>
      const TimerData(seconds: 0, timerState: TimerState.idle);

  TimerData copyWith({
    int? seconds,
    TimerState? timerState,
    SessionGoal? goal,
    SessionExtra? session,
    DateTime? startedAt,
  }) {
    return TimerData(
      seconds: seconds ?? this.seconds,
      timerState: timerState ?? this.timerState,
      goal: goal ?? this.goal,
      session: session ?? this.session,
      startedAt: startedAt ?? this.startedAt,
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
    final initial = ref.watch(initialTimerDataProvider);
    _accumulatedSeconds = initial.seconds;
    if (initial.isRunning) {
      _runStartedAt = DateTime.now();
      _startTicking();
    }
    return initial;
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
      startedAt: DateTime.now(),
    );
    _startTicking();
    unawaited(persistTimerData(state));
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
    unawaited(persistTimerData(state));
  }

  void updateGoal(SessionGoal goal) {
    state = state.copyWith(goal: goal);
    unawaited(persistTimerData(state));
  }

  void resume() {
    if (!state.isPaused) return;
    _runStartedAt = DateTime.now();
    state = state.copyWith(timerState: TimerState.running);
    _startTicking();
    unawaited(persistTimerData(state));
  }

  void stop() {
    _timer?.cancel();
    _accumulatedSeconds = 0;
    _runStartedAt = null;
    state = TimerData.initial();
    unawaited(persistTimerData(state));
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

final initialTimerDataProvider = Provider<TimerData>(
  (_) => TimerData.initial(),
);

Future<TimerData> loadPersistedTimerData() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_timerSnapshotKey);
  if (raw == null) return TimerData.initial();

  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final timerState = TimerState.values.byName(json['timerState'] as String);
    var seconds = json['seconds'] as int? ?? 0;
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (timerState == TimerState.running && updatedAt != null) {
      seconds += DateTime.now().difference(updatedAt).inSeconds.clamp(0, 86400);
    }

    return TimerData(
      seconds: seconds,
      timerState: timerState,
      goal: _decodeGoal(json['goal']),
      session: _decodeSession(json['session']),
      startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    );
  } catch (_) {
    await prefs.remove(_timerSnapshotKey);
    return TimerData.initial();
  }
}

Future<void> persistTimerData(TimerData data) async {
  final prefs = await SharedPreferences.getInstance();
  if (data.isIdle) {
    await prefs.remove(_timerSnapshotKey);
    return;
  }

  await prefs.setString(
    _timerSnapshotKey,
    jsonEncode({
      'seconds': data.seconds,
      'timerState': data.timerState.name,
      'updatedAt': DateTime.now().toIso8601String(),
      'startedAt': data.startedAt?.toIso8601String(),
      'goal': _encodeGoal(data.goal),
      'session': _encodeSession(data.session),
    }),
  );
}

Map<String, dynamic>? _encodeGoal(SessionGoal? goal) {
  if (goal == null) return null;
  return {
    'type': goal.type.name,
    'targetMinutes': goal.targetMinutes,
    'targetPage': goal.targetPage,
    'startPage': goal.startPage,
  };
}

SessionGoal? _decodeGoal(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  return SessionGoal(
    type: SessionGoalType.values.byName(raw['type'] as String),
    targetMinutes: raw['targetMinutes'] as int?,
    targetPage: raw['targetPage'] as int?,
    startPage: raw['startPage'] as int? ?? 0,
  );
}

Map<String, dynamic>? _encodeSession(SessionExtra? session) {
  if (session == null) return null;
  return {
    'bookId': session.bookId,
    'bookTitle': session.bookTitle,
    'bookAuthor': session.bookAuthor,
    'coverUrl': session.coverUrl,
    'startPage': session.startPage,
    'totalPages': session.totalPages,
  };
}

SessionExtra? _decodeSession(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  return SessionExtra(
    bookId: raw['bookId'] as String?,
    bookTitle: raw['bookTitle'] as String? ?? '',
    bookAuthor: raw['bookAuthor'] as String? ?? '',
    coverUrl: raw['coverUrl'] as String?,
    startPage: raw['startPage'] as int? ?? 0,
    totalPages: raw['totalPages'] as int? ?? 0,
  );
}
