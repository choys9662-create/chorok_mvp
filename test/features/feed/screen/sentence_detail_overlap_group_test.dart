import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chorok_app/core/constants/app_constants.dart';
import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/feed/screen/sentence_detail_screen.dart';
import 'package:chorok_app/features/search/model/aladin_book.dart';
import 'package:chorok_app/shared/models/overlap_group.dart';

class _FakeDbService extends DbService {
  @override
  Future<List<Map<String, dynamic>>> fetchBookSentenceCandidates({
    String? globalBookId,
    String? bookId,
  }) async {
    Map<String, dynamic> row(
      String id,
      String userId,
      String name,
      String content,
      String? thought,
    ) => {
      'id': id,
      'user_id': userId,
      'content': content,
      'thought': thought,
      'created_at': DateTime(2026, 6, 22).toIso8601String(),
      'profiles': {
        'id': userId,
        'username': name,
        'display_name': name,
        'avatar_url': null,
      },
      'books': {'title': '디자인의 문장'},
      'global_books': null,
    };

    return [
      row(
        'u1-no-thought',
        'user-1',
        '유저 1',
        '나는 디자이너다. 나는 산업디자이너다. 나는 시각디자이너다.',
        null,
      ),
      row(
        'u1-thought',
        'user-1',
        '유저 1',
        '나는 산업디자이너다. 나는 시각디자이너다.',
        '디자인의 경계가 이어져 보였어요.',
      ),
      row(
        'u2-thought',
        'user-2',
        '유저 2',
        '나는 산업디자이너다. 나는 시각디자이너다. 나는 기획자다.',
        '직함보다 역할의 연결이 중요하다고 생각해요.',
      ),
      row(
        'u3-thought',
        'user-3',
        '유저 3',
        '나는 산업디자이너다. 나는 시각디자이너다.',
        '저는 전문성이 겹치는 장면으로 읽었어요.',
      ),
      row(
        'unrelated',
        'user-4',
        '유저 4',
        '전혀 관계없는 다른 문장입니다.',
        '이 생각은 표시되면 안 됩니다.',
      ),
    ];
  }
}

void main() {
  testWidgets('문장 상세 상단 책 정보를 누르면 책 상세로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SentenceDetailScreen(
            data: SentenceDetailExtra(
              sentenceContent: '문장',
              bookTitle: '디자인의 문장',
              bookAuthor: '저자',
              bookId: 'book-1',
            ),
          ),
        ),
        GoRoute(
          path: AppConstants.routeBookInfo,
          builder: (context, state) {
            final book = state.extra as AladinBook;
            return Text('book:${book.title}/${book.author}');
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('디자인의 문장'));
    await tester.pumpAndSettle();

    expect(find.text('book:디자인의 문장/저자'), findsOneWidget);
  });

  testWidgets('겹문장 상세에 같은 책의 여러 기록자가 남긴 생각을 함께 표시한다', (tester) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const merged = '나는 디자이너다. 나는 산업디자이너다. 나는 시각디자이너다. 나는 기획자다.';
    const common = '나는 산업디자이너다. 나는 시각디자이너다.';
    final start = merged.indexOf(common);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [dbServiceProvider.overrideWithValue(_FakeDbService())],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: SentenceDetailScreen(
            data: SentenceDetailExtra(
              sentenceContent: merged,
              bookTitle: '디자인의 문장',
              bookAuthor: '저자',
              overlapCommonPhrase: common,
              overlapHighlight: HighlightRange(start, start + common.length),
              bookId: 'book-1',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('3명'),
      ),
      findsOneWidget,
    );
    expect(find.text('디자인의 경계가 이어져 보였어요.'), findsOneWidget);
    expect(find.text('직함보다 역할의 연결이 중요하다고 생각해요.'), findsOneWidget);

    expect(find.text('저는 전문성이 겹치는 장면으로 읽었어요.'), findsWidgets);
    expect(find.text('이 생각은 표시되면 안 됩니다.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('recorded-thought-card-유저 2')));
    await tester.pumpAndSettle();

    expect(find.text('유저 2님이 기록한 문장'), findsOneWidget);
    expect(
      find.textContaining('나는 산업디자이너다. 나는 시각디자이너다. 나는 기획자다.'),
      findsWidgets,
    );
    expect(find.text('유저 2님의 생각'), findsOneWidget);
    expect(find.text('직함보다 역할의 연결이 중요하다고 생각해요.'), findsWidgets);
  });
}
