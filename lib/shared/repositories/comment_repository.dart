import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';

/// 문장 댓글 + 댓글 공감(좋아요) 리포지토리.
class CommentRepository {
  final SupabaseClient _c;
  CommentRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  Future<List<Comment>> fetchComments(String sentenceId) async {
    final rows = await _c
        .from('sentence_comments')
        .select(
          'id, sentence_id, user_id, content, like_count, created_at, '
          'profiles!sentence_comments_user_id_fkey(username, display_name)',
        )
        .eq('sentence_id', sentenceId)
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    final me = _me;
    Set<String> liked = {};
    if (me != null && list.isNotEmpty) {
      final ids = list.map((r) => r['id'] as String).toList();
      final likeRows = await _c
          .from('sentence_comment_likes')
          .select('comment_id')
          .eq('user_id', me)
          .inFilter('comment_id', ids);
      liked = (likeRows as List)
          .map((r) => (r as Map<String, dynamic>)['comment_id'] as String)
          .toSet();
    }

    return list.map((r) {
      final p = r['profiles'] as Map<String, dynamic>?;
      final name = (p?['display_name'] as String?)?.trim();
      return Comment(
        id: r['id'] as String,
        sentenceId: r['sentence_id'] as String,
        userId: r['user_id'] as String,
        username: (name != null && name.isNotEmpty)
            ? name
            : (p?['username'] as String? ?? '익명'),
        handle: (p?['username'] as String?)?.trim(),
        content: r['content'] as String,
        likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
        likedByMe: liked.contains(r['id']),
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  Future<Comment> addComment(String sentenceId, String content) async {
    final me = _me;
    if (me == null) {
      throw StateError('not signed in');
    }
    final row = await _c
        .from('sentence_comments')
        .insert({
          'sentence_id': sentenceId,
          'user_id': me,
          'content': content,
        })
        .select('id, created_at')
        .single();
    return Comment(
      id: row['id'] as String,
      sentenceId: sentenceId,
      userId: me,
      username: '나',
      content: content,
      likeCount: 0,
      likedByMe: false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> deleteComment(String id) async =>
      _c.from('sentence_comments').delete().eq('id', id);

  Future<void> likeComment(String id) async {
    final me = _me;
    if (me == null) return;
    await _c
        .from('sentence_comment_likes')
        .insert({'comment_id': id, 'user_id': me});
  }

  Future<void> unlikeComment(String id) async {
    final me = _me;
    if (me == null) return;
    await _c
        .from('sentence_comment_likes')
        .delete()
        .eq('comment_id', id)
        .eq('user_id', me);
  }
}

final commentRepositoryProvider = Provider<CommentRepository>(
  (ref) => CommentRepository(Supabase.instance.client),
);
