# 탭 콘텐츠 밀도 보강 설계

**날짜:** 2026-04-19  
**목표:** 홈 · 피드 · 서재 탭의 시각적 공백을 채워 콘텐츠 밀도를 높인다.  
**범위:** 분석 탭은 이미 충분하므로 제외.

---

## 1. 홈 탭 — "다음에 읽을 책" 섹션

### 위치
AI 추천 섹션(`_RecommendedBooksSection`) 아래, 피드 하이라이트 위.

### 컴포넌트 구성
- **섹션 헤더:** "다음에 읽을 책" + 권수 뱃지
- **가로 스크롤 카드 (160×200px):**
  - 표지 그라디언트 (coverGradients 팔레트)
  - 제목 / 저자
  - 추가한 날짜 (`3일 전`)
  - `읽기 시작` 버튼 → SessionGoalSheet 진입
- **Empty State:** 아이콘(`bookmark_add_rounded`) + "읽고 싶은 책을 담아보세요" + 탐색 CTA 버튼

### 목업 데이터 (3권)
```dart
const _kWishlistBooks = [
  (title: '소년이 온다', author: '한강', addedDays: 3, gradientIndex: 3),
  (title: '불편한 편의점', author: '김호연', addedDays: 7, gradientIndex: 6),
  (title: '달러구트 꿈 백화점', author: '이미예', addedDays: 14, gradientIndex: 1),
];
```

### UX 규칙
- 카드 탭 시 `HapticFeedback.selectionClick()` + scale 0.97 애니메이션
- "읽기 시작" 탭 시 `HapticFeedback.mediumImpact()`

---

## 2. 피드 탭 — 활동 배너 + 트렌딩 책 섹션

### 2-A. 활동 배너

**위치:** 헤더 타이틀과 구분선 사이  
**형태:** 풀너비 컨테이너 (좌우 패딩 20)  
**내용:** `오늘 N명이 문장을 기록했어요 · 겹문장 M건`  
**값 생성:** `DateTime.now().day`를 seed로 목업 숫자 결정 (300–500명, 8–20건)  
**스타일:** `appCard` 배경 + `appBorder` 테두리, captionLarge, 도트 구분자

### 2-B. 트렌딩 책 섹션

**위치:** 필터 칩 아래, 문장 목록 바로 위  
**구성:**
- 섹션 레이블: `이번 주 화제의 책` (captionLarge + appTextTertiary)
- 가로 스크롤 소형 카드 (120×80px):
  - 표지 컬러 그라디언트 (좌측 1/3)
  - 제목 (1줄, ellipsis) / 저자 (captionSmall)
  - `N개 문장` 수집 뱃지 (우하단)
- 목업 5권

```dart
const _kTrendingBooks = [
  (title: '채식주의자', author: '한강', sentenceCount: 142, gradientIndex: 0),
  (title: '파친코', author: '이민진', sentenceCount: 98, gradientIndex: 2),
  (title: '아몬드', author: '손원평', sentenceCount: 87, gradientIndex: 4),
  (title: '소년이 온다', author: '한강', sentenceCount: 76, gradientIndex: 3),
  (title: '82년생 김지영', author: '조남주', sentenceCount: 61, gradientIndex: 1),
];
```

**겹문장 탭 선택 시:** 트렌딩 섹션 숨김 (SizedBox.shrink)

---

## 3. 서재 탭 — 성과 뱃지 카드 + 읽고 싶은 책 섹션

### 3-A. "이번 달 독서 성과" 뱃지 카드

**위치:** 프로필 헤더 바로 아래 (기존 첫 번째 콘텐츠 위)  
**구성:** 가로 3칸 균등 분할

| 칸 | 아이콘 | 값 | 레이블 |
|---|---|---|---|
| 1 | `menu_book_rounded` | 2권 | 이번 달 완독 |
| 2 | `local_fire_department_rounded` | 5일 | 최장 연속 |
| 3 | `format_quote_rounded` | 47개 | 수집 문장 |

**스타일:** ChorokCard + 그라디언트 아이콘 컨테이너 (appPrimaryAccent 10% opacity)  
**탭 시:** HapticFeedback.selectionClick() → 분석 탭으로 이동 (context.go routeAnalytics)

### 3-B. "읽고 싶은 책" 섹션

**위치:** 책 목록 그리드/리스트 아래  
**구성:**
- ChorokSectionHeader: "읽고 싶은 책" + 권수
- 리스트 형태 카드 (풀너비):
  - 좌측 4px 컬러 바 (coverGradient)
  - 제목 / 저자
  - 추가한 날짜 (`N일 전`)
  - 우측 `읽기 시작` 텍스트 버튼
- **Empty State:** 아이콘 + "탐색에서 발견한 책을 담아보세요" + CTA

**목업 데이터:** 홈 탭 위시리스트와 동일한 3권

---

## 4. UX 공통 규칙 (ux-planner 수칙)

| 항목 | 처리 |
|---|---|
| Loading | 각 섹션은 목업 데이터 사용 (즉시 표시) |
| Empty | 모든 비어있을 때 상태 구현 (아이콘 + 안내 + CTA) |
| Error | 목업이므로 해당 없음 |
| 텍스트 오버플로우 | 제목 maxLines: 1, overflow: ellipsis |
| Haptic | selectionClick(탭), mediumImpact(읽기 시작) |
| 애니메이션 | scale 0.97, 150ms, Curves.easeOutCubic |

---

## 5. 구현 순서

1. 홈 탭: `_WishlistSection` 위젯 + 목업 데이터
2. 피드 탭: `_ActivityBanner` + `_TrendingBooksSection` 위젯
3. 서재 탭: `_MonthlyAchievementCard` + `_WishlistSection` 위젯
