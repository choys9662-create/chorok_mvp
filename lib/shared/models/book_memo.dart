/// 책 단위 개인 메모 (완전 비공개).
class BookMemo {
  final String id;
  final String content;
  final DateTime createdAt;

  const BookMemo({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  factory BookMemo.fromRow(Map<String, dynamic> r) => BookMemo(
    id: r['id'] as String,
    content: r['content'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}
