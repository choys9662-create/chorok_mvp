import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/screen/session_recap_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeDbService extends DbService {
  @override
  Future<String> saveSession({
    String? bookId,
    required int durationSeconds,
    required List<String> sentences,
    List<String?>? thoughts,
    int? sentenceCount,
    int? score,
    DateTime? startedAt,
    DateTime? endedAt,
    int pagesRead = 0,
    int exitCount = 0,
    int exitDurationSeconds = 0,
    String? clientSessionId,
  }) async {
    return clientSessionId ?? 'session-id';
  }
}

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;

  @override
  void updateCurrentPage(String bookId, int newPage) {
    state = [
      for (final book in state)
        if (book.id == bookId) book.copyWith(currentPage: newPage) else book,
    ];
  }
}

Widget _buildRecapScreen() {
  const book = Book(
    id: 'book-1',
    title: '우스운 사랑들',
    author: '밀란 쿤데라',
    status: ReadingStatus.reading,
    totalPages: 356,
    currentPage: 198,
  );

  return ProviderScope(
    overrides: [
      dbServiceProvider.overrideWithValue(_FakeDbService()),
      libraryProvider.overrideWith(() => _FakeLibraryNotifier([book])),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const SessionRecapScreen(
        data: RecapData(
          seconds: 3013,
          bookTitle: '우스운 사랑들',
          bookAuthor: '밀란 쿤데라',
          sentences: [],
          bookId: 'book-1',
          startPage: 198,
          totalPages: 356,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('페이지 기록 저장 후에도 슬라이더 카드가 유지된다', (tester) async {
    await tester.pumpWidget(_buildRecapScreen());
    await tester.pumpAndSettle();

    expect(find.text('오늘 몇 쪽까지 읽었나요?'), findsOneWidget);

    await tester.ensureVisible(find.text('기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();

    expect(find.text('페이지 기록이 저장됐어요'), findsNothing);
    expect(find.text('오늘 몇 쪽까지 읽었나요?'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
  });
}
