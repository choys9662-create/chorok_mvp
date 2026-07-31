# Manual Book Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep book search primary, keep ISBN scanning permanently visible as the stronger secondary path, and add title/author/page manual entry only after search or barcode lookup failure.

**Architecture:** Add one focused manual-entry screen that creates the existing `Book` model through `libraryProvider`. Reuse the current reading-status sheet through a title-only helper, expose manual entry from search failure states and a small testable barcode failure-status widget, and use GoRouter results to report successful additions back to each caller.

**Tech Stack:** Flutter 3.41.9, Dart, Riverpod manual providers, GoRouter, existing `AppTheme` and shared widgets, flutter_test.

## Global Constraints

- Search remains the default route from every existing `책 추가` entry point.
- The 48pt barcode action stays beside the search field and uses the brand accent so it is more visible than manual entry.
- Manual entry is absent from the initial search state and appears only after search no-result/error or barcode lookup no-result/error.
- Manual bibliographic fields are exactly title, author, and total page count.
- Title and author are trimmed and required; total pages is an integer greater than zero.
- No database migration or new dependency is allowed.
- Use `AppTheme` tokens and existing shared widgets; do not add hex colors, font-size literals, radius literals, or spacing literals.
- Preserve all unrelated dirty-worktree changes and stage only files named by the current task.

---

### Task 1: Manual-entry screen, validation, and save flow

**Files:**
- Create: `lib/features/search/screen/manual_book_entry_screen.dart`
- Create: `test/features/search/screen/manual_book_entry_screen_test.dart`
- Modify: `lib/features/search/widget/add_to_library_sheet.dart`
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/shared/providers/library_provider.dart`

**Interfaces:**
- Consumes: `libraryProvider`, `Book`, `ReadingStatus`, `ChorokCard`, `ChorokBackButton`, and the existing status tiles.
- Produces: `Future<ReadingStatus?> showReadingStatusSheet(BuildContext context, String title)`, `ManualBookEntryScreen`, and `AppConstants.routeManualBookEntry`.
- Route result: a successfully added `Book`; `null` means cancel or no addition.

- [ ] **Step 1: Write failing widget tests for field scope and validation**

Add a fake notifier that preserves real in-memory add/duplicate behavior while avoiding Supabase:

```dart
class _FakeLibraryNotifier extends LibraryNotifier {
  final List<Book> initial;
  _FakeLibraryNotifier([this.initial = const []]);

  @override
  List<Book> build() => List.of(initial);

  @override
  bool addBook(Book book) {
    if (containsByTitleAuthor(book.title, book.author)) return false;
    state = [...state, book];
    return true;
  }
}
```

Test these observable behaviors:

```dart
testWidgets('직접 입력은 제목 작가 페이지 수만 받는다', (tester) async {
  await tester.pumpWidget(buildSubject());

  expect(find.widgetWithText(TextField, '제목'), findsOneWidget);
  expect(find.widgetWithText(TextField, '작가'), findsOneWidget);
  expect(find.widgetWithText(TextField, '페이지 수'), findsOneWidget);
  expect(find.byType(TextField), findsNWidgets(3));
});

testWidgets('빈 값과 0 페이지로는 책을 추가하지 않는다', (tester) async {
  await tester.pumpWidget(buildSubject());

  expect(tester.widget<GestureDetector>(
    find.ancestor(
      of: find.text('서재에 추가'),
      matching: find.byType(GestureDetector),
    ).first,
  ).onTap, isNull);

  await tester.enterText(find.widgetWithText(TextField, '제목'), '채식주의자');
  await tester.enterText(find.widgetWithText(TextField, '작가'), '한강');
  await tester.enterText(find.widgetWithText(TextField, '페이지 수'), '0');
  await tester.pump();

  expect(find.text('1쪽 이상 입력해 주세요'), findsOneWidget);
});
```

The production change caught by these tests is adding an extra bibliographic field or accepting missing/non-positive data.

- [ ] **Step 2: Run the new test and verify RED**

Run:

```bash
flutter test test/features/search/screen/manual_book_entry_screen_test.dart
```

Expected: compilation fails because `ManualBookEntryScreen` does not exist.

- [ ] **Step 3: Add a title-only status-sheet entry point**

Refactor `add_to_library_sheet.dart` without changing existing callers:

```dart
Future<ReadingStatus?> showReadingStatusSheet(
  BuildContext context,
  String title,
) {
  return showModalBottomSheet<ReadingStatus>(
    context: context,
    backgroundColor: context.appBg.withValues(alpha: 0),
    isScrollControlled: true,
    builder: (_) => _AddToLibrarySheet(title: title),
  );
}

