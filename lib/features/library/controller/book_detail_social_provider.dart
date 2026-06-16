import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';

enum BookSocialThoughtSource { sentence, review, comment }

class BookSocialThought {
  final String sentenceId;
  final String? userId;
  final String displayName;
  final String? username;
  final String? avatarUrl;
  final String sentence;
  final String thought;
  final int? pageNumber;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final bool isFollowing;
  final BookSocialThoughtSource sourceType;

  const BookSocialThought({
    required this.sentenceId,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.sentence,
    required this.thought,
    required this.pageNumber,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.isFollowing,
    required this.sourceType,
  });

  BookSocialThought copyWith({bool? isFollowing}) {
    return BookSocialThought(
      sentenceId: sentenceId,
      userId: userId,
      displayName: displayName,
      username: username,
      avatarUrl: avatarUrl,
      sentence: sentence,
      thought: thought,
      pageNumber: pageNumber,
      likeCount: likeCount,
      commentCount: commentCount,
      createdAt: createdAt,
      isFollowing: isFollowing ?? this.isFollowing,
      sourceType: sourceType,
    );
  }
}

class BookDetailSocialMeta {
  final String? globalBookId;
  final int readerCount;
  final int sentenceCount;

  const BookDetailSocialMeta({
    required this.globalBookId,
    required this.readerCount,
    required this.sentenceCount,
  });
}

class BookReviewSummary {
  final String id;
  final String displayName;
  final int starRating;
  final String? memorableLine;
  final String? legacy;
  final DateTime createdAt;
  final bool isFollowing;

  const BookReviewSummary({
    required this.id,
    required this.displayName,
    required this.starRating,
    required this.memorableLine,
    required this.legacy,
    required this.createdAt,
    required this.isFollowing,
  });
}

class BookDetailSocialData {
  final BookDetailSocialMeta meta;
  final List<BookSocialThought> popularThoughts;
  final List<BookSocialThought> followingThoughts;
  final List<BookSocialThought> recentSentenceThoughts;
  final List<BookReviewSummary> reviews;

  const BookDetailSocialData({
    required this.meta,
    required this.popularThoughts,
    required this.followingThoughts,
    required this.recentSentenceThoughts,
    required this.reviews,
  });

  static const empty = BookDetailSocialData(
    meta: BookDetailSocialMeta(
      globalBookId: null,
      readerCount: 0,
      sentenceCount: 0,
    ),
    popularThoughts: [],
    followingThoughts: [],
    recentSentenceThoughts: [],
    reviews: [],
  );
}

typedef BookDetailSocialQuery = ({String title, String author, String? isbn});

class BookDetailSocialRepository {
  final SupabaseClient _client;

  BookDetailSocialRepository(this._client);

  String? get _me => _client.auth.currentUser?.id;

