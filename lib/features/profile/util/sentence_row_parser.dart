import '../../../shared/models/reading_session.dart';

/// Supabase sentences 조인 row를 FeedSentence로 변환하는 순수 함수.
/// 피드와 유저 프로필 화면이 공유한다.
///
/// [fallbackUsername]은 row에 profiles 조인이 없을 때 사용한다 (예: 본인 문장 → '나').
FeedSentence parseSentenceRow(
  Map<String, dynamic> row, {
  required String fallbackUsername,
}) {
  final localBook = row['books'] as Map<String, dynamic>?;
  final globalBook = row['global_books'] as Map<String, dynamic>?;
  final book = globalBook ?? localBook;

  final profile = row['profiles'] as Map<String, dynamic>?;
  final username =
      (profile?['display_name'] as String?) ??
      (profile?['username'] as String?) ??
      fallbackUsername;

  final likesAgg = row['sentence_likes'] as List?;
  final likeCount = likesAgg != null && likesAgg.isNotEmpty
      ? ((likesAgg.first as Map)['count'] as int? ?? 0)
      : 0;

  final createdAt =
      DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

  return FeedSentence(
    id: row['id'] as String? ?? '',
    content: row['content'] as String? ?? '',
    thought: row['thought'] as String?,
    bookTitle: book?['title'] as String? ?? '알 수 없는 책',
    bookAuthor: book?['author'] as String? ?? '',
    coverUrl: book?['cover_url'] as String?,
    isbn13: globalBook?['isbn13'] as String? ?? localBook?['isbn'] as String?,
    username: username,
    savedAt: createdAt,
    empathyCount: likeCount,
  );
}