Future<ReadingStatus?> showAddToLibrarySheet(
  BuildContext context,
  AladinBook book,
) => showReadingStatusSheet(context, book.title);
```

Change `_AddToLibrarySheet` to store `String title` and render `title`. Do not alter status labels or status tile behavior.

- [ ] **Step 4: Implement the minimal manual-entry screen and route**

Add:

```dart
static const String routeManualBookEntry = '/manual-book-entry';
```

Register:

```dart
GoRoute(
  path: AppConstants.routeManualBookEntry,
  builder: (context, state) => const ManualBookEntryScreen(),
),
```

The screen owns three controllers, trims title/author, parses pages with `int.tryParse`, and computes:

```dart
bool get _canSubmit =>
    _titleController.text.trim().isNotEmpty &&
    _authorController.text.trim().isNotEmpty &&
    (_pages ?? 0) > 0;
```

On submit:

```dart
final status = await showReadingStatusSheet(context, title);
if (status == null || !mounted) return;

final notifier = ref.read(libraryProvider.notifier);
if (notifier.containsByTitleAuthor(title, author)) {
  ScaffoldMessenger.of(context).showSnackBar(
    chorokSnackBar(context, '이미 서재에 있는 책이에요', success: false),
  );
  return;
}

final book = Book(
  id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
  title: title,
  author: author,
  totalPages: pages,
  status: status,
);
if (notifier.addBook(book) && mounted) context.pop(book);
```

Assign `ValueKey('manual-title-field')`, `ValueKey('manual-author-field')`, and `ValueKey('manual-pages-field')` to the three fields. Use `TextInputType.number`, `FilteringTextInputFormatter.digitsOnly`, `AppTheme` styles, a leading `ChorokBackButton`, and a single green `ChorokButton(label: '서재에 추가', expand: true)`.

- [ ] **Step 5: Add failing save, cancel, and duplicate tests**

```dart
testWidgets('상태를 고르면 정리된 정보로 책을 추가해 반환한다', (tester) async {
  final notifier = _FakeLibraryNotifier();
  await tester.pumpWidget(buildSubject(notifier: notifier));

  await tester.enterText(titleField, '  채식주의자  ');
  await tester.enterText(authorField, '  한강  ');
  await tester.enterText(pagesField, '276');
  await tester.tap(find.text('서재에 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('읽는 중'));
  await tester.pumpAndSettle();

  final added = notifier.state.single;
  expect(added.title, '채식주의자');
  expect(added.author, '한강');
  expect(added.totalPages, 276);
  expect(added.status, ReadingStatus.reading);
  expect(added.isbn, isNull);
});

testWidgets('상태 선택을 취소하면 입력값을 유지한다', (tester) async {
  final notifier = _FakeLibraryNotifier();
  await tester.pumpWidget(buildSubject(notifier: notifier));
  await tester.enterText(
    find.byKey(const ValueKey('manual-title-field')),
    '채식주의자',
  );
  await tester.enterText(
    find.byKey(const ValueKey('manual-author-field')),
    '한강',
  );
  await tester.enterText(
    find.byKey(const ValueKey('manual-pages-field')),
    '276',
  );
  await tester.tap(find.text('서재에 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('취소'));
  await tester.pumpAndSettle();

  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('manual-title-field')))
        .controller!
        .text,
    '채식주의자',
  );
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('manual-author-field')))
        .controller!
        .text,
    '한강',
  );
  expect(
    tester
        .widget<TextField>(find.byKey(const ValueKey('manual-pages-field')))
        .controller!
        .text,
    '276',
  );
  expect(notifier.state, isEmpty);
});

