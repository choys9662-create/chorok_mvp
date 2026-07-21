# 초록 Design System

이 문서는 새 화면을 만들거나 기존 UI를 고칠 때의 최종 기준이다. 색상표가 아니라 초록이 어떤 앱처럼 보여야 하는지, 어떤 컴포넌트가 어떤 역할을 맡는지, Claude Code / Codex / Cursor / 개발자가 같은 판단을 하도록 고정하는 작업 문서다.

**구현 규칙 (전 섹션 공통):** 이 문서의 모든 값(색·크기·간격·곡률)은 `AppTheme` 토큰과 `shared/widgets`를 통해서만 코드에 들어간다. 화면 코드에 hex·fontSize·radius·간격 숫자를 직접 쓰지 않는다. 이 규칙은 아래 각 섹션에서 반복하지 않는다.

## 1. Core Visual Reference

브랜드 원형은 라이브 포레스트다. Figma의 세션 프레임은 402 x 874 모바일 기준이며, 검은 숲 위에 초록 빛만 살아 있는 화면이다.

핵심 규칙:

- 배경은 black / near-black을 기본으로 한다.
- black overlay는 약 80%를 기준으로 한다.
- 초록 빛은 화면 전체를 채우지 않고 점, 오브, 타이머, CTA 같은 살아 있는 상태에만 강하게 쓴다.

## 2. Color System

**팔레트는 아래 여섯 색만 쓴다. 이 외의 hex 값 도입 금지. 중간 톤·깊이감이 필요하면 새 색을 만들지 말고 이 여섯 색의 opacity로만 만든다.**

| Hex | 역할 |
|---|---|
| `#000000` | 기준 배경. 세션·라이브 포레스트·몰입 화면. 독서 중에는 다른 배경보다 우선한다. |
| `#141614` | 앱 surface / 바깥 박스(카드·시트·다이얼로그) 배경. 검은 화면 위에 정보가 뜰 때. |
| `#222422` | 이너 박스(칩·입력 필드·서브 카드) 배경, 구분선, 비활성 요소. |
| `#8DFF54` | 브랜드 그린. active, live, timer, orb, firefly, CTA, focus에만 강하게.
| `#F1FFF2` | Primary text. |
| `#7B847C` | Secondary/tertiary text, 비활성 아이콘, 보조 설명. |

- `#8DFF54` 위 텍스트는 `#000000`을 기본으로 한다.
- 오브 외피, 일시정지, muted live 같은 낮은 대비 초록은 `#8DFF54`의 opacity 조절로 만든다.
- 옛 팔레트(near-black·`#111111` 계열·dark green·구 텍스트 뉴트럴)는 폐기 — 발견 시 역할이 같은 위 색으로 치환한다.

Needs Update: 현재 코드에는 라이트 테마가 남아 있다. 일반 화면에서 필요할 수 있으나, 세션과 라이브 포레스트 계열 화면은 항상 다크를 우선한다.

## 3. Typography

**폰트는 조선굴림체(`ChosunGu`) regular(400) 하나로 통일한다.** 다른 폰트(Pretendard 포함)를 새로 도입하지 않는다. (확정: 2026-07-19)

타이포 위계는 굵기가 아니라 크기, 색, 위치, 여백으로 만든다. 기본 font-weight는 400이다.

세션 타이머는 화면의 주인공이다. 크게(60px대), `#8DFF54`, tabular figures. 독자 이름 label은 오브 가까이에 작게 붙되 주인공이 되면 안 된다.

일반 앱 타이포 (확정: 2026-07-19, 범위 없이 고정값):

- 큰 제목: 30
- 섹션 제목: 18
- 행 텍스트: 16
- 본문: 14
- 보조: 12
- 캡션: 10

이 여섯 단계 외의 크기는 새로 만들지 않는다.

## 4. Spacing and Layout

기준 프레임은 402 x 874다. 모든 모바일 화면은 이 비율에서 먼저 균형을 맞춘 뒤 다른 폭에 대응한다.

반복해서 쓰는 spacing만 쓴다:

- 4: 아주 작은 아이콘/텍스트 간격
- 8: 카드 gap, 작은 내부 간격
- 12: 카드 내부 보조 간격
- 16: 일반 카드 padding, 화면 좌우 padding
- 24: 큰 block 내부 간격
- 30: 섹션 사이 간격

나열 간격은 컨테이너가 책임진다 — `Column(spacing:)` 또는 `ChorokColumn(gap:)`. 개별 요소가 자기 위/아래 여백을 스스로 정하지 않는다.

## 5. Box and Card Rules

초록은 카드가 많은 앱이 아니다. 검은 숲 UI에서 필요한 정보만 박스로 띄우는 앱이다. 카드가 많아질수록 평범한 독서 관리 앱처럼 보인다.

