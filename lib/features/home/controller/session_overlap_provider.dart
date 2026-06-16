import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/utils/sentence_normalizer.dart';

class OverlapThought {
  final String sentenceId;
  final String? userId;
  final String content;
  final String thought;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bookTitle;
  final DateTime createdAt;
  final int empathyCount;

  const OverlapThought({
    required this.sentenceId,
    required this.userId,
    required this.content,
    required this.thought,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bookTitle,
    required this.createdAt,
    required this.empathyCount,
  });

  String get displayNameOrUsername {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return username.trim().isEmpty ? '독자' : username;
  }

  factory OverlapThought.fromMap(Map<String, dynamic> row) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final book = row['books'] as Map<String, dynamic>?;
    final createdRaw = row['created_at'];
    final likes = row['sentence_likes'];

    return OverlapThought(
      sentenceId: row['id'] as String? ?? '',
      userId: row['user_id'] as String? ?? profile?['id'] as String?,
      content: row['content'] as String? ?? '',
      thought: row['thought'] as String? ?? '',
      username: profile?['username'] as String? ?? 'reader',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      bookTitle: book?['title'] as String?,
      createdAt: createdRaw is String
          ? DateTime.tryParse(createdRaw) ??
                DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      empathyCount: _parseLikeCount(likes),
    );
  }

  static int _parseLikeCount(Object? value) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map<String, dynamic>) {
        return first['count'] as int? ?? 0;
      }
    }
    if (value is Map<String, dynamic>) {
      return value['count'] as int? ?? 0;
    }
    return 0;
  }
}

class SessionOverlapInsight {
  final CollectedSentence sentence;
  final String normalizedText;
  final int readerCount;
  final List<OverlapThought> thoughts;

  const SessionOverlapInsight({
    required this.sentence,
    required this.normalizedText,
    required this.readerCount,
    required this.thoughts,
  });

  OverlapThought? get representativeThought =>
      thoughts.isEmpty ? null : thoughts.first;
}

