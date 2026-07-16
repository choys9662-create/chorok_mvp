import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/utils/sentence_normalizer.dart';

void main() {
  group('SentenceNormalizer.tokenize', () {
    test('마침표로 분리', () {
      expect(SentenceNormalizer.tokenize('첫 번째 문장. 두 번째 문장.'), [
        '첫 번째 문장',
        '두 번째 문장',
      ]);
    });

    test('느낌표·물음표로 분리', () {
      expect(SentenceNormalizer.tokenize('놀랍다! 정말? 그렇구나.'), [
        '놀랍다',
        '정말',
        '그렇구나',
      ]);
    });

    test('줄바꿈으로 분리', () {
      expect(SentenceNormalizer.tokenize('첫 줄\n둘째 줄'), ['첫 줄', '둘째 줄']);
    });

    test('연속 구분자 중복 토큰 없음', () {
      expect(SentenceNormalizer.tokenize('문장!? 다음 문장.'), ['문장', '다음 문장']);
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
      expect(SentenceNormalizer.tokenizeAndNormalize('나도, 너를 사랑해. 정말이야!'), [
        '나도너를사랑해',
        '정말이야',
      ]);
    });

    test('정규화 후 빈 토큰 제거', () {
      expect(SentenceNormalizer.tokenizeAndNormalize('!!! ...'), isEmpty);
    });
  });

  group('SentenceNormalizer.overlapUnits', () {
    // 겹문장의 ABC/AB 케이스: 기록 범위가 달라도 공통 문장 단위에서 겹쳐야 한다.
    // 이게 깨지면 전문이 100% 같은 초서에만 알림이 가던 예전 동작으로 돌아간다.
    test('기록 범위가 달라도 공통 단위에서 겹친다', () {
      // 준석은 A.B.C.D 를, 나는 B.C 를 기록했다.
      final wider = SentenceNormalizer.overlapUnits(
        '어제는 비가 내렸다. 그는 오래 창밖을 바라보았다. 아무 말도 하지 않았다. 밤이 깊어갔다.',
      );
      final narrower = SentenceNormalizer.overlapUnits(
        '그는 오래 창밖을 바라보았다. 아무 말도 하지 않았다.',
      );

      expect(wider.toSet().intersection(narrower.toSet()), isNotEmpty);
    });

    test('겹치는 문장이 없으면 교집합이 비어야 한다', () {
      final a = SentenceNormalizer.overlapUnits('어제는 비가 내렸다. 밤이 깊어갔다.');
      final b = SentenceNormalizer.overlapUnits('그는 오래 창밖을 바라보았다.');

      expect(a.toSet().intersection(b.toSet()), isEmpty);
    });

    test('짧은 단위는 흔한 표현이라 제외한다', () {
      expect(SentenceNormalizer.overlapUnits('그렇다. 아니다.'), isEmpty);
    });
  });
}
