import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/search/widget/barcode_scanner_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('실패 상태만 직접 입력을 허용한다', () {
    expect(const BarcodeScannerStatus.idle().allowManualEntry, isFalse);
    expect(
      const BarcodeScannerStatus.loading('ISBN 조회 중…').allowManualEntry,
      isFalse,
    );
    expect(
      const BarcodeScannerStatus.failure('책 정보를 찾을 수 없어요').allowManualEntry,
      isTrue,
    );
  });

  Widget buildSubject(
    BarcodeScannerStatus status, {
    VoidCallback? onManualEntry,
  }) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: BarcodeScannerStatusCard(
          status: status,
          onManualEntry: onManualEntry ?? () {},
        ),
      ),
    );
  }

  testWidgets('바코드 실패 카드에 직접 입력 링크가 보인다', (tester) async {
    var manualEntryCount = 0;
    await tester.pumpWidget(
      buildSubject(
        const BarcodeScannerStatus.failure('책 정보를 찾을 수 없어요'),
        onManualEntry: () => manualEntryCount++,
      ),
    );
    await tester.pump();

    expect(find.text('책 정보를 찾을 수 없어요'), findsOneWidget);
    expect(find.text('직접 입력'), findsOneWidget);
    await tester.tap(find.text('직접 입력'));
    expect(manualEntryCount, 1);
  });

  testWidgets('조회 중에는 직접 입력 링크를 숨긴다', (tester) async {
    await tester.pumpWidget(
      buildSubject(const BarcodeScannerStatus.loading('ISBN 조회 중…')),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('직접 입력'), findsNothing);
  });

  testWidgets('대기 상태에는 상태 카드를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(buildSubject(const BarcodeScannerStatus.idle()));
    await tester.pump();

    expect(find.byKey(const ValueKey('barcode-status-empty')), findsOneWidget);
    expect(find.text('직접 입력'), findsNothing);
  });
}
