/// 독서 세션 모델
class ReadingSession {
  final String id;
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final List<String> collectedSentences;

  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.collectedSentences = const [],
  });

  /// 독서 시간 형식화 (예: "1시간 23분")
  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '$durationSeconds초';
  }

  bool get isActive => endedAt == null;

  ReadingSession copyWith({
    int? durationSeconds,
    DateTime? endedAt,
    List<String>? collectedSentences,
  }) {
    return ReadingSession(
      id: id,
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      startedAt: startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      collectedSentences: collectedSentences ?? this.collectedSentences,
    );
  }
}

/// 책 모델
class Book {
  final String id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? isbn;
  final ReadingStatus status;
  final int totalPages;
  final int currentPage;
  final double totalReadingHours;
  final List<String> savedSentences;
  final DateTime? completedAt;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.isbn,
    this.status = ReadingStatus.wantToRead,
    this.totalPages = 0,
    this.currentPage = 0,
    this.totalReadingHours = 0,
    this.savedSentences = const [],
    this.completedAt,
  });

  double get readingProgress =>
      totalPages > 0 ? currentPage / totalPages : 0.0;
}

enum ReadingStatus {
  reading,      // 읽는 중
  completed,    // 읽음
  wantToRead,   // 읽고 싶어요
}

extension ReadingStatusLabel on ReadingStatus {
  String get label {
    switch (this) {
      case ReadingStatus.reading: return '독서 중';
      case ReadingStatus.completed: return '완독';
      case ReadingStatus.wantToRead: return '위시';
    }
  }

}

/// 피드 문장 모델
class FeedSentence {
  final String id;
  final String content;
  final String? thought; // 유저의 생각/해석
  final String bookTitle;
  final String bookAuthor;
  final String username;
  final DateTime savedAt;
  final int empathyCount;
  final int commentCount; // 같은 문장에 대한 다른 생각 수
  final bool isLiked;
  final bool isOverlap; // 겹문장 여부

  const FeedSentence({
    required this.id,
    required this.content,
    this.thought,
    required this.bookTitle,
    required this.bookAuthor,
    required this.username,
    required this.savedAt,
    this.empathyCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isOverlap = false,
  });
}
