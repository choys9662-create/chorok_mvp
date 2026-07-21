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
    child: const MaterialApp(home: Scaffold(body: BookPickerSheet())),
  );
}

Widget _buildSheetLauncher(List<Book> books) {
  return ProviderScope(
    overrides: [
      libraryProvider.overrideWith(() => _FakeLibraryNotifier(books)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const BookPickerSheet(),
            ),
            child: const Text('책 선택 열기'),
          ),
        ),
      ),
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

List<Book> _readingBooks(int count) => List.generate(
  count,
  (index) => Book(
    id: 'reading-$index',
    title: '읽는 책 $index',
    author: '작가 $index',
    status: ReadingStatus.reading,
    totalPages: 300,
    currentPage: index * 10,
  ),
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
      expect(
        tester.getTopLeft(find.text('다른 책 검색')).dy,
        lessThan(tester.getTopLeft(find.text('채식주의자')).dy),
      );
    });

    testWidgets('4권 이상에서도 "다른 책 검색" 버튼이 책 목록 위에 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet(_readingBooks(4)));
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('다른 책 검색')).dy,
        lessThan(tester.getTopLeft(find.text('읽는 책 0')).dy),
      );
    });

    testWidgets('최근 추가한 책이 최근 읽은 책보다 위에 표시된다', (tester) async {
      final recentlyRead = Book(
        id: 'old',
        title: '최근 읽은 책',
        author: '작가',
        status: ReadingStatus.reading,
        addedAt: DateTime(2026, 7, 1),
        lastSessionStartedAt: DateTime(2026, 7, 21),
      );
      final recentlyAdded = Book(
        id: 'new',
        title: '방금 추가한 책',
        author: '작가',
        status: ReadingStatus.reading,
        addedAt: DateTime(2026, 7, 21),
      );

      await tester.pumpWidget(_buildSheet([recentlyRead, recentlyAdded]));
      await tester.pump();

      final addedTop = tester.getTopLeft(find.text('방금 추가한 책')).dy;
      final readTop = tester.getTopLeft(find.text('최근 읽은 책')).dy;
      expect(addedTop, lessThan(readTop));
    });

    testWidgets('라이브러리가 비어 있으면 "라이브러리 가기" CTA가 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([]));
      await tester.pump();

      expect(find.text('라이브러리 가기'), findsOneWidget);
    });

    testWidgets('4권 이상 시트를 아래로 끌면 원래 높이 아래로 따라 내려간다', (tester) async {
      await tester.pumpWidget(_buildSheetLauncher(_readingBooks(4)));
      await tester.tap(find.text('책 선택 열기'));
      await tester.pumpAndSettle();

      final title = find.text('오늘은 어떤 책을 읽을까요?');
      final initialTop = tester.getTopLeft(title).dy;
      final gesture = await tester.startGesture(tester.getCenter(title));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();

      expect(tester.getTopLeft(title).dy, greaterThan(initialTop));
      await gesture.cancel();
    });

    testWidgets('4권 이상 시트를 충분히 아래로 당기면 모달이 닫힌다', (tester) async {
      await tester.pumpWidget(_buildSheetLauncher(_readingBooks(4)));
      await tester.tap(find.text('책 선택 열기'));
      await tester.pumpAndSettle();

      final title = find.text('오늘은 어떤 책을 읽을까요?');
      expect(title, findsOneWidget);

      await tester.drag(title, const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(title, findsNothing);
    });
  });
}
