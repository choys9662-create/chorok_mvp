import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../shared/utils/sentence_normalizer.dart';

final dbServiceProvider = Provider<DbService>((ref) => DbService());

final _uuidLike = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

({String lowerBound, String upperBound}) utcDateRange(
  DateTime from,
  DateTime to,
) => (
  lowerBound: from.toUtc().toIso8601String(),
  upperBound: to.toUtc().toIso8601String(),
);

/// Supabase DB 접근 서비스
class DbService {
  // ── 현재 로그인된 유저 ID ─────────────────────────────────────────
  String get _uid {
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('사용자 인증 정보가 없습니다. 다시 로그인해주세요.');
    return user.id;
  }

  // ────────────────────────────────────────────────────────────────────
  // 책
  // ────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBooks() async {
    final res = await supabase
        .from('books')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>> addBook({
    required String title,
    required String author,
    String? publisher,
    int? totalPages,
  }) async {
    final res = await supabase
        .from('books')
        .insert({
          'user_id': _uid,
          'title': title,
          'author': author,
          'publisher': ?publisher,
          'total_pages': ?totalPages,
          'status': 'reading',
        })
        .select()
        .single();
    return res;
  }

  Future<void> deleteBook(String bookId) async {
    await supabase.from('books').delete().eq('id', bookId);
  }

  Future<void> updateBookProgress(String bookId, int currentPage) async {
    await supabase
        .from('books')
        .update({'current_page': currentPage})
        .eq('id', bookId);
  }

  // ────────────────────────────────────────────────────────────────────
  // 독서 세션 + 문장 저장
  // ────────────────────────────────────────────────────────────────────

  Future<({String? bookUuid, String? globalBookId})> _resolveBookIds(
    String? appBookId,
  ) async {
    if (appBookId == null || appBookId.isEmpty) {
      return (bookUuid: null, globalBookId: null);
    }

    final byAppId = await supabase
        .from('books')
        .select('id, global_book_id')
        .eq('user_id', _uid)
        .eq('book_id', appBookId)
        .maybeSingle();

    final row =
        byAppId ??
        (_uuidLike.hasMatch(appBookId)
            ? await supabase
                  .from('books')
                  .select('id, global_book_id')
                  .eq('user_id', _uid)
                  .eq('id', appBookId)
                  .maybeSingle()
            : null);

    return (
      bookUuid: row?['id'] as String?,
      globalBookId: row?['global_book_id'] as String?,
    );
  }

