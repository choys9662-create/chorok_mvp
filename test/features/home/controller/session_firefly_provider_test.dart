import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:chorok_app/features/home/controller/session_firefly_provider.dart';
import 'package:chorok_app/shared/models/user_profile.dart';
import 'package:chorok_app/shared/repositories/follow_repository.dart';
import 'package:chorok_app/shared/repositories/reading_presence_repository.dart';

class _FakeFollowRepository extends FollowRepository {
  _FakeFollowRepository(this.mutuals)
    : super(SupabaseClient('https://example.supabase.co', 'anon-key'));

  final List<UserProfile> mutuals;

  @override
  Future<List<UserProfile>> getMutualFollows() async => mutuals;
}

class _FakePresenceRepository implements ReadingPresenceRepository {
  _FakePresenceRepository({Set<String>? activeIds}) : _activeIds = activeIds;

  final Set<String>? _activeIds;

  @override
  Future<Map<String, ReadingPresenceInfo>> activeReaders(
    List<String> candidateIds,
  ) async {
    final activeIds = _activeIds ?? candidateIds.toSet();
    return {
      for (final id in candidateIds)
        if (activeIds.contains(id)) id: const ReadingPresenceInfo(),
    };
  }

  @override
  Future<int> nearbyReaderCount({int radiusMeters = 500}) async {
    throw StateError('rpc unavailable');
  }

  @override
  Future<void> end() async {}

  @override
  Future<void> heartbeat() async {}

  @override
  Future<({int active, int today, int week})> liveCounts() async {
    return (active: 0, today: 0, week: 0);
  }

  @override
  Future<void> start({
    String? bookTitle,
    String? bookAuthor,
    String? bookCoverUrl,
    double? latitude,
    double? longitude,
  }) async {}
}

void main() {
  test('nearby RPC failure does not hide live mutual friends', () async {
    const friend = UserProfile(
      id: 'friend-1',
      username: 'friend',
      displayName: '친구',
    );
    final container = ProviderContainer(
      overrides: [
        followRepositoryProvider.overrideWithValue(
          _FakeFollowRepository(const [friend]),
        ),
        readingPresenceRepositoryProvider.overrideWithValue(
          _FakePresenceRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(sessionFireflyProvider.future);

    expect(result.mutualCount, 1);
    expect(result.mutuals, const [friend]);
    expect(result.nearbyCount, 0);
  });

  test('지금 읽는 맞팔만 초록점 집계에 포함한다', () async {
    const idleFriend = UserProfile(
      id: 'friend-1',
      username: 'idle',
      displayName: '안 읽는 친구',
    );
    const activeFriend = UserProfile(
      id: 'friend-2',
      username: 'active',
      displayName: '읽는 친구',
    );
    final container = ProviderContainer(
      overrides: [
        followRepositoryProvider.overrideWithValue(
          _FakeFollowRepository(const [idleFriend, activeFriend]),
        ),
        readingPresenceRepositoryProvider.overrideWithValue(
          _FakePresenceRepository(activeIds: const {'friend-2'}),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(sessionFireflyProvider.future);

    expect(result.mutualCount, 1);
    expect(result.mutuals, const [activeFriend]);
    expect(result.books.keys, {'friend-2'});
  });
}
