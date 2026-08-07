import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/reading_books_section.dart';
import 'package:chorok_app/features/home/widget/wishlist_section.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> books;

  _FakeLibraryNotifier(this.books);

  @override
  List<Book> build() => books;
}

void main() {
  testWidgets('읽고 싶은 책은 가장 최근에 추가한 책부터 왼쪽에 보여준다', (tester) async {
    final books = [
      Book(
        id: 'older',
        title: '먼저 추가한 책',
        author: '작가 A',
        status: ReadingStatus.wantToRead,
        addedAt: DateTime(2026, 7, 1),
      ),
      Book(
        id: 'reading',
        title: '읽는 중인 책',
        author: '작가 B',
        status: ReadingStatus.reading,
        addedAt: DateTime(2026, 7, 31),
      ),
      Book(
        id: 'newest',
        title: '방금 추가한 책',
        author: '작가 C',
        status: ReadingStatus.wantToRead,
        addedAt: DateTime(2026, 7, 30),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier(books)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: WishlistSection()),
        ),
      ),
    );

    expect(find.text('읽고 싶은 책'), findsOneWidget);
    final cards = tester
        .widgetList<ReadingBookCard>(find.byType(ReadingBookCard))
        .map((card) => card.book.id)
        .toList();
    expect(cards, ['newest', 'older']);
  });
}
