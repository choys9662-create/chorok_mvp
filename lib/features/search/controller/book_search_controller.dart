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
    state = await AsyncValue.guard(() => _invoke({
          'query': q,
          'queryType': _typeParam(_type),
        }));
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
    final res = await Supabase.instance.client.functions.invoke(
      'aladin-search',
      body: body,
    );
    final data = res.data as Map<String, dynamic>;
    final items = data['item'] as List<dynamic>? ?? [];
    return items.cast<Map<String, dynamic>>().map(AladinBook.fromJson).toList();
  }
}

final bookSearchProvider =
    AsyncNotifierProvider<BookSearchNotifier, List<AladinBook>>(
      BookSearchNotifier.new,
    );
