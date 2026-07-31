import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/search/screen/manual_book_entry_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:chorok_app/shared/widgets/chorok_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> books;

  _FakeLibraryNotifier([List<Book> initial = const []])
    : books = List.of(initial);

  @override
  List<Book> build() => books;

  @override
  bool addBook(Book book) {
    if (containsByTitleAuthor(book.title, book.author)) return false;
    books.add(book);
    state = List.of(books);
    return true;
  }
}

void main() {
  late _FakeLibraryNotifier notifier;

  Widget buildSubject({_FakeLibraryNotifier? libraryNotifier}) {
    notifier = libraryNotifier ?? _FakeLibraryNotifier();
    return ProviderScope(
      overrides: [libraryProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ManualBookEntryScreen(),
                  ),
                ),
                child: const Text('직접 입력 열기'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.tap(find.text('직접 입력 열기'));
    await tester.pumpAndSettle();
  }

  Finder field(String key) => find.byKey(ValueKey(key));

  testWidgets('직접 입력은 제목 작가 페이지 수만 받는다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await openScreen(tester);

    expect(field('manual-title-field'), findsOneWidget);
    expect(field('manual-author-field'), findsOneWidget);
    expect(field('manual-pages-field'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
  });

  testWidgets('빈 값과 0 페이지로는 책을 추가하지 않는다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await openScreen(tester);

    var addButton = tester.widget<ChorokButton>(
      find.widgetWithText(ChorokButton, '서재에 추가'),
    );
    expect(addButton.onPressed, isNull);

    await tester.enterText(field('manual-title-field'), '채식주의자');
    await tester.enterText(field('manual-author-field'), '한강');
    await tester.enterText(field('manual-pages-field'), '0');
    await tester.pump();

    addButton = tester.widget<ChorokButton>(
      find.widgetWithText(ChorokButton, '서재에 추가'),
    );
    expect(addButton.onPressed, isNull);
    expect(find.text('1쪽 이상 입력해 주세요'), findsOneWidget);
    expect(notifier.books, isEmpty);
  });

  testWidgets('상태를 고르면 정리된 정보로 책을 추가한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await openScreen(tester);

    await tester.enterText(field('manual-title-field'), '  채식주의자  ');
    await tester.enterText(field('manual-author-field'), '  한강  ');
    await tester.enterText(field('manual-pages-field'), '276');
    await tester.pump();
    await tester.tap(find.text('서재에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('읽는 중'));
    await tester.pumpAndSettle();

    final added = notifier.books.single;
    expect(added.id, startsWith('manual_'));
    expect(added.title, '채식주의자');
    expect(added.author, '한강');
    expect(added.totalPages, 276);
    expect(added.status, ReadingStatus.reading);
    expect(added.isbn, isNull);
    expect(added.coverUrl, isNull);
  });

  testWidgets('상태 선택을 취소하면 입력값을 유지한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await openScreen(tester);

    await tester.enterText(field('manual-title-field'), '채식주의자');
    await tester.enterText(field('manual-author-field'), '한강');
    await tester.enterText(field('manual-pages-field'), '276');
    await tester.pump();
    await tester.tap(find.text('서재에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(field('manual-title-field')).controller!.text,
      '채식주의자',
    );
    expect(
      tester.widget<TextField>(field('manual-author-field')).controller!.text,
      '한강',
    );
    expect(
      tester.widget<TextField>(field('manual-pages-field')).controller!.text,
      '276',
    );
    expect(notifier.books, isEmpty);
  });

  testWidgets('같은 제목과 작가 책은 대소문자와 공백이 달라도 중복 추가하지 않는다', (tester) async {
    final existingNotifier = _FakeLibraryNotifier(const [
      Book(id: 'dune', title: 'Dune', author: 'Frank Herbert'),
    ]);
    await tester.pumpWidget(buildSubject(libraryNotifier: existingNotifier));
    await openScreen(tester);

    await tester.enterText(field('manual-title-field'), ' dune ');
    await tester.enterText(field('manual-author-field'), ' FRANK HERBERT ');
    await tester.enterText(field('manual-pages-field'), '688');
    await tester.pump();
    await tester.tap(find.text('서재에 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('읽는 중'));
    await tester.pump();

    expect(existingNotifier.books, hasLength(1));
    expect(find.text('이미 서재에 있는 책이에요'), findsOneWidget);
  });
}
