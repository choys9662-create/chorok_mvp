import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book_memo.dart';

/// 책 단위 개인 메모 리포지토리 (owner-only).
class MemoRepository {
  final SupabaseClient _c;
  MemoRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  Future<List<BookMemo>> fetchMemos({
    String? globalBookId,
    String? bookId,
  }) async {
    final me = _me;
    if (me == null) return const [];
    var q = _c
        .from('book_memos')
        .select('id, content, created_at')
        .eq('user_id', me);
    if (globalBookId != null) {
      q = q.eq('global_book_id', globalBookId);
    } else if (bookId != null) {
      q = q.eq('book_id', bookId);
    } else {
      return const [];
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => BookMemo.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<BookMemo> addMemo(
    String content, {
    String? globalBookId,
    String? bookId,
  }) async {
    final me = _me;
    if (me == null) {
      throw StateError('not signed in');
    }
    final payload = <String, dynamic>{'user_id': me, 'content': content};
    if (globalBookId != null) payload['global_book_id'] = globalBookId;
    if (bookId != null) payload['book_id'] = bookId;
    final row = await _c
        .from('book_memos')
        .insert(payload)
        .select('id, content, created_at')
        .single();
    return BookMemo.fromRow(row);
  }

  Future<void> deleteMemo(String id) async =>
      _c.from('book_memos').delete().eq('id', id);
}

final memoRepositoryProvider = Provider<MemoRepository>(
  (ref) => MemoRepository(Supabase.instance.client),
);
