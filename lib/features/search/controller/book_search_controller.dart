import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/aladin_book.dart';

class BookSearchNotifier extends AsyncNotifier<List<AladinBook>> {
  @override
  Future<List<AladinBook>> build() async => const [];

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _invoke({'query': q}));
  }

  void clear() => state = const AsyncValue.data([]);

  static Future<List<AladinBook>> searchByIsbn(String isbn13) =>
      _invoke({'isbn': isbn13});

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
