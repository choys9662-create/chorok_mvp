import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';

/// 오늘 독서를 한 친구 한 명 — 무슨 책을, 얼마나(초).
/// 대표 책 = 오늘 가장 최근 세션의 책. 초 = 오늘 세션 합.
/// 분이 아니라 초로 들고 있는다: 1분 미만 세션이 "0분"으로 뭉개지지 않게.
typedef FriendReadToday = ({
  UserProfile friend,
  String bookTitle,
  String? coverUrl,
  int seconds,
});

/// 맞팔 중 오늘(로컬 기준) 독서 세션이 있는 친구들. 많이 읽은 순.
final friendsReadTodayProvider = FutureProvider<List<FriendReadToday>>((
  ref,
) async {
  ref.watch(followMutationVersionProvider);
  if (kUseMock) return _mockFriendsReadToday;

  final mutuals = await ref.read(followRepositoryProvider).getMutualFollows();
  if (mutuals.isEmpty) return const [];
  final byId = {for (final m in mutuals) m.id: m};

  final now = DateTime.now();
  final startUtc = DateTime(
    now.year,
    now.month,
    now.day,
  ).toUtc().toIso8601String();

  final rows = await Supabase.instance.client
      .from('reading_sessions')
      .select('user_id, duration_seconds, ended_at, books(title, cover_url)')
      .inFilter('user_id', byId.keys.toList())
      .gte('ended_at', startUtc)
      .order('ended_at', ascending: false);

  return aggregateFriendReads(
    (rows as List).cast<Map<String, dynamic>>(),
    byId,
  );
});

/// 세션 행(ended_at desc)을 친구별로 합산. 대표 책 = 가장 최근 세션의 책,
/// 분 = 오늘 세션 합. 많이 읽은 순. (DB와 분리해 테스트 가능하게 top-level)
List<FriendReadToday> aggregateFriendReads(
  List<Map<String, dynamic>> rows,
  Map<String, UserProfile> byId,
) {
  final agg = <String, ({int seconds, String title, String? cover})>{};
  for (final r in rows) {
    final uid = r['user_id'] as String;
    if (!byId.containsKey(uid)) continue;
    final book = r['books'] as Map<String, dynamic>?;
    final secs = (r['duration_seconds'] as num?)?.toInt() ?? 0;
    final prev = agg[uid];
    agg[uid] = prev == null
        ? (
            seconds: secs,
            title: book?['title'] as String? ?? '읽은 책',
            cover: book?['cover_url'] as String?,
          )
        : (seconds: prev.seconds + secs, title: prev.title, cover: prev.cover);
  }

  return agg.entries
      .map(
        (e) => (
          friend: byId[e.key]!,
          bookTitle: e.value.title,
          coverUrl: e.value.cover,
          seconds: e.value.seconds,
        ),
      )
      .toList()
    ..sort((a, b) => b.seconds.compareTo(a.seconds));
}

const _mockFriendsReadToday = <FriendReadToday>[
  (
    friend: UserProfile(id: 'm1', username: 'mago', displayName: '마고'),
    bookTitle: '불안의 서',
    coverUrl: null,
    seconds: 72 * 60,
  ),
  (
    friend: UserProfile(id: 'm2', username: 'yong', displayName: '용성군'),
    bookTitle: '채식주의자',
    coverUrl: null,
    seconds: 35 * 60,
  ),
  (
    friend: UserProfile(id: 'm3', username: 'ground', displayName: '온더그라운드'),
    bookTitle: '토니오 크뢰거',
    coverUrl: null,
    seconds: 18 * 60,
  ),
];
