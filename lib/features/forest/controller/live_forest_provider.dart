import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/repositories/reading_presence_repository.dart';

/// 라이브 포레스트 반딧불 카운트.
/// active = 지금 읽는 중, today = 오늘 읽음, week = 최근 7일 읽음.
class LiveReaderCounts {
  final int active;
  final int today;
  final int week;

  const LiveReaderCounts({
    required this.active,
    required this.today,
    required this.week,
  });

  /// 목업/로딩 폴백 — 기존 하드코딩 값과 동일하게 둬 빈 숲을 피한다.
  static const fallback = LiveReaderCounts(active: 15, today: 33, week: 32);
}

/// 30초 주기로 전체 독자 수를 폴링한다(즉시 1회 + 주기 갱신).
/// `kUseMock`이면 고정 폴백값만 내보낸다.
/// autoDispose: 구독이 사라지면 [ref.onDispose]에서 타이머를 정리한다.
final liveReaderCountsProvider = StreamProvider.autoDispose<LiveReaderCounts>((
  ref,
) {
  if (kUseMock) {
    return Stream.value(LiveReaderCounts.fallback);
  }

  final repo = ref.read(readingPresenceRepositoryProvider);
  final controller = StreamController<LiveReaderCounts>();
  Timer? timer;

  Future<void> tick() async {
    try {
      final c = await repo.liveCounts();
      if (!controller.isClosed) {
        controller.add(
          LiveReaderCounts(active: c.active, today: c.today, week: c.week),
        );
      }
    } catch (_) {
      // 실패 시 다음 주기까지 마지막 값 유지(스트림은 끊지 않는다).
    }
  }

  tick();
  timer = Timer.periodic(const Duration(seconds: 30), (_) => tick());

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
