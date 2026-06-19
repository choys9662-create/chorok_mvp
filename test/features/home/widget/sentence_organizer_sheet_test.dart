import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/sentence_organizer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>?> showSheet(
    WidgetTester tester, {
    required String rawText,
  }) {
    return showModalBottomSheet<List<String>>(
      context: tester.element(find.byType(Scaffold)),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SentenceOrganizerSheet(rawText: rawText),
    );
  }

  testWidgets('확인 버튼은 선택된 문장만 반환한다', (tester) async {
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
    await tester.tap(find.byTooltip('문장 기록하기'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['둘째 문장입니다.']);
  });

  testWidgets('선택이 없으면 확인 버튼이 비활성화된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(tester, rawText: '하나. 둘.');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('문장 기록하기'));
    await tester.pumpAndSettle();

    expect(find.byType(SentenceOrganizerSheet), findsOneWidget);

    Navigator.of(tester.element(find.byType(SentenceOrganizerSheet))).pop();
    await tester.pumpAndSettle();
    expect(await resultFuture, isNull);
  });

  testWidgets('합치기 후에는 합쳐진 문장이 선택 상태로 유지된다', (tester) async {
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

    await tester.tap(find.byTooltip('문장 기록하기'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['첫 문장입니다. 둘째 문장입니다.']);
  });
}
