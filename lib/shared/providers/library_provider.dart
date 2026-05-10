import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../models/isar/isar_book.dart';
import '../models/reading_session.dart';
import '../repositories/book_repository.dart';
import '../repositories/supabase_book_repository.dart';

/// USE_MOCK=true (--dart-define) → 목업 데이터 (디자인 작업용)
/// 기본값 false:
///   - 모바일/데스크톱 → SQLite (BookRepository)
///   - 웹 → Supabase (SupabaseBookRepository)

Book _fromIsarBook(IsarBook b) => Book(
      id: b.bookId,
      title: b.title,
      author: b.author,
      isbn: b.isbn,
      coverUrl: b.coverUrl,
      currentPage: b.currentPage,
      totalPages: b.totalPages,
      status: switch (b.status) {
        IsarReadingStatus.reading => ReadingStatus.reading,
        IsarReadingStatus.completed => ReadingStatus.completed,
        IsarReadingStatus.wantToRead => ReadingStatus.wantToRead,
      },
      completedAt: b.completedAt,
    );

class LibraryNotifier extends Notifier<List<Book>> {
  @override
  List<Book> build() {
    if (kUseMock) return List.from(_kMockBooks);
    Future.microtask(_loadFromDb);
    return [];
  }

  Future<void> _loadFromDb() async {
    if (kIsWeb) {
      // 웹: 로그인된 사용자의 책을 Supabase에서 불러옴
      final repo = ref.read(supabaseBookRepositoryProvider);
      final loaded = await repo.getAllBooks();
      // _loadFromDb 대기 중 addBook으로 추가된 책 보존
      final extra = state.where((b) => !loaded.any((lb) => lb.id == b.id)).toList();
      state = [...loaded, ...extra];
      return;
    }
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return;
    final rows = await repo.getAllBooks();
    final loaded = rows.map(_fromIsarBook).toList();
    // _loadFromDb 대기 중 addBook으로 추가된 책 보존
    final extra = state.where((b) => !loaded.any((lb) => lb.id == b.id)).toList();
    state = [...loaded, ...extra];
  }

  bool addBook(Book book) {
    final isDuplicate = book.isbn != null &&
        book.isbn!.isNotEmpty &&
        state.any((b) => b.isbn == book.isbn);
    if (isDuplicate) return false;
    state = [...state, book];
    if (kUseMock) return true;
    if (kIsWeb) {
      // fire-and-forget — UX는 즉시 반영, Supabase 저장은 백그라운드
      ref.read(supabaseBookRepositoryProvider).saveFromBook(book);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(book);
    }
    return true;
  }

  void updateCurrentPage(String bookId, int newPage) {
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;
    final old = state[idx];
    final clamped = old.totalPages > 0 ? newPage.clamp(0, old.totalPages) : newPage;
    final updated = Book(
      id: old.id,
      title: old.title,
      author: old.author,
      isbn: old.isbn,
      coverUrl: old.coverUrl,
      currentPage: clamped,
      totalPages: old.totalPages,
      status: clamped >= old.totalPages && old.totalPages > 0
          ? ReadingStatus.completed
          : old.status,
      totalReadingHours: old.totalReadingHours,
      savedSentences: old.savedSentences,
      completedAt: (clamped >= old.totalPages && old.totalPages > 0 && old.status != ReadingStatus.completed) 
          ? DateTime.now() 
          : old.completedAt,
    );
    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    if (kIsWeb) {
      ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(updated);
    }
  }

  /// 책의 총 페이지 수 갱신.
  ///
  /// 알라딘 ItemSearch 응답에서 누락된 페이지 수를 ItemLookUp 보강 결과로 채우거나,
  /// 사용자가 수동 입력했을 때 사용한다.
  void updateTotalPages(String bookId, int totalPages) {
    if (totalPages <= 0) return;
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;
    final old = state[idx];
    if (old.totalPages == totalPages) return;
    final clampedCurrent = old.currentPage > totalPages ? totalPages : old.currentPage;
    final updated = Book(
      id: old.id,
      title: old.title,
      author: old.author,
      isbn: old.isbn,
      coverUrl: old.coverUrl,
      currentPage: clampedCurrent,
      totalPages: totalPages,
      status: old.status,
      totalReadingHours: old.totalReadingHours,
      savedSentences: old.savedSentences,
      completedAt: old.completedAt,
    );
    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    if (kIsWeb) {
      ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(updated);
    }
  }

  void deleteBook(String bookId) {
    state = state.where((b) => b.id != bookId).toList();
    if (kUseMock) return;
    if (kIsWeb) {
      ref.read(supabaseBookRepositoryProvider).deleteByBookId(bookId);
    } else {
      ref.read(bookRepositoryProvider)?.deleteByBookId(bookId);
    }
  }

  bool containsIsbn(String? isbn13) {
    if (isbn13 == null || isbn13.isEmpty) return false;
    return state.any((b) => b.isbn == isbn13);
  }

  bool containsByTitleAuthor(String title, String author) {
    return state.any((b) => b.title == title && b.author == author);
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, List<Book>>(
  LibraryNotifier.new,
);

// ─── 초기 목업 데이터 ────────────────────────────────────────────────────────
final _kMockBooks = [
  // reading
  Book(
    id: '1',
    title: '채식주의자',
    author: '한강',
    status: ReadingStatus.reading,
    totalPages: 300,
    currentPage: 186,
    totalReadingHours: 5.2,
    savedSentences: ['나는 채식주의자가 되기로 했다.', '꿈 때문에.'],
  ),
  Book(
    id: '2',
    title: '파친코',
    author: '이민진',
    status: ReadingStatus.reading,
    totalPages: 688,
    currentPage: 234,
    totalReadingHours: 8.2,
  ),
  Book(
    id: '3',
    title: '지구 끝의 온실',
    author: '김초엽',
    status: ReadingStatus.reading,
    totalPages: 304,
    currentPage: 88,
    totalReadingHours: 4.6,
  ),
  // completed
  Book(
    id: '4',
    title: '82년생 김지영',
    author: '조남주',
    status: ReadingStatus.completed,
    totalPages: 190,
    currentPage: 190,
    totalReadingHours: 4.1,
    completedAt: DateTime(2026, 5, 2),
  ),
  Book(
    id: '5',
    title: '아몬드',
    author: '손원평',
    status: ReadingStatus.completed,
    totalPages: 264,
    currentPage: 264,
    totalReadingHours: 6.3,
    completedAt: DateTime(2026, 5, 5),
  ),
  // wantToRead
  Book(
    id: '6',
    title: '소년이 온다',
    author: '한강',
    status: ReadingStatus.wantToRead,
    totalPages: 216,
    currentPage: 0,
  ),
  Book(
    id: '7',
    title: '불편한 편의점',
    author: '김호연',
    status: ReadingStatus.wantToRead,
    totalPages: 312,
    currentPage: 0,
  ),
  Book(
    id: '8',
    title: '달러구트 꿈 백화점',
    author: '이미예',
    status: ReadingStatus.wantToRead,
    totalPages: 304,
    currentPage: 0,
  ),
];
