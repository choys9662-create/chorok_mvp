import 'package:chorok_app/core/constants/app_constants.dart';
import 'package:chorok_app/features/search/util/barcode_add_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('바코드로 책을 추가하면 홈으로 이동한다', (tester) async {
    final router = GoRouter(
      initialLocation: AppConstants.routeBarcode,
      routes: [
        GoRoute(
          path: AppConstants.routeBarcode,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => navigateHomeAfterBarcodeAdd(context),
              child: const Text('추가 완료'),
            ),
          ),
        ),
        GoRoute(
          path: AppConstants.routeHome,
          builder: (_, _) => const Scaffold(body: Text('홈 화면')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('추가 완료'));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.path,
      AppConstants.routeHome,
    );
  });
}
