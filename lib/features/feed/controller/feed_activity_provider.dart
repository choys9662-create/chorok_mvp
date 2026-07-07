import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../model/feed_activity.dart';

/// 피드 활동(소식) 프로바이더. 범위(친구/전체)별로 활동 이벤트를 모은다.
final feedActivityProvider =
    FutureProvider.family<List<FeedActivity>, FeedScope>((ref, scope) async {
      if (kUseMock) {
        final all = _mockActivities();
        if (scope == FeedScope.friends) {
          return all.where((a) => a.isFriend).toList();
        }
        return all;
      }
      return _FeedActivityLoader(Supabase.instance.client).load(scope);
    });

// ─── 실데이터 로더 ──────────────────────────────────────────────────────────
class _FeedActivityLoader {
  final SupabaseClient client;
  _FeedActivityLoader(this.client);

  Future<List<FeedActivity>> load(FeedScope scope) async {
    final me = client.auth.currentUser?.id;
    if (me == null) return const [];

    if (scope == FeedScope.all) {
      final publicActivities = await _publicActivities();
      if (publicActivities != null) return publicActivities;
    }

    Set<String>? followingIds;
    if (scope == FeedScope.friends) {
      followingIds = await _followingIds(me);
      if (followingIds.isEmpty) return const [];
    }

    // 각 활동 소스를 독립적으로 수집한다. 한 소스가 RLS/스키마로 실패해도
    // 나머지는 살아남도록 try/catch로 격리한다.
    final results = await Future.wait([
      _sentenceBatches(me, followingIds),
      _sessionCompletes(me, followingIds),
      _bookCompletes(me, followingIds),
      _wantToReadEvents(me, followingIds),
      _readingStartEvents(me, followingIds),
    ]);

    final activities = results.expand((e) => e).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return activities.take(50).toList();
  }

  Future<List<FeedActivity>?> _publicActivities() async {
    try {
      final rows = await client.rpc(
        'get_feed_activities',
        params: {'p_scope': 'all', 'p_limit': 50},
      );
      return (rows as List).map((row) {
        final data = row as Map<String, dynamic>;
        final type = switch (data['event_type']) {
          'sentence_batch' => FeedActivityType.sentenceBatch,
          'session_complete' => FeedActivityType.sessionComplete,
          'want_to_read' => FeedActivityType.wantToRead,
          'reading_start' => FeedActivityType.readingStart,
          _ => FeedActivityType.bookComplete,
        };
        final sentences = (data['sentences'] as List? ?? const [])
            .map(
              (item) => FeedActivitySentence(
                id: (item as Map<String, dynamic>)['id'] as String?,
                content: item['content'] as String? ?? '',
                thought: item['thought'] as String?,
                pageNumber: (item['page_number'] as num?)?.toInt(),
              ),
            )
            .toList();
        return FeedActivity(
          id: data['event_id'] as String,
          type: type,
          username: data['username'] as String? ?? '독자',
          handle: (data['handle'] as String?)?.trim(),
          avatarUrl: data['avatar_url'] as String?,
          bookTitle: data['book_title'] as String? ?? '알 수 없는 책',
          bookAuthor: data['book_author'] as String? ?? '',
          coverUrl: data['cover_url'] as String?,
          isbn13: data['isbn13'] as String?,
          occurredAt:
              DateTime.tryParse(data['occurred_at'] as String? ?? '') ??
              DateTime.now(),
          sentenceCount: (data['sentence_count'] as num?)?.toInt() ?? 0,
          previewSentences: sentences,
          durationSeconds: (data['duration_seconds'] as num?)?.toInt() ?? 0,
          progressPercent: (data['progress_percent'] as num?)?.toInt() ?? 100,
        );
      }).toList();
    } catch (e) {
      // RPC가 아직 배포되지 않은 환경에서는 기존 RLS 범위 내 데이터로 폴백한다.
      debugPrint('feed activity: public feed rpc failed: $e');
      return null;
    }
  }

