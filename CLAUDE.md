# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Environment Synchronization (Project Specific)

**Mirror design changes across environments immediately.**

- The "Design App" is the mock-data environment for quickly shaping and reviewing UI/UX, layout, component structure, and interaction design.
- The "Test App" is the real-data environment for validating the same experience against the actual database/API.
- If you modify the UI/UX or layout in the "Design App" (mockup environment), you MUST apply the exact same visual changes to the "Test App" (real data environment).
- Keep the look, feel, copy, layout, interaction behavior, and component structure 100% identical across both environments. Only the data source (mock data vs. real database/API) should differ.
- Do not treat either environment as disposable. A design task is incomplete if only one side reflects the requested visual or UX change.
- Functional fixes that do not alter UI/UX, layout, or component structure do not require a design/test visual sync, but still verify the affected runtime environment.
- Always verify both sides are synced before completing a design task.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

## 6. 제품 지식 (Product Knowledge)

**wiki는 묻지 않는 한 읽지 않는다.** 아래 인라인 결정사항으로 대부분의 코딩 판단이 가능하다.
wiki를 읽어야 하는 경우는 사용자가 명시적으로 요청하거나, 인라인에 없는 스펙이 필요할 때뿐이다.

**확정된 설계 결정 — 코드 판단 기준:**

| 결정 | 내용 |
|------|------|
| 하단 탭 | 홈 / 검색 / **세션 orb(가운데)** / 피드 / 서재 — 2026-06-10 확정. 분석은 별도 탭 아님(서재 통계 뷰로 흡수) |
| 검색 위치 | 하단 탭 2번. 우상단 앱바에는 알림만 (검색 아이콘 제거됨) |
| 분석 위치 | 서재의 통계 뷰(`_viewIndex==1`)로 간소화. 전체 `AnalyticsScreen`은 홈 카드·서재에서 드릴다운(push)으로만 유지 |
| 하지 말 것 | SNS 공유, 챌린지 — 기능 추가 제안 금지 |
| UX 원칙 | 선택지를 주지 않고 알고리즘이 정보를 제시 (착수 마찰 최소화) |
| 피드 매칭 | 기본 95% 취향 일치. 사용자가 80%까지 조정 가능 |
| 소셜 단위 | 초서 블록이 좋아요·댓글의 기본 단위 |
| 핵심 타겟 | 종인이 — 읽으려고는 하지만 실천 못 하는 사람. UX 결정 기준 |

**wiki가 필요한 경우 (사용자 요청 시에만):**

```
화면 전체 스펙   → wiki/analyses/화면-UI-설계.md
숲 시스템 상세   → wiki/analyses/숲-시스템-상세.md
설계 결정 배경   → wiki/analyses/팀-논의-설계결정.md
타겟 유저 상세   → wiki/analyses/타겟-사용자-페르소나.md
경쟁사 분석      → wiki/analyses/경쟁사-분석.md
BM 구조         → wiki/analyses/비즈니스-모델.md
경로: /Users/joyongseong/Documents/dev/Obsidian Vault/
```

---

## 7. 프로젝트 아키텍처

**폴더 구조:**

```
lib/
├── core/
│   ├── constants/     # 앱 전역 상수, 피처 플래그
│   ├── services/      # db_service, ocr_service, stt_service
│   ├── theme/         # 앱 테마
│   └── router/        # GoRouter 설정
├── features/          # 기능별 화면 (피처 단위로 분리)
│   ├── home/          # 홈 탭
│   ├── library/       # CHOLOCK(책) 탭 — 초서 목록, 독서 기록
│   ├── timer/         # CHO_LOCK 독서 세션 — 핵심 기능
│   ├── forest/        # 숲 탭 — 면적·나이테·뿌리 얽힘
│   ├── feed/          # 소셜 탭 — 이웃 초서 피드, 겹문장 알림
│   ├── explore/       # 탐험 탭
│   ├── auth/          # 인증
│   ├── onboarding/    # 온보딩
│   ├── search/        # 검색·바코드 스캐너
│   ├── settings/      # MY 탭 — 서재 포함
│   ├── analytics/     # 통계·히트맵
│   ├── achievements/  # 스트릭·뱃지
│   └── profile/       # 유저 프로필
└── shared/
    ├── models/        # 데이터 모델 (Book, SentenceRecord, ReadingSession 등)
    ├── providers/     # Riverpod 프로바이더
    ├── repositories/  # Supabase + sqflite 리포지토리
    ├── widgets/       # 공통 위젯
    └── utils/         # 유틸 함수
```

