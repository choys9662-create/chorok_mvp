import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/widgets/book_cover.dart';

void main() {
  test('알라딘 cover150 은 흰 테두리 없는 cover500 으로 치환된다', () {
    expect(
      normalizedCoverUrl(
        'https://image.aladin.co.kr/product/3921/29/cover150/899699796x_1.jpg',
      ),
      'https://image.aladin.co.kr/product/3921/29/cover500/899699796x_1.jpg',
    );
  });

  test('알라딘 외 URL 과 null 은 그대로 통과한다', () {
    expect(normalizedCoverUrl(null), isNull);
    expect(
      normalizedCoverUrl('https://example.com/a.jpg'),
      'https://example.com/a.jpg',
    );
  });
}
