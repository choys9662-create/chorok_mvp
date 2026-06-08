import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/screen/book_detail_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;
}

void main() {
  testWidgets('책 상세 화면 하단에 이어 읽기 버튼이 고정 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = Book(
      id: 'book-1',
      title: '채식주의자 (리마스터판)',
      author: '한강',
      status: ReadingStatus.reading,
      currentPage: 196,
      totalPages: 276,
      savedSentences: ['나는 채식주의자가 되기로 했다.'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier([book])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const BookDetailScreen(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이어 읽기'), findsOneWidget);
    expect(find.bySemanticsLabel('문장 추가'), findsOneWidget);
    expect(find.text('채식주의자 (리마스터판)'), findsOneWidget);
    expect(find.text('한강 | 창비 | 2022'), findsOneWidget);

    final buttonTop = tester.getTopLeft(find.text('이어 읽기')).dy;
    expect(buttonTop, greaterThan(790));
  });
}
