# Book Picker on Session Start — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** FAB "독서 시작" 탭 시 책 선택 시트를 표시해 항상 bookId가 포함된 세션을 시작하도록 한다.

**Architecture:** 신규 `BookPickerSheet` 위젯이 `libraryProvider`에서 읽는 중인 책을 필터링해 표시한다. FAB의 `_handleOrbTap`은 세션 없을 때 이 시트를 열고, 시트에서 책을 고르면 기존 `SessionExtra` 흐름으로 `ReadingSessionScreen`에 진입한다. `book_detail_screen`의 누락된 `bookId`도 함께 수정한다.

**Tech Stack:** Flutter, Riverpod (`libraryProvider`, `ConsumerWidget`), GoRouter (`context.push` / `context.go`), `figma_squircle`, `BookCover`, `ChorokShimmer`

---

## File Map

| Action | Path | Role |
|--------|------|------|
| Create | `lib/features/timer/widget/book_picker_sheet.dart` | 책 선택 시트 (신규) |
| Create | `test/features/timer/widget/book_picker_sheet_test.dart` | 시트 위젯 테스트 |
| Modify | `lib/shared/widgets/main_scaffold.dart` | `_handleOrbTap` — 시트 호출로 교체 |
| Modify | `lib/features/home/screen/book_detail_screen.dart` | `_startSession` — `bookId` 추가 |

---

## Task 1: `BookPickerSheet` 테스트 작성 및 위젯 구현

### Files
- Create: `test/features/timer/widget/book_picker_sheet_test.dart`
- Create: `lib/features/timer/widget/book_picker_sheet.dart`

---

- [ ] **Step 1: 테스트 파일 디렉토리 생성 확인**

```bash
mkdir -p test/features/timer/widget
```

---

- [ ] **Step 2: failing 테스트 작성**

`test/features/timer/widget/book_picker_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/timer/widget/book_picker_sheet.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends Notifier<List<Book>> {
  final List<Book> books;
  _FakeLibraryNotifier(this.books);

  @override
  List<Book> build() => books;
}

Widget _buildSheet(List<Book> books) {
  return ProviderScope(
    overrides: [
      libraryProvider.overrideWith(() => _FakeLibraryNotifier(books)),
    ],
    child: const MaterialApp(
      home: Scaffold(body: BookPickerSheet()),
    ),
  );
}

final _readingBook = Book(
  id: 'b1',
  title: '채식주의자',
  author: '한강',
  status: ReadingStatus.reading,
  totalPages: 300,
  currentPage: 186,
);

final _wantToReadBook = Book(
  id: 'b2',
  title: '아몬드',
  author: '손원평',
  status: ReadingStatus.wantToRead,
  totalPages: 264,
  currentPage: 0,
);

void main() {
  group('BookPickerSheet', () {
    testWidgets('읽는 중인 책이 있으면 책 제목이 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_readingBook, _wantToReadBook]));
      await tester.pump();

      expect(find.text('채식주의자'), findsOneWidget);
      expect(find.text('아몬드'), findsNothing); // wantToRead는 표시 안 됨
    });

    testWidgets('읽는 중인 책이 없으면 empty state 문구가 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_wantToReadBook]));
      await tester.pump();

      expect(find.text('읽는 중인 책이 없어요'), findsOneWidget);
    });

    testWidgets('읽는 중인 책이 있으면 "다른 책 검색" 버튼이 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([_readingBook]));
      await tester.pump();

      expect(find.text('다른 책 검색'), findsOneWidget);
    });

    testWidgets('라이브러리가 비어 있으면 "라이브러리 가기" CTA가 표시된다', (tester) async {
      await tester.pumpWidget(_buildSheet([]));
      await tester.pump();

      expect(find.text('라이브러리 가기'), findsOneWidget);
    });
  });
}
```

---

- [ ] **Step 3: 테스트 실행 — FAIL 확인**

```bash
flutter test test/features/timer/widget/book_picker_sheet_test.dart
```

Expected: `Target of URI doesn't exist: 'book_picker_sheet.dart'` 오류

---

- [ ] **Step 4: `BookPickerSheet` 위젯 구현**

`lib/features/timer/widget/book_picker_sheet.dart`:

