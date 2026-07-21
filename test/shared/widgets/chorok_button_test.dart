import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/shared/widgets/chorok_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('높이는 30이고 내용이 넘치지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(const ChorokButton(label: '이어 읽기', icon: Icons.play_arrow_rounded)),
    );

    expect(
      tester.getSize(find.byType(ChorokButton)).height,
      ChorokButton.height,
    );
    expect(tester.takeException(), isNull); // overflow 없음
  });

  testWidgets('expand는 가로를 채우고, 기본값은 내용만큼만 차지한다', (tester) async {
    await tester.pumpWidget(
      _host(const ChorokButton(label: '서재에 있는 책', expand: true)),
    );
    final wide = tester.getSize(find.byType(ChorokButton)).width;

    await tester.pumpWidget(_host(const ChorokButton(label: '서재에 있는 책')));
    final snug = tester.getSize(find.byType(ChorokButton)).width;

    expect(wide, greaterThan(snug));
  });

  testWidgets('좌우 여백 84가 버튼 폭에 반영된다', (tester) async {
    await tester.pumpWidget(_host(const ChorokButton(label: '이어 읽기')));
    final width = tester.getSize(find.byType(ChorokButton)).width;
    final textWidth = tester.getSize(find.text('이어 읽기')).width;

    expect(width - textWidth, closeTo(ChorokButton.horizontalPadding * 2, 1));
  });

  testWidgets('탭이 콜백으로 전달된다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(ChorokButton(label: '이어 읽기', onPressed: () => taps++)),
    );

    await tester.tap(find.byType(ChorokButton));
    expect(taps, 1);
  });
}
