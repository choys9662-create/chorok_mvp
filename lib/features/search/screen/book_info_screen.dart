import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/book_memo.dart';
import '../../../shared/models/isar/isar_book_reflection.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/repositories/memo_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../feed/screen/sentence_detail_screen.dart';
import '../model/aladin_book.dart';
import '../util/add_book_flow.dart';
import '../widget/add_to_library_sheet.dart';

// ─── 커뮤니티 문장 모델 ──────────────────────────────────────────────────────

class _BookSentence {
  final String id;
  final String? userId;
  final String content;
  final String? thought;
  final String username;
  final String? handle;
  final String? avatarUrl;
  final DateTime savedAt;
  final int likeCount;
  final bool isFollowing;

  const _BookSentence({
    required this.id,
    this.userId,
    required this.content,
    this.thought,
    required this.username,
    this.handle,
    this.avatarUrl,
    required this.savedAt,
    this.likeCount = 0,
    this.isFollowing = false,
  });
}

class _BookComment {
  final String id;
  final String? userId;
  final String content;
  final String username;
  final String? handle;
  final String? avatarUrl;
  final DateTime createdAt;
  final String? sentenceContent;
  final int likeCount;
  final bool isFollowing;

  const _BookComment({
    required this.id,
    this.userId,
    required this.content,
    required this.username,
    this.handle,
    this.avatarUrl,
    required this.createdAt,
    this.sentenceContent,
    this.likeCount = 0,
    this.isFollowing = false,
  });
}

class _BookReview {
  final String id;
  final String? userId;
  final String username;
  final String? handle;
  final String? avatarUrl;
  final int starRating;
  final String? memorableLine;
  final String? legacy;
  final DateTime createdAt;
  final bool isFollowing;

  const _BookReview({
    required this.id,
    this.userId,
    required this.username,
    this.handle,
    this.avatarUrl,
    required this.starRating,
    this.memorableLine,
    this.legacy,
    required this.createdAt,
    this.isFollowing = false,
  });
}

enum _BookSocialThoughtType { sentence, review, comment }

class _BookSocialThought {
  final _BookSocialThoughtType type;
  final String id;
  final String? userId;
  final String username;
  final String? handle;
  final String? avatarUrl;
  final String content;
  final String? anchor;
  final DateTime createdAt;
  final int likeCount;
  final int? rating;

  const _BookSocialThought({
    required this.type,
    required this.id,
    required this.userId,
    required this.username,
    this.handle,
    this.avatarUrl,
    required this.content,
    this.anchor,
    required this.createdAt,
    this.likeCount = 0,
    this.rating,
  });
}

class _BookCommunityData {
  final String? globalBookId;
  final int readerCount;
  final int sentenceCount;
  final int followingReaderCount;
  final List<_BookSentence> sentences;
  final List<_BookComment> comments;
  final List<_BookReview> reviews;
  final List<_BookSocialThought> followingThoughts;

  const _BookCommunityData({
    required this.globalBookId,
    required this.readerCount,
    required this.sentenceCount,
    required this.followingReaderCount,
    required this.sentences,
    required this.comments,
    required this.reviews,
    required this.followingThoughts,
  });

  double? get averageRating {
    if (reviews.isEmpty) return null;
    final total = reviews.fold<int>(
      0,
      (sum, review) => sum + review.starRating,
    );
    return total / reviews.length;
  }
}

class _PersonalSentence {
  final String id;
  final String content;
  final String? thought;
  final int? pageNumber;
  final DateTime createdAt;

  const _PersonalSentence({
    required this.id,
    required this.content,
    this.thought,
    this.pageNumber,
    required this.createdAt,
  });
}

class _PersonalReview {
  final String id;
  final int starRating;
  final String? memorableLine;
  final String? legacy;
  final DateTime createdAt;

  const _PersonalReview({
    required this.id,
    required this.starRating,
    this.memorableLine,
    this.legacy,
    required this.createdAt,
  });
}

class _PersonalRecordData {
  final List<_PersonalSentence> sentences;
  final List<BookMemo> memos;
  final List<_PersonalReview> reviews;

  const _PersonalRecordData({
    required this.sentences,
    required this.memos,
    required this.reviews,
  });

  static const empty = _PersonalRecordData(
    sentences: [],
    memos: [],
    reviews: [],
  );

  bool get hasRecords =>
      sentences.isNotEmpty || memos.isNotEmpty || reviews.isNotEmpty;
}

typedef _PersonalRecordQuery = ({
  String? bookId,
  String title,
  String author,
  String? isbn,
  String? globalBookId,
});

// ─── Provider: isbn13 기준 커뮤니티 데이터 조회 ───────────────────────────────

