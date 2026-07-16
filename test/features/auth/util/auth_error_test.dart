import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/auth/util/auth_error.dart';

void main() {
  test('알 수 없는 인증 오류는 기술 세부정보 대신 안전한 메시지를 반환한다', () {
    const raw = 'FunctionException(status: 500, details: provider_secret)';

    final message = localizeAuthError(raw);

    expect(message, '로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
    expect(message, isNot(contains('FunctionException')));
    expect(message, isNot(contains('provider_secret')));
  });
}
