import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/feed/controller/feed_activity_provider.dart';
import 'package:chorok_app/features/feed/model/feed_activity.dart';
import 'package:chorok_app/features/feed/screen/feed_screen.dart';

void main() {
  final now = DateTime(2026, 6, 22, 11);
  final sentenceActivity = FeedActivity(
    id: 'sentence',
    type: FeedActivityType.sentenceBatch,
    username: '해진짱짱',
    isFriend: true,
    bookTitle: '데미안',
    bookAuthor: '헤르만 헤세',
    occurredAt: now,
    sentenceCount: 13,
    previewSentences: List.generate(
      13,
      (index) => FeedActivitySentence(
        id: 'sentence-$index',
        content: '기록한 문장 ${index + 1}',
        pageNumber: index + 1,
      ),
    ),
  );
  final sessionActivity = FeedActivity(
    id: 'session',
    type: FeedActivityType.sessionComplete,
    username: '해골맨',
    isFriend: true,
    bookTitle: '채식주의자',
    bookAuthor: '한강',
    occurredAt: now,
    durationSeconds: 90 * 60,
  );
  final publicActivity = FeedActivity(
    id: 'public',
    type: FeedActivityType.bookComplete,
    username: '다른독자',
    bookTitle: '아몬드',
    bookAuthor: '손원평',
    occurredAt: now,
  );

  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        feedActivityProvider.overrideWith((ref, scope) async {
          if (scope == FeedScope.friends) {
            return [sentenceActivity, sessionActivity];
          }
          return [sentenceActivity, sessionActivity, publicActivity];
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const FeedScreen(),
      ),
    );
  }

  Widget buildPushedSubject() {
    return ProviderScope(
      overrides: [
        feedActivityProvider.overrideWith(
          (ref, scope) async => [sentenceActivity, sessionActivity],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const FeedScreen()),
                ),
                child: const Text('피드 열기'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('활동 카드와 문장 더보기를 표시하고 펼친다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('기록한 문장 1'), findsOneWidget);
    expect(find.text('기록한 문장 2'), findsOneWidget);
    expect(find.text('기록한 문장 3'), findsNothing);
    expect(find.text('11개 더보기'), findsOneWidget);
    expect(find.text('1시간 30분'), findsOneWidget);

    await tester.tap(find.text('11개 더보기'));
    await tester.pumpAndSettle();

    expect(find.text('기록한 문장 3'), findsOneWidget);
    expect(find.text('접기'), findsOneWidget);
  });

  testWidgets('전체 탭에서 친구가 아닌 독자의 활동도 표시한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    Finder activityTitle(String value) => find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(value),
    );

    expect(activityTitle('다른독자'), findsNothing);

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();

    expect(activityTitle('다른독자'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('push로 진입한 피드에는 뒤로가기를 표시하고 이전 화면으로 돌아간다', (tester) async {
    await tester.pumpWidget(buildPushedSubject());

    await tester.tap(find.text('피드 열기'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    expect(find.text('피드 열기'), findsOneWidget);
  });
}
