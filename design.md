# 초록 Design System

이 문서는 새 화면을 만들거나 기존 UI를 고칠 때의 최종 기준이다. 색상표가 아니라 초록이 어떤 앱처럼 보여야 하는지, 어떤 컴포넌트가 어떤 역할을 맡는지, Claude Code / Codex / Cursor / 개발자가 같은 판단을 하도록 고정하는 작업 문서다.

## 1. Design Priority

우선순위는 항상 다음 순서다.

1. Figma `CHOROK-PITCH / UI DESIGN`
2. 라이브 포레스트 세션 화면
3. 메인 홈 화면
4. 실제 Flutter 구현
5. 기존 `AppTheme` 토큰

Figma와 코드가 충돌하면 Figma를 우선한다. 단, 코드가 이미 더 구체적인 실행 상태를 다루는 경우에는 Figma 원형을 해치지 않는 선에서 코드 구현을 유지한다. 예: 세션 화면의 OCR, 음성, 문장 정리 시트는 Figma 원형에는 없지만 제품 기능상 필요하므로 숨겨진 action layer로 둔다.

## 2. Product Identity

초록은 독서 몰입 플랫폼이다. 핵심 인상은 조용함, 몰입감, 어두운 숲, 살아 있는 초록 빛, 혼자 읽지만 혼자가 아닌 감각이다.

피해야 할 인상:

- 일반 생산성 타이머
- 밝은 독서 SNS
- 도서 쇼핑몰
- 귀여운 게임 UI
- 정보 카드가 많은 평범한 대시보드 앱

초록의 화면은 "책 관리"를 보여주는 앱이 아니라 "읽는 중인 상태"를 보여주는 앱이어야 한다. 기능 화면도 라이브 포레스트의 어두운 배경, 적은 텍스트, 살아 있는 초록 빛에서 파생되어야 한다.

## 3. Core Visual Reference

브랜드 원형은 라이브 포레스트다. Figma의 세션 프레임은 402 x 874 모바일 기준이며, 검은 숲 위에 초록 빛만 살아 있는 화면이다.

핵심 규칙:

- 배경은 black / near-black을 기본으로 한다.
- black overlay는 약 80%를 기준으로 한다.
- 초록 빛은 화면 전체를 채우지 않고 점, 오브, 타이머, CTA 같은 살아 있는 상태에만 강하게 쓴다.
- 텍스트는 적게, 공간은 넓게 둔다.
- 작은 점과 반딧불은 빠르게 움직이지 않는다. 느린 pulse와 미세한 깜빡임만 허용한다.
- 카드가 아니라 숲 위에 필요한 정보만 잠깐 떠야 한다.

## 4. Color System

`#000000`

세션, 라이브 포레스트, 몰입 화면의 기준 배경. 사용자가 독서 중일 때는 다른 배경색보다 우선한다.

Near-black: `#050805`, `#0A0F0A`, `#0B0D0B`

완전한 검정 위에 깊이를 만들 때만 쓴다. 세션 배경의 radial gradient, sheet 배경, 앱 surface에 쓴다.

`#111111`, `#111411`, `#111611`

검은 숲 위에 정보가 떠야 할 때 쓰는 box surface. prompt card, bottom sheet 내부 카드, compact list card에 쓴다.

`#8DFF54`

초록의 핵심 브랜드 컬러. active, live, timer, orb, firefly, CTA, focus에만 강하게 쓴다. 긴 본문, 일반 설명, 비활성 아이콘, 넓은 배경에는 남용하지 않는다.

Dark green: `#0D2010`, `#132A13`, `#1A3B1A`, `#2A7A3D`

오브의 외피, 일시정지 상태, muted live state, 카드 내 낮은 대비 배경에 쓴다. 초록이 너무 네온처럼 튀는 것을 눌러주는 색이다.

Text neutrals:

- Primary text: `#FFFFFF`
- Secondary text: `#B8C2B2`
- Tertiary text: `#7D8878`
- Black-on-green text: `#000000`

Needs Update: 현재 코드에는 라이트 테마가 남아 있다. 일반 화면에서 필요할 수 있으나, 세션과 라이브 포레스트 계열 화면은 항상 다크를 우선한다.