  /// 세션 종료 시 호출 — 세션 행 생성 후 문장들을 일괄 insert
  Future<String> saveSession({
    String? bookId,
    required int durationSeconds,
    required List<String> sentences,
    List<String?>? sentenceIds,
    List<String?>? thoughts, // 추가 — nullable, 기존 호출부 변경 불필요
    List<int?>? pageNumbers, // 추가 — sentences와 같은 순서, nullable
    int? sentenceCount,
    int? score,
    DateTime? startedAt,
    DateTime? endedAt,
    int pagesRead = 0,
    int exitCount = 0,
    int exitDurationSeconds = 0,
    String? clientSessionId,
  }) async {
    final ids = await _resolveBookIds(bookId);
    final ended = endedAt ?? DateTime.now();
    final started =
        startedAt ?? ended.subtract(Duration(seconds: durationSeconds));
    final sessionRow = {
      'user_id': _uid,
      'book_id': ?ids.bookUuid,
      'duration_seconds': durationSeconds,
      'sentence_count': sentenceCount ?? sentences.length,
      'score': ?score,
      // timestamptz 컬럼이라 오프셋 없는 문자열을 보내면 서버가 UTC 로 읽어 로컬 오프셋만큼 밀린다.
      'started_at': started.toUtc().toIso8601String(),
      'ended_at': ended.toUtc().toIso8601String(),
      'client_session_id': ?clientSessionId,
      'pages_read': pagesRead,
      'exit_count': exitCount,
      'exit_duration_seconds': exitDurationSeconds,
    };

    // 1) 세션 행 생성
    late final Map<String, dynamic> session;
    try {
      if (clientSessionId != null && clientSessionId.isNotEmpty) {
        session = await supabase
            .from('reading_sessions')
            .upsert(sessionRow, onConflict: 'user_id,client_session_id')
            .select('id')
            .single();
      } else {
        session = await supabase
            .from('reading_sessions')
            .insert(sessionRow)
            .select('id')
            .single();
      }
    } catch (_) {
      final legacyRow = {
        'user_id': _uid,
        'book_id': ?ids.bookUuid,
        'duration_seconds': durationSeconds,
        'sentence_count': sentenceCount ?? sentences.length,
        'score': ?score,
        'started_at': started.toUtc().toIso8601String(),
        'ended_at': ended.toUtc().toIso8601String(),
      };
      session = await supabase
          .from('reading_sessions')
          .insert(legacyRow)
          .select('id')
          .single();
    }

    final sessionId = session['id'] as String;

    // 2) 세션 중 즉시 저장한 문장은 새 세션에 연결하고, 아직 저장하지 않은
    // 문장만 새로 insert한다.
    final persistedIds = sentenceIds
        ?.whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (persistedIds != null && persistedIds.isNotEmpty) {
      await supabase
          .from('sentences')
          .update({'session_id': sessionId})
          .eq('user_id', _uid)
          .inFilter('id', persistedIds);
    }

    final pendingSentences = sentences.asMap().entries.where((entry) {
      if (sentenceIds == null || entry.key >= sentenceIds.length) return true;
      final id = sentenceIds[entry.key];
      return id == null || id.isEmpty;
    }).toList();
    if (pendingSentences.isNotEmpty) {
      await supabase
          .from('sentences')
          .insert(
            pendingSentences
                .map(
                  (e) => {
                    'user_id': _uid,
                    'book_id': ?ids.bookUuid,
                    'global_book_id': ?ids.globalBookId,
                    'session_id': sessionId,
                    'content': e.value,
                    'normalized_sentences':
                        SentenceNormalizer.tokenizeAndNormalize(e.value),
                    'thought': thoughts != null && e.key < thoughts.length
                        ? thoughts[e.key]
                        : null,
                    'page_number':
                        pageNumbers != null && e.key < pageNumbers.length
                        ? pageNumbers[e.key]
                        : null,
                  },
                )
                .toList(),
          );
    }

    return sessionId;
  }

  // ────────────────────────────────────────────────────────────────────
  // 문장 (내 것 + 팔로우 피드)
  // ────────────────────────────────────────────────────────────────────

