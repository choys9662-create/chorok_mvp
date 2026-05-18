# 독서 세션 입력 기능 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 독서 세션 중 타이핑·사진(OCR)·녹음(STT) 세 가지 입력 방식이 정상 동작하도록 완성하고, 각 입력 시 타이머를 자동으로 일시정지/재개한다.

**Architecture:** `reading_session_screen.dart`의 세 메서드(`_openChosuSheet`, `_openOcr`, `_toggleRecording`)에 pause/resume 호출을 추가한다. `ChosuSheet`에 `bookTitle` 파라미터를 추가해 하드코딩된 책 제목을 제거한다. 신규 파일 없음.

**Tech Stack:** Flutter, Riverpod, speech_to_text, image_picker, Google Cloud Vision API

---

### Task 1: ChosuSheet에 bookTitle 파라미터 추가

**Files:**
- Modify: `lib/features/home/widget/chosu_sheet.dart:8-15` (생성자)
- Modify: `lib/features/home/widget/chosu_sheet.dart:95` (하드코딩 제거)

- [ ] **Step 1: `ChosuSheet`에 `bookTitle` 파라미터 추가**

`lib/features/home/widget/chosu_sheet.dart`의 `ChosuSheet` 클래스 수정:

```dart
class ChosuSheet extends StatefulWidget {
  final String initialText;
  final String bookTitle;  // 추가

  const ChosuSheet({super.key, this.initialText = '', this.bookTitle = ''});  // 수정
```

- [ ] **Step 2: 헤더의 하드코딩된 책 정보 교체**

같은 파일 헤더 Row의 Text 위젯 수정 (현재 `'채식주의자 · 186쪽'`):

```dart
if (widget.bookTitle.isNotEmpty)
  Text(
    widget.bookTitle,
    style: AppTheme.captionSmall.copyWith(
      color: context.appTextTertiary,
    ),
  ),
```

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/features/home/widget/chosu_sheet.dart
```

Expected: 에러 없음

---

### Task 2: `_openChosuSheet` — pause 추가 및 bookTitle 전달

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart:226-240`

- [ ] **Step 1: `_openChosuSheet` 수정**

`// ignore: unused_element` 주석 제거, pause 추가, bookTitle 전달:

```dart
Future<void> _openChosuSheet({String initialText = ''}) async {
  ref.read(timerProvider.notifier).pause();
  final result = await showModalBottomSheet<CollectedSentence>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChosuSheet(
      initialText: initialText,
      bookTitle: widget.bookTitle,
    ),
  );
  if (!mounted) return;
  if (result != null && result.content.isNotEmpty) {
    setState(() => _collectedSentences.add(result));
  }
  ref.read(timerProvider.notifier).resume();
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: 에러 없음

---

### Task 3: `_openOcr` — pause/resume 완성

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart:92-100`

- [ ] **Step 1: `_openOcr` 수정**

카메라 열기 전 pause, 취소/실패 시 resume:

```dart
Future<void> _openOcr() async {
  ref.read(timerProvider.notifier).pause();
  setState(() => _isOcrLoading = true);
  final text = await ref.read(ocrServiceProvider).extractTextFromCamera();
  if (!mounted) return;
  setState(() => _isOcrLoading = false);
  if (text == null || text.isEmpty) {
    ref.read(timerProvider.notifier).resume();
    return;
  }
  _openChosuSheet(initialText: text);
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: 에러 없음

---

### Task 4: `_toggleRecording` — pause/resume 완성

**Files:**
- Modify: `lib/features/home/screen/reading_session_screen.dart:102-138`

- [ ] **Step 1: `_toggleRecording` 수정**

녹음 시작 시 pause, 텍스트 없이 종료 시 resume:

```dart
Future<void> _toggleRecording() async {
  final stt = ref.read(sttServiceProvider);
  if (_isRecording) {
    await stt.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (_recognizedText.isEmpty) {
      ref.read(timerProvider.notifier).resume();
      return;
    }
    final text = _recognizedText;
    _recognizedText = '';
    _openChosuSheet(initialText: text);
  } else {
    final initialized = await stt.initialize();
    if (!initialized && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '마이크를 사용할 수 없습니다.',
            style: TextStyle(fontFamily: 'Pretendard'),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    ref.read(timerProvider.notifier).pause();
    setState(() {
      _isRecording = true;
      _recognizedText = '';
    });
    await stt.listen(
      listenFor: const Duration(seconds: 30),
      onResult: (text) {
        if (mounted) setState(() => _recognizedText = text);
      },
    );
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/home/screen/reading_session_screen.dart
```

Expected: 에러 없음

---

### Task 5: 최종 빌드 및 수동 검증

- [ ] **Step 1: 전체 분석**

```bash
flutter analyze lib/
```

Expected: 에러 없음

- [ ] **Step 2: 수동 검증 체크리스트**

앱을 실행해 다음을 순서대로 확인:

1. **타이핑**: 하단 텍스트 필드에 문장 입력 → 전송 → 초서 시트 열릴 때 타이머 멈춤 확인 → 저장 후 타이머 재개 확인 → 초서 시트 헤더에 실제 책 제목 표시 확인
2. **사진**: 카메라 버튼 탭 → 타이머 멈춤 확인 → 카메라 취소 시 타이머 재개 확인 → 사진 촬영 후 초서 시트 열림 확인 → 저장 후 재개 확인
3. **녹음**: 마이크 버튼 탭 → 타이머 멈춤 확인 → 녹음 오버레이 표시 확인 → 탭으로 중지 → 인식 텍스트 있으면 초서 시트 열림 → 저장 후 재개 확인
4. **내 생각**: 초서 시트에서 "수집할 문장"과 "내 생각" 모두 입력 후 저장 확인

- [ ] **Step 3: 커밋**

```bash
git add lib/features/home/widget/chosu_sheet.dart lib/features/home/screen/reading_session_screen.dart
git commit -m "feat: 세션 입력 기능 완성 — 타이핑/사진/녹음 시 타이머 pause/resume"
```