## 5. Typography

기본 폰트는 현재 코드 기준 `ChosunGu`다. `CLAUDE.md`에는 Pretendard 기본, 조선굴림체 브랜드용이라고 적혀 있으나 `AppTheme.fontFamily`는 `ChosunGu`로 고정되어 있다. 새 UI는 현재 앱의 실제 렌더링과 맞추기 위해 `ChosunGu`를 우선한다. 긴 본문이나 시스템 텍스트에서 Pretendard를 도입하려면 먼저 앱 테마를 분리해야 한다.

타이포 위계는 굵기가 아니라 크기, 색, 위치, 여백으로 만든다. 기본 font-weight는 400이다.

세션 타이머:

- Figma 기준: 60-61px
- line-height: 100%
- letter-spacing: -4%
- color: `#8DFF54`
- 숫자는 tabular figures를 권장한다.

현재 Flutter 세션의 `_RevealedView`와 page input은 64px를 쓴다. 허용 범위는 60-64px이지만, Figma 매칭이 목표인 화면은 61px로 낮춘다.

상태 / 날짜 / prompt text:

- Figma 기준: 약 15.4px
- line-height: 약 114%
- letter-spacing: -2%
- color: `#8DFF54`

작은 독자 이름 label:

- Figma 기준: 약 11.8px
- 독자 이름은 오브 가까이에 붙되, 화면의 주인공이 되면 안 된다.

일반 앱 타이포:

- 큰 제목: 24-28px
- 섹션 제목: 20px
- 본문 / 행 텍스트: 16px
- 보조 설명: 12px
- 캡션: 10-12px

## 6. Spacing and Layout

기준 프레임은 402 x 874다. 모든 모바일 화면은 이 비율에서 먼저 균형을 맞춘 뒤 다른 폭에 대응한다.

반복해서 쓰는 spacing만 쓴다:

- 4: 아주 작은 아이콘/텍스트 간격
- 8: 카드 gap, 작은 내부 간격
- 12: 카드 내부 보조 간격
- 16: 일반 카드 padding
- 20: 화면 좌우 padding
- 24: 큰 block 내부 간격
- 28-32: 섹션 사이 간격

13, 17, 19 같은 임의 값은 새로 만들지 않는다. 이미 코드에 있는 특수 값은 화면 매칭 목적이 있을 때만 유지한다.

홈 레이아웃:

- 좌우 padding은 20.
- 섹션 간격은 28-32.
- 홈 summary card는 78px 높이를 기준으로 한다.
- 읽고 있는 책 card는 118 x 180, gap 8을 기준으로 한다.
- 독자 row는 최소 44px 높이를 확보한다.

체크리스트:

- 같은 화면에 카드가 4개 이상 연속으로 쌓이면 대시보드처럼 보이지 않는지 확인한다.
- 초록색 텍스트가 한 화면에 3군데 이상 강하게 보이면 active/live/focus 역할인지 확인한다.
- 섹션 제목, 숫자, CTA가 모두 같은 무게로 경쟁하지 않는지 확인한다.
- 하단 네비게이션과 center orb가 본문을 가리지 않는지 확인한다.

## 7. Box and Card Rules

초록은 카드가 많은 앱이 아니다. 검은 숲 UI에서 필요한 정보만 박스로 띄우는 앱이다. 카드가 많아질수록 평범한 독서 관리 앱처럼 보인다.

Radius:

- 기본 box radius: 10
- 홈 밀도형 카드 / 책 카드: 8
- Figma prompt card는 radius 15로 보이나, 앱 전체 규칙은 8-10을 우선한다. Figma 세션 prompt만 예외적으로 15까지 허용한다.

Prompt card:

- Figma 기준: 약 312 x 61
- background: `#111111`
- text: `#8DFF54`
- 화면 중앙보다 약간 아래에 잠깐 뜨는 질문 카드다.

Home summary card:

- 높이 78
- active card만 `#8DFF54` fill을 허용한다.
- 비활성 card는 `context.appCard` / near-black 계열이다.

Book card:

- 118 x 180
- radius 8
- 표지 이미지가 있으면 이미지를 우선하고, fallback gradient는 보조 수단이다.
- progress bar는 얇게 유지한다.

