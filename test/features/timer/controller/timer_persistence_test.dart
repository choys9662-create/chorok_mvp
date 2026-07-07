import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorok_app/features/timer/controller/timer_controller.dart';
import 'package:chorok_app/shared/models/session_goal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('실행 중인 라이브 포레스트 세션 메타데이터를 복구한다', () async {
    final startedAt = DateTime(2026, 6, 19, 10);
    final data = TimerData(
      seconds: 125,
      timerState: TimerState.paused,
      goal: const SessionGoal.time(30),
      session: const SessionExtra(
        bookId: 'book-1',
        bookTitle: '총균쇠',
        bookAuthor: '재레드 다이아몬드',
        startPage: 42,
        totalPages: 751,
      ),
      startedAt: startedAt,
    );

    await persistTimerData(data);
    final restored = await loadPersistedTimerData();

    expect(restored.timerState, TimerState.paused);
    expect(restored.seconds, 125);
    expect(restored.startedAt, startedAt);
    expect(restored.goal?.type, SessionGoalType.time);
    expect(restored.goal?.targetMinutes, 30);
    expect(restored.session?.bookId, 'book-1');
    expect(restored.session?.bookTitle, '총균쇠');
    expect(restored.session?.startPage, 42);
    expect(restored.session?.totalPages, 751);
  });

  test('정상 종료된 세션은 복구 데이터에서 제거한다', () async {
    await persistTimerData(
      TimerData(
        seconds: 10,
        timerState: TimerState.paused,
        startedAt: DateTime(2026, 6, 19, 10),
      ),
    );
    await persistTimerData(TimerData.initial());

    final restored = await loadPersistedTimerData();

    expect(restored.isIdle, isTrue);
  });

  test('앱이 죽어있던 동안의 공백은 일부만 인정한다(유령 시간 방지)', () async {
    final staleUpdatedAt = DateTime.now().subtract(const Duration(hours: 5));
    SharedPreferences.setMockInitialValues({
      'live_forest_timer_snapshot_v1': jsonEncode({
        'seconds': 100,
        'timerState': 'running',
        'updatedAt': staleUpdatedAt.toIso8601String(),
        'startedAt': staleUpdatedAt.toIso8601String(),
        'goal': null,
        'session': null,
      }),
    });

    final restored = await loadPersistedTimerData();

    expect(restored.timerState, TimerState.running);
    // 5시간 공백을 통째로 더하면 100 + 18000이 되어야 하지만, 체크포인트 주기의
    // 몇 배 수준으로만 늘어나야 한다.
    expect(restored.seconds, greaterThanOrEqualTo(100));
    expect(restored.seconds, lessThan(200));
  });
}
