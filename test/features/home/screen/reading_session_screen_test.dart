import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/controller/session_firefly_provider.dart';
import 'package:chorok_app/features/home/screen/reading_session_screen.dart';
import 'package:chorok_app/features/timer/controller/timer_controller.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/models/user_profile.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:chorok_app/shared/repositories/book_repository.dart';
import 'package:chorok_app/shared/repositories/reading_presence_repository.dart';

class _FakeDbService extends DbService {
  @override
  Future<List<Map<String, dynamic>>> fetchMySentencesForBook(
    String bookId, {
    String? title,
    String? author,
    String? isbn,
  }) async {
    return const [
      {
        'id': 'sentence-1',
        'content':
            '그러므로 다른 요소들이 모두 동등하다고 가정했을 때 기술이 가장 빠르게 발달할 수 있는 곳은 생산성이 높고 면적이 넓으며 인구가 많은 지역이다.',
        'thought': '',
        'page_number': null,
      },
    ];
  }
}

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;
}

class _FakePresenceRepository implements ReadingPresenceRepository {
  @override
  Future<void> start() async {}

  @override
  Future<void> heartbeat() async {}

  @override
  Future<void> end() async {}

  @override
  Future<Set<String>> activeUserIds(List<String> candidateIds) async {
    return const {};
  }

  @override
  Future<({int active, int today, int week})> liveCounts() async {
    return (active: 0, today: 0, week: 0);
  }
}

Widget _buildScreen() {
  const selectedBook = Book(
    id: 'guns-germs-steel',
    title: '총균쇠',
    author: '재레드 다이아몬드',
    status: ReadingStatus.reading,
    currentPage: 42,
    totalPages: 751,
  );
  const firstReadingBook = Book(
    id: 'vegetarian',
    title: '채식주의자',
    author: '한강',
    status: ReadingStatus.reading,
    currentPage: 120,
    totalPages: 267,
  );

  return ProviderScope(
    overrides: [
      dbServiceProvider.overrideWithValue(_FakeDbService()),
      libraryProvider.overrideWith(
        () => _FakeLibraryNotifier([firstReadingBook, selectedBook]),
      ),
      readingPresenceRepositoryProvider.overrideWithValue(
        _FakePresenceRepository(),
      ),
      sessionFireflyProvider.overrideWith(
        (ref) async =>
            (mutualCount: 0, nearbyCount: 0, mutuals: <UserProfile>[]),
      ),
      readingStreakProvider.overrideWith((ref) async => 0),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const ReadingSessionScreen(
        bookId: 'guns-germs-steel',
        bookTitle: '총균쇠',
        bookAuthor: '재레드 다이아몬드',
        startPage: 42,
        totalPages: 751,
      ),
    ),
  );
}

void main() {
  testWidgets('선택한 책이 첫 번째 reading 책으로 대체되지 않는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    expect(find.text('총균쇠'), findsWidgets);
    expect(find.text('재레드 다이아몬드 | 2022'), findsOneWidget);
    expect(find.text('채식주의자'), findsNothing);
    expect(find.text('영혜는 왜 채식을 결심했을까요?'), findsNothing);
  });

  testWidgets('세션 시작 질문 박스가 텍스트와 내부 여백만큼만 차지한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    final buttonSize = tester.getSize(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    final textSize = tester.getSize(find.text('이 책은 어떤 질문을 남길까요?'));

    expect(buttonSize.width, closeTo(textSize.width + 32.2, 0.1));
    expect(buttonSize.width, lessThan(402 - 80));
  });

  testWidgets('세션 시작 시 선택한 책 메타를 타이머에 저장한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.tap(find.text('이 책은 어떤 질문을 남길까요?'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReadingSessionScreen)),
    );
    final timer = container.read(timerProvider);

    expect(timer.isRunning, isTrue);
    expect(timer.session?.bookId, 'guns-germs-steel');
    expect(timer.session?.bookTitle, '총균쇠');
    expect(timer.session?.startPage, 42);
    expect(find.textContaining('앱 내 집중 모드로 시작했어요'), findsOneWidget);
  });

  testWidgets('iOS Screen Time 권한이 거절되면 디톡스 세션을 시작하지 않는다', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = MethodChannel('chorok/screen_time');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async => 'denied');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.tap(find.text('이 책은 어떤 질문을 남길까요?'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReadingSessionScreen)),
    );
    debugDefaultTargetPlatformOverride = null;
    expect(container.read(timerProvider).isIdle, isTrue);
    expect(find.textContaining('스크린 타임 권한을 허용해야'), findsOneWidget);
  });

  testWidgets('문장 모아보기 확장 카드가 좁은 폭에서 overflow 하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('이 책은 어떤 질문을 남길까요?'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapAt(const Offset(196, 426));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('+1'));
    await tester.pump(const Duration(milliseconds: 600));

    final dismissFinder = find.bySemanticsLabel('문장 모아보기 닫기');
    expect(dismissFinder, findsOneWidget);
    expect(tester.getTopLeft(dismissFinder).dy, greaterThanOrEqualTo(74));

    final sentenceFinder = find.textContaining('그러므로 다른 요소들이');
    await tester.ensureVisible(sentenceFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(sentenceFinder);
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  testWidgets('종료 페이지 슬라이더를 끝까지 밀어도 페이지 박스가 overflow 하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.tap(find.text('이 책은 어떤 질문을 남길까요?'));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapAt(const Offset(196, 426));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.longPress(
      find.byKey(const ValueKey('reading-session-lock-button')),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);

    await tester.drag(slider, const Offset(500, 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('751'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