testWidgets('같은 제목과 작가 책은 중복 추가하지 않는다', (tester) async {
  final notifier = _FakeLibraryNotifier(const [
    Book(id: 'dune', title: 'Dune', author: 'Frank Herbert'),
  ]);
  await tester.pumpWidget(buildSubject(notifier: notifier));
  await tester.enterText(
    find.byKey(const ValueKey('manual-title-field')),
    ' dune ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('manual-author-field')),
    ' FRANK HERBERT ',
  );
  await tester.enterText(
    find.byKey(const ValueKey('manual-pages-field')),
    '688',
  );
  await tester.tap(find.text('서재에 추가'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('읽는 중'));
  await tester.pump();

  expect(notifier.state, hasLength(1));
  expect(find.text('이미 서재에 있는 책이에요'), findsOneWidget);
});
```

For case-insensitive duplicate behavior, change `LibraryNotifier.containsByTitleAuthor` to compare `trim().toLowerCase()` values. This is the production change the duplicate test must catch.

- [ ] **Step 6: Run Task 1 tests and verify GREEN**

Run:

```bash
flutter test test/features/search/screen/manual_book_entry_screen_test.dart
flutter analyze lib/features/search/screen/manual_book_entry_screen.dart lib/features/search/widget/add_to_library_sheet.dart lib/core/constants/app_constants.dart lib/core/router/app_router.dart
```

Expected: all tests pass and analysis reports no issues.

- [ ] **Step 7: Commit Task 1**

```bash
git add \
  lib/features/search/screen/manual_book_entry_screen.dart \
  lib/features/search/widget/add_to_library_sheet.dart \
  lib/core/constants/app_constants.dart \
  lib/core/router/app_router.dart \
  lib/shared/providers/library_provider.dart \
  test/features/search/screen/manual_book_entry_screen_test.dart
git commit -m "책 직접 입력과 저장 흐름 구현"
```

---

### Task 2: Search hierarchy and fallback entry

**Files:**
- Create: `test/features/search/screen/search_screen_add_methods_test.dart`
- Modify: `lib/features/search/screen/search_screen.dart`

**Interfaces:**
- Consumes: `AppConstants.routeManualBookEntry` and its `Book?` route result.
- Produces: `_openManualEntry()`, an `onManualEntry` callback on book result/error views, and a permanently accented barcode action.

- [ ] **Step 1: Write failing hierarchy tests**

Use a fake `BookSearchNotifier` that returns controlled `AsyncData` and `AsyncError` values without calling Supabase:

```dart
class _FakeBookSearchNotifier extends BookSearchNotifier {
  @override
  Future<List<AladinBook>> build() async => const [];

  @override
  Future<void> search(String query, {BookSearchType? type}) async {
    state = query.trim() == '오류'
        ? AsyncValue.error(Exception('검색 실패'), StackTrace.empty)
        : const AsyncValue.data([]);
  }
}
```

Pump `SearchScreen` in a test GoRouter whose barcode route renders `Text('barcode-route')` and whose manual route renders `Text('manual-route')`.

```dart
testWidgets('초기 화면은 검색과 바코드를 보이고 직접 입력은 숨긴다', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.pump();

  expect(find.widgetWithText(TextField, '제목, 저자, 키워드 검색'), findsOneWidget);
  expect(find.bySemanticsLabel('ISBN 바코드 스캔'), findsOneWidget);
  expect(find.text('직접 입력'), findsNothing);

  final icon = tester.widget<Icon>(find.byIcon(Icons.qr_code_scanner_rounded));
  expect(icon.color, AppTheme.accent);
});

testWidgets('검색 결과가 없을 때 직접 입력으로 이동한다', (tester) async {
  await tester.enterText(searchField, '없는 책');
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();

  expect(find.text('직접 입력'), findsOneWidget);
  await tester.tap(find.text('직접 입력'));
  await tester.pumpAndSettle();
  expect(find.text('manual-route'), findsOneWidget);
});

