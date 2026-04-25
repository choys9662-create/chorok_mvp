# Full Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 코드 효율성과 가시성 개선 — dead code 제거, 3166줄 거대 파일 분리, mock 데이터 집중화, router 버그 수정

**Architecture:** 각 논리 단위(위젯·시트·뷰)를 독립 파일로 분리해 `library/widget/`에 모은다. 공용 mock 데이터는 `shared/mock/` 에 집중. Private 접두사(`_`)를 제거하고 파일 이름으로 범위를 제한.

**Tech Stack:** Flutter 3.x, Riverpod, GoRouter, Dart records

---

## 파일 변경 맵

| 변경 유형 | 파일 |
|-----------|------|
| **삭제** | `lib/features/home/screen/book_reflection_screen.dart` (dead code) |
| **수정** | `lib/core/router/app_router.dart` — onboarding 화이트리스트 |
| **신규** | `lib/shared/mock/mock_data.dart` — 전체 mock 데이터 집중 |
| **신규** | `lib/features/library/widget/library_book_card.dart` |
| **신규** | `lib/features/library/widget/library_book_list_tile.dart` |
| **신규** | `lib/features/library/widget/library_calendar_view.dart` |
| **신규** | `lib/features/library/widget/library_stats_view.dart` |
| **신규** | `lib/features/library/widget/library_sort_sheet.dart` |
| **신규** | `lib/features/library/widget/library_book_detail_sheet.dart` |
| **수정** | `lib/features/library/screen/library_screen.dart` — 위 파일 import |
| **수정** | `lib/features/home/screen/home_screen.dart` — mock 데이터 → shared/mock |

---

### Task 1: Dead file 삭제 + router onboarding 버그 수정

**Files:**
- Delete: `lib/features/home/screen/book_reflection_screen.dart`
- Modify: `lib/core/router/app_router.dart`

- [ ] **Step 1: Dead file 삭제**

```bash
rm lib/features/home/screen/book_reflection_screen.dart
```

- [ ] **Step 2: router에서 onboarding 화이트리스트 추가**

`lib/core/router/app_router.dart` redirect 수정:
```dart
redirect: (context, state) {
  final session = Supabase.instance.client.auth.currentSession;
  final isLoggedIn = session != null;
  final loc = state.matchedLocation;
  final isPublic = loc == AppConstants.routeAuth ||
      loc == AppConstants.routeOnboarding;
  if (!isLoggedIn && !isPublic) return AppConstants.routeAuth;
  if (isLoggedIn && loc == AppConstants.routeAuth) return AppConstants.routeHome;
  return null;
},
```

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/core/router/app_router.dart lib/features/home/screen/
```

- [ ] **Step 4: Commit**

```bash
git add lib/core/router/app_router.dart
git rm lib/features/home/screen/book_reflection_screen.dart
git commit -m "refactor: dead file 제거 및 router onboarding 인증 가드 수정"
```

---

### Task 2: library_screen → library_book_card.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_book_card.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 1108~1441줄(`_CoverPlaceholder`, `_BookCard`, `_EmptyShelf`) 복사해서 `library_book_card.dart` 신규 작성, public 이름으로 변경

- [ ] **Step 2:** `library_screen.dart`에서 해당 클래스 제거 후 import 추가

- [ ] **Step 3: 빌드 확인**

```bash
flutter analyze lib/features/library/
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/library/widget/library_book_card.dart lib/features/library/screen/library_screen.dart
git commit -m "refactor: LibraryBookCard 위젯 파일 분리"
```

---

### Task 3: library_screen → library_book_list_tile.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_book_list_tile.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 1707~1932줄(`_BookListTile`) 추출

- [ ] **Step 2:** `library_screen.dart`에서 제거 후 import

- [ ] **Step 3: 빌드 확인 + Commit**

---

### Task 4: library_screen → library_sort_sheet.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_sort_sheet.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 1934~2015줄(`_SortSheet`) 추출

- [ ] **Step 2:** 제거 + import + commit

---

### Task 5: library_screen → library_book_detail_sheet.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_book_detail_sheet.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 2017~2568줄(`_AddBookSheet`, `_BookDetailSheet`, `_PageAdjustButton`, `_DetailStat`) 추출

- [ ] **Step 2:** 제거 + import + commit

---

### Task 6: library_screen → library_calendar_view.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_calendar_view.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 2599~3129줄(`_SegmentToggle`, `_CalendarView`, `_CalendarGrid`, `_ReadingLogCard`) 추출

- [ ] **Step 2:** 제거 + import + commit

---

### Task 7: library_screen → library_stats_view.dart 분리

**Files:**
- Create: `lib/features/library/widget/library_stats_view.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `library_screen.dart` 3130줄~끝(`_StatsView`) 추출

- [ ] **Step 2:** 제거 + import + commit

---

### Task 8: Mock 데이터 집중화

**Files:**
- Create: `lib/shared/mock/mock_data.dart`
- Modify: `lib/features/home/screen/home_screen.dart`
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1:** `home_screen.dart`의 `_kRecommendedBooks`, `_kReadingBooks`, `_kWishlistBooks`, `_kBookStats`, `_kWeeklyMinutes`, `_kWeekLabels`, `_kGoalMessages` 등 모든 `_k*` 상수와 typedef를 `mock_data.dart`로 이동, public 이름으로 변경

- [ ] **Step 2:** `library_screen.dart`의 `_kTreemapItems`, `_kReadingLogs`, `_kBooks`, `_kLibraryWishlistBooks`, `_kGenreWeekLabels` 이동

- [ ] **Step 3:** 두 screen 파일에 import 추가 및 참조 이름 업데이트

- [ ] **Step 4: 빌드 확인**

```bash
flutter analyze lib/
```

- [ ] **Step 5: Commit**

```bash
git add lib/shared/mock/ lib/features/home/screen/home_screen.dart lib/features/library/screen/library_screen.dart
git commit -m "refactor: mock 데이터 shared/mock/mock_data.dart로 집중화"
```
