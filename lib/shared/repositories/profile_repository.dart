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
        .select()
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
    final rows = await _client
        .from('profiles')
        .select()
        .inFilter('id', ids);
    return (rows as List)
        .map((r) => UserProfile.fromRow(r as Map<String, dynamic>))
        .toList();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(Supabase.instance.client);
});
