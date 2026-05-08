/// 빌드 타임 플래그 — `--dart-define`으로 주입
///
/// 디자인 앱(d1414): `USE_MOCK=true` — 목업 데이터 사용
/// 테스트 앱(chorok-real): 기본값 false — 실제 데이터 사용
const bool kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