testWidgets('검색 오류에서도 재시도와 직접 입력을 함께 제공한다', (tester) async {
  await tester.pumpWidget(buildSubject());
  await tester.enterText(searchField, '오류');
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pump();

  expect(find.text('다시 시도'), findsOneWidget);
  expect(find.text('직접 입력'), findsOneWidget);
});
```

The production changes caught are exposing manual entry too early, hiding the frequent barcode path, or omitting a fallback after failed search.

- [ ] **Step 2: Run search hierarchy tests and verify RED**

Run:

```bash
flutter test test/features/search/screen/search_screen_add_methods_test.dart
```

Expected: initial test fails because the barcode icon is not accented; failure-state tests fail because no manual callback/link exists.

- [ ] **Step 3: Implement manual route result handling**

Add:

```dart
Future<void> _openManualEntry() async {
  HapticFeedback.selectionClick();
  final book = await context.push<Book>(AppConstants.routeManualBookEntry);
  if (!mounted || book == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    chorokSnackBar(context, '"${book.title}"을(를) 서재에 추가했어요'),
  );
}
```

Pass `onManualEntry: _openManualEntry` only to `_BookResultArea`. In `_BookResultArea`, pass it to `_EmptyResult` and `_ErrorView`, but not `_IdlePrompt` or book results.

Add a small reusable-in-file text action:

```dart
class _ManualEntryLink extends StatelessWidget {
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '책 정보 직접 입력',
      child: TextButton(
        onPressed: onTap,
        child: Text('직접 입력', style: AppTheme.supportingText.copyWith(
          color: context.appTextSecondary,
        )),
      ),
    );
  }
}
```

Place it under `그래도 책을 찾을 수 없나요?` in no-result and error states. Keep it text-only so it stays less prominent than the scanner card.

- [ ] **Step 4: Accentuate the existing barcode action**

Keep its 48pt size and location. Change only the scanner icon to:

```dart
Icon(
  Icons.qr_code_scanner_rounded,
  color: context.appPrimaryAccent,
  size: 22,
)
```

Do not add a manual icon next to it.

- [ ] **Step 5: Run Task 2 tests and verify GREEN**

Run:

```bash
flutter test test/features/search/screen/search_screen_add_methods_test.dart
flutter analyze lib/features/search/screen/search_screen.dart
```

Expected: all tests pass and analysis reports no issues.

- [ ] **Step 6: Commit Task 2**

```bash
git add \
  lib/features/search/screen/search_screen.dart \
  test/features/search/screen/search_screen_add_methods_test.dart
git commit -m "검색 실패 시 책 직접 입력 연결"
```

---

### Task 3: Barcode failure fallback

**Files:**
- Create: `lib/features/search/widget/barcode_scanner_status.dart`
- Create: `test/features/search/widget/barcode_scanner_status_test.dart`
- Modify: `lib/features/search/barcode_scanner_screen.dart`

**Interfaces:**
- Consumes: `AppConstants.routeManualBookEntry`, `Book?` route result, `ChorokCard`.
- Produces: immutable `BarcodeScannerStatus` factories (`idle`, `loading`, `failure`) and `BarcodeScannerStatusCard`.

- [ ] **Step 1: Write failing status and widget tests**

```dart
test('실패 상태만 직접 입력을 허용한다', () {
  expect(const BarcodeScannerStatus.idle().allowManualEntry, isFalse);
  expect(const BarcodeScannerStatus.loading('조회 중').allowManualEntry, isFalse);
  expect(const BarcodeScannerStatus.failure('찾을 수 없어요').allowManualEntry, isTrue);
});

testWidgets('바코드 실패 카드에만 직접 입력 링크가 보인다', (tester) async {
  await tester.pumpWidget(buildStatus(
    const BarcodeScannerStatus.failure('책 정보를 찾을 수 없어요'),
  ));
  expect(find.text('직접 입력'), findsOneWidget);

  await tester.pumpWidget(buildStatus(
    const BarcodeScannerStatus.loading('조회 중'),
  ));
  expect(find.text('직접 입력'), findsNothing);
});
```

The production change caught is offering manual entry during normal scanning/loading or omitting it after a lookup failure.

- [ ] **Step 2: Run barcode status tests and verify RED**

Run:

```bash
flutter test test/features/search/widget/barcode_scanner_status_test.dart
```

Expected: compilation fails because the status types do not exist.

- [ ] **Step 3: Implement status value and card**

Create:

```dart
class BarcodeScannerStatus {
  final bool processing;
  final String? message;
  final bool allowManualEntry;

  const BarcodeScannerStatus.idle()
      : processing = false,
        message = null,
        allowManualEntry = false;

  const BarcodeScannerStatus.loading(this.message)
      : processing = true,
        allowManualEntry = false;

