import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/screen/session_recap_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/models/session_goal.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeDbService extends DbService {
  int? savedPagesRead;
  String? savedClientSessionId;

  @override
  Future<String> saveSession({
    String? bookId,
    required int durationSeconds,
    required List<String> sentences,
    List<String?>? thoughts,
    List<int?>? pageNumbers,
    int? sentenceCount,
    int? score,
    DateTime? startedAt,
    DateTime? endedAt,
    int pagesRead = 0,
    int exitCount = 0,
    int exitDurationSeconds = 0,
    String? clientSessionId,
  }) async {
    savedPagesRead = pagesRead;
    savedClientSessionId = clientSessionId;
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

Widget _buildRecapScreen({_FakeDbService? dbService, int? endPage}) {
  const book = Book(
    id: 'book-1',
    title: '채식주의자 (리마스터판)',
    author: '한강',
    status: ReadingStatus.reading,
    totalPages: 267,
    currentPage: 196,
  );

  return ProviderScope(
    overrides: [
      dbServiceProvider.overrideWithValue(dbService ?? _FakeDbService()),
      libraryProvider.overrideWith(() => _FakeLibraryNotifier([book])),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: SessionRecapScreen(
        data: RecapData(
          seconds: 9025,
          bookTitle: '채식주의자 (리마스터판)',
          bookAuthor: '한강',
          bookPublisher: '창비',
          publishedYear: '2022',
          sentences: List.generate(
            10,
            (index) => CollectedSentence(
              id: 'sentence-$index',
              content: '문장 $index',
              thought: index < 5 ? '기록 $index' : '',
            ),
          ),
          bookId: 'book-1',
          startPage: 196,
          endPage: endPage,
          totalPages: 267,
          progressPercent: 70,
          sessionStartedAt: DateTime(2026, 1, 1, 9),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('세션 요약 화면이 첨부 이미지의 요약 행을 렌더링한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildRecapScreen());
    await tester.pumpAndSettle();

    expect(find.text('세션 요약'), findsOneWidget);
    expect(find.text('채식주의자 (리마스터판)'), findsOneWidget);
    expect(find.text('한강 | 창비 | 2022'), findsOneWidget);
    expect(find.text('02:30:25'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('196 / 267'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('문장'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('깊고 집중한 오전의 독서'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('서재'), findsOneWidget);
  });

  testWidgets('초서 기록 화살표를 누르면 내 초서 기록이 펼쳐진다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildRecapScreen());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('내 초서 기록 펼치기'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('내 초서 기록 접기'), findsOneWidget);
    expect(find.text('문장 0'), findsOneWidget);
    expect(find.text('기록 0'), findsOneWidget);
  });

  testWidgets('종료 페이지가 있으면 리캡과 원격 세션 저장에 반영한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dbService = _FakeDbService();

    await tester.pumpWidget(
      _buildRecapScreen(dbService: dbService, endPage: 211),
    );
    await tester.pumpAndSettle();

    expect(find.text('211 / 267'), findsOneWidget);
    expect(dbService.savedPagesRead, 15);
    expect(dbService.savedClientSessionId, isNotNull);
  });
}
