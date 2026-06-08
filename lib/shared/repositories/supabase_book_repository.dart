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
    return getBooksByUser(userId);
  }

  /// 특정 사용자의 서재를 읽는다. 소셜(팔로우한 사람 서재 보기)에서 사용.
  /// RLS `books_select_following` 정책이 팔로워에게만 읽기를 허용한다.
  Future<List<Book>> getBooksByUser(String userId) async {
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
  /// isbn이 있으면 global_books에도 자동 등록.
  Future<void> saveFromBook(Book book) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final globalBookId = await _upsertGlobalBook(book);

    await _client.from('books').upsert({
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
      'global_book_id': globalBookId,
      'completed_at': book.completedAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,book_id');
  }

  /// 완독 후 남긴 공개 평가를 저장한다. 테이블 미적용 환경에서는 호출부에서 무시한다.
  Future<void> saveReview({
    required Book book,
    required int starRating,
    String? memorableLine,
    String? legacy,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || starRating <= 0) return;

    final globalBookId = await _upsertGlobalBook(book);
    if (globalBookId == null) return;

    String? clean(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    final now = DateTime.now().toIso8601String();
    await _client.from('book_reviews').upsert({
      'user_id': userId,
      'global_book_id': globalBookId,
      'star_rating': starRating,
      'memorable_line': clean(memorableLine),
      'legacy': clean(legacy),
      'updated_at': now,
    }, onConflict: 'user_id,global_book_id');
  }

  Future<void> deleteByBookId(String bookId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('books')
        .delete()
        .eq('user_id', userId)
        .eq('book_id', bookId);
  }

  Future<String?> _upsertGlobalBook(Book book) async {
    if (book.isbn == null || book.isbn!.isEmpty) return null;
    try {
      final gbRow = await _client
          .from('global_books')
          .upsert({
            'isbn13': book.isbn,
            'title': book.title,
            'author': book.author,
            'cover_url': book.coverUrl,
            'total_pages': book.totalPages,
          }, onConflict: 'isbn13')
          .select('id')
          .single();
      return gbRow['id'] as String?;
    } catch (_) {
      // global_books 테이블이 아직 없거나 에러 시 무시
      return null;
    }
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
      totalReadingHours: (r['total_reading_hours'] as num?)?.toDouble() ?? 0,
      savedSentences: ((r['saved_sentences'] as List?) ?? const [])
          .map((s) => s.toString())
          .toList(),
      completedAt: r['completed_at'] != null
          ? DateTime.tryParse(r['completed_at'] as String)
          : null,
    );
  }
}

final supabaseBookRepositoryProvider = Provider<SupabaseBookRepository>((ref) {
  return SupabaseBookRepository(Supabase.instance.client);
});
