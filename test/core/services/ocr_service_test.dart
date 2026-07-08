import 'dart:convert';

import 'package:chorok_app/core/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  group('Gemini OCR parsing', () {
    test('환경 모델명에서 models/ 접두사를 제거한다', () {
      expect(
        normalizeGeminiModelName(' models/gemini-2.5-flash '),
        'gemini-2.5-flash',
      );
      expect(normalizeGeminiModelName(''), GeminiOcrConfig.defaultModel);
    });

    test('문단 배열을 공백 제거 후 파싱한다', () {
      expect(
        parseGeminiParagraphArray('[[" 첫 문장. ", "둘째 문장.", 3, ""], ["셋째 문장."]]'),
        [
          ['첫 문장.', '둘째 문장.'],
          ['셋째 문장.'],
        ],
      );
    });

    test('구형 평면 문장 배열은 한 문단으로 취급한다', () {
      expect(parseGeminiParagraphArray('["첫 문장.", "둘째 문장."]'), [
        ['첫 문장.', '둘째 문장.'],
      ]);
    });

    test('candidate parts에서 텍스트만 합친다', () {
      expect(
        extractGeminiResponseText({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '["첫 문장.",'},
                  {'inlineData': {}},
                  {'text': '"둘째 문장."]'},
                ],
              },
            },
          ],
        }),
        '["첫 문장.","둘째 문장."]',
      );
    });

    test('API 오류 상태만 안전하게 추출한다', () {
      expect(
        extractGeminiApiStatus(
          '{"error":{"status":"RESOURCE_EXHAUSTED","message":"private"}}',
        ),
        'RESOURCE_EXHAUSTED',
      );
      expect(extractGeminiApiStatus('not-json'), isNull);
    });

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
  });

  group('GeminiOcrService', () {
    test('API 키는 헤더로 전달하고 이미지 MIME과 구조화 출력을 요청한다', () async {
      final client = MockClient((request) async {
        expect(request.url.query, isEmpty);
        expect(request.headers['x-goog-api-key'], 'test-key');
        expect(request.url.path, contains('gemini-2.5-flash:generateContent'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final parts =
            ((body['contents'] as List).first as Map<String, dynamic>)['parts']
                as List;
        expect(
          (parts[1] as Map<String, dynamic>)['inline_data']['mime_type'],
          'image/png',
        );
        expect(
          (body['generationConfig']
              as Map<String, dynamic>)['responseMimeType'],
          'application/json',
        );

        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode([
                          ['첫 문장.', '둘째 문장.'],
                          ['셋째 문장.'],
                        ]),
                      },
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final service = GeminiOcrService(
        config: const GeminiOcrConfig(apiKey: 'test-key'),
        httpClient: client,
      );

      final result = await service.extractTextFromBytes([
        0x89,
        0x50,
        0x4E,
        0x47,
      ]);

      expect(
        result,
        isA<OcrSuccess>(),
        reason: result is OcrError ? result.message : null,
      );
      final success = result as OcrSuccess;
      expect(success.paragraphs, [
        ['첫 문장.', '둘째 문장.'],
        ['셋째 문장.'],
      ]);
      expect(success.text, '첫 문장. 둘째 문장.\n셋째 문장.');
    });

    test('권한 오류 본문을 그대로 노출하지 않는다', () async {
      final service = GeminiOcrService(
        config: const GeminiOcrConfig(apiKey: 'bad-key'),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":{"message":"internal provider details"}}',
            403,
          ),
        ),
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrError>());
      expect((result as OcrError).message, 'Gemini API 키 또는 사용 권한을 확인해 주세요');
      expect(result.message, isNot(contains('internal provider details')));
    });

    test('HTTP 400이어도 API 상태가 권한 오류면 키 안내를 반환한다', () async {
      final service = GeminiOcrService(
        config: const GeminiOcrConfig(apiKey: 'bad-key'),
        httpClient: MockClient(
          (_) async =>
              http.Response('{"error":{"status":"PERMISSION_DENIED"}}', 400),
        ),
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrError>());
      expect((result as OcrError).message, 'Gemini API 키 또는 사용 권한을 확인해 주세요');
    });

    test('candidate가 없는 응답을 명확한 오류로 처리한다', () async {
      final service = GeminiOcrService(
        config: const GeminiOcrConfig(apiKey: 'test-key'),
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'candidates': []}), 200),
        ),
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrError>());
      expect((result as OcrError).message, 'Gemini가 텍스트를 반환하지 않았어요');
    });

    test('구조화 출력이 배열이 아니면 OCR 텍스트로 오인하지 않는다', () async {
      final service = GeminiOcrService(
        config: const GeminiOcrConfig(apiKey: 'test-key'),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '{"sentences":["sentence"]}'},
                    ],
                  },
                },
              ],
            }),
            200,
          ),
        ),
      );

      final result = await service.extractTextFromBytes([0xFF, 0xD8, 0xFF]);

      expect(result, isA<OcrError>());
      expect((result as OcrError).message, 'Gemini 문장 응답 형식을 확인할 수 없어요');
    });
  });

  group('SupabaseGeminiOcrService', () {
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
