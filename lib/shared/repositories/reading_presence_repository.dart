import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 실시간 독서 세션 presence.
///
/// 세션을 '실행 중'인 동안만 [reading_presence] 행이 존재한다.
/// 세션 시작 시 [start], 진행 중 [heartbeat], 종료 시 [end].
/// 앱이 죽어 [end]를 못 보내도 [heartbeatTtl] 안에 갱신이 없으면 stale로 간주된다.
class ReadingPresenceRepository {
  final SupabaseClient _client;
  ReadingPresenceRepository(this._client);

  /// 이 시간 안에 heartbeat가 없으면 '세션 실행 중'이 아닌 것으로 본다.
  static const heartbeatTtl = Duration(seconds: 90);

  String? get _meId => _client.auth.currentUser?.id;

  /// 세션 시작 — presence 행 생성(있으면 갱신).
  Future<void> start() async {
    final me = _meId;
    if (me == null) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _client.from('reading_presence').upsert({
      'user_id': me,
      'started_at': nowIso,
      'last_heartbeat_at': nowIso,
    }, onConflict: 'user_id');
  }

  /// 진행 중 — last_heartbeat_at 갱신.
  Future<void> heartbeat() async {
    final me = _meId;
    if (me == null) return;
    await _client
        .from('reading_presence')
        .update({'last_heartbeat_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', me);
  }

  /// 세션 종료 — presence 행 삭제.
  Future<void> end() async {
    final me = _meId;
    if (me == null) return;
    await _client.from('reading_presence').delete().eq('user_id', me);
  }

  /// 라이브 포레스트 전체 집계 — 지금 읽는 중(active) / 오늘 읽음(today) / 최근 7일(week).
  /// RLS가 비팔로우 유저를 숨기므로 SECURITY DEFINER RPC([live_reader_counts])로 집계한다.
  Future<({int active, int today, int week})> liveCounts() async {
    final res = await _client.rpc('live_reader_counts');
    final list = res as List;
    if (list.isEmpty) return (active: 0, today: 0, week: 0);
    final row = list.first as Map<String, dynamic>;
    return (
      active: (row['active_count'] as num?)?.toInt() ?? 0,
      today: (row['today_count'] as num?)?.toInt() ?? 0,
      week: (row['week_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// [candidateIds] 중 지금 세션을 실행 중(heartbeat가 TTL 이내)인 유저 id만 반환.
  Future<Set<String>> activeUserIds(List<String> candidateIds) async {
    if (candidateIds.isEmpty) return const {};
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(heartbeatTtl)
        .toIso8601String();
    final rows = await _client
        .from('reading_presence')
        .select('user_id')
        .inFilter('user_id', candidateIds)
        .gte('last_heartbeat_at', cutoff);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
        .toSet();
  }
}

final readingPresenceRepositoryProvider = Provider<ReadingPresenceRepository>((
  ref,
) {
  return ReadingPresenceRepository(Supabase.instance.client);
});
