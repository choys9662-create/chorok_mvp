import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/models/reading_session.dart';

class FeedNotifier extends AsyncNotifier<List<FeedSentence>> {
  @override
  Future<List<FeedSentence>> build() async {
    if (kUseMock) return const [];
    return _load();
  }

  /// 이웃 피드는 팔로우한 독자의 초서(원격)만 의미가 있으므로,
  /// 플랫폼과 무관하게 항상 Supabase에서 읽는다.
  /// (모바일 로컬 sqlite는 "내 초서"만 담겨 이웃 피드로는 부적합 — 과거 결함)
  Future<List<FeedSentence>> _load() async {
    return _loadFromSupabase();
  }

  Future<List<FeedSentence>> _loadFromSupabase() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];

    try {
      // 팔로우한 사람의 문장만 — 내 문장은 제외(.neq).
      // RLS가 이미 (내 것 + 팔로우한 것)으로 제한하므로 결과는 팔로우 전용이 된다.
      final rows = await client
          .from('sentences')
          .select(
            // sentence_likes가 sentences↔profiles 다대다 관계를 만들어 'profiles'
            // 임베드가 모호해지므로(PGRST201) 작성자 FK를 명시한다.
            'id, content, thought, created_at, '
            'profiles!sentences_user_id_fkey(username, display_name), '
            'books(title, author, cover_url, isbn), '
            'global_books(title, author, cover_url, isbn13), '
            'sentence_likes(count)',
          )
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final sentenceIds = (rows as List)
          .map((r) => (r as Map<String, dynamic>)['id'] as String?)
          .whereType<String>()
          .toList();
      final likedIds = <String>{};
      if (sentenceIds.isNotEmpty) {
        final likes = await client
            .from('sentence_likes')
            .select('sentence_id')
            .eq('user_id', userId)
            .inFilter('sentence_id', sentenceIds);
        likedIds.addAll(
          (likes as List)
              .map((r) => (r as Map<String, dynamic>)['sentence_id'] as String?)
              .whereType<String>(),
        );
      }

      return (rows as List).map((r) {
        final map = r as Map<String, dynamic>;
        final localBook = map['books'] as Map<String, dynamic>?;
        final globalBook = map['global_books'] as Map<String, dynamic>?;
        final book = globalBook ?? localBook;
        final profile = map['profiles'] as Map<String, dynamic>?;
        final likesAgg = map['sentence_likes'] as List?;
        final likeCount = likesAgg?.isNotEmpty == true
            ? (likesAgg!.first['count'] as int? ?? 0)
            : 0;
        final createdAt =
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now();
        final username =
            profile?['display_name'] as String? ??
            profile?['username'] as String? ??
            '독자';
        return FeedSentence(
          id: map['id'] as String? ?? '',
          content: map['content'] as String? ?? '',
          thought: map['thought'] as String?,
          bookTitle: book?['title'] as String? ?? '알 수 없는 책',
          bookAuthor: book?['author'] as String? ?? '',
          coverUrl: book?['cover_url'] as String?,
          isbn13:
              globalBook?['isbn13'] as String? ?? localBook?['isbn'] as String?,
          username: username,
          savedAt: createdAt,
          empathyCount: likeCount,
          isLiked: likedIds.contains(map['id']),
        );
      }).toList();
    } catch (e) {
      // 팔로우 전용 피드 — 에러 시 빈 피드를 반환한다.
      // (내 문장 폴백은 "팔로우한 사람만" 의미와 맞지 않음.)
      // 단, 침묵 실패가 버그를 가리지 않도록 디버그 로그는 남긴다.
      debugPrint('feed load failed: $e');
      return const [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final feedProvider = AsyncNotifierProvider<FeedNotifier, List<FeedSentence>>(
  FeedNotifier.new,
);
