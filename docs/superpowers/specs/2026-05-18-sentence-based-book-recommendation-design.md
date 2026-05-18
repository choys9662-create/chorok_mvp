# 내 문장이 이끄는 책 — 알고리즘 기반 추천 설계

## 목적

홈 화면의 `RecommendedBooksSection`에서 하드코딩된 mock 데이터를 제거하고,
사용자가 실제로 기록한 문장 데이터를 분석해 알라딘 API로 실시간 책을 추천한다.
AI 없이 순수 알고리즘(저자 추출 + 키워드 빈도 분석)으로 구현한다.

---

## 알고리즘

### 입력 데이터

- `DbService.fetchMySentences()`: 최근 50개 문장 (books 테이블 JOIN 포함)
  - 각 row: `content`, `book_id`, `books.author`, `books.title`
- `libraryProvider`: 현재 서재의 책 목록 (추천 대상 필터링용)

### 처리 단계

#### 1. 저자 추출

- 문장들을 `book_id` 기준으로 그룹화
- 문장 수가 가장 많은 책의 저자를 대표 저자로 선정
- 대표 저자 1명을 알라딘 Author 검색에 사용

#### 2. 키워드 추출

- 모든 문장 `content`를 합쳐 공백 기준으로 토큰화
- 아래 조건의 토큰 제거:
  - 2자 미만
  - 한국어 불용어 목록에 포함 (조사·접속사·대명사 등 약 80개)
- 남은 토큰의 빈도 집계, 상위 3개를 키워드로 선정
- 키워드 2~3개를 공백으로 이어 알라딘 Keyword 검색에 사용

#### 3. 알라딘 검색

- 기존 `aladin-search` Supabase Edge Function 재사용
- 아래 2개 검색을 병렬(`Future.wait`) 실행:
  - `{queryType: "Author", query: "<대표저자>"}`
  - `{queryType: "Keyword", query: "<키워드1> <키워드2>"}`
- 각 검색 결과 최대 10건씩 수집

#### 4. 결과 병합 및 필터링

- 두 검색 결과를 합산
- 내 서재 책 제목과 일치하는 항목 제거 (대소문자·공백 무시 단순 비교)
- ISBN13 기준 중복 제거 (ISBN 없으면 title+author 기준)

#### 5. 점수 부여

| 출처 | 점수 범위 | 계산 방식 |
|------|-----------|-----------|
| 저자 검색 | 0.85 ~ 0.95 | `0.95 - (검색순위 * 0.01)` |
| 키워드 검색 | 0.75 ~ 0.90 | `0.90 - (검색순위 * 0.015)` |
| 두 검색 모두 포함 | 위 두 점수 중 높은 값 사용 | |

#### 6. 추천 이유 생성

- 저자 검색 출처: `"[대표책제목]과 같은 [저자]의 다른 작품"`
- 키워드 검색 출처: `"'[키워드1]', '[키워드2]' 감성을 자주 기록하셨어요"`
- 두 출처 모두: 저자 이유 우선

#### 7. 최종 출력

- 점수 내림차순 정렬 후 상위 4건 반환
- 반환 타입: 기존 `RecommendedBook` typedef 재사용

---

## 상태 처리

| 조건 | UI 동작 |
|------|---------|
| 문장 3개 미만 | 섹션 내 단일 안내 카드: "문장을 더 기록하면 취향에 맞는 책을 추천해드려요" |
| 로딩 중 | 카드 shimmer (기존 카드 레이아웃과 동일한 크기) |
| 검색 결과 0건 | 안내 카드와 동일 처리 |
| 에러 (네트워크 등) | 섹션 전체 숨김 (사용자에게 에러 노출 안 함) |
| 성공 | 실제 추천 카드 최대 4건 |

---

## 파일 변경

### 신규

**`lib/features/home/controller/recommended_books_provider.dart`**

```
recommendedBooksProvider (AutoDisposeFutureProvider<List<RecommendedBook>>)
  └─ _extractAuthor(sentences) → String?
  └─ _extractKeywords(sentences) → List<String>
  └─ _koreanStopwords (Set<String>, 상수)
  └─ _buildReason(source, author, bookTitle, keywords) → String
  └─ _calcScore(source, rank) → double
```

### 수정

**`lib/features/home/widget/recommended_books_section.dart`**

- `RecommendedBooksSection`: `StatelessWidget` → `ConsumerWidget`
- `kRecommendedBooks` 상수 제거
- provider watch → loading / empty / error / data 분기 렌더링

---

## 제약 및 가정

- 문장 데이터가 적을 때 (1~5개)도 동작해야 한다. 저자가 추출되면 저자 검색만으로도 결과를 반환한다.
- 알라딘 검색 결과에 coverUrl이 없는 책은 gradientIndex fallback으로 표시한다. gradientIndex는 결과 순서 기반으로 `(index % 6) + 1` 값을 사용한다.
- 테스트 앱(chorok-real, `kUseMock=false`)에서만 실데이터로 동작한다. 디자인 앱(`kUseMock=true`)은 기존 hardcoded 데이터를 유지한다.
- 불용어 목록은 앱 내 상수로 관리하며 외부 의존성 없음.