**website/ (Flutter 외부):** 정적 홍보 사이트(순수 HTML/JS, 독서 유형 테스트 포함). firebase hosting `site` 타겟으로 배포 — Flutter 웹 빌드(`design`/`prod` 타겟, `build/web`)와 별개.

**스택 규칙:**
- 상태 관리: Riverpod — 수동 선언 방식 (`NotifierProvider`/`AsyncNotifierProvider`/`Provider`를 직접 작성). `@riverpod` 코드젠은 쓰지 않는다 (`.g.dart` 없음, build_runner 불필요). `riverpod_annotation`이 pubspec에 있지만 미사용 — 신규 프로바이더도 수동 선언으로 통일한다.
- 라우팅: GoRouter — 라우트 정의는 `core/router/app_router.dart`
- 백엔드: Supabase (원격) + sqflite (로컬 캐시)
- 환경변수: `.env` 파일, `flutter_dotenv`로 로드
- 폰트: Pretendard (기본), 조선굴림체 (브랜드용)

---

## 8. 실행 환경 — 시뮬레이터·빌드

**`flutter` 명령은 반드시 `chorok_app/`에서 실행한다.** `pubspec.yaml`이 이 디렉토리에 있기 때문이다.

상위 폴더(`dev/`)에서 세션이 열려 있을 때:

```bash
cd /Users/joyongseong/Documents/dev/chorok_app && flutter run
```

또는 (작업 디렉토리를 유지하면서):

```bash
flutter run --suppress-analytics 2>&1   # ❌ dev/ 에서 실행하면 pubspec.yaml not found
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run )   # ✅
```

iOS 시뮬레이터 실행:

```bash
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run -d "iPhone" )
```

**실기기(아이폰) 실행 — 개발 중 폰 테스트의 기본 방법.** 시뮬레이터는 구글 로그인이 안 되므로, 폰에서 실제로 써보려면 아이폰을 케이블로 연결해 직접 돌린다. git push·웹배포 불필요 — 핫 리로드(`r`)로 즉시 반영되고 운영 Supabase에 붙어 실데이터가 그대로 보인다.

```bash
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run -d <아이폰-id> )  # id: flutter devices
# 코드 수정 후 터미널:  r = 핫 리로드 ,  R = 핫 리스타트
```

최초 1회: 아이폰 USB 연결 → "이 컴퓨터 신뢰" → 설정에서 개발자 모드 ON → Xcode 로 `ios/Runner.xcworkspace` 열어 Signing & Capabilities 에서 Team(본인 Apple ID) 지정(Bundle ID `com.chorok.chorokApp` 유지). 무료 개인 팀은 앱이 7일마다 만료되며 `flutter run` 한 번이면 재서명됨.

웹 실행 (목업 모드):

```bash
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run -d web-server --web-port 8080 --dart-define=USE_MOCK=true )
```

VSCode launch.json은 `chorok_app/.claude/launch.json`에 정의됨. 이 파일을 사용하면 작업 디렉토리 무관하게 실행 가능.

**디바이스 ID (고정값):**
- 실기기(아이폰): `00008120-0011549E3640C01E`
- 디자인 앱 시뮬레이터 "New Chorok iPhone": `C7F969E8-97C3-4A20-AAA4-E44AC9DC47F0`

```bash
# 디자인 앱 (시뮬레이터, 목업)
flutter run -d C7F969E8-97C3-4A20-AAA4-E44AC9DC47F0 --dart-define=USE_MOCK=true
# 실기기 (실데이터)
flutter run -d 00008120-0011549E3640C01E
```

**⚠️ iOS 서명 gotcha:**

1. **Apple 로그인 + 무료 개인 팀 조합 불가.** `Runner.entitlements`에 `com.apple.developer.applesignin`이 있으면 기기 설치 시 `0xe8008001` 오류(코드 서명 검증 실패). 무료 팀(VQ45VLJ87Y, choys9662@gmail.com)으로는 Sign in with Apple entitlement를 프로비저닝 못 함. 현재 `Runner.entitlements`는 의도적으로 비워 둔 상태 — 유료 Apple Developer Program 가입 전까지 건드리지 않는다.

