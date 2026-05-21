# Reading Session Design Norms — 라이트/다크 전체 적용

Date: 2026-05-21

## 목표

`reading_session_screen.dart` (커밋 092e71a)에서 확립된 시각 언어를 테마 토큰으로 공식화하고, 주요 화면에 산재한 하드코딩 컬러를 토큰으로 통일한다. 레이아웃은 변경하지 않는다.

---

## 독서 세션에서 추출한 디자인 규범

### 컬러 언어

| 역할 | 다크 | 라이트 |
|---|---|---|
| 브랜드 Primary | `#8DFF54` (네온 그린) | `#009B58` (딥 그린) |
| 브랜드 Accent | `#6DE034` | `#009B58` |
| 브랜드 Paused | `#2A7A3D` (어두운 그린) | `#009B58 @ 60%` |
| 배경 | `#000000` | `#F2F4F6` |
| Surface 0 | `#131313` | `#FFFFFF` |
| Surface 1 (액션 버튼) | `#161616` | `#EAEEF2` |
| Surface 2 (카드 상승) | `#1E1E1E` | `#FFFFFF` |
| 텍스트 Primary | `#FFFFFF` | `#191F28` |
| 텍스트 Secondary | `#646464` | `#8B95A1` |
| 비활성 보더 | `white @ 12%` | `#191F28 @ 10%` |
| 활성 보더 (pill) | `#8DFF54 @ 45%` | `#009B58 @ 35%` |
| 뮤트 보더 (일시정지) | `#8DFF54 @ 25%` | `#009B58 @ 18%` |
| 활성 채움 배경 | `#8DFF54 @ 15%` | `#009B58 @ 8%` |
| 공유 카드 (receipt) | `#F9F7F1` (모드 무관) | — |

### 셰이프 원칙
- Pill (상태/수치 표시): radius 20, padding `18×8`
- 사각 액션 버튼: radius 16, 52×52 / 44×44 (탑바)
- 모든 Divider 불가시 (두께 0 또는 투명)
- Drop shadow는 발광 요소(오브, 코어 도트)에만 허용

### 타이포그래피 원칙
- Font family: `조선굴림체` (전역 설정됨)
- 숫자 표시: `tabularFigures + letterSpacing 2`
- 아이콘: rounded/outlined 변형만

---

## 현황 진단 — 토큰 공백

### `AppTheme`에 없는 상수
```dart
darkActionBg = Color(0xFF161616)  // reading_session 내 _k* 상수로만 존재
lightActionBg = Color(0xFFEAEEF2) // 대응 라이트 토큰 없음
primaryPaused = Color(0xFF2A7A3D) // _GlowOrb 내 인라인 리터럴
receiptBg = Color(0xFFF9F7F1)    // session_recap 인라인 리터럴
```

### `AppThemeExt`에 없는 context 게터
```dart
appActionBg        // 비활성 액션 버튼 fill (다크/라이트 분기)
appBorderSubtle    // 비활성 컨트롤 테두리
appActiveFill      // 활성 버튼 배경
appPillBorderActive  // pill 활성 보더
appPillBorderMuted   // pill 뮤트 보더
```

### 라이트 테마 누락
- `DividerTheme` 미설정 → `Divider()` 위젯이 Material 기본 렌더링으로 폴백 가능

### 하드코딩 컬러 위반 현황

| 파일 | 줄 | 값 | 올바른 처리 |
|---|---|---|---|
| `session_recap_screen.dart` | 484 | `#F9F7F1` | `AppTheme.receiptBg` |
| `session_recap_screen.dart` | 769 | `#00FF00` | `AppTheme.primaryLight` |
| `session_recap_screen.dart` | 770 | `#00CC6A` | `AppTheme.accent` |
| `book_detail_screen.dart` | 1476 | `#CF6679` | `colorScheme.error` |
| `book_detail_screen.dart` | 1570 | `#FF6B6B` | `colorScheme.error` |
| `feed_screen.dart` | 1031, 1039 | `#FF6B6B` | `colorScheme.error` |
| `sentence_detail_screen.dart` | 646, 654 | `#FF6B6B` | `colorScheme.error` |
| `reading_session_screen.dart` | 22–25 | `_k*` 상수 4개 | `AppTheme.*` 참조로 교체 |

---

## 변경 범위

### 파일 1: `lib/core/theme/app_theme.dart`

