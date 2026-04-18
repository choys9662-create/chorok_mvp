# 초록(Chorok) 앱 프론트엔드 디자인 시스템 & 구현 표준 v2.1

본 문서는 플러터(Flutter) 기반 '초록(Chorok)' 애플리케이션의 프론트엔드 구현을 위한 **단일 진실 공급원(Single Source of Truth)** 입니다. `CLAUDE.md`에 정의된 3단계 에이전트 하네스(Planner → Generator → Evaluator)의 절대적 시각적 기준이 되며, AI 코딩 에이전트는 코드를 생성하기 전 반드시 본 문서 전체를 숙지해야 합니다.

---

## 0. 디자인 토큰 아키텍처 (Token Architecture)

> **[하네스 명명 규칙 통합]** `CLAUDE.md`의 `AppTheme.*` 참조와 본 문서의 `Chorok*` 클래스는 동일한 토큰 체계를 가리킵니다. 아래 매핑을 코드 작성의 표준으로 삼으십시오.

### 0.1. 클래스 구조 정의

```dart
// 전역 토큰 접근 구조 (모든 에이전트 공통 기준)
//
// AppTheme.colors   → ChorokColors     (색상 토큰)
// AppTheme.metrics  → ChorokMetrics    (여백/사이즈 토큰)
// AppTheme.type     → ChorokTypography (타이포그래피 토큰)
// AppTheme.shapes   → ChorokShapes     (곡률/형태 토큰)
//
// ChorokColors / ChorokMetrics / ChorokTypography / ChorokShapes 는
// ThemeData에 ThemeExtension으로 등록된 불변(immutable) 클래스입니다.
// 어느 접근 방식이든 동일한 값을 참조합니다.
```

### 0.2. ChorokMetrics 스페이싱 토큰 (CLAUDE.md `spaceSM` 등 대응)

| 토큰 이름 | 값 | CLAUDE.md 대응 | 사용 맥락 |
| :--- | :--- | :--- | :--- |
| `spaceXXS` | 4px | — | 아이콘-텍스트 미세 간격 |
| `spaceXS` | 8px | — | 리스트 타일 요소 간격 |
| `spaceSM` | 16px | `spaceSM` | 동위 카드 간 수직 간격, 버튼 내부 패딩 |
| `spaceMD` | 20px | — | 카드 내부 균등 패딩 (소형) |
| `spaceLG` | 24px | — | 글로벌 마진, 카드 내부 패딩 (표준) |
| `spaceXL` | 48px | — | 섹션 구분 여백 (최소값) |
| `spaceXXL` | 64px | — | 섹션 구분 여백 (최대값) |

> **그리드 기준:** 기본 단위는 **8px 배수**입니다. 단, `spaceXXS`(4px)는 아이콘-텍스트 사이 등 마이크로 간격에 한해 허용됩니다. Evaluator의 "4의 배수" 기준은 곧 "최소 단위 4px의 배수(4, 8, 12, 16, 20, 24…)"를 의미하며, **10, 15, 18, 22px 등 4의 배수가 아닌 값은 절대 금지**합니다.

### 0.3. ChorokTypography 텍스트 스타일 토큰 (CLAUDE.md `bodyMedium` 등 대응)

| 토큰 이름 | CLAUDE.md 대응 | 위계 |
| :--- | :--- | :--- |
| `heroTitle` | — | Hero Title (28px) |
| `title1` | — | Title 1 (24px) |
| `title2` | — | Title 2 (20px) |
| `title3` | — | Title 3 (18px) |
| `bodyLarge` | `bodyLarge` | Body 1 (16px) |
| `bodyMedium` | `bodyMedium` | Body 2 (14px) |
| `caption` | `caption` | Caption (12px) |

---

## 1. 렌더링 핵심 전제 (Core Rendering Principles)

