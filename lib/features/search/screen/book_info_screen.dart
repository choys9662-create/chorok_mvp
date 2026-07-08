import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/repositories/memo_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../feed/screen/sentence_detail_screen.dart';
import '../model/aladin_book.dart';
import '../util/add_book_flow.dart';
import '../widget/add_to_library_sheet.dart';

// ─── 모델 ────────────────────────────────────────────────────────────────────

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
  final String sentenceId;
  final String? userId;
  final String content;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final int likeCount;

  const _BookComment({
    required this.id,
    required this.sentenceId,
    this.userId,
    required this.content,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    this.likeCount = 0,
  });
}

class _BookCommunityData {
  final String? globalBookId;
  final List<_BookSentence> sentences;
  final List<_BookComment> comments;

  const _BookCommunityData({
    required this.globalBookId,
    required this.sentences,
    required this.comments,
  });

  List<_BookComment> repliesFor(String sentenceId) {
    return comments.where((c) => c.sentenceId == sentenceId).toList()
      ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
  }

  /// 인기순 — 좋아요 많은 문장부터.
  List<_BookSentence> get popular {
    return [...sentences]..sort((a, b) {
      final likeCompare = b.likeCount.compareTo(a.likeCount);
      if (likeCompare != 0) return likeCompare;
      return b.savedAt.compareTo(a.savedAt);
    });
  }

  /// 팔로우한 친구의 문장 — 최신순.
  List<_BookSentence> get friends {
    return sentences.where((s) => s.isFollowing).toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }
}

typedef _BookStats = ({
  int totalCompleted,
  int friendCompleted,
  int? avgCompletionPct,
  int? avgSessions,
});

typedef _MyRecordCounts = ({int sentences, int thoughts});

typedef _PersonalRecordQuery = ({
  String? bookId,
  String title,
  String author,
  String? isbn,
  String? globalBookId,
});

// ─── Provider: 커뮤니티 문장·댓글 ────────────────────────────────────────────

