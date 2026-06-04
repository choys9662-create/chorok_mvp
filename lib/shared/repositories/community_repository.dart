import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/other_reader_sentence.dart';

/// 같은 책을 읽은 다른 독자들의 공개 문장 조회 (global_book_sentences 뷰 기반).
class CommunityRepository {
  final SupabaseClient _c;
  CommunityRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  /// isbn으로 global_book_id를 해석한 뒤 다른 독자 문장을 조회한다.
  Future<List<OtherReaderSentence>> fetchOtherReaders({String? isbn}) async {
    if (isbn == null || isbn.isEmpty) return const [];
    final gb = await _c
        .from('global_books')
        .select('id')
        .eq('isbn13', isbn)
        .maybeSingle();
    final gid = gb?['id'] as String?;
    if (gid == null) return const [];

    final me = _me;
    final rows = await _c
        .from('global_book_sentences')
        .select(
          'sentence_id, content, page_number, thought, like_count, '
          'created_at, user_id, username, display_name',
        )
        .eq('global_book_id', gid)
        .order('like_count', ascending: false)
        .limit(20);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => r['user_id'] != me)
        .map(OtherReaderSentence.fromRow)
        .toList();
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(Supabase.instance.client),
);
