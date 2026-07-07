import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

sealed class MonoGptResult {
  const MonoGptResult();
}

class MonoGptSuccess extends MonoGptResult {
  final String reply;
  final String? conversationId;
  const MonoGptSuccess(this.reply, this.conversationId);
}

class MonoGptError extends MonoGptResult {
  final String message;
  const MonoGptError(this.message);
}

class MonoGptService {
  static const _endpoint = 'https://monogpt.kr/api/v1/chat';
  static const _requestTimeout = Duration(seconds: 30);

  final http.Client _httpClient;
  final String _apiKey;

  MonoGptService({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _apiKey = apiKey ?? (dotenv.env['MONOGPT_API_KEY'] ?? '');

  Future<MonoGptResult> chat(
    String message, {
    String model = 'gpt-5.1',
    String? conversationId,
  }) async {
    if (_apiKey.isEmpty) {
      return const MonoGptError('MonoGPT API 키가 설정되지 않았어요');
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'Idempotency-Key': _generateIdempotencyKey(),
            },
            body: jsonEncode({
              'model': model,
              'message': message,
              'conversationId': ?conversationId,
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode != 200) {
        return MonoGptError(
          monoGptErrorMessage(_extractErrorCode(data), response.statusCode),
        );
      }
      if (data is! Map<String, dynamic>) {
        return const MonoGptError('MonoGPT 응답 형식을 확인할 수 없어요');
      }

      return MonoGptSuccess(
        data['reply'] as String? ?? '',
        data['conversationId'] as String?,
      );
    } on TimeoutException {
      return const MonoGptError('MonoGPT 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      return const MonoGptError('MonoGPT 요청을 처리하지 못했어요');
    }
  }

  String _generateIdempotencyKey() {
    final rand = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-${rand.nextInt(1 << 32)}';
  }
}

String? _extractErrorCode(dynamic data) {
  if (data is! Map) return null;
  final error = data['error'];
  if (error is! Map) return null;
  return error['code'] as String?;
}

String monoGptErrorMessage(String? code, int statusCode) {
  return switch (code) {
    'INVALID_KEY' => 'MonoGPT API 키를 확인해 주세요',
    'PLAN_NOT_ALLOWED' => 'MonoGPT 유료 플랜이 필요해요',
    'PUBLIC_API_DISABLED' || 'PUBLIC_API_NOT_CONFIGURED' =>
      'MonoGPT 퍼블릭 API가 비활성화되어 있어요',
    'BILLING_FAILED' => 'MonoGPT 크레딧 결제에 실패했어요',
    'FILE_NOT_READY' => '파일이 아직 처리 중이에요. 잠시 후 다시 시도해 주세요.',
    'FILE_NOT_FOUND' => '파일을 찾을 수 없어요',
    _ => 'MonoGPT 요청을 처리하지 못했어요 ($statusCode)',
  };
}
