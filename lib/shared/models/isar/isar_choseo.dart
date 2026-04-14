/// 로컬 DB 수집 문장 행 모델 (sqflite)
class IsarChoseo {
  final int? isarId;
  final String choseoId;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final String content;      // 인용구 (필수)
  final String? myThought;   // 내 생각 (선택)
  final String? coverUrl;    // 책 표지 URL (있으면 표시)
  final int? pageNumber;
  final String? reflection;  // 나중에 추가한 리플렉션 메모
  final DateTime createdAt;

  const IsarChoseo({
    this.isarId,
    required this.choseoId,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.content,
    this.myThought,
    this.coverUrl,
    this.pageNumber,
    this.reflection,
    required this.createdAt,
  });

  IsarChoseo copyWith({String? reflection}) {
    return IsarChoseo(
      isarId: isarId,
      choseoId: choseoId,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      content: content,
      myThought: myThought,
      coverUrl: coverUrl,
      pageNumber: pageNumber,
      reflection: reflection ?? this.reflection,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'choseo_id': choseoId,
        'book_id': bookId,
        'book_title': bookTitle,
        'book_author': bookAuthor,
        'content': content,
        'my_thought': myThought,
        'cover_url': coverUrl,
        'page_number': pageNumber,
        'reflection': reflection,
        'created_at': createdAt.toIso8601String(),
      };

  factory IsarChoseo.fromMap(Map<String, dynamic> m) => IsarChoseo(
        isarId: m['id'] as int?,
        choseoId: m['choseo_id'] as String,
        bookId: m['book_id'] as String,
        bookTitle: m['book_title'] as String,
        bookAuthor: m['book_author'] as String,
        content: m['content'] as String,
        myThought: m['my_thought'] as String?,
        coverUrl: m['cover_url'] as String?,
        pageNumber: m['page_number'] as int?,
        reflection: m['reflection'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
