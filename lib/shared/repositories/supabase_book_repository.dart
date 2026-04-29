import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reading_session.dart';

/// 웹 빌드용 책 저장소.
///
/// 모바일은 sqflite 기반 [BookRepository]를 사용하지만, 웹에는 sqflite가
/// 초기화되지 않으므로 Supabase의 `public.books` 테이블에 사용자별로 저장한다.
/// 다른 브라우저/기기에서 같은 계정으로 로그인하면 동일한 서재가 보인다.
class SupabaseBookRepository {
  final SupabaseClient _client;

  SupabaseBookRepository(this._client);

  Future<List<Book>> getAllBooks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('books')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((r) => _bookFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 책을 upsert. 같은 (user_id, book_id) 조합이면 덮어쓴다.
  Future<void> saveFromBook(Book book) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client.from('books').upsert(
      {
        'user_id': userId,
        'book_id': book.id,
        'title': book.title,
        'author': book.author,
        'isbn': book.isbn,
        'cover_url': book.coverUrl,
        'current_page': book.currentPage,
        'total_pages': book.totalPages,
        'status': switch (book.status) {
          ReadingStatus.reading => 'reading',
          ReadingStatus.completed => 'completed',
          ReadingStatus.wantToRead => 'wantToRead',
        },
        'total_reading_hours': book.totalReadingHours,
        'saved_sentences': book.savedSentences,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,book_id',
    );
  }

  Book _bookFromRow(Map<String, dynamic> r) {
    return Book(
      id: r['book_id'] as String,
      title: r['title'] as String,
      author: r['author'] as String,
      isbn: r['isbn'] as String?,
      coverUrl: r['cover_url'] as String?,
      currentPage: (r['current_page'] as num?)?.toInt() ?? 0,
      totalPages: (r['total_pages'] as num?)?.toInt() ?? 0,
      status: switch (r['status'] as String?) {
        'reading' => ReadingStatus.reading,
        'completed' => ReadingStatus.completed,
        'wantToRead' => ReadingStatus.wantToRead,
        _ => ReadingStatus.wantToRead,
      },
      totalReadingHours:
          (r['total_reading_hours'] as num?)?.toDouble() ?? 0,
      savedSentences: ((r['saved_sentences'] as List?) ?? const [])
          .map((s) => s.toString())
          .toList(),
    );
  }
}

final supabaseBookRepositoryProvider =
    Provider<SupabaseBookRepository>((ref) {
  return SupabaseBookRepository(Supabase.instance.client);
});