final _bookInfoCommunityProvider =
    FutureProvider.family<_BookCommunityData, String>((ref, isbn13) async {
      if (kUseMock) return _mockBookCommunityData(isbn13);

      final client = Supabase.instance.client;

      String? globalBookId;
      try {
        final row = await client
            .from('global_books')
            .select('id')
            .eq('isbn13', isbn13)
            .maybeSingle();
        globalBookId = row?['id'] as String?;
      } catch (_) {}

      final followingIds = await _fetchAcceptedFollowingIds(client);
      final sentenceRows = await _fetchGlobalBookSentences(client, isbn13);

      final sentences = sentenceRows.map((row) {
        return _BookSentence(
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
      }).toList();

      final comments = await _fetchSentenceComments(
        client,
        sentences.map((s) => s.id).toList(),
      );

      return _BookCommunityData(
        globalBookId: globalBookId,
        sentences: sentences,
        comments: comments,
      );
    });

_BookCommunityData _mockBookCommunityData(String isbn13) {
  final now = DateTime.now();
  const firstLine = '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.';

  final sentences = [
    _BookSentence(
      id: 'mock_sentence_${isbn13}_1',
      userId: 'mock_reader_skull',
      content: firstLine,
      thought:
          '"특별한 사람이라고 생각한 적이 없었다"는 무심한 단언이지만, 문장 첫머리의 "아내가 채식을 '
          '시작하기 전까지"가 모든 걸 뒤집는다. 평범함에 대한 진술이 아니라, 그 평범함이 끝났다는 '
          '예고이기 때문이다. 화자는 아내를 무난함으로만 규정해왔고, 그래서 그녀의 변화를 끝내 '
          '이해하지 못할 인물임을 첫 문장이 미리 드러낸다. 안온한 일상이 곧 깨질 것이라는 불길함이 '
          '담담한 어조 아래 깔려 있다.',
      username: '해골맨',
      handle: 'skullman',
      savedAt: now.subtract(const Duration(hours: 3)),
      likeCount: 356,
    ),
    _BookSentence(
      id: 'mock_sentence_${isbn13}_2',
      userId: 'mock_following_yeomchang',
      content: firstLine,
      thought: '그러니까 유난떨지 마라 영혜야. 탕수육이 우습냐?',
      username: '염창맨',
      handle: 'yeomchang',
      savedAt: now.subtract(const Duration(days: 1)),
      likeCount: 4,
      isFollowing: true,
    ),
  ];

  final comments = [
    _BookComment(
      id: 'mock_comment_${isbn13}_1',
      sentenceId: sentences[0].id,
      userId: 'mock_reader_hyejin',
      content: '정말 대단한 통찰입니다. 덕분에 제 독서가 한층 업그레이드 됐어요! 젠장 해골맨 당신 뭐라고',
      username: '혜진짱짱',
      createdAt: now.subtract(const Duration(hours: 1)),
      likeCount: 15,
    ),
    _BookComment(
      id: 'mock_comment_${isbn13}_2',
      sentenceId: sentences[1].id,
      userId: 'mock_reader_dungchon',
      content: '넌 한강에 빠져서 죽어라',
      username: '둥촌맨',
      createdAt: now.subtract(const Duration(hours: 20)),
      likeCount: 15,
    ),
    _BookComment(
      id: 'mock_comment_${isbn13}_3',
      sentenceId: sentences[1].id,
      userId: 'mock_reader_bfree',
      content: '탕수육은 로보트가 만드는 줄 아냐??',
      username: '학사모 비프리',
      createdAt: now.subtract(const Duration(hours: 18)),
      likeCount: 1,
    ),
  ];

  return _BookCommunityData(
    globalBookId: 'mock_global_$isbn13',
    sentences: sentences,
    comments: comments,
  );
}

// ─── Provider: 책 통계 (완독·완독률·세션) ───────────────────────────────────

// global_books의 역정규화 카운트는 갱신되지 않으므로(전부 0) books/reading_sessions
// 를 라이브 집계한다. 공개 계정 행은 RLS 정책(books_select_public)으로 조회 가능.
final _bookStatsProvider = FutureProvider.family<_BookStats, String>((
  ref,
  isbn13,
) async {
  if (kUseMock) {
    return (
      totalCompleted: 1250,
      friendCompleted: 10,
      avgCompletionPct: 95,
      avgSessions: 4,
    );
  }

  final client = Supabase.instance.client;
  List<Map<String, dynamic>> rows;
  try {
    // ponytail: 클라이언트 집계 — 책당 독자가 수천 명 규모가 되면 RPC 집계로 전환
    final res = await client
        .from('books')
        .select('id, user_id, status, current_page, total_pages')
        .eq('isbn', isbn13)
        .limit(1000);
    rows = (res as List).cast<Map<String, dynamic>>();
  } catch (_) {
    rows = const [];
  }

  if (rows.isEmpty) {
    return (
      totalCompleted: 0,
      friendCompleted: 0,
      avgCompletionPct: null,
      avgSessions: null,
    );
  }

  final followingIds = await _fetchAcceptedFollowingIds(client);
  final completedUserIds = <String>{};
  final friendCompletedIds = <String>{};
  final rates = <double>[];

  for (final row in rows) {
    final completed = row['status'] == 'completed';
    final userId = row['user_id'] as String?;
    if (completed && userId != null) {
      completedUserIds.add(userId);
      if (followingIds.contains(userId)) friendCompletedIds.add(userId);
    }
    final total = (row['total_pages'] as num?)?.toInt() ?? 0;
    final current = (row['current_page'] as num?)?.toInt() ?? 0;
    if (completed) {
      rates.add(1);
    } else if (total > 0) {
      rates.add((current / total).clamp(0.0, 1.0));
    }
  }

  final avgCompletionPct = rates.isEmpty
      ? null
      : (rates.reduce((a, b) => a + b) / rates.length * 100).round();

  int? avgSessions;
  try {
    final bookIds = rows
        .map((r) => r['id'])
        .whereType<String>()
        .toList(growable: false);
    final sessions = await client
        .from('reading_sessions')
        .select('user_id')
        .inFilter('book_id', bookIds)
        .limit(5000);
    final list = (sessions as List).cast<Map<String, dynamic>>();
    final readers = list.map((s) => s['user_id']).whereType<String>().toSet();
    if (readers.isNotEmpty) avgSessions = (list.length / readers.length).round();
  } catch (_) {}

  return (
    totalCompleted: completedUserIds.length,
    friendCompleted: friendCompletedIds.length,
    avgCompletionPct: avgCompletionPct,
    avgSessions: avgSessions,
  );
});

// ─── Provider: 나의 문장·생각 개수 ──────────────────────────────────────────

final _myRecordCountsProvider =
    FutureProvider.family<_MyRecordCounts, _PersonalRecordQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return (sentences: 30, thoughts: 5);

      if (kUseRemoteDb) {
        var sentenceCount = 0;
        var thoughtCount = 0;
        try {
          final rows = await ref
              .read(dbServiceProvider)
              .fetchMySentencesForBook(
                query.bookId ?? query.isbn ?? query.title,
                title: query.title,
                author: query.author,
                isbn: query.isbn,
              );
          sentenceCount = rows.length;
          thoughtCount = rows
              .where((r) => (r['thought'] as String?)?.trim().isNotEmpty == true)
              .length;
        } catch (_) {}
        try {
          if (query.globalBookId != null || query.bookId != null) {
            final memos = await ref
                .read(memoRepositoryProvider)
                .fetchMemos(
                  globalBookId: query.globalBookId,
                  bookId: query.bookId,
                );
            thoughtCount += memos.length;
          }
        } catch (_) {}
        return (sentences: sentenceCount, thoughts: thoughtCount);
      }

      final bookId = query.bookId;
      final repo = ref.read(bookRepositoryProvider);
      if (bookId == null || repo == null) return (sentences: 0, thoughts: 0);
      final choseo = await repo.getChoseoByBook(bookId);
      final thoughts = choseo
          .where((c) => c.myThought?.trim().isNotEmpty == true)
          .length;
      return (sentences: choseo.length, thoughts: thoughts);
    });

