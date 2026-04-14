import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../model/aladin_book.dart';

/// 알라딘 책 검색 상태 관리
///
/// - build(): 초기 빈 리스트
/// - search(query): 알라딘 API 호출 후 결과 갱신
/// - clear(): 결과 초기화
class BookSearchNotifier extends AsyncNotifier<List<AladinBook>> {
  // 알라딘 Open API 엔드포인트
  static const String _baseUrl =
      'https://www.aladin.us/ttb/api/ItemSearch.aspx';

  @override
  Future<List<AladinBook>> build() async => const [];

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchBooks(q));
  }

  void clear() => state = const AsyncValue.data([]);

  Future<List<AladinBook>> _fetchBooks(String query) async {
    return _callApi({
      'Query': query,
      'QueryType': 'Keyword',
      'MaxResults': '20',
    });
  }

  /// ISBN-13으로 단건 조회 (바코드 스캐너용 static 메서드)
  static Future<List<AladinBook>> searchByIsbn(String isbn13) async {
    const lookupUrl = 'https://www.aladin.us/ttb/api/ItemLookUp.aspx';
    final apiKey = dotenv.env['ALADIN_API_KEY'] ?? '';

    final uri = Uri.parse(lookupUrl).replace(
      queryParameters: {
        'TTBKey': apiKey,
        'itemIdType': 'ISBN13',
        'ItemId': isbn13,
        'output': 'js',
        'Version': '20131101',
        'Cover': 'MidBig',
      },
    );

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('조회 실패 (HTTP ${response.statusCode})');
    }

    final body = response.body.replaceFirst('\uFEFF', '');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final items = decoded['item'] as List<dynamic>? ?? [];

    return items.cast<Map<String, dynamic>>().map(AladinBook.fromJson).toList();
  }

  Future<List<AladinBook>> _callApi(Map<String, String> extra) async {
    final apiKey = dotenv.env['ALADIN_API_KEY'] ?? '';

    final params = {
      'TTBKey': apiKey,
      'SearchTarget': 'Book',
      'output': 'js',
      'Version': '20131101',
      'Cover': 'MidBig',
      'start': '1',
      ...extra,
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('검색 실패 (HTTP ${response.statusCode})');
    }

    final body = response.body.replaceFirst('\uFEFF', '');
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final items = decoded['item'] as List<dynamic>? ?? [];

    return items.cast<Map<String, dynamic>>().map(AladinBook.fromJson).toList();
  }
}

final bookSearchProvider =
    AsyncNotifierProvider<BookSearchNotifier, List<AladinBook>>(
      BookSearchNotifier.new,
    );
