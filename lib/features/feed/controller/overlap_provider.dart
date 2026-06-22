import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/db_service.dart';

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
    final book = m['books'] as Map<String, dynamic>?;
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

class OverlapNotifier
    extends FamilyAsyncNotifier<List<OverlapMatch>, String> {
  @override
  Future<List<OverlapMatch>> build(String normalizedText) async {
    if (normalizedText.isEmpty) return const [];
    final rows =
        await ref.read(dbServiceProvider).findOverlappingSentences(normalizedText);
    return rows.map(OverlapMatch.fromMap).toList();
  }
}

final overlappingSentencesProvider = AsyncNotifierProvider.family<
    OverlapNotifier, List<OverlapMatch>, String>(
  OverlapNotifier.new,
);