- **다크 모드 배제**: 오직 순백색과 라이트 그레이 기반의 라이트 테마(Light Theme)만을 단일 렌더링 대상으로 삼습니다.
- **그림자(Shadow) 엄격 금지**: `boxShadow` 또는 위젯의 `elevation` 속성을 이용한 깊이감 표현을 원천 차단합니다. 모든 Z-Index 계층과 공간의 깊이감은 오직 배경색(Background)과 표면색(Surface)의 명도 대비만으로 구현합니다.
- **매직 넘버(Magic Number) 금지**: 모든 여백, 곡률, 색상은 하드코딩하지 않고 `ChorokMetrics` 또는 `ChorokColors` ThemeExtension 인스턴스를 통해 반드시 주입합니다.
- **폰트 패밀리 표준**: **Pretendard**를 공식 기본 폰트로 사용합니다. iOS 기기의 폴백(Fallback)으로만 'Apple SD Gothic Neo'를 허용합니다. 모든 `TextStyle`에는 `fontFamily: 'Pretendard'`를 명시해야 하며, `ChorokTypography` 토큰을 통해 자동 적용됩니다. (Evaluator는 토큰 미사용 Text 위젯을 반려 대상으로 간주합니다.)

---

## 2. 곡률 아키텍처 (Corner Radius & Smoothing)

뾰족하거나 애매한 곡률은 시각적 단절을 일으킵니다. 완전히 둥근 **알약 모양(Pill-shape)**과 수학적으로 매끄러운 **스쿼클(Squircle)** 형태만 사용합니다.

**스쿼클 구현**: 외부 라이브러리 `figma_squircle`의 `SmoothRectangleBorder`를 적용하거나 Flutter 네이티브의 `ContinuousRectangleBorder`를 활용하여 iOS 수준의 코너 스무딩을 구현합니다(`cornerSmoothing: 1.0`). 곡률 적용 시 반드시 **`ChorokShapes.smooth*()`** 팩토리 메서드를 사용하고, `BorderRadius.circular()`를 직접 호출하는 것을 금지합니다.

| 위계 (Level) | 지정 수치 | Flutter 위젯 적용 대상 | ChorokShapes 메서드 |
| :--- | :--- | :--- | :--- |
| **Level 1 (8px)** | 8px | 배지, 툴팁, 체크박스, 스낵바, 태그 | `ChorokShapes.smoothSmall()` |
| **Level 2 (16px)** | 16px | 메인 CTA 버튼, 썸네일, TextField, 칩 | `ChorokShapes.smoothMedium()` |
| **Level 3 (24px)** | 24px | 독립 메인 카드(Card), 팝업 다이얼로그 | `ChorokShapes.smoothLarge()` |
| **Level 4 (32px)** | 32px | 바텀 시트(Bottom Sheet) 상단 모서리 | `ChorokShapes.smoothSheet()` (`only topLeft, topRight`) |
| **Level 5 (Max)** | 999px | FAB, 캐러셀 인디케이터, 소형 보조 버튼 | `ChorokShapes.pill()` |

---

## 3. 시각 비례와 여백 (Proportion & Spacing)

8px 배수 기반의 그리드 시스템을 철저히 따릅니다. `Section 0.2`의 ChorokMetrics 토큰을 참조하십시오.

**터치 타겟 이중 기준**: 두 기준은 서로 다른 레이어에 적용되므로 충돌하지 않습니다.

- **시각적 버튼 높이**: 메인 상호작용 요소(버튼, 폼)의 렌더링 높이는 최소 **56px** 이상
- **최소 터치 인식 영역**: 모든 탭 가능 위젯의 실제 히트 영역은 최소 **48×48px** (`GestureDetector` 또는 `InkWell` 패딩으로 보장)

| 여백 분류 (Type) | 토큰 | 지정 수치 | 적용 기준 |
| :--- | :--- | :--- | :--- |
| **Global Margin** | `spaceLG` | 24px | `Scaffold` body 최상단 패딩 (가로 스크롤 캐러셀 우측 마진 제외 가능) |
| **Inner Padding (표준)** | `spaceLG` | 24px | 카드 내부 균등 여백 `EdgeInsets.all(spaceLG)` |
| **Inner Padding (소형)** | `spaceMD` | 20px | 작은 카드 또는 밀도 높은 리스트 컨테이너 |
| **Micro Spacing** | `spaceXXS` / `spaceXS` | 4px / 8px | 아이콘-텍스트(4px), 리스트 타일 요소 간(8px) |
| **Element Spacing** | `spaceSM` | 16px | 동위 카드 간, 입력 필드 간 수직 간격 |
| **Section Spacing** | `spaceXL` ~ `spaceXXL` | 48px ~ 64px | 맥락이 완전히 다른 UI 섹션 분리 여백 |