  Future<Set<String>> _followingIds(String me) async {
    try {
      final rows = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', me)
          .eq('status', 'accepted');
      return (rows as List)
          .map((r) => (r as Map<String, dynamic>)['following_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('feed activity: following load failed: $e');
      return const {};
    }
  }

  /// user_id → 프로필 맵. 세션/완독 행에는 작성자 프로필 임베드가 없으므로
  /// 한 번에 조회해 매핑한다.
  Future<Map<String, ({String name, String? handle, String? avatarUrl})>>
  _profiles(Set<String> userIds) async {
    if (userIds.isEmpty) return const {};
    try {
      final rows = await client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .inFilter('id', userIds.toList());
      final map = <String, ({String name, String? handle, String? avatarUrl})>{};
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final id = m['id'] as String?;
        if (id == null) continue;
        map[id] = (
          name:
              (m['display_name'] as String?) ??
              (m['username'] as String?) ??
              '독자',
          handle: (m['username'] as String?)?.trim(),
          avatarUrl: m['avatar_url'] as String?,
        );
      }
      return map;
    } catch (e) {
      debugPrint('feed activity: profiles load failed: $e');
      return const {};
    }
  }

  String _bookKey(Map<String, dynamic>? book) =>
      '${book?['title'] ?? ''}|${book?['author'] ?? ''}';

  // ── 문장 N개 기록 ──────────────────────────────────────────────────────────
  Future<List<FeedActivity>> _sentenceBatches(
    String me,
    Set<String>? followingIds,
  ) async {
    try {
      var query = client
          .from('sentences')
          .select(
            'id, session_id, content, thought, page_number, created_at, user_id, '
            'profiles!sentences_user_id_fkey(username, display_name, avatar_url), '
            'books(title, author, cover_url, isbn), '
            'global_books(title, author, cover_url, isbn13)',
          );
      if (followingIds != null) {
        query = query.inFilter('user_id', followingIds.toList());
      } else {
        query = query.neq('user_id', me);
      }
      final rows = await query.order('created_at', ascending: false).limit(120);

      // 한 독서 세션에서 기록한 문장을 하나의 활동으로 묶는다.
      // 세션 없이 직접 추가한 문장은 각각 독립 활동으로 남긴다.
      final groups = <String, List<Map<String, dynamic>>>{};
      for (final r in rows as List) {
        final m = r as Map<String, dynamic>;
        final book =
            (m['global_books'] as Map<String, dynamic>?) ??
            (m['books'] as Map<String, dynamic>?);
        final batchId = m['session_id'] ?? m['id'];
        final key = '${m['user_id']}|${_bookKey(book)}|$batchId';
        (groups[key] ??= []).add(m);
      }

      final out = <FeedActivity>[];
      groups.forEach((key, items) {
        final first = items.first;
        final book =
            (first['global_books'] as Map<String, dynamic>?) ??
            (first['books'] as Map<String, dynamic>?);
        final profile = first['profiles'] as Map<String, dynamic>?;
        final username =
            (profile?['display_name'] as String?) ??
            (profile?['username'] as String?) ??
            '독자';
        final handle = (profile?['username'] as String?)?.trim();
        final occurredAt =
            DateTime.tryParse(first['created_at'] as String? ?? '') ??
            DateTime.now();
        final sentences = items
            .map(
              (m) => FeedActivitySentence(
                id: m['id'] as String?,
                content: m['content'] as String? ?? '',
                thought: (m['thought'] as String?)?.trim().isNotEmpty == true
                    ? m['thought'] as String?
                    : null,
                pageNumber: (m['page_number'] as num?)?.toInt(),
              ),
            )
            .toList();
        out.add(
          FeedActivity(
            id: 'sb_$key',
            type: FeedActivityType.sentenceBatch,
            username: username,
            handle: handle,
            avatarUrl: profile?['avatar_url'] as String?,
            isFriend: followingIds != null,
            bookTitle: book?['title'] as String? ?? '알 수 없는 책',
            bookAuthor: book?['author'] as String? ?? '',
            coverUrl: book?['cover_url'] as String?,
            isbn13:
                (first['global_books'] as Map<String, dynamic>?)?['isbn13']
                    as String?,
            occurredAt: occurredAt,
            sentenceCount: items.length,
            previewSentences: sentences,
          ),
        );
      });
      return out;
    } catch (e) {
      debugPrint('feed activity: sentence batches failed: $e');
      return const [];
    }
  }

  // ── 세션 완료 ──────────────────────────────────────────────────────────────
  Future<List<FeedActivity>> _sessionCompletes(
    String me,
    Set<String>? followingIds,
  ) async {
    try {
      var query = client
          .from('reading_sessions')
          .select(
            'id, user_id, ended_at, duration_seconds, '
            'books(title, author, cover_url, isbn)',
          )
          .not('ended_at', 'is', null);
      if (followingIds != null) {
        query = query.inFilter('user_id', followingIds.toList());
      } else {
        query = query.neq('user_id', me);
      }
      final rows =
          await query.order('ended_at', ascending: false).limit(30) as List;
      if (rows.isEmpty) return const [];

      final userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final profiles = await _profiles(userIds);

      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        final book = m['books'] as Map<String, dynamic>?;
        final profile = profiles[m['user_id']];
        final occurredAt =
            DateTime.tryParse(m['ended_at'] as String? ?? '') ?? DateTime.now();
        return FeedActivity(
          id: 'ss_${m['id']}',
          type: FeedActivityType.sessionComplete,
          username: profile?.name ?? '독자',
          handle: profile?.handle,
          avatarUrl: profile?.avatarUrl,
          isFriend: followingIds != null,
          bookTitle: book?['title'] as String? ?? '알 수 없는 책',
          bookAuthor: book?['author'] as String? ?? '',
          coverUrl: book?['cover_url'] as String?,
          isbn13: book?['isbn'] as String?,
          occurredAt: occurredAt,
          durationSeconds: (m['duration_seconds'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('feed activity: session completes failed: $e');
      return const [];
    }
  }

  // ── 완독 ──────────────────────────────────────────────────────────────────
  Future<List<FeedActivity>> _bookCompletes(
    String me,
    Set<String>? followingIds,
  ) async {
    try {
      var query = client
          .from('books')
          .select('id, user_id, title, author, cover_url, isbn, completed_at')
          .eq('status', 'completed')
          .not('completed_at', 'is', null);
      if (followingIds != null) {
        query = query.inFilter('user_id', followingIds.toList());
      } else {
        query = query.neq('user_id', me);
      }
      final rows =
          await query.order('completed_at', ascending: false).limit(30) as List;
      if (rows.isEmpty) return const [];

      final userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final profiles = await _profiles(userIds);

      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        final profile = profiles[m['user_id']];
        final occurredAt =
            DateTime.tryParse(m['completed_at'] as String? ?? '') ??
            DateTime.now();
        return FeedActivity(
          id: 'bc_${m['id']}',
          type: FeedActivityType.bookComplete,
          username: profile?.name ?? '독자',
          handle: profile?.handle,
          avatarUrl: profile?.avatarUrl,
          isFriend: followingIds != null,
          bookTitle: m['title'] as String? ?? '알 수 없는 책',
          bookAuthor: m['author'] as String? ?? '',
          coverUrl: m['cover_url'] as String?,
          isbn13: m['isbn'] as String?,
          occurredAt: occurredAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('feed activity: book completes failed: $e');
      return const [];
    }
  }
  // ── 읽고 싶은 책 추가 ────────────────────────────────────────────────────────
  Future<List<FeedActivity>> _wantToReadEvents(
    String me,
    Set<String>? followingIds,
  ) async {
    try {
      var query = client
          .from('books')
          .select('id, user_id, title, author, cover_url, isbn, created_at')
          .eq('status', 'wantToRead');
      if (followingIds != null) {
        query = query.inFilter('user_id', followingIds.toList());
      } else {
        query = query.neq('user_id', me);
      }
      final rows =
          await query.order('created_at', ascending: false).limit(30) as List;
      if (rows.isEmpty) return const [];

      final userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final profiles = await _profiles(userIds);

      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        final profile = profiles[m['user_id']];
        final occurredAt =
            DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now();
        return FeedActivity(
          id: 'wr_${m['id']}',
          type: FeedActivityType.wantToRead,
          username: profile?.name ?? '독자',
          handle: profile?.handle,
          avatarUrl: profile?.avatarUrl,
          isFriend: followingIds != null,
          bookTitle: m['title'] as String? ?? '알 수 없는 책',
          bookAuthor: m['author'] as String? ?? '',
          coverUrl: m['cover_url'] as String?,
          isbn13: m['isbn'] as String?,
          occurredAt: occurredAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('feed activity: want-to-read events failed: $e');
      return const [];
    }
  }

  // ── 읽기 시작 ────────────────────────────────────────────────────────────
  Future<List<FeedActivity>> _readingStartEvents(
    String me,
    Set<String>? followingIds,
  ) async {
    try {
      var query = client
          .from('books')
          .select(
            'id, user_id, title, author, cover_url, isbn, reading_started_at',
          )
          .not('reading_started_at', 'is', null);
      if (followingIds != null) {
        query = query.inFilter('user_id', followingIds.toList());
      } else {
        query = query.neq('user_id', me);
      }
      final rows =
          await query.order('reading_started_at', ascending: false).limit(30)
              as List;
      if (rows.isEmpty) return const [];

      final userIds = rows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String?)
          .whereType<String>()
          .toSet();
      final profiles = await _profiles(userIds);

      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        final profile = profiles[m['user_id']];
        final occurredAt =
            DateTime.tryParse(m['reading_started_at'] as String? ?? '') ??
            DateTime.now();
        return FeedActivity(
          id: 'rs_${m['id']}',
          type: FeedActivityType.readingStart,
          username: profile?.name ?? '독자',
          handle: profile?.handle,
          avatarUrl: profile?.avatarUrl,
          isFriend: followingIds != null,
          bookTitle: m['title'] as String? ?? '알 수 없는 책',
          bookAuthor: m['author'] as String? ?? '',
          coverUrl: m['cover_url'] as String?,
          isbn13: m['isbn'] as String?,
          occurredAt: occurredAt,
        );
      }).toList();
    } catch (e) {
      debugPrint('feed activity: reading start events failed: $e');
      return const [];
    }
  }
}

// ─── 목업 데이터 ──────────────────────────────────────────────────────────────
List<FeedActivity> _mockActivities() {
  final now = DateTime.now();
  const demianCover =
      'https://image.aladin.co.kr/product/206/48/cover500/893643361x_1.jpg';
  const veggieCover =
      'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg';

  return [
    FeedActivity(
      id: 'm1',
      type: FeedActivityType.sentenceBatch,
      username: '해진짱짱',
      handle: 'haejin_jjang',
      isFriend: true,
      bookTitle: '데미안',
      bookAuthor: '헤르만 헤세',
      coverUrl: demianCover,
      occurredAt: now.subtract(const Duration(minutes: 16)),
      sentenceCount: 13,
      previewSentences: [
        const FeedActivitySentence(
          content: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
          thought:
              '"특별한 사람이라고 생각한 적이 없었다"는 무심한 단언이지만, 문장 첫머리의 "아내가 채식을 시작하기 전까지"가 모든 걸 뒤집는다. 평범함에 대한 진술이 아니라 곧 닥칠 균열의 예고편이다.',
          pageNumber: 9,
        ),
        const FeedActivitySentence(
          content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
          thought: '거부의 시작이 꿈이라는 건, 의지가 아닌 무의식의 선택이라는 뜻.',
          pageNumber: 12,
        ),
        ...List.generate(
          11,
          (index) => FeedActivitySentence(
            content: '데미안에서 오래 머문 문장 ${index + 3}',
            pageNumber: 20 + index,
          ),
        ),
      ],
    ),
    FeedActivity(
      id: 'm2',
      type: FeedActivityType.sessionComplete,
      username: '해진짱짱',
      handle: 'haejin_jjang',
      isFriend: true,
      bookTitle: '데미안',
      bookAuthor: '헤르만 헤세',
      coverUrl: demianCover,
      occurredAt: now.subtract(const Duration(minutes: 16)),
      durationSeconds: 90 * 60,
    ),
    FeedActivity(
      id: 'm3',
      type: FeedActivityType.sessionComplete,
      username: '해골맨',
      handle: 'skull_man',
      isFriend: true,
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      coverUrl: veggieCover,
      occurredAt: now.subtract(const Duration(hours: 1)),
      durationSeconds: 151 * 60,
    ),
    FeedActivity(
      id: 'm4',
      type: FeedActivityType.bookComplete,
      username: '해골맨',
      handle: 'skull_man',
      isFriend: true,
      bookTitle: '채식주의자',
      bookAuthor: '한강',
      coverUrl: veggieCover,
      occurredAt: now.subtract(const Duration(hours: 1)),
      progressPercent: 100,
    ),
    FeedActivity(
      id: 'm5',
      type: FeedActivityType.sentenceBatch,
      username: 'leafy_reader',
      isFriend: false,
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      coverUrl:
          'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg',
      occurredAt: now.subtract(const Duration(hours: 3)),
      sentenceCount: 4,
      previewSentences: const [
        FeedActivitySentence(
          content: '나는 괴물이 아니에요. 그냥 달라요.',
          thought: '"다름"과 "틀림"의 경계에서 선재가 내뱉은 이 한마디가 소설 전체를 관통한다.',
          pageNumber: 47,
        ),
      ],
    ),
    FeedActivity(
      id: 'm6',
      type: FeedActivityType.bookComplete,
      username: 'midnight_books',
      isFriend: false,
      bookTitle: '소년이 온다',
      bookAuthor: '한강',
      coverUrl:
          'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg',
      occurredAt: now.subtract(const Duration(hours: 6)),
      progressPercent: 100,
    ),
    FeedActivity(
      id: 'm7',
      type: FeedActivityType.readingStart,
      username: '해진짱짱',
      handle: 'haejin_jjang',
      isFriend: true,
      bookTitle: '아몬드',
      bookAuthor: '손원평',
      coverUrl:
          'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg',
      occurredAt: now.subtract(const Duration(hours: 8)),
    ),
    FeedActivity(
      id: 'm8',
      type: FeedActivityType.wantToRead,
      username: 'leafy_reader',
      isFriend: false,
      bookTitle: '소년이 온다',
      bookAuthor: '한강',
      coverUrl:
          'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg',
      occurredAt: now.subtract(const Duration(hours: 10)),
    ),
  ];
}
