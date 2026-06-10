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
│   └── achievements/  # 스트릭·뱃지
└── shared/
    ├── models/        # 데이터 모델 (Book, SentenceRecord, ReadingSession 등)
    ├── providers/     # Riverpod 프로바이더
    ├── repositories/  # Supabase + sqflite 리포지토리
    ├── widgets/       # 공통 위젯
    └── utils/         # 유틸 함수
```

**스택 규칙:**
- 상태 관리: Riverpod (`@riverpod` 어노테이션 방식)
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

---

## 9. Git · 배포 · 롤백 · 테스트 데이터 워크플로

**개발 루프:** 변경 확인은 git push 가 아니라 **실기기 `flutter run` + 핫 리로드**로 한다(§8). 웹 배포는 이제 "링크 공유 / 최종 교차확인"용이지 개발 루프가 아니다.

**브랜치 → 배포:**
- 수정은 `feat/...` 브랜치를 따서 작업 → 실기기로 테스트 → `main`에 머지.
- `main` 머지 시 GitHub Actions 가 자동 배포: 디자인앱(`chorok-d1414`, `USE_MOCK=true`) + 실앱(`chorok-real`, 실데이터). 정의: `.github/workflows/deploy-design.yml`, `deploy-prod.yml`.
- **롤백:** 배포 후 문제 시 `git revert <머지커밋>` → `main` 재배포. git 이력에 다 남아 있다.

**테스트 데이터 (출시 전):** dev/prod DB 는 아직 분리 안 함(단일 운영 Supabase). 개발 테스트는 **전용 테스트 구글 계정**으로만 로그인해 데이터를 식별 가능하게 둔다. 유저 간 상호작용 테스트는 계정 2~3개(아이폰=계정A 실로그인 + 웹 `chorok-real`=계정B). 쌓인 테스트 데이터는 `supabase/scripts/purge_test_user.sql`로 이메일 기준 일괄 삭제(모든 user 테이블이 `auth.users` cascade). dev/prod Supabase 분리는 실유저 생기기 직전에(`.env.dev`/`.env.prod` + `--dart-define=ENV`).
