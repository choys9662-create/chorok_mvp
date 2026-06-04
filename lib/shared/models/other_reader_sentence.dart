/// 같은 책(global_book)을 읽은 다른 독자가 수집한 문장 + 생각.
/// global_book_sentences 뷰 행에서 매핑.
class OtherReaderSentence {
  final String id;
  final String content;
  final int page;
  final String username; // display_name 우선
  final String? thought;
  final int empathyCount;
  final DateTime savedAt;

  const OtherReaderSentence({
    required this.id,
    required this.content,
    required this.page,
    required this.username,
    this.thought,
    this.empathyCount = 0,
    required this.savedAt,
  });

  factory OtherReaderSentence.fromRow(Map<String, dynamic> r) {
    final name = (r['display_name'] as String?)?.trim();
    return OtherReaderSentence(
      id: r['sentence_id'] as String,
      content: r['content'] as String,
      page: (r['page_number'] as num?)?.toInt() ?? 0,
      username: (name != null && name.isNotEmpty)
          ? name
          : (r['username'] as String? ?? '익명'),
      thought: r['thought'] as String?,
      empathyCount: (r['like_count'] as num?)?.toInt() ?? 0,
      savedAt: DateTime.parse(r['created_at'] as String),
    );
  }
}
