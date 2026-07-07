import 'dart:convert';

import 'package:chorok_app/core/services/openrouter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('성공 응답에서 choices[0].message.content를 파싱한다', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test_key');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': '안녕하세요!'},
              },
            ],
          }),
        ),
        200,
      );
    });
    final service = OpenRouterService(httpClient: client, apiKey: 'test_key');

    final result = await service.chat('hi');

    expect(result, isA<OpenRouterSuccess>());
    expect((result as OpenRouterSuccess).reply, '안녕하세요!');
  });

  test('error.message가 있으면 그대로 노출한다', () async {
    final client = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'error': {'message': 'openai/bad-model is not a valid model ID'},
          }),
        ),
        400,
      );
    });
    final service = OpenRouterService(httpClient: client, apiKey: 'test_key');

    final result = await service.chat('hi', model: 'openai/bad-model');

    expect(result, isA<OpenRouterError>());
    expect(
      (result as OpenRouterError).message,
      'openai/bad-model is not a valid model ID',
    );
  });

  test('API 키가 없으면 요청을 보내지 않고 바로 에러를 반환한다', () async {
    final client = MockClient((request) async {
      fail('키가 없을 땐 호출되면 안 된다');
    });
    final service = OpenRouterService(httpClient: client, apiKey: '');

    final result = await service.chat('hi');

    expect(result, isA<OpenRouterError>());
  });
}
