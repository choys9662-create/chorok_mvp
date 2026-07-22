import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/controller/session_firefly_provider.dart';
import 'package:chorok_app/features/home/screen/reading_session_screen.dart';
import 'package:chorok_app/features/home/widget/session_fireflies.dart';
import 'package:chorok_app/features/timer/controller/timer_controller.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/models/user_profile.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:chorok_app/shared/repositories/book_repository.dart';
import 'package:chorok_app/shared/repositories/reading_presence_repository.dart';

class _FakeDbService extends DbService {
  final List<Map<String, dynamic>> promptCandidates;

  _FakeDbService({this.promptCandidates = const []});

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

  @override
  Future<List<Map<String, dynamic>>> fetchSessionPromptCandidates({
    String? bookId,
    String? isbn13,
  }) async {
    return promptCandidates;
  }
}

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;

  @override
  void markSessionStarted(String bookId) {}
}

class _FakePresenceRepository implements ReadingPresenceRepository {
  int startCount = 0;
  int heartbeatCount = 0;

  @override
  Future<void> start({
    String? bookTitle,
    String? bookAuthor,
    String? bookCoverUrl,
    double? latitude,
    double? longitude,
  }) async {
    startCount++;
  }

  @override
  Future<void> heartbeat() async {
    heartbeatCount++;
  }

  @override
  Future<void> end() async {}

  @override
  Future<Map<String, ReadingPresenceInfo>> activeReaders(
    List<String> candidateIds,
  ) async {
    return const {};
  }

  @override
  Future<({int active, int today, int week})> liveCounts() async {
    return (active: 0, today: 0, week: 0);
  }

  @override
  Future<int> nearbyReaderCount({int radiusMeters = 500}) async => 0;
}

