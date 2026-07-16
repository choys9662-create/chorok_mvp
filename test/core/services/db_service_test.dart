import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';

void main() {
  test('로컬 날짜 범위를 UTC 반열림 구간으로 직렬화한다', () {
    final range = utcDateRange(
      DateTime.parse('2026-07-16T00:00:00+09:00'),
      DateTime.parse('2026-07-17T00:00:00+09:00'),
    );

    expect(range.lowerBound, '2026-07-15T15:00:00.000Z');
    expect(range.upperBound, '2026-07-16T15:00:00.000Z');
  });
}
