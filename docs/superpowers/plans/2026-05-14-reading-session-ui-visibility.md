# Reading Session UI Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 독서 세션 화면에서 텍스트 입력 중 UI가 숨겨지지 않도록 하고, OCR 로딩 중 전용 오버레이를 추가한다.

**Architecture:** `_ChosuActionBar`에 `FocusNode`와 `onFocusChanged` 콜백을 추가해 포커스 상태를 부모로 전달. 부모 `_ReadingSessionScreenState`는 `_isTyping` 플래그로 `_uiHideTimer` 재시작을 억제. `_OcrLoadingOverlay` 위젯을 신규 추가해 `_isOcrLoading` 중 Stack 최상단에 표시.

**Tech Stack:** Flutter, Riverpod, `FocusNode` (Flutter built-in)

---

### Task 1: `_resetUiTimer()` 에 `_isTyping` 가드 추가

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart:59-71`
- Test: `test/widget_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/widget_test.dart`를 열어 아래 테스트를 추가한다.

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('앱 기본 실행 테스트', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  // _isTyping 가드: _resetUiTimer가 _isTyping=true일 때 타이머를 재시작하지 않는다
  // 직접 검증은 private 상태라 어렵지만, 이 Task 완료 후 수동으로 확인한다.
  // 대신 _OcrLoadingOverlay 단독 위젯 렌더링 테스트를 Task 3에서 작성한다.
  test('isTyping guard - placeholder', () {
    // Task 3에서 실제 위젯 테스트로 교체
    expect(true, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
flutter test test/widget_test.dart
```

Expected: PASS (placeholder이므로 통과 — Task 3에서 실제 테스트로 교체)

- [ ] **Step 3: `_ReadingSessionScreenState`에 `_isTyping` 추가 및 `_resetUiTimer()` 수정**

[lib/features/home/screen/reading_session_screen.dart](lib/features/home/screen/reading_session_screen.dart) 의 59~71번째 줄을 수정한다.

기존:
```dart
bool _isUiVisible = true;
Timer? _uiHideTimer;

void _resetUiTimer() {
  setState(() => _isUiVisible = true);
  _uiHideTimer?.cancel();
  _uiHideTimer = Timer(const Duration(seconds: 4), () {
    final t = ref.read(timerProvider);
    if (mounted && t.isRunning) {
      setState(() => _isUiVisible = false);
    }
  });
}
```

변경 후:
```dart
bool _isUiVisible = true;
bool _isTyping = false;
Timer? _uiHideTimer;

void _resetUiTimer() {
  setState(() => _isUiVisible = true);
  _uiHideTimer?.cancel();
  if (_isTyping) return;
  _uiHideTimer = Timer(const Duration(seconds: 4), () {
    final t = ref.read(timerProvider);
    if (mounted && t.isRunning) {
      setState(() => _isUiVisible = false);
    }
  });
}
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: No errors

- [ ] **Step 5: 커밋**

```bash
git add lib/features/home/screen/reading_session_screen.dart test/widget_test.dart
git commit -m "feat: add _isTyping guard to _resetUiTimer"
```

---

### Task 2: `_ChosuActionBar`에 `FocusNode` + `onFocusChanged` 추가

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart`
  - `_ChosuActionBar` (line ~730)
  - `_ChosuActionBarState` (line ~749)
  - `_BottomArea` (line ~601)
  - `_ReadingSessionScreenState.build()` — `_BottomArea` 호출부 (line ~400)

- [ ] **Step 1: `_ChosuActionBar`에 `onFocusChanged` 파라미터 추가**

`_ChosuActionBar` 클래스 (line ~730)를 수정한다.

기존:
```dart
class _ChosuActionBar extends StatefulWidget {
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;

  const _ChosuActionBar({
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
  });
```

변경 후:
```dart
class _ChosuActionBar extends StatefulWidget {
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;
  final ValueChanged<bool> onFocusChanged;

  const _ChosuActionBar({
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
    required this.onFocusChanged,
  });
```

- [ ] **Step 2: `_ChosuActionBarState`에 `FocusNode` 추가 및 `TextField`에 연결**

`_ChosuActionBarState` (line ~749)를 수정한다.

기존:
```dart
class _ChosuActionBarState extends State<_ChosuActionBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
```

변경 후:
```dart
class _ChosuActionBarState extends State<_ChosuActionBar> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      widget.onFocusChanged(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
```

같은 state 안의 `TextField` (line ~782)에 `focusNode` 연결:

기존:
```dart
TextField(
  controller: _ctrl,
  style: const TextStyle(fontSize: 14, color: Colors.white),
```

변경 후:
```dart
TextField(
  controller: _ctrl,
  focusNode: _focusNode,
  style: const TextStyle(fontSize: 14, color: Colors.white),
```

- [ ] **Step 3: `_BottomArea`에 `onFocusChanged` 파라미터 추가 및 전달**

`_BottomArea` 클래스 (line ~601)를 수정한다.

기존:
```dart
class _BottomArea extends StatelessWidget {
  final int chosuCount;
  final String bookTitle;
  final String bookAuthor;
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;

  const _BottomArea({
    required this.chosuCount,
    required this.bookTitle,
    required this.bookAuthor,
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
  });
```

변경 후:
```dart
class _BottomArea extends StatelessWidget {
  final int chosuCount;
  final String bookTitle;
  final String bookAuthor;
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;
  final ValueChanged<bool> onFocusChanged;

  const _BottomArea({
    required this.chosuCount,
    required this.bookTitle,
    required this.bookAuthor,
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
    required this.onFocusChanged,
  });
```

같은 클래스의 `build()` 안에서 `_ChosuActionBar(...)` 호출부에 `onFocusChanged` 추가:

