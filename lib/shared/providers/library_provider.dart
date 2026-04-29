import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/isar/isar_book.dart';
import '../models/reading_session.dart';
import '../repositories/book_repository.dart';
import '../repositories/supabase_book_repository.dart';

/// USE_MOCK=true (--dart-define) → 목업 데이터 (디자인 작업용)
/// 기본값 false:
///   - 모바일/데스크톱 → SQLite (BookRepository)
///   - 웹 → Supabase (SupabaseBookRepository)
const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

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
    );

class LibraryNotifier extends Notifier<List<Book>> {
  @override
  List<Book> build() {
    if (_useMock) return List.from(_kMockBooks);
    Future.microtask(_loadFromDb);
    return [];
  }

  Future<void> _loadFromDb() async {
    if (kIsWeb) {
      // 웹: 로그인된 사용자의 책을 Supabase에서 불러옴
      final repo = ref.read(supabaseBookRepositoryProvider);
      state = await repo.getAllBooks();
      return;
    }
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return;
    final rows = await repo.getAllBooks();
    state = rows.map(_fromIsarBook).toList();
  }

  bool addBook(Book book) {
    final isDuplicate = state.any((b) =>
        (book.isbn != null && book.isbn!.isNotEmpty && b.isbn == book.isbn) ||
        (b.title == book.title && b.author == book.author));
    if (isDuplicate) return false;
    state = [...state, book];
    if (_useMock) return true;
    if (kIsWeb) {
      // fire-and-forget — UX는 즉시 반영, Supabase 저장은 백그라운드
      ref.read(supabaseBookRepositoryProvider).saveFromBook(book);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(book);
    }
    return true;
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
const _kMockBooks = [
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
    title: '82년생 김지영',
    author: '조남주',
    status: ReadingStatus.completed,
    totalPages: 190,
    currentPage: 190,
    totalReadingHours: 4.1,
  ),
  Book(
    id: '3',
    title: '아몬드',
    author: '손원평',
    status: ReadingStatus.completed,
    totalPages: 264,
    currentPage: 264,
    totalReadingHours: 6.3,
  ),
  Book(
    id: '4',
    title: '흰',
    author: '한강',
    status: ReadingStatus.wantToRead,
    totalPages: 160,
    currentPage: 0,
  ),
];