Live reader card:

- row 중심.
- 이름, dot, 시간만 둔다.
- dot 크기와 밝기로 live hierarchy를 만든다.

Empty state:

- 설명을 길게 쓰지 않는다.
- 하나의 행동 CTA만 둔다.

## 8. Live Forest System

독자 상태는 반딧불 밝기와 크기로 구분한다.

- active: 가장 밝음, size 2.0-3.5, brightness 1.0
- today: 중간, size 1.5-2.5, brightness 0.45
- week: 희미함, size 1.0-2.0, brightness 0.18

현재 `LiveForestWidget` 구현은 이 기준과 잘 맞는다. glow sprite를 한 번 굽고 `drawImageRect`로 재사용해 blur 연산을 피한다. 이 방식은 유지한다.

움직임:

- 빠른 이동 금지.
- 5초 안팎의 느린 pulse.
- 약 15fps 갱신으로 충분하다.
- 반딧불 위치가 계속 흔들리기보다 빛이 살아 있는 느낌만 준다.

중앙 오브는 "나의 독서 상태"다. 독자가 여럿 있어도 중심 오브는 내 상태를 나타내며, 주변 반딧불은 함께 읽는 사람들의 존재감이다.

## 9. Session Touch Model

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

## 10. Home Screen Rules

홈은 일반 대시보드가 아니라 라이브 포레스트 감각이 약하게 적용된 진입 화면이다. 홈은 독서 상태로 들어가는 문이고, 정보 리포트가 아니다.

홈 구성 원칙:

- 첫 화면에서 핵심 메시지와 오늘/이번 주 상태가 먼저 보인다.
- 섹션 수가 많아질수록 카드형 독서 관리 앱처럼 보인다.
- 책 리스트, 읽고 있는 친구, 오늘 읽은 친구, 겹문장은 모두 필요할 때만 보여준다.
- 비어 있는 섹션은 숨기는 것이 기본이다.
- CTA는 작은 아이콘 중심으로 두고 설명형 버튼을 남발하지 않는다.

현재 코드 기준:

- app bar top padding: 34, 좌우 20
- home section gap: 28-30
- summary card: 78 height
- reading book card: 118 x 180
- live reader row: 44 height

Needs Update: 현재 `HomeScreen`은 `HomeStatCards`, `ReadingBooksSection`, `ReadingFriendsSection`, `FriendsReadTodaySection`, `OverlapSection`이 연속으로 쌓인다. 데이터가 많을 때 홈이 라이브 포레스트 파생 화면이 아니라 일반 대시보드처럼 보일 수 있다. 다음 홈 리팩터에서는 섹션 노출 우선순위를 줄이고, live state를 더 강하게 만든다.

## 11. Components

Primary Button

주요 행동 하나에만 쓴다. 세션에서는 `#8DFF54` fill + black text를 쓴다. 일반 `확인`, `OK`, `완료` 대신 `계속 읽을게요`, `독서 시작하기`, `문장 남기기`처럼 행동을 말한다.

Icon Button

시각적 도구는 텍스트 버튼보다 아이콘 버튼을 우선한다. 터치 영역은 최소 42 x 42. 작은 아이콘이라도 `SizedBox`로 hit area를 확보한다.

Bottom Navigation

홈 / 검색 / center orb / 피드 / 서재 구조를 유지한다. 가운데 orb는 일반 탭이 아니라 독서 상태 진입점이다. nav icon label은 조용해야 하며 active만 초록으로 표시한다.

Center Orb FAB

현재 62 x 62. 세션 중이면 이어가기, idle이면 독서 시작. 오브는 primary CTA이므로 화면 내 다른 CTA가 같은 강도로 경쟁하면 안 된다.

Prompt Card

312 x 61, `#111111`, `#8DFF54`. 짧은 한 문장만 허용한다. 설명문을 넣지 않는다.

Book Card

118 x 180, radius 8. 책 표지를 보여주는 카드다. 메뉴 버튼은 28 x 28 정도의 작은 affordance로 충분하다.

Live Reader Row

이름, live dot, duration만 둔다. 숫자는 tabular figures. row는 44px 이상.

Empty State

