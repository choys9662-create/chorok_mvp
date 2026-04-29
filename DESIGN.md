# 🌿 Chorok Design System (DESIGN.md)

이 문서는 '초록(Chorok)' 앱의 일관적인 브랜드 경험과 유려한 UI 구현을 위한 공식 디자인 가이드라인입니다. 모든 위젯 구현 시 본 문서의 규격과 테마 토큰을 최우선으로 준수합니다.

## 1. 컬러 팔레트 (Color Palette)

토스(Toss) 스타일의 시원하고 정돈된 라이트 모드와 기존 다크 모드를 시맨틱하게 관리합니다.

| 구분 | Light Mode (Toss Style) | Dark Mode | 주요 사용처 |
| :--- | :--- | :--- | :--- |
| **Scaffold Bg** | `#F2F4F6` | `#121212` | 앱 전체 배경 |
| **Surface (Card)** | `#FFFFFF` | `#1A1A1A` | 섹션별 카드, 위젯 배경 |
| **Primary Green** | `#009B58` | `#10B981` | 브랜드 핵심 컬러, CTA 버튼 |
| **Primary Container** | `#E6F5ED` | `#1E3A2F` | 선택된 항목, 연한 강조 배경 |
| **Text Primary** | `#191F28` | `#FFFFFF` | 제목, 주요 본문 텍스트 |
| **Text Secondary** | `#8B95A1` | `#ADADAD` | 부가 설명, 날짜, 서브 텍스트 |
| **Text Tertiary** | `#B0B8C1` | `#6B6B6B` | 힌트 텍스트, 비활성 상태 |
| **Border / Divider** | `#E5E8EB` | `#2C2C2C` | 구분선, 옅은 테두리 |

## 2. 부드러운 가장자리 시스템 (Radius Hierarchy)

초록 앱은 직선에서 곡선으로 넘어가는 경계가 보이지 않는 Continuous Curve (Squircle) 방식을 채택합니다. 위젯의 크기와 역할에 따라 5가지 유형으로 구분합니다.

### 유형 1: XL (Radius: 24px)
- **용도**: 레이아웃의 가장 큰 뼈대를 이루는 메인 컨테이너
- **적용 예시**: 프로필 카드 전체 영역, 대시보드 메인 섹션, 모달 바텀 시트 상단 곡률
- **효과**: `AppTheme.smoothBox(radius: 24)`

### 유형 2: Large (Radius: 18px)
- **용도**: 시각적 강조가 필요한 중간 크기의 콘텐츠 박스
- **적용 예시**: 도서 표지(Thumbnail) 강조 박스, 주요 히어로 섹션 내 이미지 컨테이너
- **효과**: `AppTheme.smoothBox(radius: 18)`

### 유형 3: Medium (Radius: 12px)
- **용도**: 사용자가 조작하는 표준 UI 요소
- **적용 예시**: 표준 버튼(Filled/Outlined), 검색창(TextField), 리스트 타일(ListTile) 배경
- **효과**: `AppTheme.smoothBox(radius: 12)`

### 유형 4: Small (Radius: 8px)
- **용도**: 정보 위계상 가장 작은 단위의 구성 요소
- **적용 예시**: 태그(Tag), 작은 아이콘 배경 박스, 체크박스 커스텀 위젯
- **효과**: `AppTheme.smoothBox(radius: 8)`

### 유형 5: Pill (Radius: 9999px)
- **용도**: 좌우가 완벽히 둥근 독립적인 상태 표시 요소
- **적용 예시**: 🔥 스트릭 배지, 팔로우/팔로잉 상태 칩, 알림 숫자 칩
- **효과**: `AppTheme.smoothPill()`

## 3. 구현 지침 (Implementation Rules)

- **8px Grid System**: 모든 여백(Padding/Margin)과 크기 조절은 8의 배수(8, 16, 24, 32, 48)를 사용하여 공간의 리듬감을 유지한다.
- **Smoothing Only**: 플러터 기본 `BorderRadius.circular` 사용을 지양하고, 반드시 테마에 정의된 `smoothBox` 메소드를 사용하여 일관된 물성을 표현한다.
- **Contrast Rule**: 텍스트 가시성을 위해 배경색과 텍스트 색상 간 충분한 대비를 확보한다. (본문 텍스트에 브랜드 초록색 사용 금지)
- **Brand Color Unity**: 동일 화면에서 브랜드 초록 포인트 컬러는 반드시 `context.appPrimaryAccent`(`#009B58` 라이트 / `#10B981` 다크)로 통일한다. `primaryBg(alpha)` 함수는 배경 틴트(연한 배경 강조)에만 사용하며, CTA 버튼·탭 선택 배경·진행 바 등 강조 요소에는 opacity 변형 없이 원색을 사용한다. 흰색 배경 위 투명도 적용은 명도 차이를 만들어 색 통일감을 해친다.

## 14. 변경 이력 (Change Log)

| 날짜 | 변경 | 이유 |
| :--- | :--- | :--- |
| 2026-04-29 | 웹 배포 환경 분리: `chorok-d1414`(디자인, USE_MOCK=true) / `chorok-real`(실사용, Supabase) | 디자인 미리보기와 실사용을 도메인 차원에서 분리. 데이터 영속성 + Google 로그인은 실사용 환경에만 활성화. |
| 2026-04-29 | 웹 빌드용 `SupabaseBookRepository` 추가, `library_provider`가 `kIsWeb` 분기 | 웹은 sqflite 미초기화이므로 책 데이터를 Supabase `public.books`에 저장. 다른 브라우저/기기에서 같은 계정으로 로그인 시 동일 서재 유지. |
| 2026-04-29 | 웹 Google 로그인을 Supabase OAuth redirect 방식으로 구현 | `google_sign_in.signIn()`은 모바일 전용. 웹은 `supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: origin)` + `appRouterProvider`의 `refreshListenable`로 자동 라우팅. |

## 15. 버전 (Version)

- **v0.3 (2026-04-29)**: 웹 배포 분리 + Supabase 책 동기화 + 웹 Google 로그인.
