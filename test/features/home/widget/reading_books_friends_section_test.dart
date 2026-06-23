import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/controller/session_firefly_provider.dart';
import 'package:chorok_app/features/home/widget/reading_books_section.dart';
import 'package:chorok_app/features/home/widget/reading_friends_section.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/models/user_profile.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';
import 'package:chorok_app/shared/widgets/book_cover.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('읽고 있는 책 카드는 118x180 크기로 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const books = [
      Book(
        id: 'book-1',
        title: '채식주의자',
        author: '한강',
        status: ReadingStatus.reading,
        currentPage: 120,
        totalPages: 300,
      ),
      Book(
        id: 'book-2',
        title: '파친코',
        author: '이민진',
        status: ReadingStatus.reading,
        currentPage: 80,
        totalPages: 400,
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const ReadingBooksSection(),
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier(books)),
        ],
      ),
    );

    expect(tester.getSize(find.byType(BookCover).first), const Size(118, 180));
    expect(find.text('읽고 있는 책'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('읽고 있는 친구는 리스트 카드로 상위 3명과 전체 수를 보여준다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mutuals = List.generate(
      8,
      (i) => UserProfile(
        id: 'friend-$i',
        username: 'friend-$i',
        displayName: '친구$i',
      ),
    );

    await tester.pumpWidget(
      _wrap(
        const ReadingFriendsSection(),
        overrides: [
          sessionFireflyProvider.overrideWith(
            (ref) async => (
              mutualCount: mutuals.length,
              nearbyCount: 15,
              mutuals: mutuals,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('읽고 있는 친구'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('친구0'), findsOneWidget);
    expect(find.text('친구1'), findsOneWidget);
    expect(find.text('친구2'), findsOneWidget);
    expect(find.text('친구7'), findsNothing);
    expect(find.text('읽고 있는 이웃'), findsNothing);
    expect(find.text('이명이 초록숲'), findsNothing);
    expect(find.text('00:20:25'), findsNothing);
  });
}
