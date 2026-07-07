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

    expect(find.text('완독'), findsOneWidget);
    expect(find.text('날짜순'), findsOneWidget);
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
}
