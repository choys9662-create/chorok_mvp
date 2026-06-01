import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reading_session.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/profile_repository.dart';
import '../util/sentence_row_parser.dart';

/// 유저 프로필 화면 데이터: 그 유저의 초서 목록 + 내 팔로우 상태.
typedef UserProfileData = ({
  List<FeedSentence> sentences,
  FollowState followState,
});

/// userId별 프로필 데이터를 로드한다.
final userProfileProvider = FutureProvider.family<UserProfileData, String>((
  ref,
  userId,
) async {
  final profileRepo = ref.read(profileRepositoryProvider);
  final followRepo = ref.read(followRepositoryProvider);

  final followState = await followRepo.followStatus(userId);
  final rows = await profileRepo.getUserSentences(userId);
  final sentences = rows
      .map((r) => parseSentenceRow(r, fallbackUsername: '독자'))
      .toList();

  return (sentences: sentences, followState: followState);
});
