import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/reading_presence_repository.dart';

const _kUseMock = bool.fromEnvironment('USE_MOCK');

// 목업 맞팔 프로필 목록 (USE_MOCK=true 시 사용)
const _kMockMutuals = [
  (username: '책벌레수진', displayName: '책벌레수진'),
  (username: '밤의여행자', displayName: '밤의여행자'),
  (username: '초록잎', displayName: '초록잎'),
  (username: '달빛독서', displayName: '달빛독서'),
  (username: 'seoulreader', displayName: 'seoulreader'),
  (username: '북크리에이터', displayName: '북크리에이터'),
  (username: '조용한독자', displayName: '조용한독자'),
  (username: '페이지터너', displayName: '페이지터너'),
];

final sessionFireflyProvider =
    FutureProvider<
      ({int mutualCount, int nearbyCount, List<UserProfile> mutuals})
    >((ref) async {
      if (_kUseMock) {
        final mutuals = _kMockMutuals
            .map(
              (m) => UserProfile(
                id: m.username,
                username: m.username,
                displayName: m.displayName,
              ),
            )
            .toList();
        return (mutualCount: mutuals.length, nearbyCount: 15, mutuals: mutuals);
      }

      final mutuals = await ref
          .read(followRepositoryProvider)
          .getMutualFollows();
      // "읽고 있는 친구" = 지금 세션을 실행 중인 맞팔만. presence가 없으면 제외.
      final activeIds = await ref
          .read(readingPresenceRepositoryProvider)
          .activeUserIds(mutuals.map((m) => m.id).toList());
      final active = mutuals.where((m) => activeIds.contains(m.id)).toList();
      return (mutualCount: active.length, nearbyCount: 0, mutuals: active);
    });
