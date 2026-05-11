/// DB 완독 회고 행 모델 (sqflite)
class IsarBookReflection {
  final int? isarId;
  final String reflectionId;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final int starRating; // 1 ~ 5
  final String? memorableLine; // 기억에 남는 문장
  final String? legacy; // 이 책이 남긴 것
  final DateTime createdAt;

  const IsarBookReflection({
    this.isarId,
    required this.reflectionId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.starRating,
    this.memorableLine,
    this.legacy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'reflection_id': reflectionId,
    'book_id': bookId,
    'book_title': bookTitle,
    'book_author': bookAuthor,
    'star_rating': starRating,
    'memorable_line': memorableLine,
    'legacy': legacy,
    'created_at': createdAt.toIso8601String(),
  };

  factory IsarBookReflection.fromMap(Map<String, dynamic> m) =>
      IsarBookReflection(
        isarId: m['id'] as int?,
        reflectionId: m['reflection_id'] as String,
        bookId: m['book_id'] as String,
        bookTitle: m['book_title'] as String,
        bookAuthor: m['book_author'] as String,
        starRating: m['star_rating'] as int,
        memorableLine: m['memorable_line'] as String?,
        legacy: m['legacy'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
