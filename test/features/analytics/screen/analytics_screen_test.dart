import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/analytics/controller/analytics_provider.dart';
import 'package:chorok_app/features/analytics/screen/analytics_screen.dart';

class _FakeAnalyticsNotifier extends AnalyticsNotifier {
  @override
  Future<AnalyticsState> build() async => const AnalyticsState(
    weekTimeOfDay: [
      (label: '새벽', range: '00–06', minutes: 0),
      (label: '오전', range: '06–12', minutes: 0),
      (label: '오후', range: '12–18', minutes: 0),
      (label: '저녁', range: '18–24', minutes: 1),
    ],
  );
}

void main() {
  testWidgets('분석 화면에서 뒤로가기로 이전 화면에 돌아간다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyticsProvider.overrideWith(_FakeAnalyticsNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AnalyticsScreen(),
                    ),
                  ),
                  child: const Text('분석 열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('분석 열기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('분석 열기'), findsOneWidget);
  });

  // weekDailyMinutes 는 월=0 이고 weekStart 도 월요일이라, 라벨도 월요일 시작이어야 한다.
  // 일요일 시작 라벨을 쓰면 강조된(오늘) 막대 아래에 엉뚱한 요일이 찍힌다.
  testWidgets('주별 차트 라벨은 월요일 시작이고 오늘 라벨이 강조된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyticsProvider.overrideWith(_FakeAnalyticsNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const AnalyticsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const monFirst = ['월', '화', '수', '목', '금', '토', '일'];

    // 라벨이 왼쪽에서 오른쪽으로 월→일 순서로 놓여 있다.
    final xs = monFirst
        .map((d) => tester.getCenter(find.text(d).last).dx)
        .toList();
    expect(xs, orderedEquals(<double>[...xs]..sort()));

    // 강조색이 칠해진 라벨 == 오늘 요일.
    final today = monFirst[DateTime.now().weekday - 1];
    final highlighted = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => monFirst.contains(t.data))
        .where((t) => t.style?.color == AppTheme.primaryLight)
        .map((t) => t.data)
        .toList();
    expect(highlighted, [today]);
  });
}
