# AGENTS.md

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

## 6. Product Knowledge

**Do not read the wiki unless the user asks for it.** Most coding decisions should be made from the inline product decisions below.

Read `/Users/joyongseong/Documents/dev/Obsidian Vault/` only when:
- The user explicitly asks to check the wiki, planning docs, or product spec.
- The code and this file do not contain enough product detail to implement correctly.
- The task is ideation/planning rather than app implementation.

When a code change creates or changes a durable product/design decision, ask whether the wiki should be updated. Do not update the wiki during ordinary coding work unless requested.

**Confirmed decisions for code work:**

| Decision | Content |
|---|---|
| Bottom tabs | Home / CHOLOCK(book) / Forest / Social / MY. Do not change order or composition. |
| Library location | Library belongs inside the MY tab. It is not a separate tab. |
| Do not add | SNS sharing, challenges. Do not suggest these as features. |
| UX principle | The app presents information algorithmically instead of making the user choose up front. Reduce start friction. |
| Feed matching | Default taste match is 95%. User can adjust down to 80%. |
| Social unit | A choso block is the base unit for likes and comments. |
| Target user | Jongin: someone who wants to read but struggles to actually start. Use this as a UX decision baseline. |

**Wiki references only when explicitly needed:**

```
Screen specs        -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/화면-UI-설계.md
Forest system       -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/숲-시스템-상세.md
Decision background -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/팀-논의-설계결정.md
Target user         -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/타겟-사용자-페르소나.md
Competitors         -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/경쟁사-분석.md
Business model      -> /Users/joyongseong/Documents/dev/Obsidian Vault/wiki/analyses/비즈니스-모델.md
```

---

## 7. Project Architecture

Flutter commands must run from `/Users/joyongseong/Documents/dev/chorok_app`, where `pubspec.yaml` lives.

```
lib/
├── core/
│   ├── constants/
│   ├── services/
│   ├── theme/
│   └── router/
├── features/
│   ├── home/
│   ├── library/
│   ├── timer/
│   ├── forest/
│   ├── feed/
│   ├── explore/
│   ├── auth/
│   ├── onboarding/
│   ├── search/
│   ├── settings/
│   ├── analytics/
│   └── achievements/
└── shared/
    ├── models/
    ├── providers/
    ├── repositories/
    ├── widgets/
    └── utils/
```

Stack rules:
- State management: Riverpod with `@riverpod` annotations.
- Routing: GoRouter. Route definitions live in `lib/core/router/app_router.dart`.
- Backend: Supabase remote data plus sqflite local cache.
- Environment variables: `.env` loaded by `flutter_dotenv`.
- Fonts: Pretendard by default, Chosun Gulim for brand text.

Common commands:

```bash
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze )
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter test )
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run )
( cd /Users/joyongseong/Documents/dev/chorok_app && flutter run -d web-server --web-port 8080 --dart-define=USE_MOCK=true )
```
