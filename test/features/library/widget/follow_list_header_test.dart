import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chorok_app/core/constants/app_flags.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/widget/profile_header.dart';

void main() {
  // ProfileHeader.initState 가 Supabase 를 잡으므로 mock 모드에서만 의미가 있다.
  // 실행: flutter test --dart-define=USE_MOCK=true
  testWidgets('팔로잉 목록 헤더 — 뒤로가기 화살표가 제목과 겹치지 않고 왼쪽에 있다', skip: !kUseMock, (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: ProfileHeader()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('팔로잉'));
    await tester.pumpAndSettle();

    // 화면엔 '팔로잉'이 여럿(헤더 제목 + 각 행의 버튼). 제목은 16pt 짜리 하나뿐이다.
    final titleFinder = find.byWidgetPredicate(
      (w) => w is Text && w.data == '팔로잉' && w.style?.fontSize == 16.0,
    );
    final arrow = tester.getRect(find.byIcon(Icons.chevron_left_rounded));
    final title = tester.getRect(titleFinder);

    // 화살표는 화면 왼쪽에, 제목은 가운데에 — 서로 겹치면 안 된다.
    expect(
      arrow.overlaps(title),
      isFalse,
      reason: '화살표($arrow)와 제목($title)이 겹친다',
    );
    expect(arrow.right, lessThan(title.left));
  });
}
