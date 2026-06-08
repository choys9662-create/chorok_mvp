import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/repositories/book_repository.dart';

FeedSentence _toFeedSentence(IsarChoseo c) => FeedSentence(
  id: c.choseoId,
  content: c.content,
  thought: c.myThought,
  bookTitle: c.bookTitle.isNotEmpty ? c.bookTitle : '알 수 없는 책',
  bookAuthor: c.bookAuthor,
  coverUrl: null, // To be implemented later if IsarChoseo stores it
  username: '나',
  savedAt: c.createdAt,
);

class FeedNotifier extends AsyncNotifier<List<FeedSentence>> {
  @override
  Future<List<FeedSentence>> build() async {
    if (kUseMock) return const [];
    return _load();
  }

  Future<List<FeedSentence>> _load() async {
    if (kIsWeb) return _loadFromSupabase();
    return _loadFromSqlite();
  }

  Future<List<FeedSentence>> _loadFromSqlite() async {
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return const [];
    final all = await repo.getAllChoseo(limit: 50);
    return all.map(_toFeedSentence).toList();
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
            'id, content, thought, created_at, '
            'profiles(username, display_name), '
            'books(title, author, cover_url), '
            'global_books(title, author, cover_url), '
            'sentence_likes(count)',
          )
          .neq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

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
          username: username,
          savedAt: createdAt,
          empathyCount: likeCount,
        );
      }).toList();
    } catch (_) {
      // 팔로우 전용 피드 — 에러 시 빈 피드를 반환한다.
      // (내 문장 폴백은 "팔로우한 사람만" 의미와 맞지 않음.)
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
