import 'package:chorok_app/core/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeOcrText', () {
    test('한국어 줄 중간 개행을 이어 붙인다', () {
      expect(
        normalizeOcrText('도덕법\n칙이 동기인 한에\n서 이 동기가'),
        '도덕법칙이 동기인 한에서 이 동기가',
      );
    });

    test('문장부호 뒤 개행은 공백으로 이어 붙인다', () {
      expect(normalizeOcrText('보여주어야 한다.\n다음 문장이다.'), '보여주어야 한다. 다음 문장이다.');
    });

    test('영문 개행은 공백으로 이어 붙인다', () {
      expect(normalizeOcrText('hello\nworld'), 'hello world');
    });
  });
}
