import 'package:chorok_app/features/search/model/aladin_book.dart';
import 'package:chorok_app/features/search/screen/book_info_screen.dart';
import 'package:flutter_test/flutter_test.dart';

AladinBook _book({String author = '한강', String? rawAuthor}) {
  return AladinBook(
    title: '채식주의자',
    author: author,
    publisher: '창비',
    rawAuthor: rawAuthor,
  );
}

void main() {
  test('지은이·옮긴이 표기를 저자·옮긴이 행으로 파싱한다', () {
    final rows = parseBookContributors(
      _book(rawAuthor: '한강 (지은이), 데버라 스미스 (옮긴이)'),
    );
    expect(rows, [
      (name: '한강', role: '저자'),
      (name: '데버라 스미스', role: '옮긴이'),
    ]);
  });

  test('역할 표기가 없으면 저자로 간주한다', () {
    expect(parseBookContributors(_book()), [(name: '한강', role: '저자')]);
  });

  test('지은이·옮긴이 외 역할은 원문 그대로 노출한다', () {
    final rows = parseBookContributors(
      _book(rawAuthor: '앤서니 브라운 (지은이), 김향금 (그림)'),
    );
    expect(rows[1], (name: '김향금', role: '그림'));
  });
}
