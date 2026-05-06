import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class FollowRepository {
  final SupabaseClient _client;
  FollowRepository(this._client);

  String? get _meId => _client.auth.currentUser?.id;

  Future<void> follow(String targetUserId) async {
    final me = _meId;
    if (me == null || me == targetUserId) return;
    await _client.from('follows').insert({
      'follower_id': me,
      'following_id': targetUserId,
    });
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
    final me = _meId;
    if (me == null) return false;
    final row = await _client
        .from('follows')
        .select('follower_id')
        .eq('follower_id', me)
        .eq('following_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  Future<List<UserProfile>> getFollowing(String userId) async {
    final rows = await _client
        .from('follows')
        .select('following_id, profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return _extractProfiles(rows as List, 'profiles');
  }

  Future<List<UserProfile>> getFollowers(String userId) async {
    final rows = await _client
        .from('follows')
        .select('follower_id, profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId);
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
