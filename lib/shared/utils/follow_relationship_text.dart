import '../repositories/follow_repository.dart';

String followActionLabel(FollowRelationship relationship) {
  if (relationship.isMutual) return '맞팔로잉';
  return switch (relationship.outgoing) {
    FollowState.none => relationship.isFollowedByTarget ? '맞팔하기' : '팔로우',
    FollowState.accepted => '팔로잉',
    FollowState.pending => '요청됨',
  };
}

String? followRelationshipHint(FollowRelationship relationship) {
  if (relationship.isMutual) return '서로 팔로우 중이에요';
  if (relationship.isFollowedByTarget) return '회원님을 팔로우해요';
  if (relationship.outgoing == FollowState.pending) return '팔로우 요청을 보냈어요';
  return null;
}

bool followActionIsFilled(FollowRelationship relationship) {
  return relationship.outgoing == FollowState.none;
}
