import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/home/widget/chosu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _textFieldWithHint(String hint) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.hintText == hint,
  );
}

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
    final sentenceField = _textFieldWithHint('마음에 남은 문장을 입력하세요...');
    expect(sentenceField, findsOneWidget);
    expect(tester.widget<TextField>(sentenceField).autofocus, isTrue);

    await tester.enterText(
      sentenceField,
      '그래서 선이지는 행복을 누릴 만한 자격에서 없어서는 안 되는 그야말로 불가결한 조건인 것 같다.',
    );
    await tester.pump();
    await tester.tap(find.text('생각 쓰기'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('문장 수정'), findsOneWidget);
    expect(find.text('내 생각'), findsOneWidget);
    expect(find.text('저장하기'), findsOneWidget);
    expect(_textFieldWithHint('이 문장에서 무엇을 느꼈나요?'), findsOneWidget);
  });

  testWidgets('ChosuSheet keeps keyboard closed for prefilled OCR text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: ChosuSheet(
            initialText: '스캔된 문장입니다.',
            bookTitle: '채식주의자',
            autofocusSentence: false,
          ),
        ),
      ),
    );

    final sentenceField = _textFieldWithHint('마음에 남은 문장을 입력하세요...');
    expect(sentenceField, findsOneWidget);
    final textField = tester.widget<TextField>(sentenceField);
    expect(textField.autofocus, isFalse);
    expect(textField.controller?.text, '스캔된 문장입니다.');
  });

  testWidgets('ChosuSheet lifts thought field above keyboard insets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          resizeToAvoidBottomInset: false,
          body: ChosuSheet(bookTitle: '채식주의자'),
        ),
      ),
    );

    final sentenceField = _textFieldWithHint('마음에 남은 문장을 입력하세요...');
    await tester.enterText(sentenceField, '자연선택이라는 하나의 문장');
    await tester.pump();
    await tester.tap(find.text('생각 쓰기'));
    await tester.pump(const Duration(milliseconds: 120));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    final thoughtField = _textFieldWithHint('이 문장에서 무엇을 느꼈나요?');
    expect(thoughtField, findsOneWidget);
    expect(tester.getBottomLeft(thoughtField).dy, lessThanOrEqualTo(844 - 300));
  });
}