```dart
import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/sheet_handle.dart';

class BookPickerSheet extends ConsumerWidget {
  const BookPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readingBooks = ref
        .watch(libraryProvider)
        .where((b) => b.status == ReadingStatus.reading)
        .toList();
    final isLoading = ref.read(libraryProvider.notifier).isLoading;

    return Container(
      decoration: ShapeDecoration(
        color: context.appCard,
        shape: SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius(
            cornerRadius: 24,
            cornerSmoothing: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '어떤 책을 읽을까요?',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading && readingBooks.isEmpty)
              _LoadingState()
            else if (readingBooks.isEmpty)
              _EmptyState()
            else
              _BookList(books: readingBooks),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  final List<Book> books;

  const _BookList({required this.books});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: books.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _BookCard(book: books[index]),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
            context.push(AppConstants.routeSearch);
          },
          child: Text(
            '다른 책 검색',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;

  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final progress = book.totalPages > 0
        ? book.currentPage / book.totalPages
        : 0.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).pop();
        context.push(
          AppConstants.routeSession,
          extra: SessionExtra(
            bookId: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            coverUrl: book.coverUrl,
            startPage: book.currentPage,
            totalPages: book.totalPages,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: ShapeDecoration(
          color: context.appCardElevated,
          shape: SmoothRectangleBorder(
            borderRadius: SmoothBorderRadius(
              cornerRadius: 16,
              cornerSmoothing: 0.6,
            ),
          ),
        ),
        child: Row(
          children: [
            BookCover(
              coverUrl: book.coverUrl,
              width: 44,
              height: 60,
              radius: 6,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (book.totalPages > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: context.appCard,
                        color: AppTheme.primary,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${book.currentPage} / ${book.totalPages}p',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.appTextSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          ChorokShimmer(width: double.infinity, height: 80, radius: 16),
          const SizedBox(height: 8),
          ChorokShimmer(width: double.infinity, height: 80, radius: 16),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 48,
            color: context.appTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            '읽는 중인 책이 없어요',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
              context.go(AppConstants.routeLibrary);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: ShapeDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: 12,
                    cornerSmoothing: 0.6,
                  ),
                ),
              ),
              child: Text(
                '라이브러리 가기',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

- [ ] **Step 5: 테스트 실행 — PASS 확인**

```bash
flutter test test/features/timer/widget/book_picker_sheet_test.dart
```

Expected: 모든 테스트 PASS

---

- [ ] **Step 6: 커밋**

```bash
git add lib/features/timer/widget/book_picker_sheet.dart \
        test/features/timer/widget/book_picker_sheet_test.dart
git commit -m "feat: BookPickerSheet — 독서 시작 전 책 선택 시트"
```

---

## Task 2: `main_scaffold.dart` — FAB → `BookPickerSheet` 연결

### Files
- Modify: `lib/shared/widgets/main_scaffold.dart`

---

- [ ] **Step 1: `_handleOrbTap` 수정**

`lib/shared/widgets/main_scaffold.dart`에서 아래 기존 코드:

```dart
  Future<void> _handleOrbTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final timer = ref.read(timerProvider);
    if (!timer.isIdle) {
      context.push(AppConstants.routeSession);
      return;
    }
    context.push(
      AppConstants.routeSession,
      extra: SessionExtra(
        bookId: '1',
        bookTitle: '채식주의자',
        bookAuthor: '한강',
        startPage: 186,
        totalPages: 300,
      ),
    );
  }
```

를 다음으로 교체:

```dart
  Future<void> _handleOrbTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final timer = ref.read(timerProvider);
    if (!timer.isIdle) {
      context.push(AppConstants.routeSession);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BookPickerSheet(),
    );
  }
```

---

- [ ] **Step 2: import 추가**

파일 상단 imports에 추가:

```dart
import '../../features/timer/widget/book_picker_sheet.dart';
```

기존 `session_goal.dart` import는 더 이상 `_handleOrbTap`에서 쓰이지 않지만, 파일 내 다른 곳에서 쓰이는지 확인 후 불필요하면 제거.

```bash
grep -n "SessionExtra\|SessionGoal\|session_goal" lib/shared/widgets/main_scaffold.dart
```

결과에 `_handleOrbTap` 외 다른 사용이 없으면 해당 import 삭제.

---

- [ ] **Step 3: 앱 빌드 확인**

```bash
flutter analyze lib/shared/widgets/main_scaffold.dart
```

Expected: No errors or warnings

---

- [ ] **Step 4: 커밋**

```bash
git add lib/shared/widgets/main_scaffold.dart
git commit -m "fix: FAB 하드코딩 제거 — BookPickerSheet로 책 선택 연결"
```

---

## Task 3: `book_detail_screen.dart` — `_startSession`에 `bookId` 추가

### Files
- Modify: `lib/features/home/screen/book_detail_screen.dart:374-386`

---

- [ ] **Step 1: `_startSession` 수정**

`lib/features/home/screen/book_detail_screen.dart`에서 기존 코드:

```dart
  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    context.push(
      AppConstants.routeSession,
      extra: SessionExtra(
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
        coverUrl: widget.book.coverUrl,
        startPage: widget.book.currentPage,
        totalPages: widget.book.totalPages,
      ),
    );
  }
```

를 다음으로 교체:

```dart
  Future<void> _startSession() async {
    HapticFeedback.mediumImpact();
    context.push(
      AppConstants.routeSession,
      extra: SessionExtra(
        bookId: widget.book.id,
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
        coverUrl: widget.book.coverUrl,
        startPage: widget.book.currentPage,
        totalPages: widget.book.totalPages,
      ),
    );
  }
```

---

- [ ] **Step 2: 빌드 확인**

```bash
flutter analyze lib/features/home/screen/book_detail_screen.dart
```

Expected: No errors or warnings

---

- [ ] **Step 3: 커밋**

```bash
git add lib/features/home/screen/book_detail_screen.dart
git commit -m "fix: 책 상세 → 세션 시작 시 bookId 누락 수정"
```

---

## Task 4: 전체 테스트 및 최종 확인

- [ ] **Step 1: 전체 테스트 실행**

```bash
flutter test
```

Expected: All tests PASS

- [ ] **Step 2: 정적 분석**

```bash
flutter analyze
```

Expected: No issues found
