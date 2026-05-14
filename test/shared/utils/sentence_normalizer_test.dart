import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/utils/sentence_normalizer.dart';

void main() {
  group('SentenceNormalizer.tokenize', () {
    test('마침표로 분리', () {
      expect(
        SentenceNormalizer.tokenize('첫 번째 문장. 두 번째 문장.'),
        ['첫 번째 문장', '두 번째 문장'],
      );
    });

    test('느낌표·물음표로 분리', () {
      expect(
        SentenceNormalizer.tokenize('놀랍다! 정말? 그렇구나.'),
        ['놀랍다', '정말', '그렇구나'],
      );
    });

    test('줄바꿈으로 분리', () {
      expect(
        SentenceNormalizer.tokenize('첫 줄\n둘째 줄'),
        ['첫 줄', '둘째 줄'],
      );
    });

    test('연속 구분자 중복 토큰 없음', () {
      expect(
        SentenceNormalizer.tokenize('문장!? 다음 문장.'),
        ['문장', '다음 문장'],
      );
    });

    test('빈 문자열 → 빈 배열', () {
      expect(SentenceNormalizer.tokenize(''), isEmpty);
    });
  });

  group('SentenceNormalizer.normalize', () {
    test('공백 제거', () {
      expect(SentenceNormalizer.normalize('나도 너를 사랑해'), '나도너를사랑해');
    });

    test('쉼표·특수문자 제거', () {
      expect(SentenceNormalizer.normalize('나도, 너를 사랑 해'), '나도너를사랑해');
    });

    test('영문 소문자 변환', () {
      expect(SentenceNormalizer.normalize('Hello World'), 'helloworld');
    });

    test('한영 혼합', () {
      expect(SentenceNormalizer.normalize('Hello 세계!'), 'hello세계');
    });

    test('빈 문자열', () {
      expect(SentenceNormalizer.normalize(''), '');
    });
  });

  group('SentenceNormalizer.tokenizeAndNormalize', () {
    test('전체 파이프라인', () {
      expect(
        SentenceNormalizer.tokenizeAndNormalize('나도, 너를 사랑해. 정말이야!'),
        ['나도너를사랑해', '정말이야'],
      );
    });

    test('정규화 후 빈 토큰 제거', () {
      expect(
        SentenceNormalizer.tokenizeAndNormalize('!!! ...'),
        isEmpty,
      );
    });
  });
}
