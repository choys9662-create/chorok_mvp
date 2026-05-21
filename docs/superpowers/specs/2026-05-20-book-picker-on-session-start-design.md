# 독서 세션 시작 시 책 선택 플로우 설계

**날짜**: 2026-05-20  
**상태**: 승인됨

---

## 문제

FAB 오브 탭 → 세션 시작 시 책 정보 없이 세션만 생성됨.  
`RecapData.bookId == null`이면 페이지 갱신·Supabase 업로드가 모두 스킵되어 독서 트래킹 불가.  
현재 코드는 "채식주의자/한강" 하드코딩 플레이스홀더 사용 중.

---

## 결정

- 자유독서(책 없는 세션) 제거 — 항상 책을 선택하고 세션 시작
- FAB → `BookPickerSheet` → `ReadingSessionScreen` (with `SessionExtra`) 흐름 추가
- `book_detail_screen._startSession`의 누락된 `bookId`도 함께 수정

---

## 아키텍처

### 진입 분기 (`main_scaffold.dart`)

```
FAB 탭
├── 세션 진행 중 (!timer.isIdle) → routeSession 이동 (변경 없음)
└── 세션 없음 → BookPickerSheet 열기
```

하드코딩 `SessionExtra(bookId: '1', bookTitle: '채식주의자', ...)` 블록 제거.

### `BookPickerSheet` (신규)

**파일**: `lib/features/timer/widget/book_picker_sheet.dart`

**데이터 소스**: `libraryProvider` → `ReadingStatus.reading` 필터

**3가지 상태**:

| 상태 | 처리 |
|---|---|
| Loading | 책 카드 shimmer 2개 |
| Empty (0권) | "읽는 중인 책이 없어요" + "라이브러리 가기" CTA (`context.pop()` 후 라이브러리 탭 이동) |
| 책 있음 (1권 이상) | 책 카드 목록 + 하단 "다른 책 검색" 텍스트 버튼 |

**책 카드 탭 동작**:
```
Navigator.pop(context)
context.push(routeSession, extra: SessionExtra(
  bookId: book.id,
  bookTitle: book.title,
  bookAuthor: book.author,
  coverUrl: book.coverUrl,
  startPage: book.currentPage,
  totalPages: book.totalPages,
))
```

**"다른 책 검색" 탭 동작**:
```
Navigator.pop(context)
context.push(routeSearch)
```

**UX 수칙**:
- 책 카드 탭 시 `HapticFeedback.selectionClick()`
- "라이브러리 가기" / "다른 책 검색" 탭 시 `HapticFeedback.lightImpact()`
- 시트 내 애니메이션: 250ms, `Curves.easeOutCubic`

### `book_detail_screen._startSession` 수정

`SessionExtra`에 `bookId: widget.book.id` 추가.  
현재 누락으로 인해 책 상세 → 세션 진입 시에도 페이지/Supabase 저장이 안 되는 버그.

---

## 영향 범위

| 파일 | 변경 |
|---|---|
| `lib/shared/widgets/main_scaffold.dart` | `_handleOrbTap` — 하드코딩 제거 → `BookPickerSheet` 호출 |
| `lib/features/timer/widget/book_picker_sheet.dart` | **신규** |
| `lib/features/home/screen/book_detail_screen.dart` | `_startSession` — `bookId` 추가 |

`ReadingSessionScreen`, `SessionExtra`, `RecapData` — **변경 없음**.

---

## 비범위

- 세션 목표 설정 (`SessionGoalSheet`) 흐름 변경 없음
- 자유독서 모드 — 이번 스펙에서 제외
- 1권일 때 시트 스킵 최적화 — 추후 개선 사항