*(도서 리스트 타일: 최소 높이 72px / 도서 썸네일: 48×64px, 비율 3:4)*

---

## 4. 타이포그래피 (Typography Architecture)

**기본 폰트**: Pretendard (폴백: Apple SD Gothic Neo — iOS 전용). 모든 텍스트 스타일은 `ChorokTypography` 토큰을 통해 주입하며, `Text` 위젯에 직접 `TextStyle`을 작성하는 것을 금지합니다.

**대제목 여백 강제**: 앱바 직후 등장하는 Hero Title 상단에는 `16px`, 하단에는 `32px`의 수직 여백(`SizedBox`)을 반드시 삽입합니다.

| 토큰 이름 | 폰트 사이즈 | 굵기 (Weight) | 자간 (Tracking) | 행간 (Height) |
| :--- | :--- | :--- | :--- | :--- |
| `heroTitle` | 28px | Bold (w700) | -0.5px | 1.4배 (39.2px) |
| `title1` | 24px | Bold (w700) | -0.3px | 1.4배 (33.6px) |
| `title2` | 20px | SemiBold (w600) | -0.3px | 1.5배 (30.0px) |
| `title3` | 18px | SemiBold (w600) | -0.2px | 1.5배 (27.0px) |
| `bodyLarge` | 16px | Medium (w500) | -0.1px | 1.5배 (24.0px) |
| `bodyMedium` | 14px | Medium (w500) | 0.0px | 1.5배 (21.0px) |
| `caption` | 12px | Regular (w400) | 0.0px | 1.5배 (18.0px) |

---

## 5. 표면 색상 및 컬러 시스템 (Surface & Colors)

시맨틱 네이밍(Semantic Naming)을 통해 `ChorokColors` ThemeExtension에 등록하여 사용합니다. `Colors.red` 또는 `Color(0xFF...)` 등 하드코딩된 색상은 전면 금지합니다.

### 5.1. Background & Surface (그림자 대체 계층 분리)

| 시맨틱 토큰 | 헥스 값 | 용도 |
| :--- | :--- | :--- |
| `backgroundBase` | `#F2F4F6` | Scaffold 바닥 배경색 |
| `surfaceBase` | `#FFFFFF` | 카드, 다이얼로그, 폼 컨테이너 표면색 |
| `surfaceDimmed` | `#000000` @ 40% | 모달 호출 시 배경 딤(Dim) 처리 |
| `divider` | `#E5E8EB` | 구분선 및 미세 테두리 |

### 5.2. Text Grayscale (가독성 통제)

| 시맨틱 토큰 | 헥스 값 | 용도 |
| :--- | :--- | :--- |
| `textPrimary` | `#191F28` | 대제목, 핵심 정보 |
| `textSecondary` | `#333D4B` | 주요 본문 단락 |
| `textTertiary` | `#8B95A1` | 플레이스홀더, 비활성 텍스트, 캡션 |
| `textQuaternary` | `#B0B8C1` | 가장 덜 중요한 메타데이터 |

### 5.3. Brand Green (액션 포인트)

| 시맨틱 토큰 | 헥스 값 | 용도 |
| :--- | :--- | :--- |
| `green500` | `#03B26C` | 메인 CTA 배경, 스위치 ON, 선택된 탭바 |
| `green700` | `#029359` | 버튼 터치 시 즉각적인 피드백 컬러 |
| `green50` | `#F0FAF6` | 특정 텍스트 버튼 배경 틴트 |

---

## 6. 컴포넌트 해체 청사진 (Component Blueprints)

### 6.1. 컨텐츠 메인 카드 (Base Information Card)

- **배경색**: `surfaceBase` (`#FFFFFF`)
- **곡률/여백**: Level 3(24px) 스쿼클 곡률 (`ChorokShapes.smoothLarge()`), 하단 외부 여백 `spaceSM(16px)`, 내부 패딩 `spaceLG(24px)` 균등 적용
- **제약사항**: 부모 Scaffold 배경은 무조건 `backgroundBase`(`#F2F4F6`)이며, `elevation: 0.0` 강제