// ─── 공용 fetch/유틸 ─────────────────────────────────────────────────────────

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
      return _BookComment(
        id: row['id'] as String,
        sentenceId: row['sentence_id'] as String,
        userId: row['user_id'] as String? ?? profile?['id'] as String?,
        content: row['content'] as String,
        username: _displayName(profile),
        avatarUrl: profile?['avatar_url'] as String?,
        createdAt: _parseDate(row['created_at']),
        likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  } catch (_) {
    return const [];
  }
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

// ─── 저자·옮긴이 파싱 ────────────────────────────────────────────────────────

typedef BookContributor = ({String name, String role});

/// 알라딘 원본 저자 문자열("한강 (지은이), 데버라 스미스 (옮긴이)")을
/// 저자·옮긴이 행 목록으로 파싱한다. 역할 표기가 없으면 저자로 간주.
List<BookContributor> parseBookContributors(AladinBook book) {
  final raw = book.rawAuthor?.trim().isNotEmpty == true
      ? book.rawAuthor!
      : book.author;
  final result = <BookContributor>[];
  for (final part in raw.split(',')) {
    final match = RegExp(r'^(.*?)(?:\s*\(([^)]*)\))?$').firstMatch(part.trim());
    if (match == null) continue;
    final name = (match.group(1) ?? '').trim();
    if (name.isEmpty) continue;
    final roleRaw = (match.group(2) ?? '').trim();
    final String role;
    if (roleRaw.contains('옮긴') || roleRaw.contains('역자')) {
      role = '옮긴이';
    } else if (roleRaw.isEmpty ||
        roleRaw.contains('지은') ||
        roleRaw.contains('저')) {
      role = '저자';
    } else {
      role = roleRaw;
    }
    result.add((name: name, role: role));
  }
  if (result.isEmpty) result.add((name: book.author, role: '저자'));
  return result;
}

