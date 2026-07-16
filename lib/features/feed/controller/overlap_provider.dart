import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/db_service.dart';
import '../../../shared/utils/overlap_detector.dart';

// ─── OverlapMatch 모델 ─────────────────────────────────────────────────────

class OverlapMatch {
  final String sentenceId;
  final String? userId;
  final String content;
  final String? thought;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bookTitle;
  final DateTime createdAt;

  const OverlapMatch({
    required this.sentenceId,
    this.userId,
    required this.content,
    this.thought,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bookTitle,
    required this.createdAt,
  });

  factory OverlapMatch.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'] as Map<String, dynamic>?;
    final book =
        (m['global_books'] as Map<String, dynamic>?) ??
        (m['books'] as Map<String, dynamic>?);
    return OverlapMatch(
      sentenceId: m['id'] as String,
      userId: m['user_id'] as String? ?? profile?['id'] as String?,
      content: m['content'] as String,
      thought: m['thought'] as String?,
      username: profile?['username'] as String? ?? '알 수 없음',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      bookTitle: book?['title'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────

/// family 키는 문장 **원문**이다. 정규화·문장 단위 분리는
/// [DbService.findOverlappingSentences] 안에서 한 번만 한다.
class OverlapNotifier extends FamilyAsyncNotifier<List<OverlapMatch>, String> {
  @override
  Future<List<OverlapMatch>> build(String content) async {
    if (content.isEmpty) return const [];
    final rows = await ref
        .read(dbServiceProvider)
        .findOverlappingSentences(content);
    return rows.map(OverlapMatch.fromMap).toList();
  }
}

final overlappingSentencesProvider =
    AsyncNotifierProvider.family<OverlapNotifier, List<OverlapMatch>, String>(
      OverlapNotifier.new,
    );

class OverlapGroupQuery {
  final String commonPhrase;
  final String? globalBookId;
  final String? bookId;

  const OverlapGroupQuery({
    required this.commonPhrase,
    this.globalBookId,
    this.bookId,
  });

  @override
  bool operator ==(Object other) =>
      other is OverlapGroupQuery &&
      other.commonPhrase == commonPhrase &&
      other.globalBookId == globalBookId &&
      other.bookId == bookId;

  @override
  int get hashCode => Object.hash(commonPhrase, globalBookId, bookId);
}

class OverlapGroupNotifier
    extends FamilyAsyncNotifier<List<OverlapMatch>, OverlapGroupQuery> {
  @override
  Future<List<OverlapMatch>> build(OverlapGroupQuery query) async {
    if (query.commonPhrase.trim().isEmpty) return const [];
    final rows = await ref
        .read(dbServiceProvider)
        .fetchBookSentenceCandidates(
          globalBookId: query.globalBookId,
          bookId: query.bookId,
        );

    return rows
        .where((row) {
          final content = (row['content'] as String? ?? '').trim();
          return content.isNotEmpty &&
              OverlapDetector.compare(
                query.commonPhrase,
                content,
              ).isOverlapping;
        })
        .map(OverlapMatch.fromMap)
        .toList();
  }
}

final overlapGroupProvider =
    AsyncNotifierProvider.family<
      OverlapGroupNotifier,
      List<OverlapMatch>,
      OverlapGroupQuery
    >(OverlapGroupNotifier.new);
