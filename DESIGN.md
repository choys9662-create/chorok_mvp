# 초록(Chorok) 앱 프론트엔드 코어 UI/UX 아키텍처 가이드

본 문서는 플러터(Flutter) 기반 '초록(Chorok)' 애플리케이션의 프론트엔드 구현을 위한 구조적 명세서입니다. AI 코딩 에이전트는 코드를 생성할 때 본 문서에 명시된 곡률, 여백, 비례, 색상 톤, 렌더링 규칙을 한 치의 오차 없이 절대적으로 준수해야 합니다.

## 1. 렌더링 핵심 전제 (Core Rendering Principles)
- **다크 모드 배제**: 오직 순백색과 라이트 그레이 기반의 라이트 테마(Light Theme)만을 단일 렌더링 대상으로 삼습니다.
- **그림자(Shadow) 엄격 금지**: `boxShadow` 또는 위젯의 `elevation` 속성을 이용한 깊이감 표현을 원천 차단합니다. 모든 Z-Index 계층과 공간의 깊이감은 오직 배경색(Background)과 표면색(Surface)의 명도 대비만으로 구현합니다.
- **매직 넘버(Magic Number) 금지**: 모든 여백, 곡률, 색상은 하드코딩하지 않고 전역 상수(예: `ChorokMetrics`) 또는 테마 인스턴스(`ThemeExtension`)를 통해 주입합니다.

---

## 2. 곡률 아키텍처 (Corner Radius & Smoothing)
- 뾰족하거나 애매한 곡률은 시각적 단절을 일으킵니다. 완전히 둥근 **알약 모양(Pill-shape)**과 수학적으로 매끄러운 **스쿼클(Squircle)** 형태만 사용합니다.
- **스쿼클 구현**: 외부 라이브러리인 `figma_squircle`의 `SmoothRectangleBorder`를 적용하거나 플러터 네이티브의 `ContinuousRectangleBorder`를 활용하여 iOS 수준의 코너 스무딩을 구현합니다. (`cornerSmoothing: 1.0`)

| 위계 (Level) | 지정 수치 | 플러터 위젯 적용 대상 | 권장 렌더링 방식 |
| :--- | :--- | :--- | :--- |
| **Level 1 (8px)** | 8px | 배지, 툴팁, 체크박스, 스낵바, 태그 | `SmoothRectangleBorder(cornerRadius: 8)` |
| **Level 2 (16px)** | 16px | 메인 CTA 버튼, 썸네일, TextField, 칩 | `SmoothRectangleBorder(cornerRadius: 16)` |
| **Level 3 (24px)** | 24px | 독립적인 메인 카드(Card), 팝업 다이얼로그 | `SmoothRectangleBorder(cornerRadius: 24)` |
| **Level 4 (32px)** | 32px | 바텀 시트(Bottom Sheet) 상단 모서리 | `SmoothRectangleBorder`에 `only(topLeft, topRight)` 32px 적용 |
| **Level 5 (Max)** | 999px | FAB, 캐러셀 인디케이터, 소형 보조 버튼 | `RoundedRectangleBorder(borderRadius: circular(999))` |

---

## 3. 시각 비례와 여백 (Proportion & Spacing)
- 8px 배수 기반의 그리드 시스템을 철저히 따릅니다.
- **터치 타겟 최적화**: 모든 메인 상호작용 요소(버튼, 폼)의 높이는 최소 **56px** 이상으로 강제합니다.

| 여백 분류 (Type) | 지정 수치 | 레이아웃 적용 기준 및 플러터 구현 가이드 |
| :--- | :--- | :--- |
| **Global Margin** | 24px | `Scaffold` body 최상단 패딩 적용. (단, 가로 스크롤 캐러셀은 우측 마진 무시 가능) |
| **Inner Padding** | 20px / 24px | 카드 내부 균등 여백 (`EdgeInsets.all(20.0)` 또는 `24.0`) |
| **Micro Spacing** | 4px / 8px | 아이콘-텍스트 사이(4px), 리스트 타일 요소 간격(8px) |
| **Element Spacing** | 16px | 위계가 같은 카드 사이, 입력 필드 사이의 수직 간격 (`SizedBox(height: 16)`) |
| **Section Spacing** | 48px ~ 64px | 맥락이 완전히 다른 UI 섹션 사이의 분리 여백 |

*(※ 도서 리스트 타일: 최소 높이 72px / 도서 썸네일: 48px × 64px, 비율 3:4)*

---

## 4. 타이포그래피 (Typography Architecture)
- **기본 폰트**: 산세리프 계열 시스템 폰트 (Pretendard 또는 Apple SD Gothic Neo)
- **대제목 여백 강제**: 앱바 직후 등장하는 Hero Title 상단에는 `16px`, 하단에는 `32px`의 수직 여백(`SizedBox`)을 반드시 삽입합니다.

