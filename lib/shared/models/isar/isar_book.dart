/// DB 책 행 모델 (sqflite)
///
/// 파일명/클래스명은 Isar 설계 명세를 유지하되, 내부 구현은 sqflite.
/// Isar 3.1이 Dart 3.11 analyzer와 호환되지 않아 sqflite로 대체.
class IsarBook {
  final int? isarId;         // sqflite rowid
  final String bookId;       // 앱 고유 ID (isbn13 or 생성 ID)
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;
  final int currentPage;
  final int totalPages;
  final IsarReadingStatus status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const IsarBook({
    this.isarId,
    required this.bookId,
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
    this.currentPage = 0,
    this.totalPages = 0,
    this.status = IsarReadingStatus.reading,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  IsarBook copyWith({
    int? isarId,
    int? currentPage,
    int? totalPages,
    IsarReadingStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return IsarBook(
      isarId: isarId ?? this.isarId,
      bookId: bookId,
      title: title,
      author: author,
      isbn: isbn,
      coverUrl: coverUrl,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'book_id': bookId,
        'title': title,
        'author': author,
        'isbn': isbn,
        'cover_url': coverUrl,
        'current_page': currentPage,
        'total_pages': totalPages,
        'status': status.name,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory IsarBook.fromMap(Map<String, dynamic> m) => IsarBook(
        isarId: m['id'] as int?,
        bookId: m['book_id'] as String,
        title: m['title'] as String,
        author: m['author'] as String,
        isbn: m['isbn'] as String?,
        coverUrl: m['cover_url'] as String?,
        currentPage: m['current_page'] as int? ?? 0,
        totalPages: m['total_pages'] as int? ?? 0,
        status: IsarReadingStatus.values.firstWhere(
          (e) => e.name == (m['status'] as String? ?? 'reading'),
          orElse: () => IsarReadingStatus.reading,
        ),
        completedAt: m['completed_at'] != null
            ? DateTime.tryParse(m['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );
}

enum IsarReadingStatus { reading, completed, wantToRead }