Widget _buildScreen({
  List<Map<String, dynamic>> promptCandidates = const [],
  ReadingPresenceRepository? presenceRepository,
  List<Override> overrides = const [],
}) {
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
      dbServiceProvider.overrideWithValue(
        _FakeDbService(promptCandidates: promptCandidates),
      ),
      libraryProvider.overrideWith(
        () => _FakeLibraryNotifier([firstReadingBook, selectedBook]),
      ),
      readingPresenceRepositoryProvider.overrideWithValue(
        presenceRepository ?? _FakePresenceRepository(),
      ),
      sessionFireflyProvider.overrideWith(
        (ref) async => (
          mutualCount: 0,
          nearbyCount: 0,
          mutuals: <UserProfile>[],
          books: const <String, ReadingPresenceInfo>{},
        ),
      ),
      mutualFollowProvider.overrideWith((ref) async => const <UserProfile>[]),
      readingStreakProvider.overrideWith((ref) async => 0),
      ...overrides,
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
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
  test('반딧불이는 독서 시간에 따라 최대 3단까지 성장한다', () {
    expect(fireflyVisualForElapsed(Duration.zero), (
      growthScale: 1.0,
      layers: 2,
      pulseAmplitude: 0,
    ));
    expect(fireflyVisualForElapsed(const Duration(minutes: 10)), (
      growthScale: 1.2,
      layers: 2,
      pulseAmplitude: 0,
    ));
    expect(fireflyVisualForElapsed(const Duration(minutes: 30)), (
      growthScale: 1.4,
      layers: 3,
      pulseAmplitude: 0.04,
    ));
    expect(fireflyVisualForElapsed(const Duration(minutes: 60)), (
      growthScale: 1.6,
      layers: 3,
      pulseAmplitude: 0.06,
    ));
  });

  test('동시 접속자 수에 따라 반딧불이 밀도를 조절한다', () {
    expect(fireflyDensityScale(5), 1);
    expect(fireflyDensityScale(6), 0.9);
    expect(fireflyDensityScale(10), 0.9);
    expect(fireflyDensityScale(11), 0.8);
  });

  testWidgets('라이브 포레스트 진입만으로 presence를 시작한다', (tester) async {
    final presence = _FakePresenceRepository();

    await tester.pumpWidget(_buildScreen(presenceRepository: presence));
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ReadingSessionScreen)),
    );
    expect(container.read(timerProvider).isIdle, isTrue);
    expect(presence.startCount, 1);
  });

  testWidgets('진입 직후 presence 복구 heartbeat를 보낸다', (tester) async {
    final presence = _FakePresenceRepository();

    await tester.pumpWidget(_buildScreen(presenceRepository: presence));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(presence.heartbeatCount, 1);
  });

  testWidgets('내 반딧불도 세션 시작 단계의 성장 규칙을 사용한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump();

    // 나 orb = 절대 base × 성장배율(시작 단계 1.0), 화면폭 무관.
    final expectedDiameter = AppTheme.orbSelfBaseRadius * 1.0 * 2;
    final size = tester.getSize(find.byKey(const ValueKey('self-firefly')));
    expect(size.width, closeTo(expectedDiameter, 0.1));
    expect(size.height, closeTo(expectedDiameter, 0.1));
  });

  testWidgets('앱 복귀 직후 presence heartbeat와 숲 갱신을 시작한다', (tester) async {
    final presence = _FakePresenceRepository();

    await tester.pumpWidget(_buildScreen(presenceRepository: presence));
    await tester.pump();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(presence.heartbeatCount, 1);
  });

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

    final button = find.byKey(const ValueKey('session-entry-question-button'));
    final buttonSize = tester.getSize(button);
    final textSize = tester.getSize(
      find.descendant(of: button, matching: find.byType(Text)),
    );

    // 좌우 패딩 spaceLG(16)+spaceLG(16) = 32 (보더 없음)
    expect(buttonSize.width, closeTo(textSize.width + 32, 0.1));
    // 화면 좌우 여백은 sectionGap(30)*2 = 60 (SingleChildScrollView의
    // horizontal padding, _SessionStartOverlay 참고) — screenPadding(16)이
    // 아니라 이 화면 전용 sectionGap 여백을 따른다.
    expect(buttonSize.width, lessThanOrEqualTo(402 - AppTheme.sectionGap * 2));
  });

  testWidgets('세션 진입의 초록점은 지금 읽는 맞팔 수를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen(
        overrides: [
          sessionFireflyProvider.overrideWith(
            (ref) async => (
              mutualCount: 1,
              nearbyCount: 0,
              mutuals: <UserProfile>[],
              books: const <String, ReadingPresenceInfo>{},
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final activeCount = tester.widget<Text>(find.text('1'));
    expect(activeCount.style?.color, AppTheme.primaryLight);
  });

  testWidgets('긴 세션 시작 질문은 잘리지 않고 박스 높이를 늘린다', (tester) async {
    tester.view.physicalSize = const Size(320, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildScreen(
        promptCandidates: const [
          {
            'content': '우리 어머니는 이를 밤이 지난 후에도 오래 기억했다.',
            'thought': '',
            'like_count': 10,
          },
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final buttonSize = tester.getSize(
      find.byKey(const ValueKey('session-entry-question-button')),
    );

    expect(find.textContaining('왜 이 문장이 남았을까요?'), findsOneWidget);
    // 화면 좌우 sectionGap(30)*2 = 60 만큼 여백을 두고 나머지 폭을 채운다.
    expect(buttonSize.width, lessThanOrEqualTo(320 - 60));
    expect(buttonSize.height, greaterThan(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('세션 시작 시 선택한 책 메타를 타이머에 저장한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
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

  testWidgets('라이브 포레스트는 지금 같이 읽는(active) 맞팔만 반딧불로 띄운다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const mago = UserProfile(
      id: 'friend-1',
      username: 'mago',
      displayName: '마고',
    );
    const idle = UserProfile(
      id: 'friend-2',
      username: 'idle',
      displayName: '안읽는친구',
    );

    await tester.pumpWidget(
      _buildScreen(
        overrides: [
          // mago만 active(지금 읽는 중), idle은 맞팔이지만 presence 없음.
          sessionFireflyProvider.overrideWith(
            (ref) async => (
              mutualCount: 1,
              nearbyCount: 0,
              mutuals: const [mago],
              books: const <String, ReadingPresenceInfo>{},
            ),
          ),
          mutualFollowProvider.overrideWith((ref) async => const [mago, idle]),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('마고'), findsOneWidget);
    expect(find.text('안읽는친구'), findsNothing); // active 아닌 맞팔은 안 뜬다
  });

  testWidgets('실사용 독자 시트는 목업 이웃 대신 실제 빈 상태를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump();
    ScaffoldMessenger.of(
      tester.element(find.byType(ReadingSessionScreen)),
    ).hideCurrentSnackBar();
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('함께 읽는 초록 확인'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('지금 함께 읽는 친구가 없어요'), findsOneWidget);
    expect(find.text('익명의 나뭇잎'), findsNothing);
    expect(find.text('용기리기리'), findsNothing);
  });

  testWidgets('독자 시트 필터는 좌우로 전환된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildScreen());
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump();
    ScaffoldMessenger.of(
      tester.element(find.byType(ReadingSessionScreen)),
    ).hideCurrentSnackBar();
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump();
    await tester.tap(find.byType(ReadingSessionScreen));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('함께 읽는 초록 확인'));
    await tester.pump(const Duration(milliseconds: 500));

    final filter = find.byKey(const ValueKey('readers-sheet-filter'));
    final gesture = tester.widget<GestureDetector>(filter);
    gesture.onHorizontalDragEnd!(
      DragEndDetails(
        velocity: const Velocity(pixelsPerSecond: Offset(-120, 0)),
        primaryVelocity: -120,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.bySemanticsLabel('책 필터, 친구로 전환'), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
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

    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapAt(const Offset(196, 150));
    // revealed 진입 애니메이션(opacity/translate ~520ms) 완전 종료 후 배지 탭.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('+1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

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

    await tester.tap(
      find.byKey(const ValueKey('session-entry-question-button')),
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapAt(const Offset(196, 150));
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
