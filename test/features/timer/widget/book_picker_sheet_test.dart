import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/timer/widget/book_picker_sheet.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;
  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;
}

Widget _buildSheet(List<Book> books) {
  return ProviderScope(
    overrides: [
      libraryProvider.overrideWith(() => _FakeLibraryNotifier(books)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: BookPickerSheet()),
    ),
  );
}

final _readingBook = Book(
  id: 'b1',
  title: '채식주의자',
  author: '한강',
  status: ReadingStatus.reading,
  totalPages: 300,
  currentPage: 186,
);

final _wantToReadBook = Book(
  id: 'b2',
  title: '아몬드',
  author: '손원평',
  status: ReadingStatus.wantToRead,
  totalPages: 264,
  currentPage: 0,
);

void main() {
  group('BookPickerSheet', () {
    testWidgets('읽는 중인 책이 있으면 책 제목이 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_readingBook, _wantToReadBook]));
      await tester.pump();

      expect(find.text('채식주의자'), findsOneWidget);
      expect(find.text('아몬드'), findsNothing); // wantToRead는 표시 안 됨
    });

    testWidgets('읽는 중인 책이 없으면 empty state 문구가 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_wantToReadBook]));
      await tester.pump();

      expect(find.text('읽는 중인 책이 없어요'), findsOneWidget);
    });

    testWidgets('읽는 중인 책이 있으면 "다른 책 검색" 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_readingBook]));
      await tester.pump();

      expect(find.text('다른 책 검색'), findsOneWidget);
    });

    testWidgets('라이브러리가 비어 있으면 "라이브러리 가기" CTA가 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([]));
      await tester.pump();

      expect(find.text('라이브러리 가기'), findsOneWidget);
    });
  });
}