| 위계 토큰 | 폰트 사이즈 | 굵기 (Weight) | 자간 (Tracking) | 행간 (Height / Multiplier) |
| :--- | :--- | :--- | :--- | :--- |
| **Hero Title** | 28px | Bold (w700) | -0.5px | 1.4배 (39.2px) |
| **Title 1** | 24px | Bold (w700) | -0.3px | 1.4배 (33.6px) |
| **Title 2** | 20px | SemiBold (w600)| -0.3px | 1.5배 (30.0px) |
| **Title 3** | 18px | SemiBold (w600)| -0.2px | 1.5배 (27.0px) |
| **Body 1** | 16px | Medium (w500) | -0.1px | 1.5배 (24.0px) |
| **Body 2** | 14px | Medium (w500) | 0.0px | 1.5배 (21.0px) |
| **Caption** | 12px | Regular (w400) | 0.0px | 1.5배 (18.0px) |

---

## 5. 표면 색상 및 컬러 시스템 (Surface & Colors)
시맨틱 네이밍(Semantic Naming)을 통해 플러터 테마(`ThemeExtension`)에 등록하여 사용합니다.

- **Background & Surface (그림자 대체용 계층 분리)**
  - `Background Base`: `#F2F4F6` (Scaffold의 바닥 배경색)
  - `Surface Base`: `#FFFFFF` (카드, 다이얼로그, 폼 컨테이너 표면색)
  - `Surface Dimmed`: `#000000` (40% Opacity, 모달 호출 시 뒷배경 딤 처리)
  - `Divider / Border`: `#E5E8EB` (구분선 및 미세 테두리)

- **Text Grayscale (가독성 통제)**
  - `Text Primary`: `#191F28` (대제목, 핵심 정보)
  - `Text Secondary`: `#333D4B` (주요 본문 단락)
  - `Text Tertiary`: `#8B95A1` (플레이스홀더, 비활성 텍스트, 캡션)
  - `Text Quaternary`: `#B0B8C1` (가장 덜 중요한 메타데이터)

- **Brand Green (액션 포인트)**
  - `Green 500 (Primary)`: `#03B26C` (메인 CTA 배경, 스위치 ON, 선택된 탭바)
  - `Green 700 (Pressed)`: `#029359` (버튼 터치 시 즉각적인 피드백 컬러)
  - `Green 50 (Surface)`: `#F0FAF6` (특정 텍스트 버튼 배경 틴트)

---

## 6. 컴포넌트 해체 청사진 (Component Blueprints)

### 6.1. 컨텐츠 메인 카드 (Base Information Card)
- **배경색**: Surface Base (`#FFFFFF`)
- **곡률/여백**: 24px 스쿼클 곡률, 하단 외부 여백 `16px`, 내부 패딩 `24px` 균등 적용.
- **제약사항**: 부모 Scaffold 배경은 무조건 Background Base(`#F2F4F6`)여야 하며, `elevation: 0.0` 강제.

### 6.2. 프라이머리 하단 고정 버튼 (Fixed Bottom CTA)
- **크기**: 너비 `double.infinity`, 높이 `56px`.
- **여백**: 좌우 마진 `24px`, 하단 마진 `MediaQuery.padding.bottom + 16.0` (Safe Area 보호).
- **스타일**: 배경색 Green 500 (`#03B26C`), 16px 스쿼클 곡률. Body 1 텍스트(w600, `#FFFFFF`).
- **제약사항**: 화면 스크롤과 무관하게 하단 고정. 상단 투명도 그라데이션(Fade-out)이나 그림자 효과 절대 금지.

### 6.3. 텍스트 입력 폼 (Text Input Field)
- **크기**: 최소 높이 `56px`, 내부 텍스트 패딩 `16px`.
- **디폴트 상태**: 배경색 Background Base (`#F2F4F6`).
- **포커스 상태**: 배경색 Surface Base (`#FFFFFF`)로 전환되며, 테두리에 두께 `1.5px`의 Green 500 (`#03B26C`) 라인 생성.
- **텍스트**: 플레이스홀더 `Text Tertiary`, 입력 텍스트 `Text Primary`.

---

## 7. 플러터 시스템 적용 파이프라인 (에이전트 자가 검증 필수)
AI 에이전트는 위젯 트리를 렌더링하기 직전, 자신이 작성한 코드가 아래 파이프라인을 통과하는지 검사해야 합니다.

1. **컬러 하드코딩 여부**: `ChorokColors`라는 `ThemeExtension` 구조를 생성하여 모든 컬러값을 전역으로 매핑했는가?
2. **그림자 억제**: 레이아웃 내부 어딘가에 `boxShadow`, `elevation > 0` 속성이 숨어있지 않은가? (전면 금지)
3. **절대 마진 준수**: 화면의 `Scaffold` Body 좌우 마진이 `24px`(`ChorokMetrics` 참조)로 보호되고 있는가?
4. **터치 타겟 방어**: 버튼 및 텍스트 폼의 높이가 `56px` 규격을 충족하는가?
5. **텍스트 행간**: `TextTheme` 오버라이딩 시 `height` 파라미터가 1.4 또는 1.5배수로 올바르게 적용되었는가?
