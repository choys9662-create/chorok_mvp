import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/controller/book_detail_social_provider.dart';
import 'package:chorok_app/features/library/screen/book_detail_screen.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> _books;

  _FakeLibraryNotifier(this._books);

  @override
  List<Book> build() => _books;
}

void main() {
  testWidgets('책 상세 화면 하단에 이어 읽기 버튼이 고정 렌더링된다', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = Book(
      id: 'book-1',
      title: '채식주의자 (리마스터판)',
      author: '한강',
      status: ReadingStatus.reading,
      currentPage: 196,
      totalPages: 276,
      savedSentences: ['나는 채식주의자가 되기로 했다.'],
      description: '알라딘에서 가져온 책 소개가 서재 상세에 표시됩니다.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier([book])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const BookDetailScreen(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이어 읽기'), findsOneWidget);
    expect(find.bySemanticsLabel('문장 추가'), findsOneWidget);
    expect(find.text('채식주의자 (리마스터판)'), findsOneWidget);
    expect(find.text('한강 | 창비 | 2022'), findsOneWidget);

    final buttonTop = tester.getTopLeft(find.text('이어 읽기')).dy;
    expect(buttonTop, greaterThan(790));
  });

  testWidgets('책 상세 화면이 소셜 섹션을 책 소개와 함께 렌더링한다', (tester) async {
    tester.view.physicalSize = const Size(402, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = Book(
      id: 'book-1',
      title: '채식주의자 (리마스터판)',
      author: '한강',
      isbn: '9788936434595',
      status: ReadingStatus.reading,
      currentPage: 196,
      totalPages: 276,
      savedSentences: ['나는 채식주의자가 되기로 했다.'],
      description: '채식을 선언한 인물을 둘러싼 가족과 사회의 균열을 따라가는 소설입니다.',
    );

    final socialData = BookDetailSocialData(
      meta: const BookDetailSocialMeta(
        globalBookId: 'global-1',
        readerCount: 3,
        sentenceCount: 2,
      ),
      popularThoughts: [
        BookSocialThought(
          sentenceId: 'sentence-1',
          userId: 'user-1',
          displayName: '유나',
          username: 'yuna',
          avatarUrl: null,
          sentence: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
          thought: '특별하지 않다고 말하는 시선이 가장 잔인하게 느껴졌다.',
          pageNumber: 9,
          likeCount: 42,
          commentCount: 5,
          createdAt: DateTime(2026, 1, 1),
          isFollowing: true,
          sourceType: BookSocialThoughtSource.sentence,
        ),
      ],
      followingThoughts: [
        BookSocialThought(
          sentenceId: 'sentence-2',
          userId: 'user-2',
          displayName: '온도',
          username: 'ondo',
          avatarUrl: null,
          sentence: '산다는 것은 이상한 일이라고, 그 웃음의 끝에 그녀는 생각한다.',
          thought: '완독보다 멈춤이 더 많았던 책.',
          pageNumber: 202,
          likeCount: 12,
          commentCount: 1,
          createdAt: DateTime(2026, 1, 2),
          isFollowing: true,
          sourceType: BookSocialThoughtSource.sentence,
        ),
      ],
      recentSentenceThoughts: [],
      reviews: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(() => _FakeLibraryNotifier([book])),
          bookDetailSocialProvider.overrideWith((ref, query) async {
            return socialData;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const BookDetailScreen(bookId: 'book-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('내가 수집한 문장'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(
      find.text('채식을 선언한 인물을 둘러싼 가족과 사회의 균열을 따라가는 소설입니다.'),
      findsOneWidget,
    );
    expect(find.text('이웃의 문장'), findsOneWidget);
    expect(find.text('지금 많이 멈춘 생각'), findsOneWidget);
    expect(find.text('유나'), findsOneWidget);
  });
}
