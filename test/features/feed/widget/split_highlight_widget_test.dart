import 'package:chorok_app/features/feed/controller/overlap_provider.dart';
import 'package:chorok_app/features/feed/widget/split_highlight_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(List<OverlapMatch> matches) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SplitHighlightWidget(
          anchorText: 'B. C.',
          collectorUsername: '준석',
          collectorThought: '준석의 생각',
          matches: matches,
        ),
      ),
    ),
  );
}

OverlapMatch _match(int index, String content) {
  return OverlapMatch(
    sentenceId: '$index',
    content: content,
    thought: '$index번째 생각',
    username: '독자$index',
    createdAt: DateTime(2026, 6, 23),
  );
}

void main() {
  testWidgets('카드에는 생각만 보이고 탭하면 실제 기록 문장을 보여준다', (tester) async {
    await tester.pumpWidget(_subject([_match(1, 'A. B. C. D.')]));

    expect(find.text('1번째 생각'), findsOneWidget);
    expect(find.text('A. B. C. D.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('overlap-thought-card-독자1')));
    await tester.pumpAndSettle();

    expect(find.text('독자1님이 기록한 문장'), findsOneWidget);
    expect(find.textContaining('A. B. C. D.'), findsOneWidget);
    expect(find.text('독자1님의 생각'), findsOneWidget);
  });

  testWidgets('처음 세 개만 보여주고 더 보기로 나머지를 펼친다', (tester) async {
    await tester.pumpWidget(
      _subject([
        _match(1, 'B. C.'),
        _match(2, 'B. C. D.'),
        _match(3, 'A. B. C.'),
      ]),
    );

    // 수집자 카드 1개 + 다른 독자 카드 2개까지 기본 노출.
    expect(find.text('1번째 생각'), findsOneWidget);
    expect(find.text('2번째 생각'), findsOneWidget);
    expect(find.text('3번째 생각'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('overlap-thoughts-show-more')));
    await tester.pump();

    expect(find.text('3번째 생각'), findsOneWidget);
  });
}
