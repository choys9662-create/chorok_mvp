import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/explore/controller/discovery_provider.dart';
import 'package:chorok_app/features/explore/screen/explore_screen.dart';
import 'package:chorok_app/features/home/controller/recommended_books_provider.dart';
import 'package:chorok_app/features/search/model/aladin_book.dart';

void main() {
  Widget buildSubject() {
    return ProviderScope(
      overrides: [
        popularBooksProvider.overrideWith(
          (ref) async => const [
            AladinBook(title: '안녕이라 그랬어', author: '김애란', publisher: '문학동네'),
            AladinBook(title: '바다에서 온 소년', author: '개릿 카', publisher: '북하우스'),
            AladinBook(title: '불안', author: '알랭 드 보통', publisher: '은행나무'),
          ],
        ),
        popularAuthorsProvider.overrideWith(
          (ref) async => const [
            (name: '한강', titles: ['채식주의자', '소년이 온다']),
            (name: '다자이 오사무', titles: ['인간실격', '사양']),
            (name: '앙투안 드 생텍쥐페리', titles: ['어린왕자']),
          ],
        ),
        recommendedBooksProvider.overrideWith(
          (ref) async => const [
            (
              title: '흰',
              author: '한강',
              reason: '추천',
              gradientIndex: 0,
              matchScore: 0.9,
              coverUrl: '',
            ),
          ],
        ),
        myDisplayNameProvider.overrideWith((ref) async => '준돌돔'),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: const ExploreScreen(),
      ),
    );
  }

  testWidgets('탐색 검색창에서 책, 작가, 유저 탭을 전환한다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('책'), findsOneWidget);
    expect(find.text('작가'), findsOneWidget);
    expect(find.text('유저'), findsOneWidget);
    expect(find.text('책 제목, 키워드 검색'), findsOneWidget);

    await tester.tap(find.text('작가'));
    await tester.pumpAndSettle();

    expect(find.text('작가 이름 검색'), findsOneWidget);

    await tester.tap(find.text('유저'));
    await tester.pumpAndSettle();

    expect(find.text('유저 이름 검색'), findsOneWidget);
  });

  testWidgets('검색어가 없으면 인기 책, 작가, 맞춤 추천을 표시하고 항목을 검색한다', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('지금 가장 많이 검색되는 책'), findsOneWidget);
    expect(find.text('지금 가장 많이 검색되는 작가'), findsOneWidget);
    expect(find.text('준돌돔님 맞춤 추천 책'), findsOneWidget);
    expect(find.text('안녕이라 그랬어'), findsOneWidget);
    expect(find.text('한강'), findsOneWidget);

    await tester.tap(find.text('한강'));
    await tester.pump();

    expect(find.text('작가 이름 검색'), findsOneWidget);
    expect(find.widgetWithText(TextField, '한강'), findsOneWidget);
  });

  testWidgets('일부 디스커버리 데이터가 아직 로딩 중이면 빈 상태를 표시하지 않는다', (tester) async {
    final authors = Completer<List<PopularAuthor>>();
    final recommendations = Completer<List<RecommendedBook>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          popularBooksProvider.overrideWith((ref) async => const []),
          popularAuthorsProvider.overrideWith((ref) => authors.future),
          recommendedBooksProvider.overrideWith(
            (ref) => recommendations.future,
          ),
          myDisplayNameProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('책, 작가, 유저를 검색해보세요'), findsNothing);

    authors.complete(const []);
    recommendations.complete(const []);
    await tester.pumpAndSettle();
  });
}