**추가 — `AppTheme` static consts:**
```dart
static const Color darkActionBg = Color(0xFF161616);
static const Color lightActionBg = Color(0xFFEAEEF2);
static const Color primaryPaused = Color(0xFF2A7A3D);
static const Color receiptBg = Color(0xFFF9F7F1);
```

**추가 — `AppThemeExt` getters:**
```dart
Color get appActionBg => _isDark ? AppTheme.darkActionBg : AppTheme.lightActionBg;
Color get appBorderSubtle =>
    _isDark ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFF191F28).withValues(alpha: 0.10);
Color get appActiveFill =>
    _isDark ? AppTheme.primaryLight.withValues(alpha: 0.15)
            : AppTheme.lightPrimaryAccent.withValues(alpha: 0.08);
Color get appPillBorderActive =>
    _isDark ? AppTheme.primaryLight.withValues(alpha: 0.45)
            : AppTheme.lightPrimaryAccent.withValues(alpha: 0.35);
Color get appPillBorderMuted =>
    _isDark ? AppTheme.primaryLight.withValues(alpha: 0.25)
            : AppTheme.lightPrimaryAccent.withValues(alpha: 0.18);
```

**수정 — 라이트 테마에 DividerTheme 추가:**
```dart
dividerTheme: const DividerThemeData(color: Colors.transparent, thickness: 0, space: 0),
```

### 파일 2: `lib/features/home/screen/reading_session_screen.dart`

파일 상단 `_k*` 상수 4개를 `AppTheme.*` 참조로 교체. `_kFont`는 유지 (로컬 alias로 가독성 기여).

```dart
// 제거
const _kGreen = Color(0xFF8DFF54);
const _kSurface = Color(0xFF131313);
const _kSurfaceElevated = Color(0xFF1E1E1E);
const _kTextSecondary = Color(0xFF646464);

// 교체 (사용처에서 직접)
// _kGreen → AppTheme.primaryLight
// _kSurface → AppTheme.darkSurface
// _kSurfaceElevated → AppTheme.darkCardElevated
// _kTextSecondary → AppTheme.textSecondary
```

> 세션 화면은 항상 다크 — `context.appActionBg` 같은 brightness-분기 getter가 아닌
> `AppTheme.dark*` 상수를 직접 사용한다.

### 파일 3: `lib/features/home/screen/session_recap_screen.dart`

- 484: `const Color(0xFFF9F7F1)` → `AppTheme.receiptBg`
- 769: `Color(0xFF00FF00)` → `AppTheme.primaryLight`
- 770: `Color(0xFF00CC6A)` → `AppTheme.accent`

### 파일 4: `lib/features/home/screen/book_detail_screen.dart`

- 1476: `const Color(0xFFCF6679)` → `Theme.of(context).colorScheme.error`
- 1570: `const Color(0xFFFF6B6B)` → `Theme.of(context).colorScheme.error`

### 파일 5: `lib/features/feed/screen/feed_screen.dart`

- 1031, 1039: `const Color(0xFFFF6B6B)` → `Theme.of(context).colorScheme.error`

### 파일 6: `lib/features/feed/screen/sentence_detail_screen.dart`

- 646, 654: `const Color(0xFFFF6B6B)` → `Theme.of(context).colorScheme.error`

---

## 범위 외 (이번 작업 제외)

- Analytics 차트 위젯의 히트맵/레이더 차트 컬러 (`#0F6E56`, `#7A8597` 등) — 데이터 시각화 도메인 컬러, 디자인 규범과 무관
- `session_recap_screen.dart`의 카테고리 컬러 (`#7B9EFF`, `#FB923C`, `#F87171`) — 문장 유형 분류용 의미 색, 별도 토큰화 작업으로 분리
- 레이아웃, 컴포넌트 구조 변경
- 공용 `ChorokPill` / `ChorokActionButton` 위젯 추출 (Approach B)

---

## 성공 기준

1. `flutter analyze`에서 기존 이상의 경고 없음
2. 다크 모드: 독서 세션 → 리캡 → 홈 → 피드 → 책 상세 탐색 시 컬러 단절 없음
3. 라이트 모드: 동일 경로에서 브랜드 그린이 `#009B58`으로 일관, `Divider`가 불가시
4. 디자인 앱(USE_MOCK) 에뮬레이터로 확인 → 테스트 앱 미러

## 환경 적용 순서 (CLAUDE.md §5)

1. 디자인 앱 (`USE_MOCK` = d1414 환경) 에서 변경 적용 후 에뮬레이터 확인
2. 테스트 앱 (실데이터 환경) 에 동일 변경 미러 (코드가 공유되므로 동일 커밋)
