/// 빌드 타임 플래그 — `--dart-define`으로 주입
///
/// 디자인 앱(d1414): `USE_MOCK=true` — 목업 데이터 사용
/// 테스트 앱(chorok-real): 기본값 false — 실제 데이터 사용
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

/// 데이터 소스 플래그 — true면 모든 플랫폼(모바일 포함)이 책·문장·세션을
/// Supabase에서 직접 읽는다. 로컬 sqflite는 보조 기록용으로만 남는다.
/// (기기 간 데이터 동기화를 위해 2026-06 도입 — false로 되돌리면 모바일은
/// 다시 로컬 SQLite를 읽는 이전 동작으로 복귀)
const bool kUseRemoteDb = true;
