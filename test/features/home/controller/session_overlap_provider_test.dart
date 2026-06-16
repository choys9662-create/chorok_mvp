import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/db_service.dart';
import 'package:chorok_app/features/home/controller/session_overlap_provider.dart';
import 'package:chorok_app/shared/models/session_goal.dart';
import 'package:chorok_app/shared/utils/sentence_normalizer.dart';

class _FakeOverlapDbService extends DbService {
  final Map<String, List<Map<String, dynamic>>> overlaps;
  final Set<String> followingIds;
  final bool throwOnOverlap;

  _FakeOverlapDbService({
    this.overlaps = const {},
    this.followingIds = const {},
    this.throwOnOverlap = false,
  });

  @override
  Future<List<Map<String, dynamic>>> findOverlappingSentences(
    String normalizedText,
  ) async {
    if (throwOnOverlap) throw Exception('network');
    return overlaps[normalizedText] ?? const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchFollowing() async {
    return [
      for (final id in followingIds) {'following_id': id},
    ];
  }
}

ProviderContainer _container(_FakeOverlapDbService db) {
  return ProviderContainer(
    overrides: [dbServiceProvider.overrideWithValue(db)],
  );
}

Map<String, dynamic> _row({
  required String id,
  required String userId,
  required String thought,
  required int likes,
  required DateTime createdAt,
}) {
  return {
    'id': id,
    'user_id': userId,
    'content': '나도 너를 사랑해',
    'thought': thought,
    'created_at': createdAt.toIso8601String(),
    'profiles': {
      'id': userId,
      'username': 'reader_$userId',
      'display_name': '독자 $userId',
      'avatar_url': null,
    },
    'books': {'title': '책'},
    'sentence_likes': [
      {'count': likes},
    ],
  };
}

void main() {
  test('생각 없는 항목은 대표 생각 후보에서 제외한다', () async {
    const sentence = CollectedSentence(
      id: 'mine',
      content: '나도, 너를 사랑 해',
      thought: '내 생각',
    );
    final normalized = SentenceNormalizer.normalize(sentence.content);
    final container = _container(
      _FakeOverlapDbService(
        overlaps: {
          normalized: [
            _row(
              id: 'empty',
              userId: 'public-1',
              thought: '',
              likes: 10,
              createdAt: DateTime(2026, 1, 1),
            ),
            _row(
              id: 'thought',
              userId: 'public-2',
              thought: '다른 생각',
              likes: 1,
              createdAt: DateTime(2026, 1, 2),
            ),
          ],
        },
      ),
    );
    addTearDown(container.dispose);

    final insights = await container.read(
      sessionOverlapInsightsProvider(const [sentence]).future,
    );

    expect(insights, hasLength(1));
    expect(insights.first.readerCount, 2);
    expect(insights.first.thoughts, hasLength(1));
    expect(insights.first.representativeThought?.thought, '다른 생각');
  });

  test('이웃 생각이 공개 독자보다 먼저 정렬된다', () async {
    const sentence = CollectedSentence(
      id: 'mine',
      content: '나도 너를 사랑해',
      thought: '내 생각',
    );
    final normalized = SentenceNormalizer.normalize(sentence.content);
    final container = _container(
      _FakeOverlapDbService(
        followingIds: {'neighbor'},
        overlaps: {
          normalized: [
            _row(
              id: 'public',
              userId: 'public',
              thought: '공개 독자의 생각',
              likes: 99,
              createdAt: DateTime(2026, 1, 3),
            ),
            _row(
              id: 'neighbor',
              userId: 'neighbor',
              thought: '이웃의 생각',
              likes: 1,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        },
      ),
    );
    addTearDown(container.dispose);

    final insights = await container.read(
      sessionOverlapInsightsProvider(const [sentence]).future,
    );

    expect(insights.first.representativeThought?.userId, 'neighbor');
  });

  test('조회 오류는 빈 결과로 반환한다', () async {
    const sentence = CollectedSentence(
      id: 'mine',
      content: '나도 너를 사랑해',
      thought: '내 생각',
    );
    final container = _container(_FakeOverlapDbService(throwOnOverlap: true));
    addTearDown(container.dispose);

    final insights = await container.read(
      sessionOverlapInsightsProvider(const [sentence]).future,
    );

    expect(insights, isEmpty);
  });
}