빈 상태는 분위기보다 다음 행동을 알려야 한다. 긴 설명문 금지. CTA는 하나.

Snackbar / Alert

실패나 완료를 짧게 말한다. 세션 중 snackbar는 몰입을 깨므로 가능한 floating, 짧은 문장, 어두운 배경을 쓴다. destructive alert는 이유와 결과를 명확히 말한다.

## 12. Copy Rules

초록의 카피는 조용하고 약간 장난스럽지만 공격적이지 않아야 한다.

사용 가능한 톤:

- `오늘도 같이 읽어요`
- `20분만 더 읽어볼까요?`
- `이러고 오늘 책 읽었다고 하려구요?`
- `초록 왜 켰어요?`
- `계속 읽을게요`

규칙:

- 버튼은 맥락 없는 `확인`, `OK`, `완료`를 피한다.
- 너무 친절한 설명보다 짧고 단단한 한 문장을 우선한다.
- 세션 중 문구는 사용자를 오래 붙잡지 않는다.
- 공격적인 문구는 이탈 방지 맥락에서만 제한적으로 쓴다.

## 13. Motion and Feedback

움직임은 빠르고 화려한 애니메이션이 아니라 느리고 미세한 생명감이어야 한다.

세션:

- fade: UI layer 등장/퇴장
- pulse: 오브와 반딧불
- scale: press feedback
- haptic: 세션 주요 행동, tab 선택, 책 카드 tap

기준:

- 카드 press scale: 0.97
- layer transition: 180-260ms
- 세션 pulse: 3-5초
- 큰 background movement: 40초 이상 또는 거의 정지

화면 전체가 계속 움직이면 독서 몰입을 방해한다. 움직임은 살아 있는 빛에만 쓴다.

## 14. Accessibility

- 터치 영역은 최소 42 x 42.
- 작은 아이콘이라도 hit area를 확보한다.
- bottom nav, center orb, reader row, book card, notification button에는 Semantics label이 필요하다.
- 네온 그린은 긴 본문에 쓰지 않는다.
- `#8DFF54` 위 텍스트는 black을 기본으로 한다.
- 검은 배경 위 보조 텍스트는 너무 낮은 alpha로 숨기지 않는다.
- 숫자 UI는 tabular figures를 쓴다.

현재 코드에는 `HomeAppBar`, `MainScaffold`, reader row, book card 등 주요 affordance에 Semantics가 들어가 있다. 이 방향을 유지한다.

## 15. Implementation Checklist

새 화면을 만들기 전 확인한다.

Layout:

- 402 x 874 기준에서 먼저 균형이 맞는가?
- 좌우 padding은 20 또는 명확한 예외인가?
- 섹션 gap은 28-32 범위인가?
- bottom nav / orb / safe area와 겹치지 않는가?

Box:

- radius는 8 또는 10인가?
- 세션 prompt 같은 Figma 예외만 15까지 허용했는가?
- 카드가 너무 많이 쌓이지 않았는가?

Color:

- `#8DFF54`가 active/live/timer/orb/CTA/focus에만 쓰였는가?
- 긴 본문에 네온 그린을 쓰지 않았는가?
- 세션 계열은 black / near-black을 우선했는가?

Typography:

- 기본 weight는 400인가?
- 위계를 굵기가 아니라 크기, 색, 위치, 여백으로 만들었는가?
- timer 숫자는 60-64px, line-height 1.0인가?
- 숫자 UI에 tabular figures가 필요한가?

State:

- empty/loading/error가 숲의 톤을 깨지 않는가?
- mock data가 실데이터 화면에 섞이지 않는가?
- 세션 action이 hidden/revealed/social 흐름을 깨지 않는가?

Interaction:

- visible affordance는 실제로 동작하는가?
- press feedback은 0.97 scale 정도로 충분한가?
- 모든 단계가 다시 몰입 상태로 돌아가는가?

## 16. Current Drift Notes

Timer size

Figma는 60.8px, 코드의 revealed/page input timer는 64px이다. 큰 차이는 아니지만 Figma 정확 매칭 화면에서는 61px로 낮춘다.

Prompt card