### 6.2. 프라이머리 하단 고정 버튼 (Fixed Bottom CTA)

- **크기**: 너비 `double.infinity`, 높이 `56px`
- **여백**: 좌우 마진 `spaceLG(24px)`, 하단 마진 `MediaQuery.padding.bottom + 16.0` (Safe Area 보호)
- **스타일**: 배경색 `green500`(`#03B26C`), Level 2(16px) 스쿼클 곡률, `bodyLarge` 텍스트(w600, `textOnPrimary: #FFFFFF`)
- **제약사항**: 화면 스크롤과 무관하게 하단 고정. 상단 투명도 그라데이션(Fade-out) 및 그림자 효과 절대 금지

### 6.3. 텍스트 입력 폼 (Text Input Field)

- **크기**: 최소 높이 `56px`, 내부 텍스트 패딩 `spaceSM(16px)`
- **디폴트 상태**: 배경색 `backgroundBase`(`#F2F4F6`)
- **포커스 상태**: 배경색 `surfaceBase`(`#FFFFFF`)로 전환, 테두리 두께 `1.5px`의 `green500`(`#03B26C`) 라인 생성
- **텍스트**: 플레이스홀더 `textTertiary`, 입력 텍스트 `textPrimary`

### 6.4. 금지된 컴포넌트 패턴 (Anti-Patterns)

다음 패턴은 Evaluator의 하드 반려(Reject) 대상입니다. 어떠한 이유로도 사용하지 마십시오.

- **고정 높이 컬러 바 (Accent Bar)**: `Container(height: N, color: ...)` 형태로 카드나 리스트 타일 좌측에 세로 강조 바를 구현하는 패턴. 대신 `Row` + `CrossAxisAlignment.stretch` + `IntrinsicHeight`를 통해 부모 높이에 자동 종속되도록 구현해야 합니다.
- **Column 기반 긴 리스트**: 5개 이상의 동종 아이템을 `Column`에 나열하는 패턴. 반드시 `ListView.builder` 또는 `SliverList`를 사용하십시오.
- **직접 BorderRadius 호출**: `BorderRadius.circular(N)` 또는 `BorderRadius.only(...)` 직접 사용 금지. 반드시 `ChorokShapes.smooth*()` 메서드를 경유해야 합니다.

---

## 7. 디자인 토큰 Flutter 구현 참조 (Implementation Reference)

```dart
// ChorokColors — ThemeExtension<ChorokColors>
// AppTheme.colors(context) 로 접근
abstract class ChorokColors {
  static const backgroundBase = Color(0xFFF2F4F6);
  static const surfaceBase    = Color(0xFFFFFFFF);
  static const divider        = Color(0xFFE5E8EB);
  static const textPrimary    = Color(0xFF191F28);
  static const textSecondary  = Color(0xFF333D4B);
  static const textTertiary   = Color(0xFF8B95A1);
  static const textQuaternary = Color(0xFFB0B8C1);
  static const green500       = Color(0xFF03B26C);
  static const green700       = Color(0xFF029359);
  static const green50        = Color(0xFFF0FAF6);
}

// ChorokMetrics — 상수 클래스 (불변)
// AppTheme.metrics 로 접근
abstract class ChorokMetrics {
  static const spaceXXS = 4.0;
  static const spaceXS  = 8.0;
  static const spaceSM  = 16.0;
  static const spaceMD  = 20.0;
  static const spaceLG  = 24.0;
  static const spaceXL  = 48.0;
  static const spaceXXL = 64.0;
  static const touchTargetMin    = 48.0;  // 최소 터치 인식 영역
  static const buttonHeightMin   = 56.0;  // 시각적 버튼 최소 높이
  static const bookThumbnailW    = 48.0;
  static const bookThumbnailH    = 64.0;
  static const listTileMinHeight = 72.0;
}
```

---

## 8. 애니메이션 & 햅틱 토큰 (Animation & Haptic Tokens)

> Generator 에이전트가 참조하는 `kAnimNormal` 등 모든 애니메이션 상수는 본 섹션에 정의됩니다.

### 8.1. 지속 시간 상수

