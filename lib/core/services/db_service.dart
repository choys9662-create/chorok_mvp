import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../shared/utils/sentence_normalizer.dart';

final dbServiceProvider = Provider<DbService>((ref) => DbService());

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

  /// 세션 종료 시 호출 — 세션 행 생성 후 문장들을 일괄 insert
  Future<String> saveSession({
    String? bookId,
    required int durationSeconds,
    required List<String> sentences,
    List<String?>? thoughts,  // 추가 — nullable, 기존 호출부 변경 불필요
    int? score,
  }) async {
    // 1) 세션 행 생성
    final session = await supabase
        .from('reading_sessions')
        .insert({
          'user_id': _uid,
          'book_id': ?bookId,
          'duration_seconds': durationSeconds,
          'sentence_count': sentences.length,
          'score': ?score,
          'ended_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final sessionId = session['id'] as String;

    // 2) 문장들 일괄 insert
    if (sentences.isNotEmpty) {
      await supabase
          .from('sentences')
          .insert(
            sentences.asMap().entries
                .map(
                  (e) => {
                    'user_id': _uid,
                    'book_id': ?bookId,
                    'session_id': sessionId,
                    'content': e.value,
                    'normalized_sentences': [
                      SentenceNormalizer.normalize(e.value),
                    ],
                    'thought': thoughts != null && e.key < thoughts.length
                        ? thoughts[e.key]
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

  Future<List<Map<String, dynamic>>> fetchMySentences() async {
    final res = await supabase
        .from('sentences')
        .select('*, books(title, author)')
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
  }

  /// 팔로우 중인 유저들의 최근 문장 피드
  Future<List<Map<String, dynamic>>> fetchFeedSentences() async {
    // 내가 팔로우한 유저 목록 먼저 조회
    final follows = await supabase
        .from('follows')
        .select('following_id')
        .eq('follower_id', _uid);

    final followingIds = (follows as List)
        .map((f) => f['following_id'] as String)
        .toList();

    if (followingIds.isEmpty) return [];

    final res = await supabase
        .from('sentences')
        .select('*, profiles(username, display_name, avatar_url), books(title)')
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res);
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

  /// 정규화된 문장과 exact-match되는 다른 유저들의 문장을 조회한다.
  ///
  /// Supabase GIN 인덱스를 통해 normalized_sentences 배열 포함 검색.
  /// 반환: [{ id, content, thought, created_at, profiles, books }]
  Future<List<Map<String, dynamic>>> findOverlappingSentences(
    String normalizedText,
  ) async {
    if (normalizedText.isEmpty) return const [];
    final res = await supabase
        .from('sentences')
        .select(
          'id, content, thought, created_at, '
          'profiles(username, display_name, avatar_url), '
          'books(title)',
        )
        .filter('normalized_sentences', 'cs', '{"$normalizedText"}')
        .neq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res);
  }

  // ────────────────────────────────────────────────────────────────────
  // 좋아요
  // ────────────────────────────────────────────────────────────────────

  Future<void> likeSentence(String sentenceId) async {
    await supabase.from('sentence_likes').insert({
      'user_id': _uid,
      'sentence_id': sentenceId,
    });
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
        .eq('follower_id', _uid);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchFollowers() async {
    final res = await supabase
        .from('follows')
        .select(
          'follower_id, profiles!follows_follower_id_fkey(username, display_name, avatar_url)',
        )
        .eq('following_id', _uid);
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
