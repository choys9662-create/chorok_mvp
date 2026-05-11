import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/aladin_book.dart';

enum BookSearchType { keyword, title, author }

class BookSearchNotifier extends AsyncNotifier<List<AladinBook>> {
  BookSearchType _type = BookSearchType.keyword;
  String _lastQuery = '';

  @override
  Future<List<AladinBook>> build() async => const [];

  Future<void> search(String query, {BookSearchType? type}) async {
    final q = query.trim();
    _lastQuery = q;
    if (type != null) _type = type;
    if (q.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _invoke({'query': q, 'queryType': _typeParam(_type)}),
    );
  }

  void setType(BookSearchType type) {
    if (_type == type) return;
    _type = type;
    if (_lastQuery.isNotEmpty) {
      search(_lastQuery, type: type);
    }
  }

  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }

  static Future<List<AladinBook>> searchByIsbn(String isbn13) =>
      _invoke({'isbn': isbn13});

  static String _typeParam(BookSearchType t) => switch (t) {
    BookSearchType.keyword => 'Keyword',
    BookSearchType.title => 'Title',
    BookSearchType.author => 'Author',
  };

  static Future<List<AladinBook>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'aladin-search',
        body: body,
      );
      final data = res.data as Map<String, dynamic>;
      final items = data['item'] as List<dynamic>? ?? [];
      return items
          .cast<Map<String, dynamic>>()
          .map(AladinBook.fromJson)
          .toList();
    } catch (e) {
      if (e is FunctionException) {
        throw Exception('검색 서버 에러 (${e.status}): ${e.details ?? e.toString()}');
      }
      throw Exception('검색 중 오류가 발생했습니다: $e');
    }
  }
}

final bookSearchProvider =
    AsyncNotifierProvider<BookSearchNotifier, List<AladinBook>>(
      BookSearchNotifier.new,
    );

/// 알라딘 ItemLookUp으로 페이지 수만 조회.
///
/// `ItemSearch` 응답의 `subInfo.itemPage`는 누락되는 경우가 많아
/// 책 추가 후 백그라운드로 보강할 때 사용한다.
/// 페이지 수가 0 이거나 조회 실패 시 null 반환.
Future<int?> fetchTotalPagesByIsbn(String isbn13) async {
  try {
    final results = await BookSearchNotifier.searchByIsbn(isbn13);
    if (results.isEmpty) return null;
    final pages = results.first.totalPages;
    return pages > 0 ? pages : null;
  } catch (_) {
    return null;
  }
}