class SessionOverlapInsightsNotifier
    extends
        FamilyAsyncNotifier<
          List<SessionOverlapInsight>,
          List<CollectedSentence>
        > {
  @override
  Future<List<SessionOverlapInsight>> build(
    List<CollectedSentence> sentences,
  ) async {
    if (kUseMock) return _mockOverlapInsights(sentences);

    try {
      final dbService = ref.read(dbServiceProvider);
      final neighborIds = await _fetchNeighborIds(dbService);
      final candidates = _dedupeByNormalizedText(sentences).take(5).toList();
      final insights = <SessionOverlapInsight>[];

      for (final entry in candidates) {
        final normalized = SentenceNormalizer.normalize(entry.content);
        final rows = await dbService.findOverlappingSentences(normalized);
        final thoughts = _representativeThoughts(rows, neighborIds);
        if (rows.isEmpty || thoughts.isEmpty) continue;

        insights.add(
          SessionOverlapInsight(
            sentence: entry,
            normalizedText: normalized,
            readerCount: _uniqueReaderCount(rows),
            thoughts: thoughts,
          ),
        );
      }

      insights.sort((a, b) {
        final thoughtCompare = b.thoughts.length.compareTo(a.thoughts.length);
        if (thoughtCompare != 0) return thoughtCompare;
        return b.readerCount.compareTo(a.readerCount);
      });
      return insights.take(2).toList();
    } catch (_) {
      return const [];
    }
  }

  List<SessionOverlapInsight> _mockOverlapInsights(
    List<CollectedSentence> sentences,
  ) {
    final candidates = _dedupeByNormalizedText(sentences).take(2).toList();
    if (candidates.isEmpty) return const [];

    final now = DateTime.now();
    return [
      for (var index = 0; index < candidates.length; index++)
        SessionOverlapInsight(
          sentence: candidates[index],
          normalizedText: SentenceNormalizer.normalize(
            candidates[index].content,
          ),
          readerCount: index == 0 ? 3 : 2,
          thoughts: [
            OverlapThought(
              sentenceId: 'mock_overlap_${index}_neighbor',
              userId: 'mock_following_yuna',
              content: candidates[index].content,
              thought: index == 0
                  ? '나도 이 문장에서 오래 멈췄어요. 설명되지 않던 마음을 누가 대신 적어준 느낌이었어요.'
                  : '같은 문장인데 저는 체념보다 다정함 쪽으로 읽혔어요.',
              username: 'yuna',
              displayName: '유나',
              avatarUrl: null,
              bookTitle: '채식주의자',
              createdAt: now.subtract(Duration(hours: 2 + index)),
              empathyCount: index == 0 ? 12 : 7,
            ),
            OverlapThought(
              sentenceId: 'mock_overlap_${index}_public',
              userId: 'mock_reader_ondo',
              content: candidates[index].content,
              thought: index == 0
                  ? '문장이 조용한데 마음을 정확히 건드려서, 다음 페이지로 바로 넘어가지 못했습니다.'
                  : '읽을 때는 지나쳤는데 기록하고 보니 계속 남는 문장이었어요.',
              username: 'ondo',
              displayName: '온도',
              avatarUrl: null,
              bookTitle: '채식주의자',
              createdAt: now.subtract(Duration(days: 1, hours: index)),
              empathyCount: index == 0 ? 8 : 5,
            ),
          ],
        ),
    ];
  }

  Future<Set<String>> _fetchNeighborIds(DbService dbService) async {
    try {
      final rows = await dbService.fetchFollowing();
      return rows
          .map((row) => row['following_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  List<CollectedSentence> _dedupeByNormalizedText(
    List<CollectedSentence> sentences,
  ) {
    final seen = <String>{};
    final result = <CollectedSentence>[];
    for (final sentence in sentences) {
      final normalized = SentenceNormalizer.normalize(sentence.content);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      result.add(sentence);
    }
    return result;
  }

  List<OverlapThought> _representativeThoughts(
    List<Map<String, dynamic>> rows,
    Set<String> neighborIds,
  ) {
    final seenReaders = <String>{};
    final thoughts = <OverlapThought>[];

    for (final row in rows) {
      final thought = (row['thought'] as String? ?? '').trim();
      if (thought.isEmpty) continue;

      final profile = row['profiles'] as Map<String, dynamic>?;
      final readerKey =
          row['user_id'] as String? ??
          profile?['id'] as String? ??
          profile?['username'] as String? ??
          row['id'] as String? ??
          '';
      if (readerKey.isNotEmpty && !seenReaders.add(readerKey)) continue;

      thoughts.add(OverlapThought.fromMap(row));
    }

    thoughts.sort((a, b) {
      final neighborCompare = _neighborRank(
        a,
        neighborIds,
      ).compareTo(_neighborRank(b, neighborIds));
      if (neighborCompare != 0) return neighborCompare;
      final empathyCompare = b.empathyCount.compareTo(a.empathyCount);
      if (empathyCompare != 0) return empathyCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    return thoughts;
  }

  int _neighborRank(OverlapThought thought, Set<String> neighborIds) {
    final userId = thought.userId;
    return userId != null && neighborIds.contains(userId) ? 0 : 1;
  }

  int _uniqueReaderCount(List<Map<String, dynamic>> rows) {
    final readers = <String>{};
    for (final row in rows) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final key =
          row['user_id'] as String? ??
          profile?['id'] as String? ??
          profile?['username'] as String? ??
          row['id'] as String? ??
          '';
      if (key.isNotEmpty) readers.add(key);
    }
    return readers.isEmpty ? rows.length : readers.length;
  }
}

final sessionOverlapInsightsProvider =
    AsyncNotifierProvider.family<
      SessionOverlapInsightsNotifier,
      List<SessionOverlapInsight>,
      List<CollectedSentence>
    >(SessionOverlapInsightsNotifier.new);
