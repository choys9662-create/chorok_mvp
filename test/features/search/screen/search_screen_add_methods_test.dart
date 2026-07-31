import 'package:chorok_app/core/constants/app_constants.dart';
import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/search/controller/book_search_controller.dart';
import 'package:chorok_app/features/search/model/aladin_book.dart';
import 'package:chorok_app/features/search/screen/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeBookSearchNotifier extends BookSearchNotifier {
  @override
  Future<List<AladinBook>> build() async => const [];

  @override
  Future<void> search(String query, {BookSearchType? type}) async {
    state = const AsyncValue.loading();
    state = query.trim() == '오류'
        ? AsyncValue.error(Exception('검색 실패'), StackTrace.empty)
        : AsyncValue.data(<AladinBook>[]);
  }
}

void main() {
  late GoRouter router;

  Widget buildSubject() {
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
        GoRoute(
          path: AppConstants.routeBarcode,
          builder: (_, _) => const Scaffold(body: Text('barcode-route')),
        ),
        GoRoute(
          path: AppConstants.routeManualBookEntry,
          builder: (_, _) => const Scaffold(body: Text('manual-route')),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [bookSearchProvider.overrideWith(_FakeBookSearchNotifier.new)],
      child: MaterialApp.router(theme: AppTheme.dark, routerConfig: router),
    );
  }

  Finder searchField() => find.byType(TextField);

  Future<void> enterQuery(WidgetTester tester, String query) async {
    await tester.enterText(searchField(), query);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
  }

  testWidgets('초기 화면은 검색과 바코드를 보이고 직접 입력은 숨긴다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(searchField(), findsOneWidget);
    final input = tester.widget<TextField>(searchField());
    expect(input.decoration?.hintText, '제목, 저자, 키워드 검색');
    expect(find.bySemanticsLabel('ISBN 바코드 스캔'), findsOneWidget);
    expect(find.text('직접 입력'), findsNothing);

    final scannerIcon = tester.widget<Icon>(
      find.byIcon(Icons.qr_code_scanner_rounded),
    );
    expect(scannerIcon.color, AppTheme.accent);
  });

  testWidgets('검색 결과가 없을 때 직접 입력으로 이동한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await enterQuery(tester, '없는 책');

    expect(find.text('직접 입력'), findsOneWidget);
    await tester.tap(find.text('직접 입력'));
    await tester.pumpAndSettle();

    expect(find.text('manual-route'), findsOneWidget);
  });

  testWidgets('검색 오류에서도 재시도와 직접 입력을 함께 제공한다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await enterQuery(tester, '오류');

    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.text('직접 입력'), findsOneWidget);
  });

  testWidgets('바코드는 검색 중에도 바로 열 수 있다', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await enterQuery(tester, '채식주의자');

    await tester.tap(find.bySemanticsLabel('ISBN 바코드 스캔'));
    await tester.pumpAndSettle();

    expect(find.text('barcode-route'), findsOneWidget);
  });
}
