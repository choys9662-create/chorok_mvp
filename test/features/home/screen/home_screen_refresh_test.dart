import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/home/controller/weekly_minutes_provider.dart';
import 'package:chorok_app/features/home/screen/home_screen.dart';
import 'package:chorok_app/features/timer/controller/timer_controller.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  List<Book> build() => const [];
}

class _FakeTimerNotifier extends TimerNotifier {
  @override
  TimerData build() => TimerData.initial();
}

void main() {
  testWidgets('홈 새로고침은 완료될 때까지 본문 위 공간을 유지한다', (tester) async {
    final refreshCompleter = Completer<List<int>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(_FakeLibraryNotifier.new),
          timerProvider.overrideWith(_FakeTimerNotifier.new),
          weeklyMinutesProvider.overrideWith((ref) => refreshCompleter.future),
        ],
        child: MaterialApp(theme: ThemeData.dark(), home: const HomeScreen()),
      ),
    );
    await tester.pump();

    final today = find.text('오늘');
    final initialTop = tester.getTopLeft(today).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pump();

    expect(find.byType(CupertinoSliverRefreshControl), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsNothing);
    expect(tester.getTopLeft(today).dy, greaterThan(initialTop));

    refreshCompleter.complete(List.filled(7, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(today).dy, closeTo(initialTop, 1));
  });
}
