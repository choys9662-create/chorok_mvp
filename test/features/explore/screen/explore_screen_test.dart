import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/explore/screen/explore_screen.dart';

void main() {
  testWidgets('탐색 검색창에서 책, 작가, 유저 탭을 전환한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const ExploreScreen(),
        ),
      ),
    );

    expect(find.text('책'), findsOneWidget);
    expect(find.text('작가'), findsOneWidget);
    expect(find.text('유저'), findsOneWidget);
    expect(find.text('책 제목, 키워드 검색'), findsOneWidget);

    await tester.tap(find.text('작가'));
    await tester.pumpAndSettle();

    expect(find.text('작가 이름 검색'), findsOneWidget);

    await tester.tap(find.text('유저'));
    await tester.pumpAndSettle();

    expect(find.text('유저 이름 검색'), findsOneWidget);
  });
}
