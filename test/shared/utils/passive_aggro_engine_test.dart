import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/utils/passive_aggro_engine.dart';

void main() {
  // Random(고정 시드) — 메시지 선택을 결정적으로 만들어 테스트 안정화
  Random seeded() => Random(42);

  group('PassiveAggroEngine.messageFor — 트리거별 메시지', () {
    test('idleDays: 경과 일수가 클수록 톤이 진해진다 (다른 문구)', () {
      final ctx1 = AggroContext(idleDays: 1);
      final ctx7 = AggroContext(idleDays: 7);

      final m1 = PassiveAggroEngine.messageFor(
        AggroTrigger.idleDays,
        ctx1,
        rng: seeded(),
      );
      final m7 = PassiveAggroEngine.messageFor(
        AggroTrigger.idleDays,
        ctx7,
        rng: seeded(),
      );

      expect(m1, isNotEmpty);
      expect(m7, isNotEmpty);
      expect(m1, isNot(equals(m7)));
    });

    test('streakRisk: 메시지에 스트릭 일수가 포함된다', () {
      final msg = PassiveAggroEngine.messageFor(
        AggroTrigger.streakRisk,
        AggroContext(streakDays: 12),
        rng: seeded(),
      );
      expect(msg, contains('12'));
    });

    test('neighborCompare: 메시지에 이웃 닉네임이 포함된다', () {
      final msg = PassiveAggroEngine.messageFor(
        AggroTrigger.neighborCompare,
        AggroContext(neighborName: '준석'),
        rng: seeded(),
      );
      expect(msg, contains('준석'));
    });

    test('sessionEscape: 비어있지 않은 메시지를 반환', () {
      final msg = PassiveAggroEngine.messageFor(
        AggroTrigger.sessionEscape,
        const AggroContext(),
        rng: seeded(),
      );
      expect(msg, isNotEmpty);
    });

    test('같은 시드는 같은 메시지를 반환 (결정성)', () {
      final a = PassiveAggroEngine.messageFor(
        AggroTrigger.idleDays,
        AggroContext(idleDays: 3),
        rng: seeded(),
      );
      final b = PassiveAggroEngine.messageFor(
        AggroTrigger.idleDays,
        AggroContext(idleDays: 3),
        rng: seeded(),
      );
      expect(a, equals(b));
    });
  });

  group('PassiveAggroEngine.selectTrigger — 발동 판정 + 우선순위', () {
    final now = DateTime(2026, 6, 1, 9);

    test('오늘 이미 읽었으면 공격하지 않는다 (null)', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: true, idleDays: 0, streakDays: 5),
        lastShownAt: null,
        now: now,
      );
      expect(t, isNull);
    });

    test('스트릭 끊기기 직전(읽음 안함 + streak>=2)이 최우선', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(
          readToday: false,
          streakDays: 5,
          idleDays: 0,
          neighborName: '준석',
        ),
        lastShownAt: null,
        now: now,
      );
      expect(t, AggroTrigger.streakRisk);
    });

    test('스트릭 위험 없고 N일 방치면 idleDays', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: false, streakDays: 0, idleDays: 3),
        lastShownAt: null,
        now: now,
      );
      expect(t, AggroTrigger.idleDays);
    });

    test('스트릭·방치 모두 아니지만 활동한 이웃 있으면 neighborCompare', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(
          readToday: false,
          streakDays: 0,
          idleDays: 0,
          neighborName: '준석',
        ),
        lastShownAt: null,
        now: now,
      );
      expect(t, AggroTrigger.neighborCompare);
    });

    test('아무 조건도 안 맞으면 null', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: false, streakDays: 0, idleDays: 0),
        lastShownAt: null,
        now: now,
      );
      expect(t, isNull);
    });

    test('빈도 제한: 마지막 공격이 24시간 안이면 공격하지 않는다', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: false, streakDays: 5, idleDays: 3),
        lastShownAt: now.subtract(const Duration(hours: 3)),
        now: now,
      );
      expect(t, isNull);
    });

    test('빈도 제한: 24시간 지났으면 다시 공격 가능', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: false, streakDays: 5, idleDays: 3),
        lastShownAt: now.subtract(const Duration(hours: 25)),
        now: now,
      );
      expect(t, AggroTrigger.streakRisk);
    });

    test('streakRisk는 streak 1일에는 발동하지 않는다 (지킬 게 약함)', () {
      final t = PassiveAggroEngine.selectTrigger(
        AggroContext(readToday: false, streakDays: 1, idleDays: 0),
        lastShownAt: null,
        now: now,
      );
      expect(t, isNull);
    });
  });
}
