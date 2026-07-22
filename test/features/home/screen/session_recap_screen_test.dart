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
  final Map<String, List<Map<String, dynamic>>> overlaps;
  int? savedPagesRead;
  String? savedClientSessionId;

  _FakeDbService({this.overlaps = const {}});

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

  @override
  Future<List<Map<String, dynamic>>> findOverlappingSentences(
    String content,
  ) async {
    return overlaps[content] ?? const [];
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

Widget _buildRecapScreen({
  _FakeDbService? dbService,
  int? endPage,
  List<CollectedSentence>? sentences,
}) {
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
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: SessionRecapScreen(
        data: RecapData(
          seconds: 9025,
          bookTitle: '채식주의자 (리마스터판)',
          bookAuthor: '한강',
          bookPublisher: '창비',
          publishedYear: '2022',
          sentences:
              sentences ??
              List.generate(
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

    expect(find.text('6번째 세션 요약'), findsOneWidget);
    expect(find.text('채식주의자 (리마스터판)'), findsOneWidget);
    expect(find.text('한강 | 창비 | 2022'), findsOneWidget);
    expect(find.text('02:30:25'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('196 / 267'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('문장 10 | 생각 5'), findsOneWidget);
    expect(find.text('10개'), findsOneWidget);
    expect(find.text('깊고 집중한 오전의 독서'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('서재'), findsOneWidget);
  });

  testWidgets('리캡 진입 시 내 초서 기록이 바로 보이고 화살표로 접을 수 있다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildRecapScreen());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('내 초서 기록 접기'), findsOneWidget);
    expect(find.text('문장 0'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('내 초서 기록 접기'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('내 초서 기록 펼치기'), findsOneWidget);
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

  testWidgets('겹문장이 있으면 리캡에 대표 생각을 노출하고 상세 시트를 연다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mySentence = '나도, 너를 사랑 해';
    final dbService = _FakeDbService(
      overlaps: {
        mySentence: [
          {
            'id': 'overlap-1',
            'user_id': 'user-2',
            'content': '나도 너를 사랑해',
            'thought': '같은 문장에서 오래 멈췄어요.',
            'created_at': DateTime(2026, 1, 2).toIso8601String(),
            'profiles': {
              'id': 'user-2',
              'username': 'reader_yun',
              'display_name': '윤',
              'avatar_url': null,
            },
            'books': {'title': '다른 책'},
            'sentence_likes': [
              {'count': 3},
            ],
          },
        ],
      },
    );

    await tester.pumpWidget(
      _buildRecapScreen(
        dbService: dbService,
        sentences: const [
          CollectedSentence(id: 'mine-1', content: mySentence, thought: '내 생각'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.text('내 생각'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    await tester.ensureVisible(find.text(mySentence));
    await tester.pumpAndSettle();
    await tester.tap(find.text(mySentence));
    await tester.pumpAndSettle();

    expect(find.text('내 생각'), findsOneWidget);
    expect(find.text('1명의 독자가 이 문장에 남긴 생각'), findsOneWidget);
    expect(find.text('같은 문장에서 오래 멈췄어요.'), findsOneWidget);
  });
}
