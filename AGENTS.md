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

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

## 5. 문서 라우팅 — 작업 종류별 필독 문서

작업을 시작하기 전에, 해당하는 문서를 **반드시 먼저 읽는다.** 여기에 내용을 중복 기재하지 않는다.

| 작업 | 필독 문서 |
|------|-----------|
| UI 생성·수정 (화면·위젯·색·간격 전부) | `design.md`(규칙·값) + `docs/components.md`(코드에서 쓸 토큰·위젯 이름) |
| 앱 실행, 시뮬레이터·실기기, 빌드, 배포, 커밋 전 검증, 테스트 데이터 | `docs/run.md` |
| Figma 링크·스크린샷·목업 이미지를 구현 | `docs/figma.md` + `design.md` |

**UI 작업 핵심 규칙 (상시):**
- 참고 이미지를 첨부받아도 그대로 복제하지 않는다. 이미지는 레이아웃·구조 참고, 색상·타이포·톤은 design.md가 이긴다. design.md에 없는 판단은 임의로 정하지 말고 묻는다.
- 스타일은 `AppTheme` 토큰과 `shared/widgets`로만 구현한다. 화면 코드에 hex·px 리터럴을 넣지 않는다.
- 하드코딩 리터럴 검사 시 `BorderRadius.circular(N)`뿐 아니라 named param `radius: N`(`smoothBox`/`smoothShape`/`BookCover`/`ChorokShimmer` 등)도 함께 grep한다. 단 `CircleAvatar(radius:)`·`RadialGradient(radius:)`는 크기/그라디언트 폭이라 토큰화 대상이 아니다 — false positive로 제외.

## 6. 환경 동기화

디자인앱(목업 데이터)과 실앱(실데이터)은 데이터 소스만 다르고 UI는 100% 동일해야 한다. UI/레이아웃을 한쪽에서 바꿨으면 반드시 다른 쪽에도 동일하게 반영하고 확인한다. 한쪽만 반영된 디자인 작업은 미완료다.

## 7. 제품 지식

**wiki는 묻지 않는 한 읽지 않는다.** 아래 인라인 결정사항으로 대부분의 코딩 판단이 가능하다.

| 결정 | 내용 |
|------|------|
| 하단 탭 | 홈 / 검색 / **세션 orb(가운데)** / 피드 / 서재 — 2026-06-10 확정. 분석은 별도 탭 아님(서재 통계 뷰로 흡수) |
| 검색 위치 | 하단 탭 2번. 우상단 앱바에는 알림만 |
| 분석 위치 | 서재의 통계 뷰(`_viewIndex==1`). 전체 `AnalyticsScreen`은 드릴다운(push)으로만 |
| 하지 말 것 | SNS 공유, 챌린지 — 기능 추가 제안 금지 |
| UX 원칙 | 선택지를 주지 않고 알고리즘이 정보를 제시 (착수 마찰 최소화) |
| 피드 매칭 | 기본 95% 취향 일치, 80%까지 조정 가능 |
| 소셜 단위 | 초서 블록이 좋아요·댓글의 기본 단위 |
| 핵심 타겟 | 종인이 — 읽으려고는 하지만 실천 못 하는 사람. UX 결정 기준 |

상세 스펙이 필요하면 (사용자 요청 시에만): `/Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/` — 화면-UI-설계, 숲-시스템-상세, 팀-논의-설계결정, 타겟-사용자-페르소나 등.

## 8. 아키텍처 · 스택 규칙

구조는 `lib/core/`(테마·라우터·서비스) + `lib/features/<기능>/`(화면) + `lib/shared/`(models·providers·repositories·widgets). 폴더를 열어보면 알 수 있으므로 여기 나열하지 않는다.

- 상태 관리: Riverpod — **수동 선언 방식** (`NotifierProvider` 등 직접 작성). `@riverpod` 코드젠 금지 (`.g.dart` 없음, build_runner 불필요). `riverpod_annotation`이 pubspec에 있지만 미사용 — 신규도 수동 선언.
- 라우팅: GoRouter — `core/router/app_router.dart`
- 백엔드: Supabase (원격) + sqflite (로컬 캐시). 환경변수는 `.env` + `flutter_dotenv`.
- **website/** (Flutter 외부): 정적 홍보 사이트. firebase hosting `site` 타겟 — Flutter 웹 빌드(`design`/`prod` 타겟)와 별개.

## 9. Claude Code 작업 시 참고

- 저장소가 이미 대규모 미완료 리팩터로 uncommitted 상태다. `git diff <file>`은 이번 세션 변경분이 아니라 누적 전체를 보여준다 — 세션 범위 확인 시 착각 주의.
- 서브에이전트에게 좁은 범위(리터럴 치환 등)를 위임할 때는 "발견한 TODO/ponytail 주석·미완성 기능에 손대지 말 것"을 매번 명시한다. 명시하지 않으면 무관한 기능을 임의로 "복원"하는 사고가 난 적 있다.
- Flutter 3.41.9 사용 중 — `Column(spacing:)`/`Row(spacing:)` 사용 가능(3.27+). design.md가 언급하는 `ChorokColumn(gap:)`은 만들어진 적 없고 필요 없다 — 네이티브 `spacing:`으로 충분.
- **AGENTS.md는 CLAUDE.md의 사본이다** (코덱스가 읽음). CLAUDE.md를 고치면 AGENTS.md에도 그대로 반영한다 — 안 하면 코덱스와 규칙이 어긋난다.
- 코드 구현은 코덱스, 검증은 Claude 분업. 코덱스의 "완료" 보고는 그대로 믿지 말고 `flutter analyze`·`flutter test`를 직접 재실행해 확인한다.