// ─── 책 정보 화면 ────────────────────────────────────────────────────────────

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
    final showBackButton = Navigator.of(context).canPop();

    final globalBookId = isbn.isEmpty
        ? null
        : ref
              .watch(_bookInfoCommunityProvider(isbn))
              .maybeWhen(data: (data) => data.globalBookId, orElse: () => null);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          // ── 히어로: 뒤로가기 + 표지 + 제목 + 저자 ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (showBackButton)
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
                        )
                      else
                        const SizedBox(width: 44, height: 44),
                      const Spacer(),
                      Semantics(
                        button: true,
                        label: '도서 정보 보기',
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push(
                              AppConstants.routeBookDetailInfo,
                              extra: book,
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.info_outline_rounded,
                              color: context.appTextSecondary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BookCover(
                    coverUrl: book.coverUrl,
                    gradientIndex: gradientIndex,
                    width: 132,
                    height: 192,
                    radius: 12,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    book.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: context.appTextPrimary,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    book.author,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // ── 이어 읽기 (서재에 있는 책만) ───────────────────────────────
          if (libraryBook != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Center(
                  child: SizedBox(
                    width: 172,
                    child: _ContinueReadingButton(book: libraryBook),
                  ),
                ),
              ),
            ),

          // ── 서재에 있는 책 / 서재에 추가 ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Center(
                child: SizedBox(
                  width: 172,
                  child: _AddToLibraryButton(
                    isInLibrary: isInLibrary,
                    onTap: _onAddTap,
                  ),
                ),
              ),
            ),
          ),

          // ── 통계 4종 ──────────────────────────────────────────────────
          if (isbn.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _BookStatsRow(isbn: isbn),
              ),
            ),

          // ── 책 소개 ───────────────────────────────────────────────────
          if (book.description != null && book.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GestureDetector(
                  onTap: () => setState(() => _descExpanded = !_descExpanded),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.smoothBox(
                      color: context.appCard,
                      side: BorderSide.none,
                    ),
                    child: Text(
                      book.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                        height: 1.7,
                      ),
                      maxLines: _descExpanded ? null : 4,
                      overflow: _descExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

          // ── 저자·옮긴이 ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  for (final contributor in parseBookContributors(book))
                    _ContributorRow(contributor: contributor),
                ],
              ),
            ),
          ),

          // ── 나의 문장·생각 ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: _MyRecordsSection(
                book: book,
                libraryBook: libraryBook,
                globalBookId: globalBookId,
              ),
            ),
          ),

          // ── 인기있는 문장·생각 ────────────────────────────────────────
          if (isbn.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _CommunityThoughtsSection(
                  title: '인기있는 문장·생각',
                  book: book,
                  isbn: isbn,
                  friendsOnly: false,
                ),
              ),
            ),

          // ── 친구의 문장·생각 ──────────────────────────────────────────
          if (isbn.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: _CommunityThoughtsSection(
                  title: '친구의 문장·생각',
                  book: book,
                  isbn: isbn,
                  friendsOnly: true,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── CTA 버튼 ────────────────────────────────────────────────────────────────

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
        width: double.infinity,
        height: 28,
        decoration: AppTheme.smoothBox(
          gradient: AppTheme.greenGradient,
          radius: 5,
          side: BorderSide.none,
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 15, color: AppTheme.darkBg),
            SizedBox(width: 4),
            Text(
              '이어 읽기',
              style: TextStyle(
                fontSize: 12,
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
            width: double.infinity,
            height: 28,
            decoration: AppTheme.smoothBox(
              gradient: isIn ? null : AppTheme.greenGradient,
              color: isIn ? Colors.transparent : null,
              radius: 5,
              side: isIn
                  ? BorderSide(color: context.appPillBorderActive)
                  : BorderSide.none,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isIn ? Icons.check_rounded : Icons.add_rounded,
                  size: 15,
                  color: isIn ? context.appTextPrimary : AppTheme.darkBg,
                ),
                const SizedBox(width: 4),
                Text(
                  isIn ? '서재에 있는 책' : '서재에 추가',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: isIn ? context.appTextPrimary : AppTheme.darkBg,
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

// ─── 통계 4종 ────────────────────────────────────────────────────────────────

class _BookStatsRow extends ConsumerWidget {
  final String isbn;

  const _BookStatsRow({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookStatsProvider(isbn));

    return state.when(
      loading: () => Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            const Expanded(
              child: ChorokShimmer(width: double.infinity, height: 68),
            ),
          ],
        ],
      ),
      error: (_, _) => _cells(context, null),
      data: (stats) => _cells(context, stats),
    );
  }

  Widget _cells(BuildContext context, _BookStats? stats) {
    return Row(
      children: [
        _StatCell(label: '전체 완독', value: '${stats?.totalCompleted ?? '-'}'),
        const SizedBox(width: 8),
        _StatCell(label: '친구 완독', value: '${stats?.friendCompleted ?? '-'}'),
        const SizedBox(width: 8),
        _StatCell(
          label: '평균 완독률',
          value: stats?.avgCompletionPct == null
              ? '-'
              : '${stats!.avgCompletionPct}%',
        ),
        const SizedBox(width: 8),
        _StatCell(label: '평균 세션', value: '${stats?.avgSessions ?? '-'}'),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          side: BorderSide.none,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: context.appTextTertiary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: context.appTextPrimary,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 저자·옮긴이 행 ──────────────────────────────────────────────────────────

class _ContributorRow extends StatelessWidget {
  final BookContributor contributor;

  const _ContributorRow({required this.contributor});

  @override
  Widget build(BuildContext context) {
    // ponytail: 저자 상세 화면이 아직 없어 탐색만 표시 — 작가 페이지 생기면 onTap 연결
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: context.appCardElevated,
            child: Text(
              contributor.name.isNotEmpty ? contributor.name[0] : '?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appPrimaryAccent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contributor.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  contributor.role,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: context.appTextTertiary,
          ),
        ],
      ),
    );
  }
}

// ─── 섹션 헤더 ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.appTextPrimary,
          ),
        ),
        const Spacer(),
        if (onSeeAll != null)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSeeAll!();
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Text(
                  '모두 보기',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: context.appTextTertiary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── 나의 문장·생각 ──────────────────────────────────────────────────────────

class _MyRecordsSection extends ConsumerWidget {
  final AladinBook book;
  final Book? libraryBook;
  final String? globalBookId;

  const _MyRecordsSection({
    required this.book,
    required this.libraryBook,
    required this.globalBookId,
  });

  void _openChoseoList(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(AppConstants.routeChoseoList);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      bookId: libraryBook?.id,
      title: book.title,
      author: book.author,
      isbn: book.isbn13,
      globalBookId: globalBookId,
    );
    final state = ref.watch(_myRecordCountsProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: '나의 문장·생각',
          onSeeAll: () => _openChoseoList(context),
        ),
        const SizedBox(height: 12),
        state.when(
          loading: () => const Row(
            children: [
              Expanded(child: ChorokShimmer(width: double.infinity, height: 76)),
              SizedBox(width: 10),
              Expanded(child: ChorokShimmer(width: double.infinity, height: 76)),
            ],
          ),
          error: (_, _) => _cards(context, (sentences: 0, thoughts: 0)),
          data: (counts) => _cards(context, counts),
        ),
      ],
    );
  }

  Widget _cards(BuildContext context, _MyRecordCounts counts) {
    return Row(
      children: [
        Expanded(
          child: _CountCard(
            label: '문장',
            count: counts.sentences,
            background: Colors.white,
            foreground: AppTheme.darkBg,
            onTap: () => _openChoseoList(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CountCard(
            label: '생각',
            count: counts.thoughts,
            background: context.appPrimaryAccent,
            foreground: AppTheme.darkBg,
            onTap: () => _openChoseoList(context),
          ),
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _CountCard({
    required this.label,
    required this.count,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label $count개 모두 보기',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: AppTheme.smoothBox(
            color: background,
            side: BorderSide(color: context.appPillBorderActive),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: foreground,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 인기·친구 문장·생각 섹션 ────────────────────────────────────────────────

class _CommunityThoughtsSection extends ConsumerWidget {
  final String title;
  final AladinBook book;
  final String isbn;
  final bool friendsOnly;

  const _CommunityThoughtsSection({
    required this.title,
    required this.book,
    required this.isbn,
    required this.friendsOnly,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoCommunityProvider(isbn));

    return state.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          const ChorokShimmer(width: double.infinity, height: 180),
        ],
      ),
      error: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title),
          const SizedBox(height: 12),
          Text(
            '문장을 불러오지 못했어요',
            style: TextStyle(fontSize: 12, color: context.appTextTertiary),
          ),
        ],
      ),
      data: (data) {
        final sentences = friendsOnly ? data.friends : data.popular;

        if (sentences.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(title: title),
              const SizedBox(height: 12),
              _EmptyCommunityState(
                icon: friendsOnly
                    ? Icons.people_outline_rounded
                    : Icons.format_quote_rounded,
                title: friendsOnly ? '친구의 기록이 아직 없어요' : '아직 남겨진 문장이 없어요',
                body: friendsOnly
                    ? '이 책을 읽은 독자를 팔로우하면 여기에 보여요'
                    : '첫 번째로 문장을 남겨보세요',
              ),
            ],
          );
        }

        final top = sentences.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: title,
              onSeeAll: () => _showThoughtsSheet(
                context,
                title: title,
                book: book,
                sentences: sentences,
                data: data,
              ),
            ),
            const SizedBox(height: 12),
            _SentenceThoughtCard(
              book: book,
              sentence: top,
              replies: data.repliesFor(top.id),
            ),
          ],
        );
      },
    );
  }
}

