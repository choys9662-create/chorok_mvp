/// Supabase sentences 테이블 row 모델
class SentenceRecord {
  final String id;
  final String userId;
  final String? bookId;
  final String? sessionId;
  final String content;
  final String? thought;
  final List<String> normalizedSentences;
  final DateTime createdAt;

  const SentenceRecord({
    required this.id,
    required this.userId,
    this.bookId,
    this.sessionId,
    required this.content,
    this.thought,
    required this.normalizedSentences,
    required this.createdAt,
  });

  factory SentenceRecord.fromMap(Map<String, dynamic> m) => SentenceRecord(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    bookId: m['book_id'] as String?,
    sessionId: m['session_id'] as String?,
    content: m['content'] as String,
    thought: m['thought'] as String?,
    normalizedSentences: (m['normalized_sentences'] as List<dynamic>?)
        ?.map((s) => s.toString())
        .toList() ??
    [],
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
