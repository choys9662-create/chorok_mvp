import 'dart:async';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/constants/app_constants.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/search/model/aladin_book.dart';
import 'package:chorok_app/features/search/screen/book_info_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;
  final VoidCallback? onReload;

  _FakeLibraryNotifier(this._books, {this.onReload});

  @override
  List<Book> build() => _books;

  @override
  Future<void> reload() async => onReload?.call();
}

class _PendingDbService extends DbService {
  @override
  Future<List<Map<String, dynamic>>> fetchMySentencesForBook(
    String bookId, {
    String? title,
    String? author,
    String? isbn,
  }) => Completer<List<Map<String, dynamic>>>().future;
}

class _EmptyDbService extends DbService {
  @override
  Future<List<Map<String, dynamic>>> fetchMySentencesForBook(
    String bookId, {
    String? title,
    String? author,
    String? isbn,
  }) async => const [];
}

void main() {
  testWidgets('스크롤하면 책 표지가 축소된 고정 헤더로 남는다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = AladinBook(
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      publisher: '한빛미디어',
      description: '고객이 원하는 제품을 만들기 위한 책 소개입니다.',
      rawAuthor:
          '신디 앨버레즈 (지은이), A (옮긴이), B (옮긴이), C (옮긴이), '
          'D (옮긴이), E (옮긴이), F (옮긴이), G (옮긴이), H (옮긴이)',
    );
    const libraryBook = Book(
      id: 'lean-customer-development',
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      status: ReadingStatus.reading,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(
            () => _FakeLibraryNotifier([libraryBook]),
          ),
          dbServiceProvider.overrideWithValue(_PendingDbService()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const BookInfoScreen(book: book),
        ),
      ),
    );
    await tester.pump();

    final cover = find.byKey(const ValueKey('book-info-cover'));
    final heroHeader = find.byKey(const ValueKey('book-info-hero-header'));
    expect(cover, findsOneWidget);
    expect(heroHeader, findsOneWidget);
    final viewportWidth = tester.getSize(find.byType(CustomScrollView)).width;
    final expandedSize = tester.getSize(cover);
    final expandedRect = tester.getRect(cover);
    expect(expandedSize, AppTheme.bookInfoCoverExpandedSize);
    final expandedAuthorRect = tester.getRect(
      find.byKey(const ValueKey('book-info-expanded-author')),
    );
    final continueReading = tester.widget<Text>(find.text('이어 읽기'));
    expect(continueReading.style?.color, AppTheme.darkBg);
    final continueReadingTop = tester.getTopLeft(find.text('이어 읽기')).dy;
    expect(
      continueReadingTop - expandedAuthorRect.bottom,
      lessThanOrEqualTo(AppTheme.spaceLG + AppTheme.spaceXS),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pump();

    final collapsedSize = tester.getSize(cover);
    final collapsedRect = tester.getRect(cover);
    final collapsedMetadataHeight =
        (AppTheme.body.fontSize! * AppTheme.body.height! +
                AppTheme.spaceXS +
                AppTheme.supportingText.fontSize! *
                    AppTheme.supportingText.height!)
            .ceilToDouble();
    final collapsedContentHeight =
        collapsedMetadataHeight > AppTheme.touchTarget
        ? collapsedMetadataHeight
        : AppTheme.touchTarget;
    expect(
      tester.getSize(heroHeader).height,
      closeTo(AppTheme.spaceXS * 2 + collapsedContentHeight, 0.01),
    );
    expect(collapsedSize, AppTheme.bookInfoCoverCollapsedSize);
    expect(collapsedRect.center.dx, greaterThan(expandedRect.center.dx));
    expect(
      collapsedRect.right,
      closeTo(viewportWidth - AppTheme.screenPadding, 0.01),
    );
    expect(
      tester
          .getCenter(find.byKey(const ValueKey('book-info-collapsed-title')))
          .dx,
      closeTo(viewportWidth / 2, 0.01),
    );
  });

  testWidgets('아래로 당기면 표지가 커지고 더 당기면 새로고침한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var refreshCount = 0;
    const book = AladinBook(
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      publisher: '한빛미디어',
    );
    const libraryBook = Book(
      id: 'lean-customer-development',
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      status: ReadingStatus.reading,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(
            () => _FakeLibraryNotifier([
              libraryBook,
            ], onReload: () => refreshCount++),
          ),
          dbServiceProvider.overrideWithValue(_PendingDbService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const BookInfoScreen(book: book),
        ),
      ),
    );
    await tester.pump();

    final scrollView = find.byType(CustomScrollView);
    final cover = find.byKey(const ValueKey('book-info-cover'));
    final initialSize = tester.getSize(cover);
    final gesture = await tester.startGesture(tester.getCenter(scrollView));

    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();

    final pulledSize = tester.getSize(cover);
    expect(pulledSize.width, greaterThan(initialSize.width));
    expect(pulledSize.height, greaterThan(initialSize.height));

    await gesture.moveBy(const Offset(0, 240));
    await tester.pump();
    expect(tester.getSize(cover), AppTheme.bookInfoCoverPulledSize);

    await gesture.up();
    await tester.pump();
    expect(refreshCount, 1);
  });

  testWidgets('나의 문장 카드는 overflow 없이 표시된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = AladinBook(
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      publisher: '한빛미디어',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier(const [])),
          dbServiceProvider.overrideWithValue(_EmptyDbService()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const BookInfoScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('문장'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('문장과 생각 카드는 현재 책의 기록 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = AladinBook(
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      publisher: '한빛미디어',
    );
    const libraryBook = Book(
      id: 'lean-customer-development',
      title: '린 고객 개발',
      author: '신디 앨버레즈',
      status: ReadingStatus.reading,
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const BookInfoScreen(book: book),
        ),
        GoRoute(
          path: AppConstants.routeBookSentences,
          builder: (_, state) {
            final routedBook = state.extra as Book;
            return Scaffold(body: Text('records:${routedBook.id}'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(
            () => _FakeLibraryNotifier([libraryBook]),
          ),
          dbServiceProvider.overrideWithValue(_EmptyDbService()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('문장'));
    await tester.pumpAndSettle();
    expect(find.text('records:lean-customer-development'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('생각'));
    await tester.pumpAndSettle();
    expect(find.text('records:lean-customer-development'), findsOneWidget);
  });
}