final _bookInfoCommunityProvider =
    FutureProvider.family<_BookCommunityData, String>((ref, isbn13) async {
      if (kUseMock) return _mockBookCommunityData(isbn13);

      final client = Supabase.instance.client;

      Map<String, dynamic>? globalBook;
      try {
        final row = await client
            .from('global_books')
            .select('id, reader_count, sentence_count')
            .eq('isbn13', isbn13)
            .maybeSingle();
        globalBook = row;
      } catch (_) {
        globalBook = null;
      }

      final followingIds = await _fetchAcceptedFollowingIds(client);
      final sentenceRows = await _fetchGlobalBookSentences(client, isbn13);

      final withThought = <_BookSentence>[];
      final withoutThought = <_BookSentence>[];

      for (final row in sentenceRows) {
        final sentence = _BookSentence(
          id: row['sentence_id'] as String,
          userId: row['user_id'] as String?,
          content: row['content'] as String,
          thought: row['thought'] as String?,
          username: _displayName(row),
          handle: _handle(row),
          avatarUrl: row['avatar_url'] as String?,
          savedAt: _parseDate(row['created_at']),
          likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
          isFollowing: followingIds.contains(row['user_id'] as String?),
        );
        if (sentence.thought != null && sentence.thought!.isNotEmpty) {
          withThought.add(sentence);
        } else {
          withoutThought.add(sentence);
        }
      }

      final sentences = [...withThought, ...withoutThought];
      final comments = <_BookComment>[
        for (final sentence in sentences)
          if (sentence.thought != null && sentence.thought!.trim().isNotEmpty)
            _BookComment(
              id: 'thought_${sentence.id}',
              userId: sentence.userId,
              content: sentence.thought!.trim(),
              username: sentence.username,
              handle: sentence.handle,
              avatarUrl: sentence.avatarUrl,
              createdAt: sentence.savedAt,
              sentenceContent: sentence.content,
              likeCount: sentence.likeCount,
              isFollowing: sentence.isFollowing,
            ),
        ...await _fetchSentenceComments(
          client,
          sentences.map((sentence) => sentence.id).toList(),
          followingIds,
        ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final globalBookId = globalBook?['id'] as String?;
      final reviews = globalBookId == null
          ? const <_BookReview>[]
          : await _fetchBookReviews(client, globalBookId, followingIds);

      final followingThoughts = _buildFollowingThoughts(
        sentences: sentences,
        comments: comments,
        reviews: reviews,
      );

      return _BookCommunityData(
        globalBookId: globalBookId,
        readerCount: (globalBook?['reader_count'] as num?)?.toInt() ?? 0,
        sentenceCount:
            (globalBook?['sentence_count'] as num?)?.toInt() ??
            sentences.length,
        followingReaderCount: _followingReaderCount(
          followingIds,
          sentences: sentences,
          comments: comments,
          reviews: reviews,
        ),
        sentences: sentences,
        comments: comments,
        reviews: reviews,
        followingThoughts: followingThoughts,
      );
    });

_BookCommunityData _mockBookCommunityData(String isbn13) {
  final now = DateTime.now();
  final sentences = [
    _BookSentence(
      id: 'mock_sentence_${isbn13}_1',
      userId: 'mock_following_yuna',
      content: '사람은 어떤 문장 앞에서 오래 멈출 때, 자기 마음의 모양을 조금 더 알게 된다.',
      thought: '이 책을 읽는 동안 계속 밑줄을 긋게 된 문장. 조용한 위로보다 정확한 진단에 가까웠다.',
      username: '유나',
      handle: 'yuna',
      savedAt: now.subtract(const Duration(hours: 3)),
      likeCount: 18,
      isFollowing: true,
    ),
    _BookSentence(
      id: 'mock_sentence_${isbn13}_2',
      userId: 'mock_reader_mago',
      content: '좋은 책은 답을 주기보다 내가 오래 피하던 질문을 다시 내 앞에 놓는다.',
      thought: '읽고 나서 바로 덮기 어려웠다. 다음 장으로 넘어가기 전에 내 생활을 먼저 돌아보게 했다.',
      username: '마고',
      handle: 'mago',
      savedAt: now.subtract(const Duration(days: 1, hours: 2)),
      likeCount: 11,
    ),
    _BookSentence(
      id: 'mock_sentence_${isbn13}_3',
      userId: 'mock_following_ondo',
      content: '우리가 끝내 이해하지 못한 마음도, 어떤 문장 안에서는 잠시 같은 자리에 앉는다.',
      thought: '같은 장면을 보고도 서로 다른 곳에서 멈춘다는 게 좋았다.',
      username: '온도',
      handle: 'ondo',
      savedAt: now.subtract(const Duration(days: 2)),
      likeCount: 7,
      isFollowing: true,
    ),
    _BookSentence(
      id: 'mock_sentence_${isbn13}_4',
      userId: 'mock_reader_jin',
      content: '오래된 기억은 사라지는 게 아니라, 말할 수 있는 문장을 기다리고 있었다.',
      thought: null,
      username: '진',
      handle: 'jin',
      savedAt: now.subtract(const Duration(days: 3)),
      likeCount: 4,
    ),
  ];

  final comments = [
    for (final sentence in sentences)
      if (sentence.thought?.trim().isNotEmpty == true)
        _BookComment(
          id: 'thought_${sentence.id}',
          userId: sentence.userId,
          content: sentence.thought!.trim(),
          username: sentence.username,
          avatarUrl: sentence.avatarUrl,
          createdAt: sentence.savedAt,
          sentenceContent: sentence.content,
          likeCount: sentence.likeCount,
          isFollowing: sentence.isFollowing,
        ),
    _BookComment(
      id: 'mock_comment_${isbn13}_1',
      userId: 'mock_following_yuna',
      content: '후반부보다 초반의 문장들이 더 오래 남았어요. 천천히 읽을수록 밀도가 살아나는 책.',
      username: '유나',
      handle: 'yuna',
      createdAt: now.subtract(const Duration(hours: 8)),
      sentenceContent: sentences[1].content,
      likeCount: 6,
      isFollowing: true,
    ),
    _BookComment(
      id: 'mock_comment_${isbn13}_2',
      userId: 'mock_reader_river',
      content: '문장이 차분한데 감정은 꽤 깊게 들어와요. 읽는 속도를 일부러 늦추게 됐습니다.',
      username: '리버',
      handle: 'river',
      createdAt: now.subtract(const Duration(days: 1, hours: 5)),
      sentenceContent: sentences[0].content,
      likeCount: 3,
    ),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final reviews = [
    _BookReview(
      id: 'mock_review_${isbn13}_1',
      userId: 'mock_following_ondo',
      username: '온도',
      handle: 'ondo',
      starRating: 5,
      memorableLine: '말할 수 있는 문장을 기다리고 있었다.',
      legacy: '짧은 문장마다 생각이 남아서, 완독보다 멈춤이 더 많았던 책.',
      createdAt: now.subtract(const Duration(days: 2, hours: 3)),
      isFollowing: true,
    ),
    _BookReview(
      id: 'mock_review_${isbn13}_2',
      userId: 'mock_reader_mago',
      username: '마고',
      handle: 'mago',
      starRating: 4,
      memorableLine: '자기 마음의 모양을 조금 더 알게 된다.',
      legacy: '인상적인 문장이 많고, 읽은 뒤에 다른 사람의 밑줄이 궁금해지는 책.',
      createdAt: now.subtract(const Duration(days: 4)),
    ),
  ];

  final followingThoughts = _buildFollowingThoughts(
    sentences: sentences,
    comments: comments,
    reviews: reviews,
  );

  return _BookCommunityData(
    globalBookId: 'mock_global_$isbn13',
    readerCount: 128,
    sentenceCount: 36,
    followingReaderCount: 2,
    sentences: sentences,
    comments: comments,
    reviews: reviews,
    followingThoughts: followingThoughts,
  );
}

// ─── Provider: 내 개인 기록 조회 ────────────────────────────────────────────

final _bookPersonalRecordsProvider =
    FutureProvider.family<_PersonalRecordData, _PersonalRecordQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return _PersonalRecordData.empty;

      if (kUseRemoteDb) {
        final sentences = await _fetchMyWebSentences(ref, query);
        final memos = await _fetchMyWebMemos(ref, query);
        final review = await _fetchMyWebReview(
          Supabase.instance.client,
          query.globalBookId,
        );
        return _PersonalRecordData(
          sentences: sentences,
          memos: memos,
          reviews: review == null ? const [] : [review],
        );
      }

      final bookId = query.bookId;
      final repo = ref.read(bookRepositoryProvider);
      if (bookId == null || repo == null) return _PersonalRecordData.empty;

      final choseo = await repo.getChoseoByBook(bookId);
      final reflections = await repo.getReflectionsForBook(bookId);
      return _PersonalRecordData(
        sentences: choseo.map(_personalSentenceFromChoseo).toList(),
        memos: const [],
        reviews: reflections.map(_personalReviewFromReflection).toList(),
      );
    });

Future<List<_PersonalSentence>> _fetchMyWebSentences(
  Ref ref,
  _PersonalRecordQuery query,
) async {
  try {
    final rows = await ref
        .read(dbServiceProvider)
        .fetchMySentencesForBook(
          query.bookId ?? query.isbn ?? query.title,
          title: query.title,
          author: query.author,
          isbn: query.isbn,
        );
    return rows.map((row) {
      return _PersonalSentence(
        id: row['id'] as String,
        content: row['content'] as String,
        thought: row['thought'] as String?,
        pageNumber: (row['page_number'] as num?)?.toInt(),
        createdAt: _parseDate(row['created_at']),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

Future<List<BookMemo>> _fetchMyWebMemos(
  Ref ref,
  _PersonalRecordQuery query,
) async {
  if (query.globalBookId == null && query.bookId == null) return const [];
  try {
    return ref
        .read(memoRepositoryProvider)
        .fetchMemos(globalBookId: query.globalBookId, bookId: query.bookId);
  } catch (_) {
    return const [];
  }
}

Future<_PersonalReview?> _fetchMyWebReview(
  SupabaseClient client,
  String? globalBookId,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null || globalBookId == null) return null;
  try {
    final row = await client
        .from('book_reviews')
        .select('id, star_rating, memorable_line, legacy, created_at')
        .eq('user_id', userId)
        .eq('global_book_id', globalBookId)
        .maybeSingle();
    if (row == null) return null;
    return _PersonalReview(
      id: row['id'] as String,
      starRating: (row['star_rating'] as num?)?.toInt() ?? 0,
      memorableLine: row['memorable_line'] as String?,
      legacy: row['legacy'] as String?,
      createdAt: _parseDate(row['created_at']),
    );
  } catch (_) {
    return null;
  }
}

_PersonalSentence _personalSentenceFromChoseo(IsarChoseo choseo) {
  return _PersonalSentence(
    id: choseo.choseoId,
    content: choseo.content,
    thought: choseo.myThought,
    pageNumber: choseo.pageNumber,
    createdAt: choseo.createdAt,
  );
}

_PersonalReview _personalReviewFromReflection(IsarBookReflection reflection) {
  return _PersonalReview(
    id: reflection.reflectionId,
    starRating: reflection.starRating,
    memorableLine: reflection.memorableLine,
    legacy: reflection.legacy,
    createdAt: reflection.createdAt,
  );
}

Future<Set<String>> _fetchAcceptedFollowingIds(SupabaseClient client) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const {};
  try {
    final rows = await client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .eq('status', 'accepted');
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['following_id'] as String?)
        .whereType<String>()
        .toSet();
  } catch (_) {
    return const {};
  }
}

Future<List<Map<String, dynamic>>> _fetchGlobalBookSentences(
  SupabaseClient client,
  String isbn13,
) async {
  try {
    final rows = await client
        .from('global_book_sentences')
        .select(
          'sentence_id, user_id, content, thought, created_at, username, '
          'display_name, avatar_url, like_count',
        )
        .eq('isbn13', isbn13)
        .order('created_at', ascending: false)
        .limit(30);
    return (rows as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return const [];
  }
}

Future<List<_BookComment>> _fetchSentenceComments(
  SupabaseClient client,
  List<String> sentenceIds,
  Set<String> followingIds,
) async {
  if (sentenceIds.isEmpty) return const [];
  try {
    final rows = await client
        .from('sentence_comments')
        .select(
          'id, sentence_id, user_id, content, like_count, created_at, '
          'profiles!sentence_comments_user_id_fkey(id, username, display_name, avatar_url)',
        )
        .inFilter('sentence_id', sentenceIds)
        .order('created_at', ascending: false)
        .limit(80);

    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final userId = row['user_id'] as String? ?? profile?['id'] as String?;
      return _BookComment(
        id: row['id'] as String,
        userId: userId,
        content: row['content'] as String,
        username: _displayName(profile),
        handle: _handle(profile),
        avatarUrl: profile?['avatar_url'] as String?,
        createdAt: _parseDate(row['created_at']),
        likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
        isFollowing: userId != null && followingIds.contains(userId),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

Future<List<_BookReview>> _fetchBookReviews(
  SupabaseClient client,
  String globalBookId,
  Set<String> followingIds,
) async {
  try {
    final rows = await client
        .from('book_reviews')
        .select(
          'id, user_id, star_rating, memorable_line, legacy, created_at, '
          'profiles!book_reviews_user_id_fkey(id, username, display_name, avatar_url)',
        )
        .eq('global_book_id', globalBookId)
        .order('created_at', ascending: false)
        .limit(30);

    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final userId = row['user_id'] as String? ?? profile?['id'] as String?;
      return _BookReview(
        id: row['id'] as String,
        userId: userId,
        username: _displayName(profile),
        handle: _handle(profile),
        avatarUrl: profile?['avatar_url'] as String?,
        starRating: (row['star_rating'] as num?)?.toInt() ?? 0,
        memorableLine: row['memorable_line'] as String?,
        legacy: row['legacy'] as String?,
        createdAt: _parseDate(row['created_at']),
        isFollowing: userId != null && followingIds.contains(userId),
      );
    }).toList();
  } catch (_) {
    return const [];
  }
}

List<_BookSocialThought> _buildFollowingThoughts({
  required List<_BookSentence> sentences,
  required List<_BookComment> comments,
  required List<_BookReview> reviews,
}) {
  final items = <_BookSocialThought>[
    for (final sentence in sentences)
      if (sentence.isFollowing && sentence.thought?.trim().isNotEmpty == true)
        _BookSocialThought(
          type: _BookSocialThoughtType.sentence,
          id: sentence.id,
          userId: sentence.userId,
          username: sentence.username,
          handle: sentence.handle,
          avatarUrl: sentence.avatarUrl,
          content: sentence.thought!.trim(),
          anchor: sentence.content,
          createdAt: sentence.savedAt,
          likeCount: sentence.likeCount,
        ),
    for (final review in reviews)
      if (review.isFollowing &&
          ((review.legacy?.trim().isNotEmpty == true) ||
              (review.memorableLine?.trim().isNotEmpty == true)))
        _BookSocialThought(
          type: _BookSocialThoughtType.review,
          id: review.id,
          userId: review.userId,
          username: review.username,
          handle: review.handle,
          avatarUrl: review.avatarUrl,
          content: review.legacy?.trim().isNotEmpty == true
              ? review.legacy!.trim()
              : review.memorableLine!.trim(),
          anchor:
              review.legacy?.trim().isNotEmpty == true &&
                  review.memorableLine?.trim().isNotEmpty == true
              ? review.memorableLine!.trim()
              : null,
          createdAt: review.createdAt,
          rating: review.starRating,
        ),
    for (final comment in comments)
      if (comment.isFollowing &&
          !comment.id.startsWith('thought_') &&
          comment.content.trim().isNotEmpty)
        _BookSocialThought(
          type: _BookSocialThoughtType.comment,
          id: comment.id,
          userId: comment.userId,
          username: comment.username,
          handle: comment.handle,
          avatarUrl: comment.avatarUrl,
          content: comment.content.trim(),
          anchor: comment.sentenceContent,
          createdAt: comment.createdAt,
          likeCount: comment.likeCount,
        ),
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return items;
}

int _followingReaderCount(
  Set<String> followingIds, {
  required List<_BookSentence> sentences,
  required List<_BookComment> comments,
  required List<_BookReview> reviews,
}) {
  final ids = <String>{
    for (final sentence in sentences)
      if (sentence.userId != null && followingIds.contains(sentence.userId))
        sentence.userId!,
    for (final comment in comments)
      if (comment.userId != null && followingIds.contains(comment.userId))
        comment.userId!,
    for (final review in reviews)
      if (review.userId != null && followingIds.contains(review.userId))
        review.userId!,
  };
  return ids.length;
}

String _displayName(Map<String, dynamic>? row) {
  final displayName = (row?['display_name'] as String?)?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final username = (row?['username'] as String?)?.trim();
  return username != null && username.isNotEmpty ? username : '독자';
}

/// @아이디(핸들) — 동명이인 구분용. 없으면 null.
String? _handle(Map<String, dynamic>? row) {
  final username = (row?['username'] as String?)?.trim();
  return username != null && username.isNotEmpty ? username : null;
}

DateTime _parseDate(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

String _relativeDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}년 전';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}달 전';
  if (diff.inDays >= 1) return '${diff.inDays}일 전';
  if (diff.inHours >= 1) return '${diff.inHours}시간 전';
  return '방금';
}

void _openBookInfoProfile(
  BuildContext context, {
  required String? userId,
  required String username,
  required String? avatarUrl,
}) {
  if (userId == null || userId.isEmpty) return;
  HapticFeedback.selectionClick();
  context.push(
    AppConstants.routeUserProfile,
    extra: UserProfile(
      id: userId,
      username: username,
      displayName: username,
      avatarUrl: avatarUrl,
    ),
  );
}

class _FollowingBadge extends StatelessWidget {
  const _FollowingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: AppTheme.smoothBox(
        color: context.appPrimaryAccent.withValues(alpha: 0.12),
        radius: 8,
        side: BorderSide.none,
      ),
      child: Text(
        '팔로잉',
        style: TextStyle(
          fontSize: 10,
          color: context.appPrimaryAccent,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

// ─── 책 정보 화면 ─────────────────────────────────────────────────────────────

class BookInfoScreen extends ConsumerStatefulWidget {
  final AladinBook book;

  const BookInfoScreen({super.key, required this.book});

  @override
  ConsumerState<BookInfoScreen> createState() => _BookInfoScreenState();
}

class _BookInfoScreenState extends ConsumerState<BookInfoScreen> {
  bool _descExpanded = false;

  Future<void> _onAddTap() async {
    final lib = ref.read(libraryProvider);
    final book = widget.book;

    final existing = book.isbn13 != null && book.isbn13!.isNotEmpty
        ? lib.where((b) => b.isbn == book.isbn13).firstOrNull
        : lib
              .where((b) => b.title == book.title && b.author == book.author)
              .firstOrNull;

    if (existing != null) {
      HapticFeedback.mediumImpact();
      ref.read(libraryProvider.notifier).deleteBook(existing.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '"${book.title}"을(를) 서재에서 삭제했어요'));
      return;
    }

    HapticFeedback.selectionClick();
    final status = await showAddToLibrarySheet(context, book);
    if (status == null || !mounted) return;

    final added = addBookAndFetchPages(ref, book, status);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      chorokSnackBar(
        context,
        added
            ? '"${book.title}"을(를) ${readingStatusLabel(status)}에 추가했어요'
            : '"${book.title}"은(는) 이미 서재에 있어요',
        success: added,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final topPad = MediaQuery.of(context).padding.top;
    final isbn = book.isbn13 ?? '';

    final isInLibrary = ref.watch(
      libraryProvider.select((books) {
        if (isbn.isNotEmpty) return books.any((b) => b.isbn == isbn);
        return books.any(
          (b) => b.title == book.title && b.author == book.author,
        );
      }),
    );

    final libraryBook = ref.watch(
      libraryProvider.select((books) {
        if (isbn.isNotEmpty) {
          return books.where((b) => b.isbn == isbn).firstOrNull;
        }
        return books
            .where((b) => b.title == book.title && b.author == book.author)
            .firstOrNull;
      }),
    );

    final gradientIndex =
        book.title.hashCode.abs() % AppTheme.coverGradients.length;
    final coverColors = AppTheme.coverGradients[gradientIndex];
    final showBackButton = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: context.appBg,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              coverColors[0].withValues(alpha: 0.45),
              coverColors[0].withValues(alpha: 0.12),
              context.appBg,
              context.appBg,
            ],
            stops: const [0.0, 0.16, 0.34, 1.0],
          ),
        ),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            // ── 히어로 섹션 ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  // 표지 컬러 대기권 그라디언트
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topPad + 320,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            coverColors[0].withValues(alpha: 0.45),
                            coverColors[0].withValues(alpha: 0.12),
                            context.appBg.withValues(alpha: 0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 28),
                    child: Column(
                      children: [
                        if (showBackButton) ...[
                          Row(
                            children: [
                              Semantics(
                                button: true,
                                label: '뒤로가기',
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: context.appTextSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 책 표지
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: coverColors[1].withValues(alpha: 0.35),
                                blurRadius: 36,
                                offset: const Offset(0, 14),
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: BookCover(
                            coverUrl: book.coverUrl,
                            gradientIndex: gradientIndex,
                            width: 128,
                            height: 184,
                            radius: 10,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 제목
                        Text(
                          book.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: context.appTextPrimary,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // 저자
                        Text(
                          book.author,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.appTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),

                        // 출판사 · 장르
                        Text(
                          [
                            book.publisher,
                            if (book.genre != null) book.genre!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 이어 읽기 (서재에 있는 책만) ──────────────────────────────
            if (libraryBook != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _ContinueReadingButton(book: libraryBook),
                ),
              ),

            // ── 서재 추가 버튼 ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _AddToLibraryButton(
                  isInLibrary: isInLibrary,
                  onTap: _onAddTap,
                ),
              ),
            ),

            if (isbn.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: _CommunityOverview(isbn: isbn),
                ),
              ),

            if (isbn.isNotEmpty) _PopularBookThoughtsSection(book: book),

            // ── 책 소개 ───────────────────────────────────────────────────
            if (book.description != null && book.description!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '책 소개',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.appTextTertiary,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _descExpanded = !_descExpanded),
                        child: Text(
                          book.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                            height: 1.7,
                          ),
                          maxLines: _descExpanded ? null : 4,
                          overflow: _descExpanded
                              ? null
                              : TextOverflow.ellipsis,
                        ),
                      ),
                      if (!_descExpanded && book.description!.length > 120)
                        GestureDetector(
                          onTap: () => setState(() => _descExpanded = true),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '더 보기',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.appPrimaryAccent,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            _PersonalRecordsSection(
              book: book,
              libraryBook: libraryBook,
              globalBookId: isbn.isEmpty
                  ? null
                  : ref
                        .watch(_bookInfoCommunityProvider(isbn))
                        .maybeWhen(
                          data: (data) => data.globalBookId,
                          orElse: () => null,
                        ),
            ),

            if (isbn.isNotEmpty) _FollowingThoughtsSection(isbn: isbn),

            if (isbn.isNotEmpty) _ReviewsSection(isbn: isbn),

            if (isbn.isNotEmpty) _CommentsSection(isbn: isbn),

            // ── 독자들의 문장 콘텐츠 ─────────────────────────────────────
            if (isbn.isNotEmpty) _SentencesSection(isbn: isbn),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ─── 서재 추가 CTA 버튼 ────────────────────────────────────────────────────────

class _ContinueReadingButton extends StatelessWidget {
  final Book book;
  const _ContinueReadingButton({required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push(
          AppConstants.routeSession,
          extra: SessionExtra(
            bookId: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            coverUrl: book.coverUrl,
            startPage: book.currentPage,
            totalPages: book.totalPages,
          ),
        );
      },
      child: Container(
        height: 50,
        decoration: AppTheme.smoothBox(
          gradient: AppTheme.greenGradient,
          radius: AppTheme.radiusMD,
          side: BorderSide.none,
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 20, color: AppTheme.darkBg),
            SizedBox(width: 6),
            Text(
              '이어 읽기',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppTheme.darkBg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddToLibraryButton extends StatefulWidget {
  final bool isInLibrary;
  final VoidCallback onTap;

  const _AddToLibraryButton({required this.isInLibrary, required this.onTap});

  @override
  State<_AddToLibraryButton> createState() => _AddToLibraryButtonState();
}

class _AddToLibraryButtonState extends State<_AddToLibraryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isIn = widget.isInLibrary;

    return Semantics(
      button: true,
      label: isIn ? '서재에서 삭제' : '서재에 추가',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 50,
            decoration: AppTheme.smoothBox(
              gradient: isIn ? null : AppTheme.greenGradient,
              color: isIn ? context.appCardElevated : null,
              radius: AppTheme.radiusMD,
              side: BorderSide.none,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isIn ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                  color: isIn ? context.appPrimaryAccent : AppTheme.darkBg,
                ),
                const SizedBox(width: 6),
                Text(
                  isIn ? '서재에 있어요' : '서재에 추가',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isIn ? context.appPrimaryAccent : AppTheme.darkBg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 내 개인 기록 섹션 ───────────────────────────────────────────────────────

class _PersonalRecordsSection extends ConsumerWidget {
  final AladinBook book;
  final Book? libraryBook;
  final String? globalBookId;

  const _PersonalRecordsSection({
    required this.book,
    required this.libraryBook,
    required this.globalBookId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      bookId: libraryBook?.id,
      title: book.title,
      author: book.author,
      isbn: book.isbn13,
      globalBookId: globalBookId,
    );
    final state = ref.watch(_bookPersonalRecordsProvider(query));

    return state.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _SectionSkeleton(title: '내 기록'),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: _SectionError(title: '내 기록', message: '내 기록을 불러오지 못했어요'),
      ),
      data: (data) {
        if (libraryBook == null && !data.hasRecords) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _SectionTitle(title: '내 기록'),
                  SizedBox(height: 12),
                  _EmptyCommunityState(
                    icon: Icons.menu_book_outlined,
                    title: '아직 내 기록이 없어요',
                    body: '서재에 추가하고 읽으면 진행률과 문장이 여기에 보여요',
                  ),
                ],
              ),
            ),
          );
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  title: '내 기록',
                  trailing: libraryBook?.status.label,
                ),
                const SizedBox(height: 12),
                if (libraryBook != null)
                  _MyProgressCard(
                    book: libraryBook!,
                    sentenceCount: data.sentences.length,
                    memoCount: data.memos.length,
                    reviewCount: data.reviews.length,
                  ),
                if (libraryBook != null &&
                    (data.hasRecords || data.sentences.isEmpty)) ...[
                  const SizedBox(height: 10),
                ],
                if (data.reviews.isNotEmpty) ...[
                  _SubsectionLabel(label: '내 평가', count: data.reviews.length),
                  const SizedBox(height: 8),
                  ...data.reviews
                      .take(2)
                      .map(
                        (review) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MyReviewCard(review: review),
                        ),
                      ),
                ],
                if (data.sentences.isNotEmpty) ...[
                  _SubsectionLabel(label: '내 문장', count: data.sentences.length),
                  const SizedBox(height: 8),
                  ...data.sentences
                      .take(3)
                      .map(
                        (sentence) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MySentenceCard(sentence: sentence),
                        ),
                      ),
                ],
                if (data.memos.isNotEmpty) ...[
                  _SubsectionLabel(label: '개인 메모', count: data.memos.length),
                  const SizedBox(height: 8),
                  ...data.memos
                      .take(3)
                      .map(
                        (memo) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MyMemoCard(memo: memo),
                        ),
                      ),
                ],
                if (libraryBook != null && !data.hasRecords)
                  const _EmptyCommunityState(
                    icon: Icons.edit_note_rounded,
                    title: '아직 남긴 기록이 없어요',
                    body: '읽으면서 수집한 문장과 메모가 여기에 쌓여요',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MyProgressCard extends StatelessWidget {
  final Book book;
  final int sentenceCount;
  final int memoCount;
  final int reviewCount;

  const _MyProgressCard({
    required this.book,
    required this.sentenceCount,
    required this.memoCount,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = book.readingProgress.clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final pageLabel = book.totalPages > 0
        ? '${book.currentPage}/${book.totalPages}쪽'
        : book.currentPage > 0
        ? '${book.currentPage}쪽'
        : '페이지 기록 없음';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: AppTheme.smoothPill(
                  color: context.appPrimaryAccent.withValues(alpha: 0.12),
                ),
                child: Text(
                  book.status.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.appPrimaryAccent,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                pageLabel,
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: book.totalPages > 0 ? progress : 0,
              minHeight: 6,
              backgroundColor: context.appCardElevated,
              valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                book.totalPages > 0 ? '$percent%' : '진행률 없음',
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(),
              Text(
                '문장 $sentenceCount · 메모 $memoCount · 평가 $reviewCount',
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  final String label;
  final int count;

  const _SubsectionLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: context.appTextTertiary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: TextStyle(fontSize: 12, color: context.appPrimaryAccent),
        ),
      ],
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  final _PersonalReview review;

  const _MyReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _RatingStars(rating: review.starRating),
              const Spacer(),
              Text(
                _relativeDate(review.createdAt),
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
          if (review.memorableLine != null &&
              review.memorableLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '“${review.memorableLine!.trim()}”',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextPrimary,
                height: 1.65,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (review.legacy != null && review.legacy!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.legacy!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.65,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MySentenceCard extends StatelessWidget {
  final _PersonalSentence sentence;

  const _MySentenceCard({required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (sentence.pageNumber != null)
                Text(
                  'p.${sentence.pageNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appPrimaryAccent,
                  ),
                ),
              if (sentence.pageNumber != null) const SizedBox(width: 8),
              Text(
                _relativeDate(sentence.createdAt),
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sentence.content,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextPrimary,
              fontStyle: FontStyle.italic,
              height: 1.65,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          if (sentence.thought != null &&
              sentence.thought!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              sentence.thought!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.65,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MyMemoCard extends StatelessWidget {
  final BookMemo memo;

  const _MyMemoCard({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _relativeDate(memo.createdAt),
            style: TextStyle(fontSize: 12, color: context.appTextTertiary),
          ),
          const SizedBox(height: 8),
          Text(
            memo.content,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextPrimary,
              height: 1.65,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── 커뮤니티 요약 ───────────────────────────────────────────────────────────

class _CommunityOverview extends ConsumerWidget {
  final String isbn;

  const _CommunityOverview({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => const _CommunityOverviewSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        final average = data.averageRating;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            side: BorderSide.none,
          ),
          child: Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.people_alt_rounded,
                  value: data.readerCount > 0 ? '${data.readerCount}' : '-',
                  label: '읽는 독자',
                ),
              ),
              _OverviewDivider(),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.chat_bubble_outline_rounded,
                  value: data.comments.isNotEmpty
                      ? '${data.comments.length}'
                      : '-',
                  label: '코멘트',
                ),
              ),
              _OverviewDivider(),
              Expanded(
                child: _OverviewMetric(
                  icon: Icons.star_rounded,
                  value: average == null ? '-' : average.toStringAsFixed(1),
                  label: '평균 별점',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityOverviewSkeleton extends StatelessWidget {
  const _CommunityOverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: const Row(
        children: [
          Expanded(child: ChorokShimmer(width: 56, height: 34)),
          Expanded(child: ChorokShimmer(width: 56, height: 34)),
          Expanded(child: ChorokShimmer(width: 56, height: 34)),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _OverviewMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: context.appPrimaryAccent),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: context.appTextPrimary,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: context.appTextTertiary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: context.appCardElevated);
  }
}

// ─── 인기 생각 섹션 ───────────────────────────────────────────────────────

class _PopularBookThoughtsSection extends ConsumerWidget {
  final AladinBook book;

  const _PopularBookThoughtsSection({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isbn = book.isbn13 ?? '';
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _SectionSkeleton(title: '지금 많이 멈춘 생각'),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (data) {
        final thoughts =
            data.sentences
                .where(
                  (sentence) => sentence.thought?.trim().isNotEmpty == true,
                )
                .toList()
              ..sort((a, b) {
                final likeCompare = b.likeCount.compareTo(a.likeCount);
                if (likeCompare != 0) return likeCompare;
                return b.savedAt.compareTo(a.savedAt);
              });
        if (thoughts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 0, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: _SectionTitle(
                    title: '지금 많이 멈춘 생각',
                    trailing: data.readerCount > 0
                        ? '${data.readerCount}명'
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 214,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: thoughts.take(5).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _PopularBookThoughtCard(
                        book: book,
                        sentence: thoughts[index],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PopularBookThoughtCard extends StatelessWidget {
  final AladinBook book;
  final _BookSentence sentence;

  const _PopularBookThoughtCard({required this.book, required this.sentence});

  void _openSentence(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: sentence.content,
        bookTitle: book.title,
        bookAuthor: book.author,
        collectorUsername: sentence.username,
        collectorUserHandle: sentence.handle,
        collectorThought: sentence.thought,
        sentenceId: sentence.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSentence(context),
      child: Container(
        width: 268,
        padding: const EdgeInsets.all(15),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusMD,
          side: BorderSide(color: context.appPillBorderActive),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(
                  username: sentence.username,
                  avatarUrl: sentence.avatarUrl,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openBookInfoProfile(
                      context,
                      userId: sentence.userId,
                      username: sentence.username,
                      avatarUrl: sentence.avatarUrl,
                    ),
                    child: _AuthorLabel(
                      displayName: sentence.username,
                      handle: sentence.handle,
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
                if (sentence.isFollowing) const _FollowingBadge(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sentence.thought!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.appTextPrimary,
                height: 1.58,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: AppTheme.smoothBox(
                color: context.appCardElevated.withValues(alpha: 0.72),
                radius: AppTheme.radiusSM,
                side: BorderSide.none,
              ),
              child: Text(
                '“${sentence.content}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: context.appTextTertiary,
                  height: 1.45,
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: context.appPrimaryAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${sentence.likeCount}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextTertiary,
                  ),
                ),
                const Spacer(),
                Text(
                  _relativeDate(sentence.savedAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 팔로잉 생각 섹션 ───────────────────────────────────────────────────────

class _FollowingThoughtsSection extends ConsumerWidget {
  final String isbn;

  const _FollowingThoughtsSection({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _SectionSkeleton(title: '팔로잉 생각'),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (data) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '팔로잉 생각',
                trailing: data.followingReaderCount > 0
                    ? '${data.followingReaderCount}명'
                    : null,
              ),
              const SizedBox(height: 12),
              if (data.followingThoughts.isEmpty)
                const _EmptyCommunityState(
                  icon: Icons.people_outline_rounded,
                  title: '팔로잉한 독자의 생각이 아직 없어요',
                  body: '이 책을 읽은 독자를 팔로우하면 생각이 먼저 보여요',
                )
              else
                SizedBox(
                  height: 188,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.followingThoughts.take(8).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final thought = data.followingThoughts[index];
                      return _FollowingThoughtCard(thought: thought);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowingThoughtCard extends StatelessWidget {
  final _BookSocialThought thought;

  const _FollowingThoughtCard({required this.thought});

  String get _typeLabel {
    return switch (thought.type) {
      _BookSocialThoughtType.sentence => '문장 생각',
      _BookSocialThoughtType.review => '완독 의견',
      _BookSocialThoughtType.comment => '코멘트',
    };
  }

  void _openProfile(BuildContext context) {
    final userId = thought.userId;
    if (userId == null || userId.isEmpty) return;
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeUserProfile,
      extra: UserProfile(
        id: userId,
        username: thought.username,
        displayName: thought.username,
        avatarUrl: thought.avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: thought.userId != null,
      label: '${thought.username} 프로필 보기',
      child: GestureDetector(
        onTap: () => _openProfile(context),
        child: Container(
          width: 258,
          padding: const EdgeInsets.all(15),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusMD,
            side: BorderSide(color: context.appPillBorderActive),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(
                    username: thought.username,
                    avatarUrl: thought.avatarUrl,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AuthorLabel(
                      displayName: thought.username,
                      handle: thought.handle,
                      color: context.appTextSecondary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: AppTheme.smoothBox(
                      color: context.appPrimaryAccent.withValues(alpha: 0.12),
                      radius: 8,
                      side: BorderSide.none,
                    ),
                    child: Text(
                      _typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                thought.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextPrimary,
                  height: 1.6,
                ),
              ),
              if (thought.anchor != null && thought.anchor!.isNotEmpty) ...[
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(9),
                  decoration: AppTheme.smoothBox(
                    color: context.appCardElevated.withValues(alpha: 0.72),
                    radius: AppTheme.radiusSM,
                    side: BorderSide.none,
                  ),
                  child: Text(
                    '“${thought.anchor!}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appTextTertiary,
                      height: 1.45,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              Row(
                children: [
                  if (thought.rating != null) ...[
                    _RatingStars(rating: thought.rating!),
                    const SizedBox(width: 8),
                  ],
                  if (thought.likeCount > 0)
                    Text(
                      '공감 ${thought.likeCount}',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextTertiary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _relativeDate(thought.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 사용자 평가 섹션 ───────────────────────────────────────────────────────

class _ReviewsSection extends ConsumerWidget {
  final String isbn;

  const _ReviewsSection({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _SectionSkeleton(title: '다른 독자 의견'),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: _SectionError(title: '다른 독자 의견', message: '평가를 불러오지 못했어요'),
      ),
      data: (data) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '다른 독자 의견',
                trailing: data.averageRating == null
                    ? null
                    : '${data.averageRating!.toStringAsFixed(1)} · ${data.reviews.length}명',
              ),
              const SizedBox(height: 12),
              if (data.reviews.isEmpty)
                const _EmptyCommunityState(
                  icon: Icons.star_outline_rounded,
                  title: '아직 공개 평가가 없어요',
                  body: '완독 후 남긴 별점과 의견이 여기에 모여요',
                )
              else
                ...data.reviews.map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewCard(review: review),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _BookReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(username: review.username, avatarUrl: review.avatarUrl),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openBookInfoProfile(
                    context,
                    userId: review.userId,
                    username: review.username,
                    avatarUrl: review.avatarUrl,
                  ),
                  child: _AuthorLabel(
                    displayName: review.username,
                    handle: review.handle,
                    color: review.userId == null
                        ? context.appTextTertiary
                        : context.appTextSecondary,
                  ),
                ),
              ),
              if (review.isFollowing) ...[
                const SizedBox(width: 8),
                const _FollowingBadge(),
              ],
              const SizedBox(width: 8),
              _RatingStars(rating: review.starRating),
            ],
          ),
          if (review.memorableLine != null &&
              review.memorableLine!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '“${review.memorableLine!.trim()}”',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextPrimary,
                height: 1.65,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (review.legacy != null && review.legacy!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.legacy!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.65,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Text(
            _relativeDate(review.createdAt),
            style: TextStyle(fontSize: 12, color: context.appTextTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── 독자 코멘트 섹션 ───────────────────────────────────────────────────────

class _CommentsSection extends ConsumerWidget {
  final String isbn;

  const _CommentsSection({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _SectionSkeleton(title: '독자 코멘트'),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: _SectionError(title: '독자 코멘트', message: '코멘트를 불러오지 못했어요'),
      ),
      data: (data) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '독자 코멘트',
                trailing: data.comments.isEmpty
                    ? null
                    : '${data.comments.length}개',
              ),
              const SizedBox(height: 12),
              if (data.comments.isEmpty)
                const _EmptyCommunityState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '아직 코멘트가 없어요',
                  body: '다른 독자들의 생각과 댓글이 여기에 모여요',
                )
              else
                ...data.comments
                    .take(12)
                    .map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CommentCard(comment: comment),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final _BookComment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(username: comment.username, avatarUrl: comment.avatarUrl),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openBookInfoProfile(
                    context,
                    userId: comment.userId,
                    username: comment.username,
                    avatarUrl: comment.avatarUrl,
                  ),
                  child: _AuthorLabel(
                    displayName: comment.username,
                    handle: comment.handle,
                    color: comment.userId == null
                        ? context.appTextTertiary
                        : context.appTextSecondary,
                  ),
                ),
              ),
              if (comment.isFollowing) ...[
                const SizedBox(width: 8),
                const _FollowingBadge(),
              ],
              const SizedBox(width: 8),
              Text(
                _relativeDate(comment.createdAt),
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.content,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextPrimary,
              height: 1.65,
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
          if (comment.sentenceContent != null &&
              comment.sentenceContent!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: AppTheme.smoothBox(
                color: context.appCardElevated,
                radius: AppTheme.radiusSM,
                side: BorderSide.none,
              ),
              child: Text(
                comment.sentenceContent!.trim(),
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextTertiary,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 공통 커뮤니티 UI ───────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: context.appTextPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.appTextTertiary,
            ),
          ),
      ],
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  final String title;

  const _SectionSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            side: BorderSide.none,
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChorokShimmer(width: double.infinity, height: 13),
              SizedBox(height: 8),
              ChorokShimmer(width: 220, height: 13),
              SizedBox(height: 14),
              ChorokShimmer(width: 92, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  final String title;
  final String message;

  const _SectionError({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 12, color: context.appTextTertiary),
          ),
        ],
      ),
    );
  }
}

class _EmptyCommunityState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyCommunityState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: context.appTextTertiary.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: context.appTextSecondary,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(fontSize: 12, color: context.appTextTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    final safeRating = rating.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < safeRating;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 14,
          color: filled ? context.appPrimaryAccent : context.appTextTertiary,
        );
      }),
    );
  }
}

// ─── 커뮤니티 문장 섹션 ────────────────────────────────────────────────────────

class _SentencesSection extends ConsumerWidget {
  final String isbn;

  const _SentencesSection({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, index) => index == 0
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SectionTitle(title: '독자들의 문장'),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _SentenceShimmer(),
                ),
          childCount: 4,
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Center(
            child: Text(
              '문장을 불러오지 못했어요',
              style: TextStyle(fontSize: 12, color: context.appTextTertiary),
            ),
          ),
        ),
      ),
      data: (data) {
        final sentences = data.sentences;
        if (sentences.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                children: [
                  _SectionTitle(title: '독자들의 문장'),
                  const SizedBox(height: 12),
                  Icon(
                    Icons.format_quote_rounded,
                    size: 40,
                    color: context.appTextTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아직 기록된 문장이 없어요',
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '첫 번째로 문장을 남겨보세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _SectionTitle(
                  title: '독자들의 문장',
                  trailing: data.sentenceCount > 0
                      ? '${data.sentenceCount}개'
                      : null,
                ),
              );
            }
            final sentence = sentences[i - 1];
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SentenceCard(sentence: sentence),
            );
          }, childCount: sentences.length + 1),
        );
      },
    );
  }
}

// ─── 문장 카드 ────────────────────────────────────────────────────────────────

class _SentenceCard extends StatelessWidget {
  final _BookSentence sentence;

  const _SentenceCard({required this.sentence});

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365}년 전';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}달 전';
    if (diff.inDays >= 1) return '${diff.inDays}일 전';
    if (diff.inHours >= 1) return '${diff.inHours}시간 전';
    return '방금';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 문장 본문
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 16,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  color: context.appPrimaryAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: Text(
                  sentence.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextPrimary,
                    fontStyle: FontStyle.italic,
                    height: 1.7,
                  ),
                ),
              ),
            ],
          ),

          // 생각 (있을 때만)
          if (sentence.thought != null && sentence.thought!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Divider(
                color: context.appCardElevated,
                thickness: 1,
                height: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                sentence.thought!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                  height: 1.65,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // 메타 정보
          const SizedBox(height: 12),
          Row(
            children: [
              _Avatar(
                username: sentence.username,
                avatarUrl: sentence.avatarUrl,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: GestureDetector(
                  onTap: () => _openBookInfoProfile(
                    context,
                    userId: sentence.userId,
                    username: sentence.username,
                    avatarUrl: sentence.avatarUrl,
                  ),
                  child: _AuthorLabel(
                    displayName: sentence.username,
                    handle: sentence.handle,
                    color: sentence.userId == null
                        ? context.appTextTertiary
                        : context.appTextSecondary,
                  ),
                ),
              ),
              if (sentence.isFollowing) ...[
                const SizedBox(width: 8),
                const _FollowingBadge(),
              ],
              const SizedBox(width: 6),
              Text(
                '·',
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
              const SizedBox(width: 6),
              Text(
                _relativeDate(sentence.savedAt),
                style: TextStyle(fontSize: 12, color: context.appTextTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 유저 아바타 ──────────────────────────────────────────────────────────────

/// 표시명 + @아이디(핸들)를 함께 보여주는 작성자 라벨. 동명이인 구분용.
class _AuthorLabel extends StatelessWidget {
  final String displayName;
  final String? handle;
  final Color color;

  const _AuthorLabel({
    required this.displayName,
    required this.color,
    this.handle,
  });

  @override
  Widget build(BuildContext context) {
    final showHandle =
        handle != null && handle!.isNotEmpty && handle != displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (showHandle)
          Text(
            '@$handle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: context.appTextTertiary),
          ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final String username;
  final String? avatarUrl;

  const _Avatar({required this.username, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 10,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: context.appCardElevated,
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: context.appCardElevated,
      child: Text(
        username.isNotEmpty ? username[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
          color: context.appPrimaryAccent,
        ),
      ),
    );
  }
}

// ─── 문장 카드 shimmer ─────────────────────────────────────────────────────────

class _SentenceShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChorokShimmer(width: double.infinity, height: 13),
          const SizedBox(height: 6),
          ChorokShimmer(width: double.infinity, height: 13),
          const SizedBox(height: 6),
          ChorokShimmer(width: 160, height: 13),
          const SizedBox(height: 16),
          Row(
            children: [
              ChorokShimmer(width: 20, height: 20, radius: 10),
              const SizedBox(width: 8),
              ChorokShimmer(width: 60, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}
