import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/screen/taste_analysis_screen.dart';
import 'package:chorok_app/features/library/widget/library_stats_view.dart';

void main() {
  testWidgets('독서 취향 상세는 장르별 정확한 시간과 비율을 리스트로 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          genreReadingTimesProvider.overrideWith((ref) async {
            return const [
              (label: '철학·종교', hours: 8.4),
              (label: '인문', hours: 4.0),
              (label: '소설', hours: 3.3),
            ];
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const TasteAnalysisScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('독서 취향'), findsOneWidget);
    expect(find.text('읽은 시간 기준'), findsOneWidget);
    expect(find.text('철학·종교'), findsOneWidget);
    expect(find.text('8시간 24분'), findsOneWidget);
    expect(find.text('53.5%'), findsOneWidget);
    expect(find.text('인문'), findsOneWidget);
    expect(find.text('4시간'), findsOneWidget);
    expect(find.text('소설'), findsOneWidget);
    expect(find.text('3시간 18분'), findsOneWidget);
  });
}
