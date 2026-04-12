import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_session.dart';

/// 서재(책장) 상태 관리
///
/// 현재: 인메모리 List — 추후 Isar / Supabase 연동으로 교체 예정
class LibraryNotifier extends Notifier<List<Book>> {
  @override
  List<Book> build() => List.from(_kMockBooks);

  /// 서재에 책 추가. ISBN 또는 제목+저자 기준 중복 시 false 반환.
  bool addBook(Book book) {
    final isDuplicate = state.any((b) =>
        (book.isbn != null && book.isbn!.isNotEmpty && b.isbn == book.isbn) ||
        (b.title == book.title && b.author == book.author));
    if (isDuplicate) return false;
    state = [...state, book];
    return true;
  }

  /// ISBN으로 이미 서재에 있는지 확인
  bool containsIsbn(String? isbn13) {
    if (isbn13 == null || isbn13.isEmpty) return false;
    return state.any((b) => b.isbn == isbn13);
  }

  /// 제목+저자로 이미 서재에 있는지 확인
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