  Future<BookDetailSocialData> fetch(BookDetailSocialQuery query) async {
    final isbn = query.isbn?.trim();
    if (isbn == null || isbn.isEmpty) return BookDetailSocialData.empty;

    try {
      final followingIds = await _fetchFollowingIds();
      final globalBook = await _fetchGlobalBook(isbn);
      final sentenceRows = await _fetchSentenceRows(isbn);
      final commentCounts = await _fetchCommentCounts(
        sentenceRows
            .map((row) => row['sentence_id'] as String?)
            .whereType<String>()
            .toList(),
      );
      final thoughts = sentenceRows
          .map(
            (row) => _thoughtFromSentenceRow(
              row,
              followingIds: followingIds,
              commentCounts: commentCounts,
            ),
          )
          .whereType<BookSocialThought>()
          .toList();

      final popular = [...thoughts]
        ..sort((a, b) {
          final likeCompare = b.likeCount.compareTo(a.likeCount);
          if (likeCompare != 0) return likeCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
      final recent = [...thoughts]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final following =
          thoughts.where((thought) => thought.isFollowing).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final globalBookId = globalBook?['id'] as String?;
      return BookDetailSocialData(
        meta: BookDetailSocialMeta(
          globalBookId: globalBookId,
          readerCount: (globalBook?['reader_count'] as num?)?.toInt() ?? 0,
          sentenceCount:
              (globalBook?['sentence_count'] as num?)?.toInt() ??
              sentenceRows.length,
        ),
        popularThoughts: popular.take(5).toList(),
        followingThoughts: following.take(8).toList(),
        recentSentenceThoughts: recent.take(24).toList(),
        reviews: globalBookId == null
            ? const []
            : await _fetchReviews(globalBookId, followingIds),
      );
    } catch (_) {
      return BookDetailSocialData.empty;
    }
  }

  Future<Set<String>> _fetchFollowingIds() async {
    final me = _me;
    if (me == null) return const {};
    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', me)
        .eq('status', 'accepted');
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['following_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<Map<String, dynamic>?> _fetchGlobalBook(String isbn) async {
    return _client
        .from('global_books')
        .select('id, reader_count, sentence_count')
        .eq('isbn13', isbn)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> _fetchSentenceRows(String isbn) async {
    final rows = await _client
        .from('global_book_sentences')
        .select(
          'sentence_id, user_id, content, thought, page_number, created_at, '
          'username, display_name, avatar_url, like_count',
        )
        .eq('isbn13', isbn)
        .order('like_count', ascending: false)
        .limit(40);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, int>> _fetchCommentCounts(List<String> sentenceIds) async {
    if (sentenceIds.isEmpty) return const {};
    final rows = await _client
        .from('sentence_comments')
        .select('sentence_id')
        .inFilter('sentence_id', sentenceIds);
    final counts = <String, int>{};
    for (final row in rows as List) {
      final id = (row as Map<String, dynamic>)['sentence_id'] as String?;
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  BookSocialThought? _thoughtFromSentenceRow(
    Map<String, dynamic> row, {
    required Set<String> followingIds,
    required Map<String, int> commentCounts,
  }) {
    final thought = (row['thought'] as String? ?? '').trim();
    if (thought.isEmpty) return null;
    final sentenceId = row['sentence_id'] as String? ?? '';
    if (sentenceId.isEmpty) return null;
    final userId = row['user_id'] as String?;
    return BookSocialThought(
      sentenceId: sentenceId,
      userId: userId,
      displayName: _displayName(row),
      username: row['username'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      sentence: row['content'] as String? ?? '',
      thought: thought,
      pageNumber: (row['page_number'] as num?)?.toInt(),
      likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      commentCount: commentCounts[sentenceId] ?? 0,
      createdAt: _parseDate(row['created_at']),
      isFollowing: userId != null && followingIds.contains(userId),
      sourceType: BookSocialThoughtSource.sentence,
    );
  }

  Future<List<BookReviewSummary>> _fetchReviews(
    String globalBookId,
    Set<String> followingIds,
  ) async {
    final rows = await _client
        .from('book_reviews')
        .select(
          'id, user_id, star_rating, memorable_line, legacy, created_at, '
          'profiles!book_reviews_user_id_fkey(username, display_name)',
        )
        .eq('global_book_id', globalBookId)
        .order('created_at', ascending: false)
        .limit(12);
    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      final userId = row['user_id'] as String?;
      return BookReviewSummary(
        id: row['id'] as String? ?? '',
        displayName: _displayName(profile),
        starRating: (row['star_rating'] as num?)?.toInt() ?? 0,
        memorableLine: row['memorable_line'] as String?,
        legacy: row['legacy'] as String?,
        createdAt: _parseDate(row['created_at']),
        isFollowing: userId != null && followingIds.contains(userId),
      );
    }).toList();
  }

  static String _displayName(Map<String, dynamic>? row) {
    final displayName = (row?['display_name'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final username = (row?['username'] as String?)?.trim();
    return username != null && username.isNotEmpty ? username : '독자';
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

final bookDetailSocialRepositoryProvider = Provider<BookDetailSocialRepository>(
  (ref) => BookDetailSocialRepository(Supabase.instance.client),
);

final bookDetailSocialProvider =
    FutureProvider.family<BookDetailSocialData, BookDetailSocialQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return _mockBookDetailSocialData(query);
      return ref.read(bookDetailSocialRepositoryProvider).fetch(query);
    });

BookDetailSocialData _mockBookDetailSocialData(BookDetailSocialQuery query) {
  final now = DateTime.now();
  final base = [
    BookSocialThought(
      sentenceId: 'mock_popular_1',
      userId: 'mock_yuna',
      displayName: '유나',
      username: 'yuna',
      avatarUrl: null,
      sentence: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      thought: '특별하지 않다고 말하는 시선이 오히려 가장 잔인하게 느껴졌습니다.',
      pageNumber: 9,
      likeCount: 42,
      commentCount: 5,
      createdAt: now.subtract(const Duration(hours: 2)),
      isFollowing: true,
      sourceType: BookSocialThoughtSource.sentence,
    ),
    BookSocialThought(
      sentenceId: 'mock_popular_2',
      userId: 'mock_mago',
      displayName: '마고',
      username: 'mago',
      avatarUrl: null,
      sentence: '산다는 것은 이상한 일이라고, 그 웃음의 끝에 그녀는 생각한다.',
      thought: '이 문장은 체념처럼 시작해서 이상하게 삶 쪽으로 기울어요.',
      pageNumber: 202,
      likeCount: 37,
      commentCount: 4,
      createdAt: now.subtract(const Duration(hours: 5)),
      isFollowing: false,
      sourceType: BookSocialThoughtSource.sentence,
    ),
    BookSocialThought(
      sentenceId: 'mock_popular_3',
      userId: 'mock_ondo',
      displayName: '온도',
      username: 'ondo',
      avatarUrl: null,
      sentence: '크지도 작지도 않은 키, 길지도 짧지도 않은 단발머리, 각질이 일어난 노르스름한 피부.',
      thought: '무채색이라는 말이 옷차림보다 존재 방식처럼 읽혔어요.',
      pageNumber: 12,
      likeCount: 28,
      commentCount: 3,
      createdAt: now.subtract(const Duration(days: 1)),
      isFollowing: true,
      sourceType: BookSocialThoughtSource.sentence,
    ),
    BookSocialThought(
      sentenceId: 'mock_recent_1',
      userId: 'mock_river',
      displayName: '리버',
      username: 'river',
      avatarUrl: null,
      sentence: '빠르지도, 느리지도, 힘있지도, 가냘프지도 않은 걸음걸이로.',
      thought: '아무 특징 없는 묘사가 오히려 오래 남는다는 게 이상했습니다.',
      pageNumber: 52,
      likeCount: 15,
      commentCount: 2,
      createdAt: now.subtract(const Duration(days: 2)),
      isFollowing: false,
      sourceType: BookSocialThoughtSource.sentence,
    ),
  ];
  return BookDetailSocialData(
    meta: const BookDetailSocialMeta(
      globalBookId: 'mock_global_book',
      readerCount: 128,
      sentenceCount: 36,
    ),
    popularThoughts: [...base]
      ..sort((a, b) => b.likeCount.compareTo(a.likeCount)),
    followingThoughts: base.where((thought) => thought.isFollowing).toList(),
    recentSentenceThoughts: [...base]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    reviews: [
      BookReviewSummary(
        id: 'mock_review_1',
        displayName: '온도',
        starRating: 5,
        memorableLine: '산다는 것은 이상한 일이라고.',
        legacy: '완독보다 멈춤이 더 많았던 책.',
        createdAt: now.subtract(const Duration(days: 2)),
        isFollowing: true,
      ),
    ],
  );
}
