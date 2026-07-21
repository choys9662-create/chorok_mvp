# 컴포넌트 · 토큰 레퍼런스

design.md가 **규칙과 값**(왜 이 색, 왜 이 간격)을 정한다면, 이 문서는 **코드에서 뭘 타이핑하는지**를 정리한다. 화면을 만들 때 hex·px를 직접 쓰지 말고 아래 심볼만 조립한다.

값의 근거·역할은 design.md를, 실제 정의는 `lib/core/theme/app_theme.dart`를 본다. 값(숫자)은 여기 중복하지 않는다 — 바뀔 수 있으므로 심볼 이름만 신뢰한다.

## 토큰 (AppTheme)

**색** — 6색 팔레트(design.md §2). 화면에서는 `context.app*` 확장을 우선 쓴다(다크/라이트 자동 분기).

| 쓸 심볼 | 역할 |
|---|---|
| `context.appBg` | 기준 배경 |
| `context.appCard` | 바깥 박스 surface |
| `context.appCardElevated` / `AppTheme.darkNested` | 이너 박스 surface |
| `context.appPrimaryAccent` / `AppTheme.accent` | 브랜드 그린 (active/CTA/focus 전용) |
| `context.appTextPrimary` | 본문 텍스트 |
| `context.appTextSecondary` / `appTextTertiary` | 보조 텍스트 |
| `context.appBorder` | 구분선·테두리 |

**타이포** — 6단계(design.md §3). `AppTheme.<이름>`.

| 심볼 | 용도 |
|---|---|
| `screenTitle` | 큰 제목 |
| `sectionTitle` | 섹션 제목 |
| `rowText` | 행 텍스트 |
| `body` | 본문 |
| `supportingText` | 보조 |
| `caption` | 캡션 |
| `displayMedium` | 세션 타이머·통계 hero (스케일 예외) |

**간격** — 래더 6단계(design.md §4). `AppTheme.<이름>`.

`spaceXS` · `spaceSM` · `spaceMD` · `spaceLG` · `space2XL` · `sectionGap`(=`space3XL`). `screenPadding`은 화면 좌우 여백 전용.

- 나열 간격은 `Column(spacing: AppTheme.sectionGap)` / `Row(spacing:)`으로 컨테이너가 책임진다. `SizedBox`로 손간격을 박지 않는다.
- 래더에 없는 값(18, 20, 22 등)은 토큰이 없다 — 새로 쓰지 말고, 발견하면 가장 가까운 래더 값으로 스냅할지 사용자에게 확인한다.

**곡률** — 2단계(design.md §5). `AppTheme.radiusOuter`(바깥 박스) / `radiusInner`(이너 박스). smooth corner는 `AppTheme.smoothBox(...)` / `smoothShape(...)` / `smoothBorder(...)`가 자동 적용.

## 공용 위젯 (lib/shared/widgets)

새 위젯은 "기존 조합으로 못 만들고 + 3곳 이상 반복"일 때만 만든다. 한 화면 전용 조각은 그 feature 폴더에 둔다.

| 위젯 | 용도 | 핵심 파라미터 |
|---|---|---|
| `ChorokCard` | 모든 박스. 기본 padding·radius·surface 내장 | `inner`(이너 박스), `hasShadow`, `showBorder`, `padding` |
| `ChorokProgressBar` | 진행 바 | `value` |
| `ChorokButton` | 얇은 버튼(높이 30). 초록=주요 행동, 흰색=보조 | `label`, `onPressed`, `icon`, `tone`, `expand` |
| `ChorokListRow` | 아바타+제목+보조+trailing 가로줄 (댓글·저자·설정 행 등 공용) | `title`, `leading`, `supporting`, `trailing` |
| `ChorokSectionHeader` | 섹션 제목 (+모두 보기) | `title`, `trailing`, `inlineTrailing` |
| `ChorokStatCell` | 통계 숫자 셀 (박스 없음, 숫자 먼저, 좌측) | `label`, `value` |
| `ChorokStatBox` | 작은 통계 박스 (라벨 먼저, 가운데). 가로 나열은 `ChorokStatBox.row([...])` | `label`, `value`, `valueColor` |
| `BookCover` | 책 표지 (이미지 우선, fallback 그라디언트) | `radius`, `gradientIndex` |
| `AsyncStateView` | loading/empty/error 상태 (shimmer 포함) | — |
| `ChorokSheetHandle` / `ChorokSheetHeader` | 바텀시트 핸들·헤더 | `title`, `includeHandle` |
| `MainScaffold` | 하단 네비 + center orb 뼈대 | — |
| `ChorokBackButton` | 앱바 뒤로가기 | — |
| `ChorokSnackbar` (함수) | 스낵바 | — |
| `ChorokRefresh` / `ChorokShimmer` | 당겨서 새로고침 · 로딩 shimmer | — |
| `PageSliderCard` | 페이지 입력 슬라이더 (세션 전용) | — |

## 화면 조립 규칙

1. 박스처럼 생긴 건 전부 `ChorokCard`. 그 안의 서브 박스는 `ChorokCard(inner: true)`.
2. 아바타+텍스트+trailing 가로줄은 전부 `ChorokListRow`.
3. 섹션 제목은 `ChorokSectionHeader`.
4. 색·크기·간격·곡률은 위 토큰만. 화면 코드에 hex·fontSize·radius·간격 숫자 리터럴이 남으면 미완료.
5. 나열 간격은 `Column(spacing:)`. 이름(값 아님)만 쓴다.