Radius (곡률):

**2단계 규칙으로 통일한다. 가장 바깥 박스(컨테이너/카드)는 radius 10, 그 안의 이너 박스는 radius 6. 둘 다 smooth corner(smoothing 0.6).** (확정: 2026-07-19)

- 바깥 박스 = 화면 배경 위에 직접 놓이는 카드·시트·다이얼로그 → 10
- 이너 박스(inner) = 바깥 박스 안에 들어간 칩·썸네일·입력 필드·서브 카드 → 6
- 완전한 원(아바타, 오브, 점 인디케이터)만 예외다.

Prompt card: `#141614` 배경 + `#8DFF54` 텍스트, 화면 중앙보다 약간 아래에 잠깐 뜨는 질문 카드다.

Home summary card: active card만 `#8DFF54` fill을 허용한다. 비활성 card는 surface 계열이다.

Book card: 표지 이미지가 있으면 이미지를 우선하고, fallback gradient는 보조 수단이다. progress bar는 얇게 유지한다.

Book info hero: 402 기준 첫 진입 표지는 168 x 244, 스크롤 후 표지는 28 x 40이다. 첫 화면의 제목·저자와 CTA는 실제 제목 줄 수에 맞춰 붙인다. 스크롤 시 고정 헤더는 제목·저자 두 줄과 48pt 터치 영역 높이까지 접히고, 표지는 오른쪽 상단으로 축소되며 제목·저자는 상단 중앙에 정렬된다. 실제 표지 값은 `AppTheme.bookInfoCoverExpandedSize` / `bookInfoCoverCollapsedSize`가 가진다.

Live reader card:

- row 중심.
- 이름, dot, 시간만 둔다.
- dot 크기와 밝기로 live hierarchy를 만든다.

Empty state:

- 설명을 길게 쓰지 않는다.
- 하나의 행동 CTA만 둔다.

## 6. Live Forest System

독자 상태는 반딧불 밝기와 크기로 구분한다: active(가장 밝음) > today(중간) > week(희미함). 구체 수치는 `LiveForestWidget` 구현을 기준으로 한다. glow sprite를 한 번 굽고 재사용해 blur 연산을 피하는 현재 방식은 유지한다.

움직임: 빠른 이동 금지. 느린 pulse만. 반딧불 위치가 계속 흔들리기보다 빛이 살아 있는 느낌만 준다.

중앙 오브는 "나의 독서 상태"다. 독자가 여럿 있어도 중심 오브는 내 상태를 나타내며, 주변 반딧불은 함께 읽는 사람들의 존재감이다.

## 7. Session Touch Model

세션 화면은 처음부터 모든 UI를 보여주지 않는다. 기본 구조는 다음 3단계다.

1. Hidden Forest
2. Revealed Timer
3. Social / Action Layer

첫 번째 터치: 시간과 상태만 보여준다.

두 번째 터치: 독자/사회적 감각을 보여준다.

세 번째 단계: 필요할 때만 plus/action으로 OCR, 음성, 문장, 종료 같은 주요 액션을 연다.

모든 단계는 다시 몰입 상태로 돌아가야 한다. 자동 숨김은 6-8초 범위를 기준으로 한다.

현재 Flutter 구현:

- `UiVisibility.hidden`
- `UiVisibility.revealed`
- `UiVisibility.social`
- `UiVisibility.actions`

이 구조는 유지 기준이다. 단, action layer가 너무 빨리 많은 기능을 보여주면 Figma 원형에서 멀어진다. 새 액션은 hidden/revealed/social을 건드리지 말고 actions 안에만 추가한다.

## 8. Accessibility

- 터치 영역은 최소 42 x 42. 작은 아이콘이라도 hit area를 확보한다.
- bottom nav, center orb, reader row, book card, notification button에는 Semantics label이 필요하다.
- 검은 배경 위 보조 텍스트는 너무 낮은 alpha로 숨기지 않는다.
- 숫자 UI는 tabular figures를 쓴다.

## 9. 판단 체크리스트

값 규칙(§2~§5)은 토큰·위젯이 강제하므로 여기서 반복하지 않는다. 아래는 기계로 못 잡는 판단 항목만:

- 402 x 874 기준에서 먼저 균형이 맞는가?
- 카드가 4개 이상 연속으로 쌓여 대시보드처럼 보이지 않는가?
- `#8DFF54`가 active/live/focus 역할에만 쓰였는가? 긴 본문에 없는가?
- 섹션 제목, 숫자, CTA가 같은 무게로 경쟁하지 않는가?
- bottom nav / orb / safe area와 겹치지 않는가?

## 10. Current Drift Notes

Session touch steps