  /// 세션 없이 단독으로 문장 저장 (서재 화면에서 직접 추가 시 사용)
  Future<String> saveSentenceStandalone({
    required String bookId,
    required String content,
    String? thought,
    int? pageNumber,
  }) async {
    final ids = await _resolveBookIds(bookId);
    final trimmedContent = content.trim();
    final trimmedThought = thought?.trim();
    final row = await supabase
        .from('sentences')
        .insert({
          'user_id': _uid,
          'book_id': ?ids.bookUuid,
          'global_book_id': ?ids.globalBookId,
          'content': trimmedContent,
          'page_number': ?pageNumber,
          'normalized_sentences': SentenceNormalizer.tokenizeAndNormalize(
            trimmedContent,
          ),
          'thought': (trimmedThought?.isNotEmpty == true)
              ? trimmedThought
              : null,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Map<String, dynamic>>> fetchMySentencesForBook(
    String bookId, {
    String? title,
    String? author,
    String? isbn,
  }) async {
    final ids = await _resolveBookIds(bookId);
    final batches = <List<dynamic>>[];
    const selectColumns =
        'id, user_id, book_id, global_book_id, session_id, content, thought, page_number, normalized_sentences, created_at, '
        'books(id, book_id, title, author, isbn)';

    if (ids.bookUuid != null) {
      final rows = await supabase
          .from('sentences')
          .select(selectColumns)
          .eq('user_id', _uid)
          .eq('book_id', ids.bookUuid!)
          .order('created_at', ascending: false);
      batches.add(rows as List);
    }

    if (ids.globalBookId != null) {
      final rows = await supabase
          .from('sentences')
          .select(selectColumns)
          .eq('user_id', _uid)
          .eq('global_book_id', ids.globalBookId!)
          .order('created_at', ascending: false);
      batches.add(rows as List);
    }

    final byId = <String, Map<String, dynamic>>{};
    for (final batch in batches) {
      for (final row in batch) {
        final map = Map<String, dynamic>.from(row as Map);
        byId[map['id'] as String] = map;
      }
    }

    final needsFallback =
        (title?.trim().isNotEmpty == true) || (isbn?.trim().isNotEmpty == true);
    if (needsFallback) {
      final rows = await supabase
          .from('sentences')
          .select(selectColumns)
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(1000);
      for (final row in rows as List) {
        final map = Map<String, dynamic>.from(row as Map);
        final book = map['books'] as Map<String, dynamic>?;
        if (_matchesBookFallback(
          rowTitle: book?['title'] as String?,
          rowAuthor: book?['author'] as String?,
          rowIsbn: book?['isbn'] as String?,
          title: title,
          author: author,
          isbn: isbn,
        )) {
          byId[map['id'] as String] = map;
        }
      }
    }

    final rows = byId.values.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at'] as String? ?? '');
        final bDate = DateTime.tryParse(b['created_at'] as String? ?? '');
        return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      });
    return rows;
  }

  bool _matchesBookFallback({
    required String? rowTitle,
    required String? rowAuthor,
    required String? rowIsbn,
    required String? title,
    required String? author,
    required String? isbn,
  }) {
    final targetIsbn = _compact(isbn);
    final candidateIsbn = _compact(rowIsbn);
    if (targetIsbn.isNotEmpty &&
        candidateIsbn.isNotEmpty &&
        targetIsbn == candidateIsbn) {
      return true;
    }

    final targetTitle = _compact(title);
    final candidateTitle = _compact(rowTitle);
    if (targetTitle.length < 4 || candidateTitle.length < 4) return false;

    final titleMatches =
        targetTitle == candidateTitle ||
        targetTitle.contains(candidateTitle) ||
        candidateTitle.contains(targetTitle);
    if (!titleMatches) return false;

    final targetAuthor = _compact(author);
    final candidateAuthor = _compact(rowAuthor);
    if (targetAuthor.isEmpty || candidateAuthor.isEmpty) return true;
    return targetAuthor == candidateAuthor ||
        targetAuthor.contains(candidateAuthor) ||
        candidateAuthor.contains(targetAuthor);
  }

  String _compact(String? value) {
    if (value == null) return '';
    return value.toLowerCase().replaceAll(
      RegExp(r'[\s\p{P}\p{S}]+', unicode: true),
      '',
    );
  }

  Future<void> updateSentenceThought(String sentenceId, String? thought) async {
    final trimmed = thought?.trim();
    await supabase
        .from('sentences')
        .update({'thought': trimmed?.isNotEmpty == true ? trimmed : null})
        .eq('id', sentenceId)
        .eq('user_id', _uid);
  }

  Future<void> updateSentencePage(String sentenceId, int? pageNumber) async {
    await supabase
        .from('sentences')
        .update({'page_number': pageNumber})
        .eq('id', sentenceId)
        .eq('user_id', _uid);
  }

  Future<void> deleteSentence(String sentenceId) async {
    await supabase
        .from('sentences')
        .delete()
        .eq('id', sentenceId)
        .eq('user_id', _uid);
  }

  /// 알림 등에서 sentence_id만 있을 때, 문장 상세 화면에 필요한 정보를 조회.
  /// RLS: 내 문장(own) / 팔로우한 문장(following) / 공개 문장(global_book_id 있음)만 보인다.
  /// 못 찾거나 권한 없으면 null.
  Future<Map<String, dynamic>?> fetchSentenceDetailById(
    String sentenceId,
  ) async {
    final row = await supabase
        .from('sentences')
        .select(
          'id, content, thought, page_number, '
          'profiles!sentences_user_id_fkey(username, display_name), '
          'books(title, author), global_books(title, author)',
        )
        .eq('id', sentenceId)
        .maybeSingle();
    if (row == null) return null;
    final local = row['books'] as Map<String, dynamic>?;
    final global = row['global_books'] as Map<String, dynamic>?;
    final book = global ?? local;
    final profile = row['profiles'] as Map<String, dynamic>?;
    return {
      'id': row['id'],
      'content': row['content'] ?? '',
      'thought': row['thought'],
      'page_number': row['page_number'],
      'book_title': book?['title'] ?? '알 수 없는 책',
      'book_author': book?['author'] ?? '',
      'username':
          (profile?['display_name'] as String?) ??
          (profile?['username'] as String?) ??
          '독자',
      'handle': (profile?['username'] as String?)?.trim(),
    };
  }

  /// 초서 전체 목록 — 커서 기반 페이지네이션. [before]보다 오래된 [limit]개를 반환한다.
  /// 반환 개수가 [limit]보다 적으면 더 이상 불러올 데이터가 없다는 뜻이다.
  Future<List<Map<String, dynamic>>> fetchMySentences({
    DateTime? before,
    int limit = 50,
  }) async {
    var query = supabase
        .from('sentences')
        .select(
          '*, books(title, author), sentence_likes(count), sentence_comments(count)',
        )
        .eq('user_id', _uid);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final res = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(res);
  }

  /// 팔로우 중인 유저들의 최근 문장 피드
  Future<List<Map<String, dynamic>>> fetchFeedSentences() async {
    // 내가 팔로우한 유저 목록 먼저 조회
    final follows = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', _uid)
        .eq('status', 'accepted');

    final followingIds = (follows as List)
        .map((f) => f['following_id'] as String)
        .toList();

    if (followingIds.isEmpty) return [];

    final res = await supabase
        .from('sentences')
        .select(
          '*, profiles!sentences_user_id_fkey(username, display_name, avatar_url), books(title)',
        )
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  /// 내 문장 + 좋아요 수 (기간 필터, 좋아요 많은 순)
  /// 반환: [{content, book_title, book_author, like_count}]
  Future<List<Map<String, dynamic>>> fetchMySentencesWithLikes({
    required DateTime from,
    required DateTime to,
    int limit = 5,
  }) async {
    final range = utcDateRange(from, to);
    final res = await supabase
        .from('sentences')
        .select('content, books(title, author), sentence_likes(count)')
        .eq('user_id', _uid)
        .gte('created_at', range.lowerBound)
        .lt('created_at', range.upperBound)
        .limit(50);

    final items =
        (res as List).map((r) {
          final book = r['books'] as Map<String, dynamic>?;
          final likesAgg = r['sentence_likes'] as List?;
          final likeCount = likesAgg?.isNotEmpty == true
              ? (likesAgg!.first['count'] as int? ?? 0)
              : 0;
          return {
            'content': r['content'] as String,
            'book_title': book?['title'] as String? ?? '',
            'book_author': book?['author'] as String? ?? '',
            'like_count': likeCount,
          };
        }).toList()..sort(
          (a, b) => (b['like_count'] as int).compareTo(a['like_count'] as int),
        );

    return items.take(limit).toList();
  }

  /// 팔로우 유저 문장 중 좋아요 많은 것 (커뮤니티 하이라이트)
  /// 반환: [{content, book_title, book_author, like_count}]
  Future<List<Map<String, dynamic>>> fetchCommunityHighlights({
    required DateTime from,
    required DateTime to,
    int limit = 3,
  }) async {
    final range = utcDateRange(from, to);
    final follows = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', _uid)
        .eq('status', 'accepted');

    final followingIds = (follows as List)
        .map((f) => f['following_id'] as String)
        .toList();

    if (followingIds.isEmpty) return const [];

    final res = await supabase
        .from('sentences')
        .select('content, books(title, author), sentence_likes(count)')
        .inFilter('user_id', followingIds)
        .gte('created_at', range.lowerBound)
        .lt('created_at', range.upperBound)
        .limit(50);

    final items =
        (res as List).map((r) {
          final book = r['books'] as Map<String, dynamic>?;
          final likesAgg = r['sentence_likes'] as List?;
          final likeCount = likesAgg?.isNotEmpty == true
              ? (likesAgg!.first['count'] as int? ?? 0)
              : 0;
          return {
            'content': r['content'] as String,
            'book_title': book?['title'] as String? ?? '',
            'book_author': book?['author'] as String? ?? '',
            'like_count': likeCount,
          };
        }).toList()..sort(
          (a, b) => (b['like_count'] as int).compareTo(a['like_count'] as int),
        );

    return items.take(limit).toList();
  }

  // ────────────────────────────────────────────────────────────────────
  // 문장 겹침 분석 — 같은 내용을 기록한 유저 수
  // ────────────────────────────────────────────────────────────────────

  Future<int> countSentenceOverlap(String content) async {
    final res = await supabase
        .from('sentences')
        .select('id')
        .eq('content', content)
        .neq('user_id', _uid);
    return (res as List).length;
  }

  /// 한 문장 단위라도 겹치는 다른 유저들의 문장을 조회한다.
  ///
  /// `A.B.C.D` 와 `B.C` 는 `B`·`C` 에서 겹친다 — 전문이 같을 필요는 없다.
  /// DB 트리거 `notify_on_overlap` 의 `&&` 와 같은 의미가 되도록 `ov`(배열 교집합)를 쓴다.
  /// GIN 인덱스(normalized_sentences)는 그대로 태워진다.
  ///
  /// 반환: [{ id, user_id, content, thought, created_at, profiles, books, sentence_likes }]
  Future<List<Map<String, dynamic>>> findOverlappingSentences(
    String content,
  ) async {
    final units = SentenceNormalizer.overlapUnits(content);
    if (units.isEmpty) return const [];
    // units 는 정규화를 거쳐 한글·영숫자만 남으므로 배열 리터럴에 주입될 문자가 없다.
    final literal = '{${units.map((u) => '"$u"').join(',')}}';
    final res = await supabase
        .from('sentences')
        .select(
          'id, user_id, content, thought, created_at, '
          'profiles!sentences_user_id_fkey(id, username, display_name, avatar_url), '
          'books(title), '
          'sentence_likes(count)',
        )
        .filter('normalized_sentences', 'ov', literal)
        .neq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  /// 같은 책의 겹문장 그룹을 상세 화면에서 재구성하기 위한 후보 문장.
  Future<List<Map<String, dynamic>>> fetchBookSentenceCandidates({
    String? globalBookId,
    String? bookId,
  }) async {
    if ((globalBookId == null || globalBookId.isEmpty) &&
        (bookId == null || bookId.isEmpty)) {
      return const [];
    }

    var query = supabase
        .from('sentences')
        .select(
          'id, user_id, content, thought, created_at, '
          'profiles!sentences_user_id_fkey(id, username, display_name, avatar_url), '
          'books(title), global_books(title)',
        );
    final filtered = globalBookId != null && globalBookId.isNotEmpty
        ? query.eq('global_book_id', globalBookId)
        : query.eq('book_id', bookId!);
    final res = await filtered.order('created_at', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(res);
  }

  /// 세션 진입 화두 생성용 후보.
  ///
  /// ISBN이 있으면 전체 독자의 같은 책 문장 뷰를 우선 보고, 없으면 현재 책 id로
  /// 저장된 문장을 본다. 호출부가 문장 중복/생각 유무로 다시 랭킹한다.
  Future<List<Map<String, dynamic>>> fetchSessionPromptCandidates({
    String? bookId,
    String? isbn13,
  }) async {
    final isbn = isbn13?.trim();
    if (isbn != null && isbn.isNotEmpty) {
      final rows = await supabase
          .from('global_book_sentences')
          .select('content, thought, like_count, created_at')
          .eq('isbn13', isbn)
          .order('like_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(60);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) return list;
    }

    final id = bookId?.trim();
    if (id == null || id.isEmpty || !_uuidLike.hasMatch(id)) return const [];
    final rows = await supabase
        .from('sentences')
        .select('content, thought, created_at')
        .eq('book_id', id)
        .order('created_at', ascending: false)
        .limit(80);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// 겹문장(나 ∩ 팔로잉, 같은 책) 판정용 후보 문장.
  ///
  /// exact-match 서버 쿼리(findOverlappingSentences)와 달리 부분 일치까지
  /// 잡아야 하므로, 내 문장과 팔로잉 문장 원본을 함께 반환해 클라이언트에서
  /// 책 단위로 OverlapDetector 비교를 돌린다.
  Future<
    ({List<Map<String, dynamic>> mine, List<Map<String, dynamic>> neighbors})
  >
  fetchFollowOverlapCandidates() async {
    final follows = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', _uid)
        .eq('status', 'accepted');
    final followingIds = (follows as List)
        .map((f) => (f as Map<String, dynamic>)['following_id'] as String?)
        .whereType<String>()
        .toList();
    if (followingIds.isEmpty) {
      return (
        mine: const <Map<String, dynamic>>[],
        neighbors: const <Map<String, dynamic>>[],
      );
    }

    const cols =
        'id, user_id, content, thought, page_number, book_id, global_book_id, '
        'normalized_sentences, created_at, '
        'books(title, author, cover_url, isbn), '
        'global_books(title, author, cover_url, isbn13)';

    final mineRes = await supabase
        .from('sentences')
        .select(cols)
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(100);

    final neighborRes = await supabase
        .from('sentences')
        .select(
          '$cols, profiles!sentences_user_id_fkey(id, username, display_name, avatar_url)',
        )
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .limit(150);

    return (
      mine: List<Map<String, dynamic>>.from(mineRes),
      neighbors: List<Map<String, dynamic>>.from(neighborRes),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // 좋아요
  // ────────────────────────────────────────────────────────────────────

  Future<void> likeSentence(String sentenceId) async {
    await supabase.from('sentence_likes').upsert({
      'user_id': _uid,
      'sentence_id': sentenceId,
    }, onConflict: 'user_id,sentence_id');
  }

  Future<void> unlikeSentence(String sentenceId) async {
    await supabase
        .from('sentence_likes')
        .delete()
        .eq('user_id', _uid)
        .eq('sentence_id', sentenceId);
  }

  // ────────────────────────────────────────────────────────────────────
  // 팔로우
  // ────────────────────────────────────────────────────────────────────

  Future<void> follow(String targetId) async {
    await supabase.from('follows').insert({
      'follower_id': _uid,
      'following_id': targetId,
    });
  }

  Future<void> unfollow(String targetId) async {
    await supabase
        .from('follows')
        .delete()
        .eq('follower_id', _uid)
        .eq('following_id', targetId);
  }

  Future<List<Map<String, dynamic>>> fetchFollowing() async {
    final res = await supabase
        .from('follows')
        .select(
          'following_id, profiles!follows_following_id_fkey(username, display_name, avatar_url)',
        )
        .eq('follower_id', _uid)
        .eq('status', 'accepted');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchFollowers() async {
    final res = await supabase
        .from('follows')
        .select(
          'follower_id, profiles!follows_follower_id_fkey(username, display_name, avatar_url)',
        )
        .eq('following_id', _uid)
        .eq('status', 'accepted');
    return List<Map<String, dynamic>>.from(res);
  }

  // ────────────────────────────────────────────────────────────────────
  // 프로필
  // ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchProfile() async {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
    return res;
  }

  Future<void> updateProfile({String? displayName, String? bio}) async {
    await supabase
        .from('profiles')
        .update({'display_name': ?displayName, 'bio': ?bio})
        .eq('id', _uid);
  }

  // ────────────────────────────────────────────────────────────────────
  // 통계
  // ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchStats() async {
    final sessions = await supabase
        .from('reading_sessions')
        .select('duration_seconds, sentence_count, ended_at')
        .eq('user_id', _uid)
        .order('ended_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(sessions);
    final totalSeconds = list.fold<int>(
      0,
      (sum, s) => sum + (s['duration_seconds'] as int? ?? 0),
    );
    final totalSentences = list.fold<int>(
      0,
      (sum, s) => sum + (s['sentence_count'] as int? ?? 0),
    );

    return {
      'session_count': list.length,
      'total_seconds': totalSeconds,
      'total_sentences': totalSentences,
      'sessions': list,
    };
  }
}