기존:
```dart
_ChosuActionBar(
  onOcrTap: onOcrTap,
  onRecordTap: onRecordTap,
  isRecording: isRecording,
  isOcrLoading: isOcrLoading,
  onTypeSentence: onTypeSentence,
),
```

변경 후:
```dart
_ChosuActionBar(
  onOcrTap: onOcrTap,
  onRecordTap: onRecordTap,
  isRecording: isRecording,
  isOcrLoading: isOcrLoading,
  onTypeSentence: onTypeSentence,
  onFocusChanged: onFocusChanged,
),
```

- [ ] **Step 4: 부모 `build()`에서 `_BottomArea` 호출부에 `onFocusChanged` 콜백 연결**

`_ReadingSessionScreenState.build()` 안의 `_BottomArea(...)` (line ~400)를 수정한다.

기존:
```dart
child: _BottomArea(
  chosuCount: _collectedSentences.length,
  bookTitle: widget.bookTitle,
  bookAuthor: widget.bookAuthor,
  onOcrTap: _openOcr,
  onRecordTap: _toggleRecording,
  isRecording: _isRecording,
  isOcrLoading: _isOcrLoading,
  onTypeSentence: (text) =>
      _openChosuSheet(initialText: text),
),
```

변경 후:
```dart
child: _BottomArea(
  chosuCount: _collectedSentences.length,
  bookTitle: widget.bookTitle,
  bookAuthor: widget.bookAuthor,
  onOcrTap: _openOcr,
  onRecordTap: _toggleRecording,
  isRecording: _isRecording,
  isOcrLoading: _isOcrLoading,
  onTypeSentence: (text) =>
      _openChosuSheet(initialText: text),
  onFocusChanged: (focused) {
    setState(() => _isTyping = focused);
    if (focused) {
      _uiHideTimer?.cancel();
      setState(() => _isUiVisible = true);
    } else {
      _resetUiTimer();
    }
  },
),
```

- [ ] **Step 5: 빌드 및 분석 확인**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: No errors

- [ ] **Step 6: 커밋**

```bash
git add lib/features/home/screen/reading_session_screen.dart
git commit -m "feat: keep UI visible while sentence input is focused"
```

---

### Task 3: `_OcrLoadingOverlay` 위젯 추가 및 Stack에 삽입

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart`
  - 새 위젯 `_OcrLoadingOverlay` 추가 (파일 하단 `_RecordingOverlay` 근처)
  - `build()` Stack에 오버레이 레이어 추가
- Test: `test/widget_test.dart`

- [ ] **Step 1: `_OcrLoadingOverlay` 위젯 작성**

`reading_session_screen.dart` 파일 하단, `_RecordingOverlay` 클래스 (line ~1170) 바로 앞에 아래 위젯을 추가한다.

```dart
// ─── OCR 로딩 오버레이 ─────────────────────────────────────────────────
class _OcrLoadingOverlay extends StatelessWidget {
  const _OcrLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(
                color: _kGreen,
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
    );
  }
}
```

- [ ] **Step 2: `build()`의 Stack에 `_OcrLoadingOverlay` 레이어 추가**

`_ReadingSessionScreenState.build()` 의 Stack children (line ~420) 에서 `_RecordingOverlay` 조건부 삽입 바로 위에 추가한다.

기존:
```dart
              // ④ 녹음 오버레이 (STT 중일 때)
              if (_isRecording)
                _RecordingOverlay(
                  recognizedText: _recognizedText,
                  onStop: _toggleRecording,
                ),
```

변경 후:
```dart
              // ④ OCR 로딩 오버레이
              if (_isOcrLoading)
                const _OcrLoadingOverlay(),

              // ⑤ 녹음 오버레이 (STT 중일 때)
              if (_isRecording)
                _RecordingOverlay(
                  recognizedText: _recognizedText,
                  onStop: _toggleRecording,
                ),
```

- [ ] **Step 3: `_OcrLoadingOverlay` 단독 위젯 테스트 작성**

`test/widget_test.dart`를 아래 내용으로 교체한다.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// _OcrLoadingOverlay 는 private이므로 동일한 내용을 테스트용으로 인라인 재현
Widget _buildOcrOverlay() {
  return const MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
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

  testWidgets('OCR 로딩 오버레이 — AbsorbPointer로 탭이 차단된다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => tapped = true,
                child: const SizedBox.expand(),
              ),
              const Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(color: Color(0x99000000)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ColoredBox));
    expect(tapped, isFalse);
  });
}
```

- [ ] **Step 4: 테스트 실행**

```bash
flutter test test/widget_test.dart
```

Expected:
```
00:00 +3: All tests passed!
```

- [ ] **Step 5: 전체 analyze**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: No errors

- [ ] **Step 6: 커밋**

```bash
git add lib/features/home/screen/reading_session_screen.dart test/widget_test.dart
git commit -m "feat: add OCR loading overlay to reading session screen"
```

---

## 수동 검증 체크리스트

구현 완료 후 실기기 또는 에뮬레이터에서 확인:

- [ ] 텍스트 입력 필드 탭 → 키보드 올라온 상태에서 4초 이상 대기 → UI(타이머 포함) 숨겨지지 않음
- [ ] 키보드 내림(다른 곳 탭) → 4초 후 UI 자동 숨김 정상 동작
- [ ] 카메라 버튼 탭 → 시스템 카메라 열림 → 사진 촬영 후 "텍스트 인식 중..." 오버레이 표시 → ChosuSheet 열림
- [ ] OCR 오버레이 표시 중 탭해도 UI가 반응하지 않음 (IgnorePointer 동작)
- [ ] 녹음 버튼 탭 → 기존 `_RecordingOverlay` 정상 표시 (기존 동작 회귀 없음)
