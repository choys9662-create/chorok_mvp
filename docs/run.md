# 실행 · 배포 · 테스트 데이터

## 실행 — 시뮬레이터·실기기·빌드

**`flutter` 명령은 반드시 `chorok_app/`에서 실행한다** (dev/ 루트에서는 `( cd .../chorok_app && flutter ... )`). launch 설정: `chorok_app/.claude/launch.json`.

**디바이스 ID (고정값):**

```bash
# 실기기 아이폰 (실데이터) — 개발 중 폰 테스트의 기본. 핫 리로드 r / 리스타트 R
flutter run -d 00008120-0011549E3640C01E
# 디자인 앱 시뮬레이터 "New Chorok iPhone" (목업)
flutter run -d C7F969E8-97C3-4A20-AAA4-E44AC9DC47F0 --dart-define=USE_MOCK=true
# 웹 목업
flutter run -d web-server --web-port 8080 --dart-define=USE_MOCK=true
```

시뮬레이터는 구글 로그인 불가 — 실사용 테스트는 실기기로. 실기기 최초 1회는 Xcode에서 Team 지정 필요(무료 개인 팀, 7일마다 만료 → `flutter run`으로 재서명).

## iOS gotcha (건드리지 말 것)

1. `Runner.entitlements`는 의도적으로 비어 있다. 무료 팀으로는 Sign in with Apple entitlement 프로비저닝 불가(`0xe8008001` 크래시) — 유료 가입 전까지 유지.
2. `path_provider_foundation`은 `dependency_overrides`로 2.5.1 고정. 2.6.x는 iOS 시뮬레이터에서 dlopen 실패로 흰 화면 크래시 — 올리지 않는다.

## 검증 (커밋·푸시 전)

`flutter analyze` + `flutter test` (test/는 lib/ 구조 미러링).

## Git · 배포 · 테스트 데이터

- 개발 루프는 실기기 핫 리로드. 웹 배포는 링크 공유/최종 확인용.
- `main` 직접 커밋·푸시가 기본. 머지 시 GitHub Actions 자동 배포: 디자인앱(`chorok-d1414`, USE_MOCK) + 실앱(`chorok-real`). 롤백은 `git revert <머지커밋>`.
- dev/prod DB 미분리 (단일 운영 Supabase). 테스트는 **전용 테스트 구글 계정**으로만 로그인. 정리는 `supabase/scripts/purge_test_user.sql` (auth.users cascade). DB 분리는 실유저 직전에.
