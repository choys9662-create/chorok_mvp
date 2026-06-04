import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

/// 알림 조회 + 읽음 처리. insert는 DB 트리거 전용(클라이언트 불가).
class NotificationRepository {
  final SupabaseClient _c;
  NotificationRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  Future<List<AppNotification>> fetch() async {
    final me = _me;
    if (me == null) return const [];
    final rows = await _c
        .from('notifications')
        .select(
          'id, type, sentence_id, is_read, created_at, '
          'actor:profiles!notifications_actor_id_fkey(id, username, display_name), '
          'sentence:sentences!notifications_sentence_id_fkey(content)',
        )
        .eq('recipient_id', me)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async =>
      _c.from('notifications').update({'is_read': true}).eq('id', id);

  Future<void> markAllRead() async {
    final me = _me;
    if (me == null) return;
    await _c
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', me)
        .eq('is_read', false);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(Supabase.instance.client),
);