void _showThoughtsSheet(
  BuildContext context, {
  required String title,
  required AladinBook book,
  required List<_BookSentence> sentences,
  required _BookCommunityData data,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            const ChorokSheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: sheetContext.appTextPrimary,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: sentences.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final sentence = sentences[index];
                  return _SentenceThoughtCard(
                    book: book,
                    sentence: sentence,
                    replies: data.repliesFor(sentence.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ─── 문장·생각 카드 ──────────────────────────────────────────────────────────

class _SentenceThoughtCard extends StatelessWidget {
  final AladinBook book;
  final _BookSentence sentence;
  final List<_BookComment> replies;

  const _SentenceThoughtCard({
    required this.book,
    required this.sentence,
    required this.replies,
  });

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
    final thought = sentence.thought?.trim();

    return GestureDetector(
      onTap: () => _openSentence(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusMD,
          side: BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 + 댓글·공감 수
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
                    child: Text(
                      sentence.username,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: context.appTextTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${replies.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.favorite_border_rounded,
                  size: 13,
                  color: context.appTextTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${sentence.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 인용 문장
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.smoothBox(
                color: context.appCardElevated.withValues(alpha: 0.5),
                radius: AppTheme.radiusMD,
                side: BorderSide(color: context.appPillBorderActive),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 16,
                    color: context.appPrimaryAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sentence.content,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.appTextPrimary,
                        height: 1.6,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 생각
            if (thought != null && thought.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.smoothBox(
                  color: context.appCardElevated.withValues(alpha: 0.5),
                  radius: AppTheme.radiusMD,
                  side: BorderSide(color: context.appPillBorderActive),
                ),
                child: Text(
                  thought,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    height: 1.65,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],

            // 댓글
            for (final reply in replies.take(2)) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  _Avatar(
                    username: reply.username,
                    avatarUrl: reply.avatarUrl,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openBookInfoProfile(
                        context,
                        userId: reply.userId,
                        username: reply.username,
                        avatarUrl: reply.avatarUrl,
                      ),
                      child: Text(
                        reply.username,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 12,
                    color: context.appTextTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${reply.likeCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  reply.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── 공통 UI ─────────────────────────────────────────────────────────────────

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
