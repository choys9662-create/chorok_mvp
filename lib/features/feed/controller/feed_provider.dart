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

    final rows = await client
        .from('sentences')
        .select('id, content, created_at, books(title, author)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (rows as List).map((r) {
      final map = r as Map<String, dynamic>;
      final book = map['books'] as Map<String, dynamic>?;
      final createdAt =
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now();
      return FeedSentence(
        id: map['id'] as String? ?? '',
        content: map['content'] as String? ?? '',
        bookTitle: book?['title'] as String? ?? '알 수 없는 책',
        bookAuthor: book?['author'] as String? ?? '',
        username: '나',
        savedAt: createdAt,
      );
    }).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<FeedSentence>>(FeedNotifier.new);
