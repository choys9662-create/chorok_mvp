import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/sentence_organizer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>?> showSheet(
    WidgetTester tester, {
    required String rawText,
    List<List<String>>? paragraphs,
    Future<OcrCapture?> Function()? onCapture,
  }) {
    return showModalBottomSheet<List<String>>(
      context: tester.element(find.byType(Scaffold)),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SentenceOrganizerSheet(
        rawText: rawText,
        paragraphs: paragraphs,
        onCapture: onCapture,
      ),
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

  testWidgets('추가 촬영 뒤에도 기존 선택 문장과 합칠 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(
      tester,
      rawText: '첫 페이지 문장입니다.',
      onCapture: () async => (
        text: '다음 페이지 문장입니다.',
        paragraphs: [
          ['다음 페이지 문장입니다.'],
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('첫 페이지 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('추가 촬영'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음 페이지 문장입니다.'));
    await tester.pumpAndSettle();

    expect(find.text('문장 합치기'), findsOneWidget);
    await tester.tap(find.text('문장 합치기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['첫 페이지 문장입니다. 다음 페이지 문장입니다.']);
  });

  testWidgets('추가 촬영분에서 다음 문단을 넘겨 합치지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    final resultFuture = showSheet(
      tester,
      rawText: '첫 페이지 문장입니다.',
      onCapture: () async => (
        text: '이어지는 문장입니다. 다음 문단 문장입니다.',
        paragraphs: [
          ['이어지는 문장입니다.'],
          ['다음 문단 문장입니다.'],
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('첫 페이지 문장입니다.'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('추가 촬영'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다음 문단 문장입니다.'));
    await tester.pumpAndSettle();

    expect(find.text('문장 합치기'), findsNothing);
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(await resultFuture, ['첫 페이지 문장입니다.', '다음 문단 문장입니다.']);
  });
}
