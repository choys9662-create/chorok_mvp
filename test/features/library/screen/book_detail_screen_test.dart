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

    final popularThought = BookSocialThought(
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
    );
    final followingThought = BookSocialThought(
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
    );
    final neighboringThought = BookSocialThought(
      sentenceId: 'sentence-3',
      userId: 'user-3',
      displayName: '준석',
      username: 'junseok',
      avatarUrl: null,
      sentence: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다. 그저 평범하다고 여겼다.',
      thought: '평범하다는 말이 누군가를 지우는 방식처럼 느껴졌다.',
      pageNumber: 9,
      likeCount: 18,
      commentCount: 2,
      createdAt: DateTime(2026, 1, 3),
      isFollowing: false,
      sourceType: BookSocialThoughtSource.sentence,
    );

    final socialData = BookDetailSocialData(
      meta: const BookDetailSocialMeta(
        globalBookId: 'global-1',
        readerCount: 3,
        sentenceCount: 2,
      ),
      discussedPassages: [
        BookDiscussedPassage(
          id: 'passage-1',
          representativeText: popularThought.sentence,
          pageNumber: 9,
          thoughtCount: 2,
          readerCount: 2,
          previewThoughts: [popularThought, neighboringThought],
          members: [popularThought, neighboringThought],
          recentActivityAt: DateTime(2026, 1, 3),
        ),
      ],
      popularThoughts: [popularThought],
      followingThoughts: [followingThought],
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
    expect(find.text('사람들이 멈춘 문장'), findsOneWidget);
    expect(find.text('2명이 이 부분에 생각을 남겼어요'), findsOneWidget);
    expect(find.text('지금 많이 멈춘 생각'), findsOneWidget);
    expect(find.text('유나'), findsOneWidget);

    final passageCard = find.byKey(
      const ValueKey('discussed-passage-card-passage-1'),
    );
    await tester.ensureVisible(passageCard);
    await tester.tap(passageCard);
    await tester.pumpAndSettle();

    expect(find.text('이 대목에 남겨진 생각'), findsOneWidget);
    expect(find.text('2명의 독자가 이 부분에 머물렀어요'), findsOneWidget);
    expect(find.text(neighboringThought.sentence), findsOneWidget);
    expect(find.text(neighboringThought.thought), findsWidgets);
  });

  testWidgets('사람들이 멈춘 문장 카드와 시트는 좁은 화면의 긴 문장을 안전하게 표시한다', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const book = Book(
      id: 'book-narrow',
      title: '좁은 화면 테스트',
      author: '초록',
      isbn: '9780000000001',
      status: ReadingStatus.reading,
      currentPage: 10,
      totalPages: 200,
      savedSentences: [],
    );
    final thoughts = List.generate(
      4,
      (index) => BookSocialThought(
        sentenceId: 'long-sentence-$index',
        userId: 'long-reader-$index',
        displayName: '긴 이름의 독자 ${index + 1}',
        username: 'long_reader_${index + 1}',
        avatarUrl: null,
        sentence:
            '아주 긴 문장을 기록한 독자가 좁은 화면에서도 자신이 읽은 대목 전체와 그 문장에 대한 생각을 빠짐없이 확인할 수 있어야 한다.',
        thought: '이 생각 역시 여러 줄로 길게 이어지지만 카드에서는 절제해서 보이고 상세 시트에서는 자연스럽게 읽혀야 한다.',
        pageNumber: 32,
        likeCount: 4 - index,
        commentCount: 0,
        createdAt: DateTime(2026, 1, index + 1),
        isFollowing: false,
        sourceType: BookSocialThoughtSource.sentence,
      ),
    );
    final socialData = BookDetailSocialData(
      meta: const BookDetailSocialMeta(
        globalBookId: 'global-narrow',
        readerCount: 4,
        sentenceCount: 4,
      ),
      discussedPassages: [
        BookDiscussedPassage(
          id: 'narrow-passage',
          representativeText: thoughts.first.sentence,
          pageNumber: 32,
          thoughtCount: thoughts.length,
          readerCount: thoughts.length,
          previewThoughts: thoughts.take(2).toList(),
          members: thoughts,
          recentActivityAt: DateTime(2026, 1, 4),
        ),
      ],
      popularThoughts: const [],
      followingThoughts: const [],
      recentSentenceThoughts: const [],
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
          home: const BookDetailScreen(bookId: 'book-narrow'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final passageCard = find.byKey(
      const ValueKey('discussed-passage-card-narrow-passage'),
    );
    await tester.scrollUntilVisible(
      passageCard,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(passageCard);
    await tester.pumpAndSettle();

    expect(find.text('이 대목에 남겨진 생각'), findsOneWidget);
    expect(find.text('4명의 독자가 이 부분에 머물렀어요'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('긴 이름의 독자 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