```dart
abstract class ChorokAnimations {
  static const kAnimFast    = Duration(milliseconds: 150); // 즉각 피드백 (버튼 색상 전환)
  static const kAnimNormal  = Duration(milliseconds: 250); // 표준 전환 (페이지, 카드 확장)
  static const kAnimSlow    = Duration(milliseconds: 400); // 강조 전환 (온보딩, 모달 진입)
  static const kAnimXSlow   = Duration(milliseconds: 600); // 연출 애니메이션 (스플래시)
}
```

### 8.2. 커브 표준

| 맥락 | 커브 | 사용 기준 |
| :--- | :--- | :--- |
| 화면 진입 | `Curves.easeOutCubic` | 요소가 화면 내부로 들어오는 모든 전환 |
| 화면 퇴장 | `Curves.easeInCubic` | 요소가 화면 밖으로 나가는 모든 전환 |
| 상태 전환 | `Curves.easeInOut` | 탭 선택, 로딩 완료 등 in-place 상태 변경 |
| 물리적 반응 | `Curves.elasticOut` | FAB 등 눈에 띄는 강조 UI에 한해 제한적 사용 |

### 8.3. 햅틱 피드백 정책

```dart
// 모든 메인 CTA 버튼 onPressed:
HapticFeedback.mediumImpact();   // 메인 액션 확정 (저장, 다음 등)
HapticFeedback.lightImpact();    // 보조 액션 (선택, 토글, 탭)
HapticFeedback.heavyImpact();    // 삭제, 경고성 확정 액션에만 사용
```

---

## 9. 접근성 표준 (Accessibility Standards)

> Evaluator 에이전트의 "UX 결함 검사" 항목의 근거 정의입니다.

### 9.1. 터치 타겟 & Semantics 필수 요건

- 모든 탭 가능한 위젯은 실제 히트 영역이 최소 **48×48px**를 충족해야 합니다.
- 모든 인터랙티브 요소에는 `Semantics` 위젯으로 `label`을 명시해야 합니다.

```dart
// 올바른 구현 예시
Semantics(
  label: '독서 기록 저장 버튼',
  button: true,
  child: SizedBox(
    width: double.infinity,
    height: ChorokMetrics.buttonHeightMin, // 56px
    child: ElevatedButton(/* ... */),
  ),
)
```

### 9.2. 색상 대비 기준 (WCAG AA)

- 모든 텍스트 요소는 배경 대비 최소 **4.5:1** 대비율을 충족해야 합니다.
- `textTertiary`(`#8B95A1`) on `backgroundBase`(`#F2F4F6`) 조합은 캡션 전용으로만 사용합니다.

---

## 10. 4-State UI 렌더링 패턴 (Four-State Rendering Pattern)

> `CLAUDE.md` Generator 에이전트 제 3항 "4단계 상태 렌더링"의 근거 정의입니다.
> 모든 비동기 데이터에 의존하는 UI 컴포넌트는 예외 없이 이 4가지 상태를 `switch` 문으로 완전히 분기 처리해야 합니다.

### 10.1. 상태 정의

```dart
enum UiState<T> {
  loading,             // 데이터 로드 중
  success(T data),     // 데이터 로드 성공 (1개 이상)
  empty,               // 데이터 없음 (성공이지만 결과 0건)
  error(String msg),   // 오류 발생
}
```

### 10.2. 렌더링 규칙

| 상태 | 렌더링 방식 | 금지 사항 |
| :--- | :--- | :--- |
| **Loading** | `Shimmer` 스켈레톤 (실제 레이아웃 형태 모방) | `CircularProgressIndicator` 사용 금지 |
| **Success** | 정상 콘텐츠 위젯 | — |
| **Empty** | 일러스트 + 안내 메시지 + 선택적 CTA 버튼 | 빈 `Container` 또는 빈 `SizedBox` 단독 반환 금지 |
| **Error** | 오류 메시지 + 재시도(`retry`) 버튼 | `print()` 또는 로그만 출력 후 무시 금지 |

### 10.3. 구현 예시 골격

