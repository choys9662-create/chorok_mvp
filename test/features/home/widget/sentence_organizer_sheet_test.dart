import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/sentence_organizer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>?> showSheet(
    WidgetTester tester, {
    required String rawText,
    List<List<String>>? paragraphs,
  }) {
    return showModalBottomSheet<List<String>>(
      context: tester.element(find.byType(Scaffold)),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SentenceOrganizerSheet(rawText: rawText, paragraphs: paragraphs),
    );
  }

  testWidgets('추가 버튼은 선택된 문장만 반환한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(
      tester,
      rawText: '첫 문장입니다. 둘째 문장입니다. 셋째 문장입니다.',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('둘째 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['둘째 문장입니다.']);
  });

  testWidgets('선택이 없으면 추가 버튼이 비활성화된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(tester, rawText: '하나. 둘.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.byType(SentenceOrganizerSheet), findsOneWidget);

    Navigator.of(tester.element(find.byType(SentenceOrganizerSheet))).pop();
    await tester.pumpAndSettle();
    expect(await resultFuture, isNull);
  });

  testWidgets('같은 문단 여러 문장을 합치면 추가 버튼으로 바뀐다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(
      tester,
      rawText: '첫 문장입니다. 둘째 문장입니다. 셋째 문장입니다.',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('첫 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘째 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문장 합치기'));
    await tester.pumpAndSettle();

    expect(find.text('2개의 문장을 합쳤어요'), findsOneWidget);
    expect(find.text('문장 합치기'), findsNothing);

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['첫 문장입니다. 둘째 문장입니다.']);
  });

  testWidgets('다른 문단의 문장끼리는 합치기가 뜨지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(
      tester,
      rawText: '첫 문단 문장입니다.\n둘째 문단 문장입니다.',
      paragraphs: [
        ['첫 문단 문장입니다.'],
        ['둘째 문단 문장입니다.'],
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('첫 문단 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('둘째 문단 문장입니다.'));
    await tester.pumpAndSettle();

    // 문단이 다르므로 합치기 대신 추가 버튼이 유지되고, 각 문장이 따로 반환된다.
    expect(find.text('문장 합치기'), findsNothing);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['첫 문단 문장입니다.', '둘째 문단 문장입니다.']);
  });
}
