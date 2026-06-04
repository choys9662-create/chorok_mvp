enum NotificationType { follow, like, comment, overlap }

/// 알림 — DB에는 구조화(type+actor+sentence)로 저장하고, 한국어 문구는 앱에서 렌더링한다.
class AppNotification {
  final String id;
  final NotificationType type;
  final String actorName; // actor display_name (없으면 username)
  final String? actorId;
  final String? sentenceId;
  final String? sentenceContent;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    this.actorId,
    this.sentenceId,
    this.sentenceContent,
    required this.isRead,
    required this.createdAt,
  });

  String get title => switch (type) {
    NotificationType.follow => '$actorName님이 회원님을 팔로우해요',
    NotificationType.like => '$actorName님이 내 문장을 좋아해요',
    NotificationType.comment => '$actorName님이 내 문장에 생각을 남겼어요',
    NotificationType.overlap => '$actorName님과 같은 문장을 수집했어요',
  };

  String get body => sentenceContent == null ? '' : '"$sentenceContent"';

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    actorName: actorName,
    actorId: actorId,
    sentenceId: sentenceId,
    sentenceContent: sentenceContent,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  static NotificationType _type(String s) => switch (s) {
    'follow' => NotificationType.follow,
    'like' => NotificationType.like,
    'comment' => NotificationType.comment,
    _ => NotificationType.overlap,
  };

  factory AppNotification.fromRow(Map<String, dynamic> r) {
    final actor = r['actor'] as Map<String, dynamic>?;
    final sentence = r['sentence'] as Map<String, dynamic>?;
    final name = (actor?['display_name'] as String?)?.trim();
    final uname = actor?['username'] as String?;
    return AppNotification(
      id: r['id'] as String,
      type: _type(r['type'] as String),
      actorName: (name != null && name.isNotEmpty) ? name : (uname ?? '누군가'),
      actorId: actor?['id'] as String?,
      sentenceId: r['sentence_id'] as String?,
      sentenceContent: sentence?['content'] as String?,
      isRead: r['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }
}
