import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/chosu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ChosuSheet separates sentence and thought entry steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: ChosuSheet(bookTitle: '채식주의자')),
      ),
    );

    expect(find.text('수집할 문장'), findsOneWidget);
    expect(find.text('생각 쓰기'), findsOneWidget);
    expect(find.text('문장만 저장'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      '그래서 선이지는 행복을 누릴 만한 자격에서 없어서는 안 되는 그야말로 불가결한 조건인 것 같다.',
    );
    await tester.pump();
    await tester.tap(find.text('생각 쓰기'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('문장 수정'), findsOneWidget);
    expect(find.text('내 생각'), findsOneWidget);
    expect(find.text('저장하기'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
