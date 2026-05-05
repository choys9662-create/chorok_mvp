import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/follow_repository.dart';

const _kUseMock = bool.fromEnvironment('USE_MOCK');

final sessionFireflyProvider =
    FutureProvider<({int mutualCount, int nearbyCount})>((ref) async {
  if (_kUseMock) {
    return (mutualCount: 15, nearbyCount: 5);
  }
  final mutualCount =
      await ref.read(followRepositoryProvider).getMutualFollowCount();
  return (mutualCount: mutualCount, nearbyCount: 0);
});
