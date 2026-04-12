/// DB 독서 세션 행 모델 (sqflite)
class IsarReadingSession {
  final int? isarId;
  final String sessionId;
  final String? bookId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final int pagesRead;
  final int choseoCount;

  const IsarReadingSession({
    this.isarId,
    required this.sessionId,
    this.bookId,
    required this.startedAt,
    required this.endedAt,
    this.durationSeconds = 0,
    this.pagesRead = 0,
    this.choseoCount = 0,
  });

  Map<String, dynamic> toMap() => {
        'session_id': sessionId,
        'book_id': bookId,
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'pages_read': pagesRead,
        'choseo_count': choseoCount,
      };

  factory IsarReadingSession.fromMap(Map<String, dynamic> m) =>
      IsarReadingSession(
        isarId: m['id'] as int?,
        sessionId: m['session_id'] as String,
        bookId: m['book_id'] as String?,
        startedAt: DateTime.parse(m['started_at'] as String),
        endedAt: DateTime.parse(m['ended_at'] as String),
        durationSeconds: m['duration_seconds'] as int? ?? 0,
        pagesRead: m['pages_read'] as int? ?? 0,
        choseoCount: m['choseo_count'] as int? ?? 0,
      );
}
