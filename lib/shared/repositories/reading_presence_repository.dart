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
  /// 지금 읽기 시작한 책 정보를 함께 기록해 친구들의 라이브 시트에 노출한다.
  Future<void> start({
    String? bookTitle,
    String? bookAuthor,
    String? bookCoverUrl,
    double? latitude,
    double? longitude,
  }) async {
    final me = _meId;
    if (me == null) return;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await _client.from('reading_presence').upsert({
      'user_id': me,
      'started_at': nowIso,
      'last_heartbeat_at': nowIso,
      'book_title': bookTitle,
      'book_author': bookAuthor,
      'book_cover_url': bookCoverUrl,
    }, onConflict: 'user_id');

    // 위치 좌표는 맞팔에게도 직접 읽힐 수 없도록 SELECT 권한을 막아 둔다.
    // PostgreSQL upsert는 conflict update에 포함한 컬럼의 SELECT 권한도 요구하므로,
    // 공개 가능한 presence 필드를 먼저 저장한 뒤 좌표만 별도 갱신한다.
    await _client
        .from('reading_presence')
        .update({'location_lat': latitude, 'location_lng': longitude})
        .eq('user_id', me);
  }

  /// 진행 중 — last_heartbeat_at 갱신.
  ///
  /// 인증 복원보다 화면 진입이 먼저 끝나 [start]가 행을 만들지 못한 경우에도
  /// heartbeat가 presence를 복구할 수 있도록 upsert한다.
  Future<void> heartbeat() async {
    final me = _meId;
    if (me == null) return;
    await _client.from('reading_presence').upsert({
      'user_id': me,
      'last_heartbeat_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
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

  Future<int> nearbyReaderCount({int radiusMeters = 500}) async {
    final res = await _client.rpc(
      'nearby_reader_count',
      params: {'radius_meters': radiusMeters},
    );
    return (res as num?)?.toInt() ?? 0;
  }

  /// [candidateIds] 중 지금 세션을 실행 중(heartbeat가 TTL 이내)인 유저를
  /// user_id → 읽고 있는 책·세션 시작 시각으로 반환. 책 정보가 없으면 필드가 null.
  Future<Map<String, ReadingPresenceInfo>> activeReaders(
    List<String> candidateIds,
  ) async {
    if (candidateIds.isEmpty) return const {};
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(heartbeatTtl)
        .toIso8601String();
    final rows = await _client
        .from('reading_presence')
        .select('user_id, started_at, book_title, book_author, book_cover_url')
        .inFilter('user_id', candidateIds)
        .gte('last_heartbeat_at', cutoff);
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['user_id'] as String: ReadingPresenceInfo(
          title: r['book_title'] as String?,
          author: r['book_author'] as String?,
          coverUrl: r['book_cover_url'] as String?,
          startedAt: DateTime.tryParse(
            r['started_at'] as String? ?? '',
          )?.toLocal(),
        ),
    };
  }
}

/// presence 행에 기록된 '지금 읽고 있는 책'과 세션 시작 시각.
class ReadingPresenceInfo {
  final String? title;
  final String? author;
  final String? coverUrl;
  final DateTime? startedAt;

  const ReadingPresenceInfo({
    this.title,
    this.author,
    this.coverUrl,
    this.startedAt,
  });

  bool get hasTitle => title != null && title!.isNotEmpty;
}

final readingPresenceRepositoryProvider = Provider<ReadingPresenceRepository>((
  ref,
) {
  return ReadingPresenceRepository(Supabase.instance.client);
});
