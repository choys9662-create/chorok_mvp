import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository(this._client);

  Future<List<UserProfile>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final pattern = '%$q%';
    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio, is_private')
        .or('username.ilike.$pattern,display_name.ilike.$pattern')
        .limit(limit);
    return (rows as List)
        .map((r) => UserProfile.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<UserProfile?> getById(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromRow(row);
  }

  Future<List<UserProfile>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('profiles').select().inFilter('id', ids);
    return (rows as List)
        .map((r) => UserProfile.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 특정 유저의 초서 목록 조회.
  /// RLS가 가시성을 제어한다: 공개 문장(global_book_id 있음) 또는
  /// 본인이 accepted 팔로워인 경우 노출.
  Future<List<Map<String, dynamic>>> getUserSentences(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('sentences')
        .select(
          'id, content, thought, created_at, '
          'books(title, author, cover_url), '
          'global_books(title, author, cover_url), '
          'sentence_likes(count)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// 가입 전 anon도 호출 가능 (SECURITY DEFINER RPC 사용)
  Future<bool> isUsernameAvailable(String username) async {
    final result = await _client.rpc(
      'is_username_available',
      params: {'p_username': username},
    );
    return result as bool? ?? false;
  }

  Future<void> updateProfile(
    String userId, {
    String? displayName,
    String? bio,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (updates.isEmpty) return;
    await _client.from('profiles').update(updates).eq('id', userId);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});
