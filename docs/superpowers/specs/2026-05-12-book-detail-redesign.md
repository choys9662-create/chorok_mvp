# 책 상세 페이지 리디자인

**날짜:** 2026-05-12  
**상태:** 승인 대기

---

## 목표

현재 책 상세 페이지의 세 가지 문제를 해결한다.

1. 페이지 업데이트 UI가 -10/+10/+50 버튼 방식이라 조작이 불편하다
2. "완독하기" 버튼이 지나치게 큰 비중을 차지한다
3. 이 책의 인기 문장, 내 문장, 독서 기록 등 풍부한 콘텐츠를 스크롤로 볼 수 없다

---

## 변경 사항

### 1. 페이지 업데이트 — 슬라이더 + 탭 입력

**현재:** `-10 / +10 / +50` 버튼 + 텍스트필드 + 저장 버튼  
**변경:** 슬라이더 드래그 + 숫자 탭해서 직접 입력

- 슬라이더를 좌우로 드래그해서 페이지 조절 (0 ~ totalPages)
- 가운데 큰 숫자를 탭하면 키보드가 열려서 직접 숫자 입력 가능
- "저장하기" 버튼은 유지 (명시적 확정)
- "수동 기록" 링크는 우측 상단에 유지

### 2. 완독 버튼 — "읽었어요" 인라인 pill

**현재:** 히어로 섹션 하단에 전폭 카드 버튼 ("완독하기")  
**변경:** 진행률 `10% · 50/504쪽` 옆에 작은 pill 형태로 배치

- 텍스트: "완독하기" → "읽었어요"
- 크기: 전폭 버튼 → 인라인 pill (border 1px, 패딩 4px 12px)
- 완독 상태일 때: pill이 초록색으로 채워짐 + 체크 아이콘
- 완독 토글 로직은 동일하게 유지

### 3. 탭 콘텐츠 섹션 (신규)

슬라이더 카드 아래에 탭 3개를 추가한다.

#### 탭 1: 인기 문장

- 이 책을 읽는 다른 유저들이 저장한 문장 목록
- 저장 수 기준 내림차순 정렬, 최대 20개
- 각 아이템: 문장 텍스트 / 저장 수 / "+ 내 컬렉션에 추가" 버튼
- 데이터 소스: Supabase RPC `get_popular_sentences(p_isbn TEXT)`
  - `books` 테이블에서 동일 `isbn`을 가진 모든 유저의 `saved_sentences` 배열을 `unnest` + `count` 집계
  - 결과: `{ sentence: string, save_count: number }[]`
- isbn이 없는 책은 탭을 비활성화 + "ISBN 정보가 없어 인기 문장을 불러올 수 없어요" 안내

#### 탭 2: 내 문장

- 현재 `book.savedSentences` 리스트를 표시
- 각 아이템: 문장 텍스트 (탭 시 문장 상세 화면으로 이동)
- 비어 있을 때: "아직 저장한 문장이 없어요" 빈 상태

#### 탭 3: 독서 기록

- 이 책의 `ReadingSession` 목록 (최신순)
- 각 아이템: 날짜 / 독서 시간 / 읽은 페이지 범위 / 그 세션에서 저장한 문장 수
- 현재 `ReadingSession`에 시작/종료 페이지 정보가 없으면 날짜 + 시간만 표시
- 비어 있을 때: "아직 독서 세션이 없어요"

---

## 데이터 변경

### Supabase RPC 추가

```sql
-- get_popular_sentences(p_isbn TEXT) -> TABLE(sentence TEXT, save_count BIGINT)
CREATE OR REPLACE FUNCTION get_popular_sentences(p_isbn TEXT)
RETURNS TABLE(sentence TEXT, save_count BIGINT)
LANGUAGE sql STABLE AS $$
  SELECT s.sentence, COUNT(*) AS save_count
  FROM public.books b,
       UNNEST(b.saved_sentences) AS s(sentence)
  WHERE b.isbn = p_isbn
  GROUP BY s.sentence
  ORDER BY save_count DESC
  LIMIT 20;
$$;
```

### Provider 추가

- `popularSentencesProvider(isbn)` — `AsyncNotifierProvider`, RPC 호출
- `readingSessionsForBookProvider(bookId)` — 기존 세션 데이터에서 필터

---

## 영향 범위

- 수정: `lib/features/library/screen/book_detail_screen.dart` (전면 재작성)
- 추가: Supabase migration (RPC 함수)
- 추가: Provider 2개
- 변경 없음: `Book` 모델, `libraryProvider`, 라우팅

---

## 미구현 범위 (이번 스펙 외)

- 독서 기록 탭의 "읽은 페이지 범위" — `ReadingSession`에 startPage/endPage 필드 없음. 이번엔 시간/날짜만 표시.
- 인기 문장 → 내 컬렉션 추가 액션 — UI만 구현, 실제 저장은 기존 `updateSavedSentences` 연동
