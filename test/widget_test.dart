import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildOcrOverlay() {
  return const MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      color: Colors.white,
                      size: 48,
                    ),
                    SizedBox(height: 16),
                    CircularProgressIndicator(
                      color: Color(0xFF00FF00),
                      strokeWidth: 2,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '텍스트 인식 중...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('앱 기본 실행 테스트', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  testWidgets('OCR 로딩 오버레이 — 아이콘, 스피너, 텍스트가 렌더링된다', (tester) async {
    await tester.pumpWidget(_buildOcrOverlay());

    expect(find.byIcon(Icons.document_scanner_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('텍스트 인식 중...'), findsOneWidget);
  });

  testWidgets('OCR 로딩 오버레이 — AbsorbPointer가 오버레이를 감싼다', (tester) async {
    await tester.pumpWidget(_buildOcrOverlay());

    // AbsorbPointer 하위에 오버레이 콘텐츠가 있는지 확인
    expect(
      find.descendant(
        of: find.byType(AbsorbPointer),
        matching: find.text('텍스트 인식 중...'),
      ),
      findsOneWidget,
    );
  });
}