2. **`path_provider_foundation` 2.6.0 시뮬레이터 크래시.** 2.6.0부터 objective_c native-assets 방식으로 전환됐는데, Flutter 3.41 + iOS 시뮬레이터에서 `SdkRoot` 미전달로 `dlopen` 실패 → 앱이 흰 화면으로 죽음. `pubspec.yaml`의 `dependency_overrides: path_provider_foundation: 2.5.1`로 고정 중 — 2.6.x로 올리지 않는다.

**검증 명령** (커밋·푸시 전):

```bash
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze )
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter test )   # test/ 가 lib/ 구조(core·features·shared) 미러링
```

---

## 9. Git · 배포 · 롤백 · 테스트 데이터 워크플로

**개발 루프:** 변경 확인은 git push 가 아니라 **실기기 `flutter run` + 핫 리로드**로 한다(§8). 웹 배포는 이제 "링크 공유 / 최종 교차확인"용이지 개발 루프가 아니다.

**브랜치 → 배포:**
- 기본: `main`에 직접 커밋·푸시 (빠른 개발 루프). 기능이 크거나 롤백 안전망이 필요할 때만 `feat/...` 브랜치.
- `main` 머지 시 GitHub Actions 가 자동 배포: 디자인앱(`chorok-d1414`, `USE_MOCK=true`) + 실앱(`chorok-real`, 실데이터). 정의: `.github/workflows/deploy-design.yml`, `deploy-prod.yml`.
- **롤백:** 배포 후 문제 시 `git revert <머지커밋>` → `main` 재배포. git 이력에 다 남아 있다.

**테스트 데이터 (출시 전):** dev/prod DB 는 아직 분리 안 함(단일 운영 Supabase). 개발 테스트는 **전용 테스트 구글 계정**으로만 로그인해 데이터를 식별 가능하게 둔다. 유저 간 상호작용 테스트는 계정 2~3개(아이폰=계정A 실로그인 + 웹 `chorok-real`=계정B). 쌓인 테스트 데이터는 `supabase/scripts/purge_test_user.sql`로 이메일 기준 일괄 삭제(모든 user 테이블이 `auth.users` cascade). dev/prod Supabase 분리는 실유저 생기기 직전에(`.env.dev`/`.env.prod` + `--dart-define=ENV`).

---

## 10. Figma / 이미지 → Flutter 변환 규칙

**적용 대상:** Figma 링크, 스크린샷, 목업 이미지를 주고 "이 화면 구현해줘" 류의 요청을 받을 때 항상 적용한다. 디자인을 MCP로 읽든 수동 복사(CSS 모든 레이어 + PNG)로 받든 아래 변환 규칙은 동일하게 적용한다.

**Figma MCP 한도 주의:** Starter 플랜은 **월 6회** — 호출 전에 nodeId·fileKey가 정확한지 확인해 낭비를 막고, 한도 초과 시 사용자에게 수동 복사(프레임 우클릭 → 코드로 복사 → CSS 모든 레이어 + PNG로 복사)를 요청한다. 수동 경로는 한도와 무관.

`get_metadata` 도구는 현재 "Tool not found" MCP 에러로 호출 불가(2026-07 기준) — `get_design_context` 하나로 좌표·크기·폰트가 Tailwind 클래스에 다 포함되어 있으니 재시도 없이 그것만 쓴다.

**핵심 원칙:** Figma Dev Mode·Code Connect는 React/HTML/SwiftUI/Jetpack Compose가 1급 대상이고 Flutter는 공식 지원 목록에 없다. 따라서 Figma·MCP가 반환하는 값(Auto Layout, CSS-like 속성)은 **중간 표현**일 뿐, 그대로 옮기면 안 되고 Flutter의 constraint 기반 레이아웃·위젯·테마 구조로 번역해야 한다. React, HTML, CSS 코드를 생성하지 않는다.

**Figma 링크 → React 치환 파이프라인 (항상 이 순서):**
1. URL에서 `fileKey`/`nodeId` 추출 (`node-id` 쿼리의 `-`는 `:`로 바꿔도 되고 그대로 써도 됨)
2. `get_design_context(fileKey, nodeId)` 호출 — MCP는 **항상 React+Tailwind JSX로 반환한다** (Flutter를 모르는 도구라 다른 형식으로 안 옴, 버그 아님)
3. 반환된 JSX를 그대로 쓰지 않는다 — `className` 안 임의값(`left-[16px]`, `top-[76px]`, `text-[14px]`, `tracking-[-0.28px]`)만 진짜 스펙 숫자로 신뢰하고, Tailwind 클래스 이름·구조(`absolute`, `flex` 등)는 무시한다
4. 그 숫자를 **레이아웃 매핑 표**(아래)로 Flutter 위젯/속성에, **색상 매핑 표**(아래)로 `AppTheme` 토큰에 치환한다

