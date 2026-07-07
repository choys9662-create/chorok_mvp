import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

sealed class OpenRouterResult {
  const OpenRouterResult();
}

class OpenRouterSuccess extends OpenRouterResult {
  final String reply;
  const OpenRouterSuccess(this.reply);
}

class OpenRouterError extends OpenRouterResult {
  final String message;
  const OpenRouterError(this.message);
}

class OpenRouterService {
  static const _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  static const _requestTimeout = Duration(seconds: 30);
  static const defaultModel = 'openai/gpt-4o-mini';

  final http.Client _httpClient;
  final String _apiKey;

  OpenRouterService({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _apiKey = apiKey ?? (dotenv.env['OPENROUTER_API_KEY'] ?? '');

  Future<OpenRouterResult> chat(
    String message, {
    String model = defaultModel,
  }) async {
    if (_apiKey.isEmpty) {
      return const OpenRouterError('OpenRouter API 키가 설정되지 않았어요');
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': message},
              ],
            }),
          )
          .timeout(_requestTimeout);

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode != 200) {
        return OpenRouterError(_extractErrorMessage(data, response.statusCode));
      }
      if (data is! Map<String, dynamic>) {
        return const OpenRouterError('OpenRouter 응답 형식을 확인할 수 없어요');
      }

      final reply = _extractReply(data);
      if (reply == null) {
        return const OpenRouterError('OpenRouter가 응답을 반환하지 않았어요');
      }
      return OpenRouterSuccess(reply);
    } on TimeoutException {
      return const OpenRouterError('OpenRouter 응답이 지연되고 있어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      return const OpenRouterError('OpenRouter 요청을 처리하지 못했어요');
    }
  }
}

String? _extractReply(Map<String, dynamic> data) {
  final choices = data['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  if (first is! Map) return null;
  final message = first['message'];
  if (message is! Map) return null;
  return message['content'] as String?;
}

String _extractErrorMessage(dynamic data, int statusCode) {
  if (data is Map) {
    final error = data['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
  }
  return switch (statusCode) {
    401 => 'OpenRouter API 키를 확인해 주세요',
    400 => 'OpenRouter 요청 형식이 올바르지 않아요',
    429 => 'OpenRouter 사용량 한도에 도달했어요. 잠시 후 다시 시도해 주세요',
    >= 500 => 'OpenRouter 서버가 일시적으로 응답하지 않아요',
    _ => 'OpenRouter 요청을 처리하지 못했어요 ($statusCode)',
  };
}
