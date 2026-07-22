import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/screen/taste_analysis_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  List<Book> build() => const [
    Book(
      id: 'novel',
      title: '문학 책',
      author: '작가 A',
      genre: '소설',
      totalReadingHours: 8.4,
      status: ReadingStatus.reading,
    ),
    Book(
      id: 'philosophy',
      title: '인문 책',
      author: '작가 B',
      genre: '철학',
      totalReadingHours: 4.0,
      status: ReadingStatus.reading,
    ),
    Book(
      id: 'history',
      title: '역사 책',
      author: '작가 C',
      genre: '한국사',
      totalReadingHours: 3.3,
      status: ReadingStatus.reading,
    ),
  ];
}

void main() {
  test('독서 취향 상세는 reading_sessions를 책별로 합산한다', () {
    final rows = tasteSessionRowsForTest([
      {
        'book_id': 'vegetarian',
        'duration_seconds': 3600,
        'books': {
          'title': '채식주의자',
          'author': '한강',
          'genre': null,
          'global_books': {'category': '국내도서>소설/시/희곡>한국소설'},
        },
      },
      {
        'book_id': 'vegetarian',
        'duration_seconds': 1800,
        'books': {
          'title': '채식주의자',
          'author': '한강',
          'genre': null,
          'global_books': {'category': '국내도서>소설/시/희곡>한국소설'},
        },
      },
      {
        'book_id': 'philosophy',
        'duration_seconds': 1200,
        'books': {'title': '몸과 삶의 철학자 메를로퐁티', 'author': '심귀연', 'genre': '철학'},
      },
    ]);

    expect(rows.first.genre, '문학');
    expect(rows.first.title, '채식주의자');
    expect(rows.first.minutes, 90);
    expect(rows.last.genre, '인문');
    expect(rows.last.minutes, 20);
  });

  testWidgets('독서 취향 상세는 장르별 정확한 시간을 순위 리스트로 표시한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [libraryProvider.overrideWith(_FakeLibraryNotifier.new)],
        child: MaterialApp(
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const TasteAnalysisScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('나의 독서 취향'), findsOneWidget);
    expect(find.text('읽은 시간 기준'), findsOneWidget);

    // 히어로 카드 — 최다 독서 장르
    expect(find.text('문학 책벌레'), findsOneWidget);

    // 장르 순위 섹션 — 읽은 시간 내림차순 (시간은 섹션 합계 + 책 행에 중복 표시)
    expect(find.text('1 | 문학'), findsOneWidget);
    expect(find.text('8시간 24분'), findsNWidgets(2));
    expect(find.text('2 | 인문'), findsOneWidget);
    expect(find.text('4시간'), findsNWidgets(2));

    // 3위 섹션은 뷰포트 밖 — 스크롤해서 확인
    await tester.scrollUntilVisible(find.text('3 | 역사'), 300);
    expect(find.text('3 | 역사'), findsOneWidget);
    expect(find.text('3시간 18분'), findsNWidgets(2));
  });
}
