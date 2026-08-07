import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/aladin_book.dart';

enum BookSearchType { keyword, title, author }

const bookSearchFailureMessage = '검색 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.';

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
    final searchType = _type;
    state = await AsyncValue.guard(() async {
      final books = await invoke({
        'query': q,
        'queryType': _typeParam(searchType),
      });
      // 알라딘 ItemSearch는 QueryType(Title/Author/Keyword)을 사실상 무시하고
      // 항상 keyword 검색으로 동작한다. '작가' 탭이 의미를 가지려면 저자명으로
      // 클라이언트에서 걸러야 한다.
      // ponytail: 첫 저자(지은이) 기준 매칭. 공동저자 2순위/옮긴이는 제외 —
      //   정밀 매칭 필요하면 model에 rawAuthor 보존 후 그걸로 검색.
      if (searchType == BookSearchType.author) {
        final needle = q.toLowerCase();
        return books
            .where((b) => b.author.toLowerCase().contains(needle))
            .toList();
      }
      return books;
    });
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
      invoke({'isbn': isbn13});

  static String _typeParam(BookSearchType t) => switch (t) {
    BookSearchType.keyword => 'Keyword',
    BookSearchType.title => 'Title',
    BookSearchType.author => 'Author',
  };

  static Future<List<AladinBook>> invoke(Map<String, dynamic> body) async {
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
    } on FunctionException catch (error, stackTrace) {
      debugPrint(
        '[도서 검색 서버 오류] ${error.status}: ${error.details}\n$stackTrace',
      );
      throw Exception(bookSearchFailureMessage);
    } catch (error, stackTrace) {
      debugPrint('[도서 검색 오류] $error\n$stackTrace');
      throw Exception(bookSearchFailureMessage);
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
