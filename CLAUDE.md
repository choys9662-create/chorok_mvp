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

- If you modify the UI/UX or layout in the "Design App" (mockup environment), you MUST apply the exact same visual changes to the "Test App" (real data environment).
- Keep the look, feel, and component structure 100% identical across both environments. Only the data source (mock data vs. real database/API) should differ.
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
| 하단 탭 | 홈 / CHOLOCK(책) / 숲 / 소셜 / MY — 순서·구성 변경 불가 |
| 서재 위치 | MY 탭 안에 포함. 별도 탭 없음 |
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