import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/comment.dart';

/// 문장 댓글 + 댓글 공감(좋아요) 리포지토리.
class CommentRepository {
  final SupabaseClient _c;
  CommentRepository(this._c);

  String? get _me => _c.auth.currentUser?.id;

  /// 문장의 최상위 댓글을 최신순으로 반환. 각 댓글의 `replies`에는 1단계 답글이
  /// 작성 시간 오름차순(오래된 답글이 위)으로 담긴다.
  Future<List<Comment>> fetchComments(String sentenceId) async {
    final rows = await _c
        .from('sentence_comments')
        .select(
          'id, sentence_id, user_id, content, like_count, created_at, '
          'parent_comment_id, '
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

    Comment toComment(Map<String, dynamic> r, List<Comment> replies) {
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
        parentCommentId: r['parent_comment_id'] as String?,
        replies: replies,
      );
    }

    // 답글을 부모 id로 그룹핑 (오름차순: 쿼리는 내림차순이므로 뒤집는다)
    final repliesByParent = <String, List<Comment>>{};
    for (final r in list) {
      final pid = r['parent_comment_id'] as String?;
      if (pid != null) {
        (repliesByParent[pid] ??= []).insert(0, toComment(r, const []));
      }
    }

    return list
        .where((r) => r['parent_comment_id'] == null)
        .map((r) => toComment(r, repliesByParent[r['id']] ?? const []))
        .toList();
  }

  /// 댓글 또는 답글 작성. [parentCommentId]가 있으면 1단계 답글로 저장된다.
  Future<Comment> addComment(
    String sentenceId,
    String content, {
    String? parentCommentId,
  }) async {
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
          'parent_comment_id': ?parentCommentId,
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
      parentCommentId: parentCommentId,
    );
  }

  Future<void> deleteComment(String id) async =>
      _c.from('sentence_comments').delete().eq('id', id);

  Future<void> likeComment(String id) async {
    final me = _me;
    if (me == null) return;
    await _c.from('sentence_comment_likes').insert({
      'comment_id': id,
      'user_id': me,
    });
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
