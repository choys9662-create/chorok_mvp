/// 피드 활동(소식) 모델 — 친구/이웃의 독서 활동 이벤트.
///
/// 기존 문장 단위(FeedSentence) 피드를 대체하는 "활동 이벤트" 단위.
/// - sentenceBatch: 문장을 N개 기록함
/// - sessionComplete: 독서 세션을 완료함
/// - bookComplete: 도서를 완독함
enum FeedActivityType { sentenceBatch, sessionComplete, bookComplete }

/// 활동 카드 안에 미리보기로 노출되는 개별 문장.
class FeedActivitySentence {
  final String? id;
  final String content;
  final String? thought;
  final int? pageNumber;

  const FeedActivitySentence({
    this.id,
    required this.content,
    this.thought,
    this.pageNumber,
  });
}

class FeedActivity {
  final String id;
  final FeedActivityType type;

  // 행위자
  final String username; // 표시명 (display_name)
  final String? handle; // @아이디 (동명이인 구분용)
  final String? avatarUrl;
  final bool isFriend;

  // 책
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final String? isbn13;

  final DateTime occurredAt;

  // sentenceBatch 전용
  final int sentenceCount;
  final List<FeedActivitySentence> previewSentences;

  // sessionComplete 전용
  final int durationSeconds;

  // bookComplete 전용
  final int progressPercent;

  const FeedActivity({
    required this.id,
    required this.type,
    required this.username,
    this.handle,
    this.avatarUrl,
    this.isFriend = false,
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    this.isbn13,
    required this.occurredAt,
    this.sentenceCount = 0,
    this.previewSentences = const [],
    this.durationSeconds = 0,
    this.progressPercent = 100,
  });

  /// "1시간 30분" 형식
  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
    if (m > 0) return '$m분';
    return '$durationSeconds초';
  }
}

/// 피드 범위 필터.
enum FeedScope { friends, all }
