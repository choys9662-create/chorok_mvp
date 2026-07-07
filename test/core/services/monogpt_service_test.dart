import 'dart:convert';

import 'package:chorok_app/core/services/monogpt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('성공 응답에서 reply와 conversationId를 파싱한다', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test_key');
      return http.Response.bytes(
        utf8.encode(jsonEncode({'reply': '안녕하세요', 'conversationId': 'conv_1'})),
        200,
      );
    });
    final service = MonoGptService(httpClient: client, apiKey: 'test_key');

    final result = await service.chat('hi');

    expect(result, isA<MonoGptSuccess>());
    expect((result as MonoGptSuccess).reply, '안녕하세요');
    expect(result.conversationId, 'conv_1');
  });

  test('에러 코드가 있으면 사람이 읽을 수 있는 메시지로 매핑한다', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'error': {'code': 'BILLING_FAILED'},
        }),
        402,
      );
    });
    final service = MonoGptService(httpClient: client, apiKey: 'test_key');

    final result = await service.chat('hi');

    expect(result, isA<MonoGptError>());
    expect((result as MonoGptError).message, 'MonoGPT 크레딧 결제에 실패했어요');
  });

  test('API 키가 없으면 요청을 보내지 않고 바로 에러를 반환한다', () async {
    final client = MockClient((request) async {
      fail('키가 없을 땐 호출되면 안 된다');
    });
    final service = MonoGptService(httpClient: client, apiKey: '');

    final result = await service.chat('hi');

    expect(result, isA<MonoGptError>());
  });
}
