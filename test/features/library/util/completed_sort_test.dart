import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/features/library/util/completed_sort.dart';
import 'package:chorok_app/shared/models/reading_session.dart';

Book book({required String title, int pages = 100, DateTime? completedAt}) =>
    Book(
      id: title,
      title: title,
      author: '작가',
      status: ReadingStatus.completed,
      totalPages: pages,
      completedAt: completedAt,
    );

List<String> sorted(CompletedSort sort, List<Book> books) =>
    (books.toList()..sort((a, b) => compareCompletedBooks(sort, a, b)))
        .map((b) => b.title)
        .toList();

void main() {
  test('최근에 완독한 순 — 최신이 먼저, 완독일 없는 책은 맨 뒤', () {
    final books = [
      book(title: '오래된', completedAt: DateTime(2026, 1, 1)),
      book(title: '완독일없음'),
      book(title: '최신', completedAt: DateTime(2026, 7, 1)),
    ];
    expect(sorted(CompletedSort.recent, books), ['최신', '오래된', '완독일없음']);
  });

  test('가나다 순 — 한글 자모 순서대로', () {
    final books = [book(title: '하늘'), book(title: '가방'), book(title: '나무')];
    expect(sorted(CompletedSort.title, books), ['가방', '나무', '하늘']);
  });

  test('페이지 순 — 두꺼운 책이 먼저', () {
    final books = [
      book(title: '얇은', pages: 50),
      book(title: '두꺼운', pages: 500),
      book(title: '보통', pages: 200),
    ];
    expect(sorted(CompletedSort.pages, books), ['두꺼운', '보통', '얇은']);
  });
}