```dart
// Shimmer 스켈레톤: 실제 카드와 동일한 비율의 회색 블록
Widget _buildLoadingSkeleton() => Shimmer.fromColors(
  baseColor: ChorokColors.backgroundBase,
  highlightColor: ChorokColors.divider,
  child: Container(
    height: 120,
    decoration: ShapeDecoration(
      color: ChorokColors.backgroundBase,
      shape: ChorokShapes.smoothLarge(),
    ),
  ),
);

// 빈 상태: 일러스트 + 메시지 + CTA
Widget _buildEmptyState() => Column(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    SvgPicture.asset('assets/empty_books.svg', height: 120),
    const SizedBox(height: ChorokMetrics.spaceLG),
    Text('아직 기록된 책이 없어요', style: AppTheme.type.title3),
    const SizedBox(height: ChorokMetrics.spaceSM),
    Text('첫 번째 책을 추가해보세요', style: AppTheme.type.bodyMedium),
  ],
);

// switch 분기 예시
return switch (state) {
  UiState.loading   => _buildLoadingSkeleton(),
  UiState.success() => _buildContent(state.data),
  UiState.empty     => _buildEmptyState(),
  UiState.error()   => _buildErrorState(state.msg, onRetry: _reload),
};
```

---

## 11. 아키텍처 패턴 (Architecture Patterns)

### 11.1. 계층 분리 원칙

Generator 에이전트는 모든 코드를 아래 계층 구조로 엄격히 분리해야 합니다.

```
Presentation Layer  (Widget / View)
        ↕
State Layer         (Controller / Notifier / ViewModel)
        ↕
Domain Layer        (UseCase / Repository Interface)
        ↕
Data Layer          (Repository Impl / API / Local DB)
```

- **Presentation Layer**에는 `AppTheme.*` 참조, `const` 위젯 선언, 빌드 최적화 로직만 포함합니다.
- **State Layer** 이하에는 UI 참조(`BuildContext`, 위젯 클래스 등)를 포함하지 않습니다.

### 11.2. `const` 최적화 강제

- 정적인 모든 위젯 요소(`Icon`, `SizedBox`, `Divider`, 텍스트 상수 등)에는 `const` 키워드를 집요하게 추가합니다.
- Evaluator는 `const` 가 누락된 정적 위젯을 성능 결함으로 간주하여 반려 대상에 포함합니다.

---

## 12. 에이전트 자가 검증 파이프라인 (Agent Self-Verification Checklist)

AI 에이전트는 위젯 트리를 커밋하기 직전, 아래 12개 항목을 순서대로 통과해야 합니다. **하나라도 위반 시 즉시 코드를 수정하고 재검증**하십시오.

| # | 검증 항목 | 통과 기준 |
| :--- | :--- | :--- |
| 1 | **컬러 하드코딩** | 모든 색상이 `ChorokColors.*` 또는 `AppTheme.colors.*` 경유 |
| 2 | **수치 하드코딩** | 모든 여백/사이즈가 `ChorokMetrics.*` 경유 또는 4의 배수 |
| 3 | **곡률 직접 호출** | `BorderRadius.circular()` 직접 호출 없음, `ChorokShapes.*` 사용 |
| 4 | **그림자 억제** | `boxShadow`, `elevation > 0` 속성 전무 |
| 5 | **글로벌 마진** | Scaffold body 좌우 마진 `spaceLG(24px)` 보호 |
| 6 | **터치 타겟** | 모든 버튼 시각적 높이 ≥ 56px, 히트 영역 ≥ 48×48px |
| 7 | **Semantics** | 모든 인터랙티브 요소에 `Semantics(label: ...)` 래핑 |
| 8 | **폰트 패밀리** | `ChorokTypography` 토큰을 사용하지 않는 `Text` 위젯 없음 |
| 9 | **텍스트 행간** | `TextStyle.height`가 1.4 또는 1.5배수로 적용 |
| 10 | **4-State 완전 분기** | 비동기 UI의 Loading/Success/Empty/Error 4상태 모두 처리 |
| 11 | **const 최적화** | 정적 위젯에 `const` 키워드 누락 없음 |
| 12 | **금지 패턴 부재** | Accent Bar, Column 긴 리스트, 직접 BorderRadius 호출 없음 |

> **[자동 확장 구역]** Evaluator 에이전트가 새로운 위반 유형을 발견하면 위 테이블 끝에 새 행을 추가합니다. 기존 항목의 번호나 내용은 절대 변경하지 않습니다.

---

