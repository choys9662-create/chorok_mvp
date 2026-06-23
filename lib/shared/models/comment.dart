/// 문장(초서 블록)에 달린 댓글 — 소셜 단위는 문장.
class Comment {
  final String id;
  final String sentenceId;
  final String userId;
  final String username; // display_name 우선, 없으면 username
  final String? handle; // @아이디 (동명이인 구분용)
  final String content;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.sentenceId,
    required this.userId,
    required this.username,
    this.handle,
    required this.content,
    required this.likeCount,
    required this.likedByMe,
    required this.createdAt,
  });

  Comment copyWith({int? likeCount, bool? likedByMe}) => Comment(
    id: id,
    sentenceId: sentenceId,
    userId: userId,
    username: username,
    handle: handle,
    content: content,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    createdAt: createdAt,
  );
}