코드는 이미 `hidden -> revealed -> social`, plus로 `actions`를 가진다. 다만 시작 토픽, OCR, STT, 문장 정리 흐름 때문에 세션이 기능 앱처럼 보일 위험이 있다. 기능은 actions/sheet 안에만 숨긴다.

Home card density

현재 홈은 여러 섹션이 연속으로 쌓인다. 데이터가 많은 사용자에게는 일반 독서 관리 대시보드처럼 보일 수 있다. 다음 리팩터에서는 live forest 감각을 홈 상단에 약하게 도입하고, 섹션 수를 상태 기반으로 줄인다.

코드 정리 대기: 옛 팔레트·radius(8/15 등)·padding 20이 코드에 남아 있다. 화면 만질 때 §2/§4/§5 규칙으로 정리한다.

판단이 필요한 질문:

1. 홈도 항상 다크 기반으로 고정할 것인가, 아니면 일반 화면에는 라이트 테마를 계속 허용할 것인가?
2. 홈 상단에 실제 `LiveForestWidget`의 약한 버전을 넣을 것인가, 아니면 현재 summary card 중심을 유지할 것인가?

## Flutter UI 리팩터 실행 프롬프트

목표: **위젯·토큰만 수정하면 앱 전체가 바뀌는 구조** (문서 상단 구현 규칙 참조).

구조 3층:
- design.md = 규칙과 이유 (헌법)
- AppTheme = 규칙의 현재 숫자값 (색·크기·간격·곡률)
- shared/widgets = 값을 자동 적용하는 손 (박스·행·헤더·버튼 + 간격 자동)

```
chorok_app을 "위젯만 수정하면 앱 전체가 바뀌는" 구조로 리팩터해줘.
기준 문서는 chorok_app/design.md다. 시작 전에 전체를 읽어라.

## 전제
- 라이트 모드는 보류: 라이트 토큰·분기를 삭제하지도, 새로 만들지도 않는다. 다크 기준으로만 작업한다.
- 새 파일·새 의존성 최소화. 기존 AppTheme·shared/widgets 확장을 우선한다.
- 공용 위젯은 적게 유지한다. 새 공용 위젯은 "기존 위젯 조합으로 못 만들고 + 3개 이상 화면에서 반복"일 때만 만든다. 한 화면 전용 조각은 그 feature 폴더에 둔다.

## 0단계 — 시작 전
- git 커밋으로 시작점을 남긴다.
- 시뮬레이터에서 홈·세션·서재·피드·책상세 스크린샷을 찍어 비교 기준으로 삼는다.

## 1단계 — AppTheme 토큰을 §2~§5 값으로 정렬 (app_theme.dart만)
- 팔레트 밖 색(warningColor·empathyColor·coverGradients)은 값 유지 + "// TODO: 팔레트 위반 §2" 주석.
- 스케일 밖 타이포 토큰은 가장 가까운 단계로 흡수하되 기존 토큰명은 별칭으로 유지(컴파일 보호). 세션 타이머·통계 hero(30 초과)는 디스플레이 예외로 유지.

## 2단계 — 공용 위젯 키트 정비 (shared/widgets)
- ChorokCard: 바깥 기본 + inner 옵션 (§5). ForestAccentCard 흡수.
- 간격 자동화(§4): Column(spacing:) 또는 얇은 ChorokColumn(gap:) 도입.
- 죽은/전용 위젯 정리: GradientText/GradientIcon 삭제(그라디언트가 단색), PageSliderCard는 세션 전용이면 features/session/로 이동.

## 3단계 — 화면을 위젯 조립으로 치환 (한 번에 한 기능: 홈→서재→피드→검색→세션→프로필)
- 직접 만든 박스 → ChorokCard, 직접 만든 TextStyle → 타이포 토큰(가장 가까운 단계로 스냅, 타이머·hero 예외), 하드코딩 색 → 색 토큰, SizedBox 나열 간격 → 자동 간격 레이아웃.
- 여섯 색 밖 색은 역할상 가장 가까운 토큰으로. 애매하면 목록으로 보고하고 임의 결정하지 않는다.
- 화면 코드에 hex·fontSize·radius·간격 숫자가 남아 있으면 그 화면은 미완료.
- 세션 화면은 hidden/revealed/social/actions 흐름과 LiveForestWidget 렌더링 방식을 깨지 않는다.

## 각 단계 완료 시
- flutter analyze + flutter test 통과 → 스크린샷 비교(의도한 변화 vs 사고 구분) → git 커밋 → 다음 단계.

## 완료 기준
- grep으로 features/ 안의 Color(0x / fontSize: / BorderRadius.circular( / SizedBox(height: 가 0에 수렴.
- AppTheme 색 하나를 바꿔 앱 전체가 따라오는지 확인 후 원복.
- design/test 양쪽 환경 동일 반영 확인.
```
