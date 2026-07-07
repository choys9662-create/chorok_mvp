import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// 팔로우 시도 결과 상태.
enum FollowState { accepted, pending, none }

/// 현재 사용자 기준 대상 유저와의 양방향 팔로우 관계.
class FollowRelationship {
  final FollowState outgoing;
  final FollowState incoming;

  const FollowRelationship({required this.outgoing, required this.incoming});

  static const none = FollowRelationship(
    outgoing: FollowState.none,
    incoming: FollowState.none,
  );

  bool get isMutual =>
      outgoing == FollowState.accepted && incoming == FollowState.accepted;

  bool get isFollowedByTarget => incoming == FollowState.accepted;

  FollowRelationship copyWith({FollowState? outgoing, FollowState? incoming}) {
    return FollowRelationship(
      outgoing: outgoing ?? this.outgoing,
      incoming: incoming ?? this.incoming,
    );
  }
}

class UserRecommendation {
  final UserProfile profile;
  final String reason;

  const UserRecommendation({required this.profile, required this.reason});
}

class FollowRepository {
  final SupabaseClient _client;
  FollowRepository(this._client);

  String? get _meId => _client.auth.currentUser?.id;

  /// 팔로우 시도. 공개 계정이면 accepted, 비공개 계정이면 pending.
  /// 반환값은 결과 상태.
  Future<FollowState> follow(String targetUserId) async {
    final me = _meId;
    if (me == null || me == targetUserId) return FollowState.none;

    var isPrivate = false;
    try {
      final targetRow = await _client
          .from('profiles')
          .select('is_private')
          .eq('id', targetUserId)
          .maybeSingle();
      isPrivate = targetRow?['is_private'] as bool? ?? false;
    } catch (_) {
      isPrivate = false;
    }
    final status = isPrivate ? 'pending' : 'accepted';

    final existing = await followStatus(targetUserId);
    if (existing != FollowState.none) return existing;

    try {
      await _client.from('follows').insert({
        'follower_id': me,
        'following_id': targetUserId,
        'status': status,
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      return followStatus(targetUserId);
    }
    return isPrivate ? FollowState.pending : FollowState.accepted;
  }

  Future<void> unfollow(String targetUserId) async {
    final me = _meId;
    if (me == null) return;
    await _client
        .from('follows')
        .delete()
        .eq('follower_id', me)
        .eq('following_id', targetUserId);
  }

  Future<bool> isFollowing(String targetUserId) async {
    final state = await followStatus(targetUserId);
    return state == FollowState.accepted;
  }

  /// 내가 대상에 대해 가진 팔로우 상태. 팔로우 안 했으면 none.
  Future<FollowState> followStatus(String targetUserId) async {
    final me = _meId;
    if (me == null) return FollowState.none;
    return _statusBetween(followerId: me, followingId: targetUserId);
  }

  /// 현재 사용자와 대상 사이의 양방향 팔로우 상태.
  Future<FollowRelationship> relationshipWith(String targetUserId) async {
    final me = _meId;
    if (me == null || me == targetUserId) return FollowRelationship.none;
    final states = await Future.wait([
      _statusBetween(followerId: me, followingId: targetUserId),
      _statusBetween(followerId: targetUserId, followingId: me),
    ]);
    return FollowRelationship(outgoing: states[0], incoming: states[1]);
  }

  Future<FollowState> _statusBetween({
    required String followerId,
    required String followingId,
  }) async {
    final row = await _client
        .from('follows')
        .select('status')
        .eq('follower_id', followerId)
        .eq('following_id', followingId)
        .maybeSingle();
    if (row == null) return FollowState.none;
    final status = row['status'] as String?;
    return status == 'pending' ? FollowState.pending : FollowState.accepted;
  }

  Future<List<UserProfile>> getFollowing(String userId) async {
    final rows = await _client
        .from('follows')
        .select('following_id, profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId)
        .eq('status', 'accepted');
    return _extractProfiles(rows as List, 'profiles');
  }

  Future<List<UserProfile>> getFollowers(String userId) async {
    final rows = await _client
        .from('follows')
        .select('follower_id, profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId)
        .eq('status', 'accepted');
    return _extractProfiles(rows as List, 'profiles');
  }

  /// 내가 팔로우하는 유저들 중에서 query로 검색
  Future<List<UserProfile>> searchFollowing(String query) async {
    final me = _meId;
    if (me == null) return const [];
    final q = query.trim();
    final all = await getFollowing(me);
    if (q.isEmpty) return all;
    final lowerQ = q.toLowerCase();
    return all.where((p) {
      return p.username.toLowerCase().contains(lowerQ) ||
          p.displayName.toLowerCase().contains(lowerQ);
    }).toList();
  }

  /// 나를 팔로우하는 유저들 중에서 query로 검색
  Future<List<UserProfile>> searchFollowers(String query) async {
    final me = _meId;
    if (me == null) return const [];
    final q = query.trim();
    final all = await getFollowers(me);
    if (q.isEmpty) return all;
    final lowerQ = q.toLowerCase();
    return all.where((p) {
      return p.username.toLowerCase().contains(lowerQ) ||
          p.displayName.toLowerCase().contains(lowerQ);
    }).toList();
  }

  /// 맞팔 (내가 팔로우하고 나를 팔로우하는) 수 반환
  Future<int> getMutualFollowCount() async {
    return (await getMutualFollows()).length;
  }

  /// 맞팔 프로필 목록 반환
  Future<List<UserProfile>> getMutualFollows() async {
    final me = _meId;
    if (me == null) return const [];
    final following = await getFollowing(me);
    final followingIds = following.map((u) => u.id).toSet();
    final followers = await getFollowers(me);
    return followers.where((u) => followingIds.contains(u.id)).toList();
  }

  Future<List<UserRecommendation>> getUserRecommendations() async {
    final me = _meId;
    if (me == null) return const [];

    final following = await getFollowing(me);
    final followers = await getFollowers(me);
    final followingIds = following.map((u) => u.id).toSet();
    final mutualIds = followers
        .where((u) => followingIds.contains(u.id))
        .map((u) => u.id)
        .toSet();

    final scores = <String, double>{};
    final reasons = <String, String>{};

    if (mutualIds.isNotEmpty) {
      final rows = await _client
          .from('follows')
          .select('following_id')
          .inFilter('follower_id', mutualIds.toList())
          .eq('status', 'accepted');
      for (final row in rows as List) {
        final id = (row as Map<String, dynamic>)['following_id'] as String?;
        if (id == null || id == me || followingIds.contains(id)) continue;
        scores[id] = (scores[id] ?? 0) + 3;
        reasons[id] = '맞팔 독자들이 많이 팔로우해요';
      }
    }

    final myBooks = await _bookKeysForUsers({me});
    if (myBooks.isNotEmpty) {
      final visibleBookRows = await _safeVisibleBookRows();
      final overlapCounts = <String, int>{};
      for (final row in visibleBookRows) {
        final userId = row['user_id'] as String?;
        if (userId == null || userId == me || followingIds.contains(userId)) {
          continue;
        }
        if (myBooks.contains(_bookKey(row))) {
          overlapCounts[userId] = (overlapCounts[userId] ?? 0) + 1;
        }
      }
      for (final entry in overlapCounts.entries) {
        scores[entry.key] = (scores[entry.key] ?? 0) + entry.value * 5;
        reasons[entry.key] = '나와 비슷한 책을 읽어요';
      }
    }

    if (scores.isEmpty) return const [];
    final ids = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final profiles = await _profilesByIds(ids.take(20).toList());
    return ids
        .map(
          (id) => profiles[id] == null
              ? null
              : UserRecommendation(
                  profile: profiles[id]!,
                  reason: reasons[id] ?? '함께 읽을 만한 독자예요',
                ),
        )
        .whereType<UserRecommendation>()
        .take(10)
        .toList();
  }

  Future<Set<String>> _bookKeysForUsers(Set<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client
        .from('books')
        .select('global_book_id, book_id')
        .inFilter('user_id', userIds.toList())
        .limit(200);
    return (rows as List)
        .map((row) => _bookKey(row as Map<String, dynamic>))
        .whereType<String>()
        .toSet();
  }

  Future<List<Map<String, dynamic>>> _safeVisibleBookRows() async {
    try {
      final rows = await _client
          .from('books')
          .select('user_id, global_book_id, book_id')
          .limit(500);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, UserProfile>> _profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('*')
        .inFilter('id', ids)
        .limit(ids.length);
    return {
      for (final row in rows as List)
        UserProfile.fromRow(row as Map<String, dynamic>).id:
            UserProfile.fromRow(row),
    };
  }

  String? _bookKey(Map<String, dynamic> row) {
    final global = row['global_book_id'] as String?;
    if (global != null && global.isNotEmpty) return 'g:$global';
    final local = row['book_id'] as String?;
    if (local != null && local.isNotEmpty) return 'b:$local';
    return null;
  }

  List<UserProfile> _extractProfiles(List rows, String key) {
    return rows
        .map((r) => r as Map<String, dynamic>)
        .map((r) => r[key] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map(UserProfile.fromRow)
        .toList();
  }
}

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(Supabase.instance.client);
});

final followMutationVersionProvider = StateProvider<int>((ref) => 0);
