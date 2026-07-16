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
    final rows = await _selectBooksByUser(userId);
    return rows.map((r) => _bookFromRow(r as Map<String, dynamic>)).toList();
  }

  Future<List<dynamic>> _selectBooksByUser(String userId) async {
    try {
      return await _client
          .from('books')
          .select('*, global_books(description)')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
    } catch (_) {
      return await _client
          .from('books')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
    }
  }

  /// 책을 upsert. 같은 (user_id, book_id) 조합이면 덮어쓴다.
  /// isbn이 있으면 global_books에도 자동 등록.
  Future<void> saveFromBook(Book book) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final globalBookId = await _upsertGlobalBook(book);

    final row = {
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
      // timestamptz — 오프셋 없이 보내면 서버가 UTC 로 읽어 로컬 오프셋만큼 밀린다.
      'completed_at': book.completedAt?.toUtc().toIso8601String(),
      'genre': book.genre,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.from('books').upsert(row, onConflict: 'user_id,book_id');
    } catch (e) {
      if (!e.toString().contains('genre')) rethrow;
      row.remove('genre');
      await _client.from('books').upsert(row, onConflict: 'user_id,book_id');
    }
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

    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('book_reviews').upsert({
      'user_id': userId,
      'global_book_id': globalBookId,
      'star_rating': starRating,
      'memorable_line': clean(memorableLine),
      'legacy': clean(legacy),
      'updated_at': now,
    }, onConflict: 'user_id,global_book_id');
  }

  /// 라이브 포레스트(독서 세션) 시작 시각만 갱신 — 다른 필드는 건드리지 않는다.
  Future<void> markSessionStarted(String bookId, DateTime startedAt) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('books')
        .update({
          'last_session_started_at': startedAt.toUtc().toIso8601String(),
        })
        .eq('user_id', userId)
        .eq('book_id', bookId);
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

  /// global_books는 클라이언트가 직접 쓰지 못한다(RLS로 INSERT/UPDATE 정책 제거됨).
  /// upsert_global_book RPC가 null/빈 값만 채우는 병합 규칙으로 서버에서 대신 쓴다 —
  /// 인증된 아무 유저나 공용 서지정보를 임의로 덮어쓰는 것을 막기 위함(ISSUE: global_books
  /// 임의 수정 취약점).
  Future<String?> _upsertGlobalBook(Book book) async {
    if (book.isbn == null || book.isbn!.isEmpty) return null;
    try {
      final id = await _client.rpc(
        'upsert_global_book',
        params: {
          'p_isbn13': book.isbn,
          'p_title': book.title,
          'p_author': book.author,
          'p_cover_url': book.coverUrl,
          'p_description': book.description?.trim(),
          'p_total_pages': book.totalPages,
          'p_category': book.genre?.trim(),
        },
      );
      return id as String?;
    } catch (_) {
      // global_books/RPC가 아직 없거나 에러 시 무시
      return null;
    }
  }

  Book _bookFromRow(Map<String, dynamic> r) {
    final globalBook = r['global_books'] as Map<String, dynamic>?;
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
      genre: r['genre'] as String?,
      description:
          r['description'] as String? ?? globalBook?['description'] as String?,
      addedAt: r['created_at'] != null
          ? DateTime.tryParse(r['created_at'] as String)
          : null,
      // last_session_started_at 기록이 없는 책(이 필드 생기기 전에 읽던 책)은
      // updated_at(페이지 갱신 등으로 매번 갱신됨)으로 대체해 정렬이 어긋나지 않게 한다.
      lastSessionStartedAt: r['last_session_started_at'] != null
          ? DateTime.tryParse(r['last_session_started_at'] as String)
          : (r['updated_at'] != null
                ? DateTime.tryParse(r['updated_at'] as String)
                : null),
    );
  }
}

final supabaseBookRepositoryProvider = Provider<SupabaseBookRepository>((ref) {
  return SupabaseBookRepository(Supabase.instance.client);
});