Figma prompt card는 312 x 61, `#111111`, radius 15, green text다. 코드의 세션 entry와 action cards는 더 기능적이고 복잡하다. Figma prompt는 세션 중간 질문에만 쓰고, 기능 action card와 혼동하지 않는다.

Session touch steps

코드는 이미 `hidden -> revealed -> social`, plus로 `actions`를 가진다. 이 부분은 Figma 방향과 맞다. 다만 시작 토픽, OCR, STT, 문장 정리 흐름 때문에 세션이 기능 앱처럼 보일 위험이 있다. 기능은 actions/sheet 안에만 숨긴다.

Home card density

현재 홈은 여러 섹션이 연속으로 쌓인다. 데이터가 많은 사용자에게는 일반 독서 관리 대시보드처럼 보일 수 있다. 다음 리팩터에서는 live forest 감각을 홈 상단에 약하게 도입하고, 섹션 수를 상태 기반으로 줄인다.

Radius

현재 `AppTheme`는 radius 10으로 통일되어 있고, 책/홈 밀도형 카드는 8을 쓴다. Figma prompt의 15는 예외로만 둔다.

Spacing

현재 코드에는 20, 28-30, 8, 12, 16이 반복되어 있어 큰 방향은 맞다. 일부 세션 entry에 17, 23 같은 화면 매칭용 값이 있다. 새 토큰으로 확장하지 않는다.

Green usage

`#8DFF54`가 analytics, feed, library까지 넓게 쓰인다. active/focus/live 역할이면 허용하지만, 일반 설명 텍스트나 decorative border에 반복되면 초록의 힘이 약해진다. 긴 본문에는 secondary/tertiary text를 쓴다.

Figma vs code conflicts:

- Figma는 세션 원형이 극도로 단순하다. 코드는 실제 제품 기능 때문에 시작 토픽, 문장 수집, OCR, STT, page input을 포함한다.
- Figma prompt radius는 15에 가깝다. 현재 앱 규칙은 8-10이다.
- Figma 타이머는 60.8px이다. 코드 일부는 64px이다.
- Figma는 black overlay 80%가 강하다. 홈 코드는 라이트/다크 테마 분기를 갖고 있어 홈이 밝은 독서 앱처럼 보일 수 있다.

판단이 필요한 질문:

1. 홈도 항상 다크 기반으로 고정할 것인가, 아니면 일반 화면에는 라이트 테마를 계속 허용할 것인가?
2. Figma prompt card radius 15를 세션 전용 예외로 둘 것인가, 앱 전체 radius 10으로 맞출 것인가?
3. 홈 상단에 실제 `LiveForestWidget`의 약한 버전을 넣을 것인가, 아니면 현재 summary card 중심을 유지할 것인가?

## Flutter UI 수정 실행 프롬프트

```
chorok_app/design.md를 기준으로 Flutter UI를 수정해줘.

우선순위는 Figma UI DESIGN > 라이브 포레스트 세션 > 홈 > 현재 코드 > AppTheme 토큰이다.
새 추상화나 새 dependency는 만들지 말고, 기존 AppTheme, ChorokCard, BookCover, LiveForestWidget, MainScaffold 패턴을 먼저 재사용한다.

수정 전:
- 관련 화면의 실제 코드 경로를 먼저 읽는다.
- visible affordance가 있으면 실제 동작까지 확인한다.
- 세션 화면은 hidden/revealed/social/actions 상태 흐름을 깨지 않는다.

수정 기준:
- #8DFF54는 active/live/timer/orb/CTA/focus에만 강하게 쓴다.
- radius는 기본 10, 책/홈 밀도형 카드는 8, 세션 prompt만 예외적으로 15까지 허용한다.
- 화면 좌우 padding은 20, 섹션 gap은 28-32, 카드 내부 padding은 16/20을 우선한다.
- 타이머는 60-64px, line-height 1.0, tabular figures를 쓴다.
- 홈은 대시보드가 아니라 라이브 포레스트 감각이 약하게 적용된 진입 화면이어야 한다.

검증:
- flutter analyze를 실행한다.
- UI 변경이 design/test 양쪽 환경에 영향을 주면 두 환경이 같은 구조인지 확인한다.
- 변경 요약에 Figma 기준과 코드 기준이 충돌한 지점을 따로 적는다.
```
