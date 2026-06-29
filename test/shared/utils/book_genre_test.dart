import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/utils/book_genre.dart';

void main() {
  test('세부 장르가 대분류로 흡수된다', () {
    expect(classifyBookGenre('소설'), '문학');
    expect(classifyBookGenre('에세이'), '문학');
    expect(classifyBookGenre('역사소설'), '문학'); // '역사'가 아니라 '문학'
    expect(classifyBookGenre('철학'), '인문');
    expect(classifyBookGenre('철학·종교'), '인문'); // 기존 저장 라벨 재매핑
    expect(classifyBookGenre('심리'), '인문');
    expect(classifyBookGenre('컴퓨터'), '기술·IT');
    expect(classifyBookGenre('투자'), '경제·경영');
    expect(classifyBookGenre('여행'), '실용·생활');
    expect(classifyBookGenre('웹툰'), '만화');
  });

  test('역사/사회/과학은 각 대분류로', () {
    expect(classifyBookGenre('역사'), '역사');
    expect(classifyBookGenre('정치'), '사회');
    expect(classifyBookGenre('물리'), '과학');
  });

  test('빈 값/미매칭은 미분류', () {
    expect(classifyBookGenre(null), unclassifiedGenre);
    expect(classifyBookGenre(''), unclassifiedGenre);
    expect(classifyBookGenre('xyzzy'), unclassifiedGenre);
  });
}
