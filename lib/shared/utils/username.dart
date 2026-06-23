/// 핸들(username) 정규화·검증 — 서버(normalize_username / is_username_available,
/// profiles_username_format_chk)와 동일한 규칙. 가입 폼의 즉시 피드백용이며
/// 최종 유일성·정합성은 항상 서버가 보장한다.
///
/// 규칙: 소문자 a-z, 숫자 0-9, 밑줄(_)만. 3~20자. 연속 _ 축약, 양끝 _ 제거.
library;

const int kUsernameMinLength = 3;
const int kUsernameMaxLength = 20;
final RegExp _kUsernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

/// 임의 입력 → latin 슬러그. 비면 null. (서버 normalize_username과 동일)
String? normalizeUsername(String raw) {
  final slug = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return slug.isEmpty ? null : slug;
}

/// 핸들 형식이 유효한가 (3~20자, a-z0-9_).
bool isUsernameFormatValid(String username) =>
    _kUsernamePattern.hasMatch(username.trim().toLowerCase());

/// 형식 위반 사유 한 줄. 유효하면 null.
String? usernameFormatError(String username) {
  final u = username.trim();
  if (u.isEmpty) return null;
  if (u.length < kUsernameMinLength) return '$kUsernameMinLength자 이상 입력해주세요';
  if (u.length > kUsernameMaxLength) return '$kUsernameMaxLength자 이하로 입력해주세요';
  if (!_kUsernamePattern.hasMatch(u.toLowerCase())) {
    return '영문 소문자·숫자·밑줄(_)만 쓸 수 있어요';
  }
  return null;
}
