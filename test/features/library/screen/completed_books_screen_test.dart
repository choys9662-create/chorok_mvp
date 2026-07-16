import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/screen/library_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  List<Book> build() => [
    Book(
      id: 'older',
      title: '오래된 완독',
      author: '작가 A',
      status: ReadingStatus.completed,
      completedAt: DateTime(2026, 5, 1),
    ),
    const Book(
      id: 'reading',
      title: '읽는 책',
      author: '작가 B',
      status: ReadingStatus.reading,
    ),
    Book(
      id: 'newer',
      title: '최근 완독',
      author: '작가 C',
      status: ReadingStatus.completed,
      completedAt: DateTime(2026, 6, 2),
    ),
  ];
}

void main() {
  testWidgets('완독 화면은 날짜순 완독만 보여주고 격자로 전환된다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWith(_FakeLibraryNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const CompletedBooksScreen(),
        ),
      ),
    );

    // 제목은 '완독' + 완독 권수(초록)를 함께 보여준다.
    expect(find.text('완독  2', findRichText: true), findsOneWidget);
    expect(find.text('최근에 완독한 순'), findsOneWidget);
    expect(find.text('읽는 책'), findsNothing);
    expect(find.text('최근 완독'), findsOneWidget);
    expect(find.text('오래된 완독'), findsOneWidget);

    final newerTop = tester.getTopLeft(find.text('최근 완독')).dy;
    final olderTop = tester.getTopLeft(find.text('오래된 완독')).dy;
    expect(newerTop, lessThan(olderTop));

    await tester.tap(find.byIcon(Icons.view_module_rounded));
    await tester.pumpAndSettle();

    expect(find.text('최근 완독'), findsOneWidget);
    expect(find.text('작가 C'), findsOneWidget);
  });

  testWidgets('정렬 라벨을 누르면 시트가 열리고, 고르면 라벨과 순서가 바뀐다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWith(_FakeLibraryNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const CompletedBooksScreen(),
        ),
      ),
    );

    await tester.tap(find.text('최근에 완독한 순'));
    await tester.pumpAndSettle();

    // 시트에 3개 기준이 모두 뜬다 (헤더의 현재 라벨까지 합쳐 '최근에...'는 2개).
    expect(find.text('최근에 완독한 순'), findsNWidgets(2));
    expect(find.text('가나다 순'), findsOneWidget);
    expect(find.text('페이지 순'), findsOneWidget);

    await tester.tap(find.text('가나다 순'));
    await tester.pumpAndSettle();

    expect(find.text('가나다 순'), findsOneWidget); // 헤더 라벨이 바뀜
    final olderTop = tester.getTopLeft(find.text('오래된 완독')).dy;
    final newerTop = tester.getTopLeft(find.text('최근 완독')).dy;
    expect(olderTop, lessThan(newerTop)); // '오' < '최'
  });
}