  const BarcodeScannerStatus.failure(this.message)
      : processing = false,
        allowManualEntry = true;
}
```

`BarcodeScannerStatusCard` renders the existing animated status card. It accepts `BarcodeScannerStatus status` and `VoidCallback onManualEntry`. Render the same secondary `_ManualEntryLink` copy as search: supporting text, no filled card, no accent color.

- [ ] **Step 4: Wire scanner branches to the status model**

Replace `_processing` and `_statusMessage` with:

```dart
BarcodeScannerStatus _status = const BarcodeScannerStatus.idle();
```

Use:

```dart
setState(() {
  _status = BarcodeScannerStatus.loading('ISBN $raw 조회 중…');
});
```

For an empty response and `catch`, call:

```dart
_resetWithFailure('책 정보를 찾을 수 없어요. 다시 스캔해보세요.');
```

where `_resetWithFailure` assigns `BarcodeScannerStatus.failure(message)` and restarts the controller. Normal cancellation assigns `const BarcodeScannerStatus.idle()`.

Add:

```dart
Future<void> _openManualEntry() async {
  final book = await context.push<Book>(AppConstants.routeManualBookEntry);
  if (!mounted || book == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    chorokSnackBar(context, '"${book.title}"을(를) 서재에 추가했어요'),
  );
  Navigator.of(context).pop();
}
```

Pass `_status` and `_openManualEntry` to `BarcodeScannerStatusCard`.

- [ ] **Step 5: Run Task 3 tests and verify GREEN**

Run:

```bash
flutter test test/features/search/widget/barcode_scanner_status_test.dart
flutter analyze lib/features/search/barcode_scanner_screen.dart lib/features/search/widget/barcode_scanner_status.dart
```

Expected: all tests pass and analysis reports no issues.

- [ ] **Step 6: Commit Task 3**

```bash
git add \
  lib/features/search/barcode_scanner_screen.dart \
  lib/features/search/widget/barcode_scanner_status.dart \
  test/features/search/widget/barcode_scanner_status_test.dart
git commit -m "바코드 조회 실패에 직접 입력 연결"
```

---

### Task 4: Integrated verification

**Files:**
- Verify only; fix only files already listed by Tasks 1-3 if evidence finds a defect.

**Interfaces:**
- Consumes: all feature behavior from Tasks 1-3.
- Produces: fresh test, analysis, formatting, and diff evidence.

- [ ] **Step 1: Format touched Dart files**

Run:

```bash
dart format \
  lib/core/constants/app_constants.dart \
  lib/core/router/app_router.dart \
  lib/features/search/barcode_scanner_screen.dart \
  lib/features/search/screen/manual_book_entry_screen.dart \
  lib/features/search/screen/search_screen.dart \
  lib/features/search/widget/add_to_library_sheet.dart \
  lib/features/search/widget/barcode_scanner_status.dart \
  lib/shared/providers/library_provider.dart \
  test/features/search/screen/manual_book_entry_screen_test.dart \
  test/features/search/screen/search_screen_add_methods_test.dart \
  test/features/search/widget/barcode_scanner_status_test.dart
```

- [ ] **Step 2: Run all affected tests together**

Run:

```bash
flutter test \
  test/features/search/screen/manual_book_entry_screen_test.dart \
  test/features/search/screen/search_screen_add_methods_test.dart \
  test/features/search/widget/barcode_scanner_status_test.dart \
  test/features/search/screen/book_info_screen_test.dart
```

Expected: zero failures.

- [ ] **Step 3: Run targeted static analysis**

Run:

```bash
flutter analyze \
  lib/core/constants/app_constants.dart \
  lib/core/router/app_router.dart \
  lib/features/search/barcode_scanner_screen.dart \
  lib/features/search/screen/manual_book_entry_screen.dart \
  lib/features/search/screen/search_screen.dart \
  lib/features/search/widget/add_to_library_sheet.dart \
  lib/features/search/widget/barcode_scanner_status.dart \
  lib/shared/providers/library_provider.dart
```

Expected: `No issues found!`

- [ ] **Step 4: Inspect scope and whitespace**

Run:

```bash
git diff --check
git status --short
git diff --stat
```

Confirm no unrelated dirty file was staged or modified by this implementation.

- [ ] **Step 5: Commit verification-only fixes if any**

If Steps 2-4 required corrections, stage only the corrected Task 1-3 files and commit:

```bash
git commit -m "책 추가 대체 흐름 검증 보완"
```

If no corrections were required, do not create an empty commit.