**구현 전 확인 순서** (기존 구조 우선, §7 참조):
1. Figma 프레임의 한국어 텍스트로 `lib/features/`를 grep — 이 화면이 이미 구현돼 있을 수 있다(예: `feed_screen.dart`가 이미 있었던 사례). 있으면 새로 만들지 않고 기존 화면의 정렬·색상만 대조·수정한다.
2. `lib/core/theme/` — 색상·타이포·spacing 토큰이 이미 있는지 확인
3. `lib/shared/widgets/` — 재사용 가능한 컴포넌트(버튼, 카드, 리스트 아이템 등)가 이미 있는지 확인
4. 없을 때만 새 토큰/컴포넌트 추가. 화면 파일에 매직 넘버·중복 컴포넌트를 만들지 않는다.

**레이아웃 매핑:**
| Figma / CSS | Flutter |
|---|---|
| 수직 Auto Layout / `flex-direction: column` | `Column` |
| 수평 Auto Layout / `flex-direction: row` | `Row` |
| `gap` | `SizedBox(width/height:)` 또는 spacing 토큰 |
| `padding` | `Padding` |
| hug contents | 위젯 기본 크기 |
| fill container | `Expanded` / `Flexible` |
| `justify-content: center` | `mainAxisAlignment: .center` |
| `justify-content: space-between` | `mainAxisAlignment: .spaceBetween` |
| `align-items: center` | `crossAxisAlignment: .center` |
| `border-radius` | `BorderRadius` |
| `box-shadow` | `BoxShadow` |
| absolute positioning / 레이어 오버레이 | `Stack` + `Positioned` — **일반 레이아웃에는 쓰지 않는다.** 실제 겹침(배지, 이미지 오버레이 등)에만 사용 |

**타이포·색상:** `Theme.of(context).textTheme` / 기존 테마 확장을 우선 사용. 기존 스타일과 근접하면 새 `TextStyle`을 만들지 않는다.

**CHOROK-PITCH 색상 변수 매핑** (새 hex 상수 만들기 전에 확인):
| Figma 변수 | hex | AppTheme |
|---|---|---|
| `--색상` | `#141614` | `darkCard` / `context.appCard` |
| `--색상-2` | `#7b847c` | `textSecondary`/`textTertiary` (동일값) |
| `--색상-3` | `#8dff54` | `primaryLight` / `context.appPrimaryAccent` |
| `--색상-4` | `#f1fff2` | `textPrimary` |
| `--색상-5` | `#222422` | 대응 토큰 없음 — 화면 로컬 const로 선언 |

**반응형:** 특정 디바이스 고정 폭·높이를 하드코딩하지 않는다. `Expanded`/`Flexible`/`MediaQuery`/`LayoutBuilder`/`SafeArea`/`ListView`를 우선 사용하고, 아이콘·아바타·버튼 높이처럼 진짜 고정 크기여야 하는 요소에만 고정값을 쓴다.

**구현 순서:** 화면 구조 파악 → 반복 패턴 식별 → 기존 컴포넌트 재사용 → 부족한 컴포넌트만 추가 → 화면 조립 → `flutter analyze` 실행, 에러 수정 (§8 검증 명령 참조).

**`flutter analyze` 통과 ≠ Figma 일치.** 컴파일 에러만 잡아준다. 색상값 / 폰트 실제 px(`AppTheme.bodySmall`처럼 스타일 이름이 같아도 px가 Figma와 다를 수 있음) / 정렬(Figma 절대좌표가 함의하는 상대 배치 — 예: 텍스트가 이미지 아래쪽에 붙어야 하는지)을 **각각 따로** Figma 원본 수치와 대조한다. 한 카테고리만 보고 다른 카테고리를 놓치기 쉽다.

**금지:** React/HTML/CSS/Tailwind 생성, 전체 화면을 `Stack`/`Positioned`로 구현, 반복 컴포넌트 중복 생성, UI 전체를 이미지로 export.

**픽셀 정확도 vs 유지보수성:** 완전한 픽셀 매칭이 나쁜 Flutter 구조를 요구하면, 트레이드오프를 설명하고 유지보수 가능한 쪽을 선택한다.
