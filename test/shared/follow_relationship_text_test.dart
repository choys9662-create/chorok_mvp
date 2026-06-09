import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/shared/repositories/follow_repository.dart';
import 'package:chorok_app/shared/utils/follow_relationship_text.dart';

void main() {
  test('mutual accepted relationship renders as mutual following', () {
    const relationship = FollowRelationship(
      outgoing: FollowState.accepted,
      incoming: FollowState.accepted,
    );

    expect(followActionLabel(relationship), '맞팔로잉');
    expect(followRelationshipHint(relationship), '서로 팔로우 중이에요');
    expect(followActionIsFilled(relationship), isFalse);
  });

  test('incoming accepted only renders follow-back action', () {
    const relationship = FollowRelationship(
      outgoing: FollowState.none,
      incoming: FollowState.accepted,
    );

    expect(followActionLabel(relationship), '맞팔하기');
    expect(followRelationshipHint(relationship), '회원님을 팔로우해요');
    expect(followActionIsFilled(relationship), isTrue);
  });

  test('outgoing pending keeps request state', () {
    const relationship = FollowRelationship(
      outgoing: FollowState.pending,
      incoming: FollowState.none,
    );

    expect(followActionLabel(relationship), '요청됨');
    expect(followRelationshipHint(relationship), '팔로우 요청을 보냈어요');
    expect(followActionIsFilled(relationship), isFalse);
  });
}
