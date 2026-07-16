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

  group('SupabaseGeminiOcrService', () {
    test('지원 이미지 MIME을 시그니처로 판별한다', () {
      expect(detectImageMimeType([0xFF, 0xD8, 0xFF]), 'image/jpeg');
      expect(detectImageMimeType([0x89, 0x50, 0x4E, 0x47]), 'image/png');
      expect(detectImageMimeType('RIFFxxxxWEBP'.codeUnits), 'image/webp');
      expect(
        detectImageMimeType([0, 0, 0, 0, ...'ftypheic'.codeUnits]),
        'image/heic',
      );
      expect(
        detectImageMimeType([0, 0, 0, 0, ...'ftypmif1'.codeUnits]),
        'image/heif',
      );
      expect(detectImageMimeType([1, 2, 3]), isNull);
    });

    test('이미지와 MIME만 Edge Function에 전달하고 문단 목록을 반환한다', () async {
      Map<String, dynamic>? invokedBody;
      final service = SupabaseGeminiOcrService(
        invoke: (body) async {
          invokedBody = body;
          return {
            'sentences': [' 첫 문장. ', '둘째 문장.', '셋째 문장.'],
            'paragraphs': [
              [' 첫 문장. ', '둘째 문장.'],
              ['셋째 문장.'],
            ],
          };
        },
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(invokedBody?['mimeType'], 'image/jpeg');
      expect(invokedBody?['imageBase64'], isNotEmpty);
      expect(invokedBody, isNot(contains('apiKey')));
      expect(result, isA<OcrSuccess>());
      expect((result as OcrSuccess).paragraphs, [
        ['첫 문장.', '둘째 문장.'],
        ['셋째 문장.'],
      ]);
    });

    test('문단 정보가 없는 구버전 응답은 한 문단으로 폴백한다', () async {
      final service = SupabaseGeminiOcrService(
        invoke: (_) async => {
          'sentences': [' 첫 문장. ', '둘째 문장.'],
        },
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrSuccess>());
      expect((result as OcrSuccess).paragraphs, [
        ['첫 문장.', '둘째 문장.'],
      ]);
    });

    test('프록시 응답이 문장 목록이 아니면 오류 처리한다', () async {
      final service = SupabaseGeminiOcrService(
        invoke: (_) async => {'text': 'unexpected'},
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrError>());
      expect((result as OcrError).message, 'Gemini 프록시가 문장 목록을 반환하지 않았어요');
    });

    test('프록시 상태 코드를 사용자 메시지로 변환한다', () {
      expect(supabaseGeminiErrorMessage(401), '로그인 상태를 확인한 뒤 다시 시도해 주세요');
      expect(supabaseGeminiErrorMessage(429), contains('사용량 한도'));
      expect(supabaseGeminiErrorMessage(503), contains('일시적으로 응답하지 않아요'));
    });
  });
}
