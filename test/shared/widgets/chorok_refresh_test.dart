import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/shared/widgets/chorok_refresh.dart';

void main() {
  testWidgets('새로고침 완료 전까지 본문 위 공간을 유지한다', (tester) async {
    final refreshCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              ChorokSliverRefreshControl(
                onRefresh: () => refreshCompleter.future,
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 800, child: Text('본문')),
              ),
            ],
          ),
        ),
      ),
    );

    final contentTop = tester.getTopLeft(find.text('본문')).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(tester.getTopLeft(find.text('본문')).dy, greaterThan(contentTop));

    refreshCompleter.complete();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('본문')).dy, closeTo(contentTop, 1));
  });

  testWidgets('고정 헤더 아래에서 새로고침을 표시한다', (tester) async {
    final refreshCompleter = Completer<void>();
    final headerKey = UniqueKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                key: headerKey,
                height: 72,
                child: const Center(child: Text('고정 헤더')),
              ),
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    ChorokSliverRefreshControl(
                      onRefresh: () => refreshCompleter.future,
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 800, child: Text('본문')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final headerTop = tester.getTopLeft(find.byKey(headerKey)).dy;
    final headerBottom = tester.getBottomRight(find.byKey(headerKey)).dy;
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 160));
    await tester.pump();

    final indicator = find.byType(CupertinoActivityIndicator);
    expect(indicator, findsOneWidget);
    expect(tester.getTopLeft(find.byKey(headerKey)).dy, closeTo(headerTop, 1));
    expect(tester.getTopLeft(indicator).dy, greaterThan(headerBottom));

    refreshCompleter.complete();
    await tester.pumpAndSettle();
  });
}
