/// 앱 실행 모드 — `--dart-define=APP_MODE=design|test` 로 주입.
///
/// 기본값은 `test` 이다. 테스트 앱에서 실수로 `USE_MOCK=true` 가 섞여도
/// design 모드가 아니면 mock 데이터를 켜지 않는다.
const String kAppMode = String.fromEnvironment('APP_MODE', defaultValue: 'test');

/// 빌드 타임 플래그 — `--dart-define`으로 주입
///
/// 디자인 앱(d1414): `APP_MODE=design` + `USE_MOCK=true`
/// 테스트 앱(chorok-real): `APP_MODE=test` + `USE_MOCK=false`
const bool kUseMock =
    kAppMode == 'design' &&
    bool.fromEnvironment('USE_MOCK', defaultValue: false);

/// 데이터 소스 플래그 — true면 모든 플랫폼(모바일 포함)이 책·문장·세션을
/// Supabase에서 직접 읽는다. 로컬 sqflite는 보조 기록용으로만 남는다.
/// (기기 간 데이터 동기화를 위해 2026-06 도입 — false로 되돌리면 모바일은
/// 다시 로컬 SQLite를 읽는 이전 동작으로 복귀)
const bool kUseRemoteDb = true;