## 13. 안티패턴 레지스트리 (Anti-Pattern Registry)

> **[Evaluator 전용 갱신 구역]** 코드 검증 중 기존 체크리스트에 없는 새로운 위반 패턴이 발견되면, Evaluator는 반드시 아래 테이블에 항목을 추가해야 합니다. Generator는 매 작업 시작 시 이 섹션을 정독하여 동일한 실수를 반복하지 않을 의무가 있습니다.

### 등록 형식

```
| 등록일 | 발생 횟수 | 위반 유형 (요약) | ❌ 잘못된 패턴 | ✅ 올바른 패턴 | 근거 섹션 |
```

### 레지스트리 테이블

| 등록일 | 발생 횟수 | 위반 유형 | ❌ 잘못된 패턴 | ✅ 올바른 패턴 | 근거 섹션 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-04-17 | 1 | 라이트 배경 위 neon 초록 직접 사용 — 가시성 불충분 | `color: AppTheme.primaryLight` (정적 const #00FF00, 라이트 배경 대비 미달) | `color: context.appPrimaryAccent` (다크: #00FF00, 라이트: #1B7A3A ~7.2:1) | §2 토큰 사용 원칙 |
| 2026-04-17 | 1 | accent(#00CC6A)를 라이트 배경에 직접 적용 — 대비 불충분 | `color: AppTheme.accent` (정적 const) | `color: context.appAccentColor` | §2 토큰 사용 원칙 |

> 이 테이블이 비어있다면 아직 새로운 위반 유형이 발견되지 않은 것입니다. 레지스트리가 채워질수록 시스템의 품질 면역력이 강해집니다.

---

## 14. 사용자 변경 요청 이력 (User Change Request Log)

> **[Planner 전용 갱신 구역]** 사용자가 기존 디자인 규칙의 변경을 요청하면, Planner는 `DESIGN.md` 관련 섹션을 수정한 후 반드시 아래 테이블에 변경 내역을 기록해야 합니다. 이 이력은 의사결정의 맥락을 보존하고 향후 에이전트가 변경의 '이유'를 이해하는 데 사용됩니다.

### 등록 형식

```
| 요청일 | 요청자 | 변경 대상 섹션 | 변경 이전 내용 (요약) | 변경 이후 내용 (요약) | 사유 |
```

### 변경 요청 테이블

| 요청일 | 요청자 | 변경 대상 섹션 | 변경 이전 (요약) | 변경 이후 (요약) | 사유 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-04-17 | 사용자 | §2 색상 토큰, AppThemeExt | primaryLight(#00FF00)·accent(#00CC6A)를 라이트 모드에서도 직접 사용 | `lightPrimaryAccent`(#1B7A3A) 토큰 추가, `appPrimaryAccent`·`appAccentColor` 확장으로 모드별 분기 | 라이트 배경에서 neon 그린의 가시성(대비비) 불충분 |

---

## 15. 문서 버전 이력 (Document Revision History)

> 모든 에이전트는 `DESIGN.md`를 수정할 때마다 반드시 이 섹션에 기록을 추가합니다. 버전은 `vMAJOR.MINOR` 규칙을 따릅니다. 사용자 변경 요청 또는 섹션 추가 시 MINOR를 올리고, 핵심 설계 변경 시 MAJOR를 올립니다.

| 버전 | 날짜 | 작성/수정 주체 | 변경 내용 요약 |
| :--- | :--- | :--- | :--- |
| v1.0 | (최초 작성일) | 사용자 | 초기 UI/UX 아키텍처 가이드 작성 |
| v2.0 | (통합 작성일) | Planner | CLAUDE.md 하네스와 충돌 해소, 섹션 0·7·8·9·10·11·12 추가 |
| v2.1 | (현재) | Planner | 자기 갱신 프로토콜 연동 — §13 안티패턴 레지스트리, §14 변경 요청 이력, §15 버전 이력 추가 |
| v2.2 | 2026-04-17 | Planner | 라이트 모드 브랜드 컬러 가시성 개선 — `lightPrimaryAccent`(#1B7A3A) 토큰 추가, `appPrimaryAccent`·`appAccentColor` AppThemeExt 확장 추가, §13·§14에 위반 패턴 및 변경 이력 등록 |
