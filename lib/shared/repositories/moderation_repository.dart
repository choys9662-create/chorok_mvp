import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

enum ReportTargetType { user, sentence, comment }

extension on ReportTargetType {
  String get _value => switch (this) {
    ReportTargetType.user => 'user',
    ReportTargetType.sentence => 'sentence',
    ReportTargetType.comment => 'comment',
  };
}

/// 유저 차단 + 콘텐츠/유저 신고 리포지토리 (App Store 1.2 UGC 안전 요건 대응).
class ModerationRepository {
  final SupabaseClient _c;
  ModerationRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  /// 차단 + 양방향 팔로우 관계 해제.
  Future<void> block(String targetUserId) async {
    final me = _me;
    if (me == null || me == targetUserId) return;
    await _c.from('blocked_users').insert({
      'blocker_id': me,
      'blocked_id': targetUserId,
    });
    await Future.wait([
      _c
          .from('follows')
          .delete()
          .eq('follower_id', me)
          .eq('following_id', targetUserId),
      _c
          .from('follows')
          .delete()
          .eq('follower_id', targetUserId)
          .eq('following_id', me),
    ]);
  }

  Future<void> unblock(String targetUserId) async {
    final me = _me;
    if (me == null) return;
    await _c
        .from('blocked_users')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', targetUserId);
  }

  Future<bool> isBlocked(String targetUserId) async {
    final me = _me;
    if (me == null) return false;
    final row = await _c
        .from('blocked_users')
        .select('id')
        .eq('blocker_id', me)
        .eq('blocked_id', targetUserId)
        .maybeSingle();
    return row != null;
  }

  Future<List<UserProfile>> getBlockedUsers() async {
    final me = _me;
    if (me == null) return const [];
    final rows = await _c
        .from('blocked_users')
        .select('profiles!blocked_users_blocked_id_fkey(*)')
        .eq('blocker_id', me)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (r) =>
              (r as Map<String, dynamic>)['profiles'] as Map<String, dynamic>?,
        )
        .whereType<Map<String, dynamic>>()
        .map(UserProfile.fromRow)
        .toList();
  }

  Future<void> report(
    ReportTargetType targetType,
    String targetId, {
    String? reason,
  }) async {
    final me = _me;
    if (me == null) return;
    await _c.from('content_reports').insert({
      'reporter_id': me,
      'target_type': targetType._value,
      'target_id': targetId,
      'reason': reason,
    });
  }
}

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => ModerationRepository(Supabase.instance.client),
);

/// 차단/차단해제 시 증가시켜 userProfileProvider 등의 재조회를 트리거한다.
final blockMutationVersionProvider = StateProvider<int>((ref) => 0);
