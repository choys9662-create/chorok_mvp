import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/book_memo.dart';
import '../../../shared/models/isar/isar_book_reflection.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/repositories/memo_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_shimmer.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../model/aladin_book.dart';
import '../util/add_book_flow.dart';
import '../widget/add_to_library_sheet.dart';

// ─── 커뮤니티 문장 모델 ──────────────────────────────────────────────────────

class _BookSentence {
  final String id;
  final String content;
  final String? thought;
  final String username;
  final String? avatarUrl;
  final DateTime savedAt;
  final int likeCount;

  const _BookSentence({
    required this.id,
    required this.content,
    this.thought,
    required this.username,
    this.avatarUrl,
    required this.savedAt,
    this.likeCount = 0,
  });
}

class _BookComment {
  final String id;
  final String content;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;
  final String? sentenceContent;
  final int likeCount;

  const _BookComment({
    required this.id,
    required this.content,
    required this.username,
    this.avatarUrl,
    required this.createdAt,
    this.sentenceContent,
    this.likeCount = 0,
  });
}

class _BookReview {
  final String id;
  final String username;
  final String? avatarUrl;
  final int starRating;
  final String? memorableLine;
  final String? legacy;
  final DateTime createdAt;

  const _BookReview({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.starRating,
    this.memorableLine,
    this.legacy,
    required this.createdAt,
  });
}

class _BookCommunityData {
  final String? globalBookId;
  final int readerCount;
  final int sentenceCount;
  final List<_BookSentence> sentences;
  final List<_BookComment> comments;
  final List<_BookReview> reviews;

  const _BookCommunityData({
    required this.globalBookId,
    required this.readerCount,
    required this.sentenceCount,
    required this.sentences,
    required this.comments,
    required this.reviews,
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

      final sentenceRows = await _fetchGlobalBookSentences(client, isbn13);

      final withThought = <_BookSentence>[];
      final withoutThought = <_BookSentence>[];

      for (final row in sentenceRows) {
        final sentence = _BookSentence(
          id: row['sentence_id'] as String,
          content: row['content'] as String,
          thought: row['thought'] as String?,
          username: _displayName(row),
          avatarUrl: row['avatar_url'] as String?,
          savedAt: _parseDate(row['created_at']),
          likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
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
              content: sentence.thought!.trim(),
              username: sentence.username,
              avatarUrl: sentence.avatarUrl,
              createdAt: sentence.savedAt,
              sentenceContent: sentence.content,
              likeCount: sentence.likeCount,
            ),
        ...await _fetchSentenceComments(
          client,
          sentences.map((sentence) => sentence.id).toList(),
        ),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final globalBookId = globalBook?['id'] as String?;
      final reviews = globalBookId == null
          ? const <_BookReview>[]
          : await _fetchBookReviews(client, globalBookId);

      return _BookCommunityData(
        globalBookId: globalBookId,
        readerCount: (globalBook?['reader_count'] as num?)?.toInt() ?? 0,
        sentenceCount:
            (globalBook?['sentence_count'] as num?)?.toInt() ??
            sentences.length,
        sentences: sentences,
        comments: comments,
        reviews: reviews,
      );
    });

// ─── Provider: 내 개인 기록 조회 ────────────────────────────────────────────

final _bookPersonalRecordsProvider =
    FutureProvider.family<_PersonalRecordData, _PersonalRecordQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return _PersonalRecordData.empty;

      if (kIsWeb) {
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

Future<List<Map<String, dynamic>>> _fetchGlobalBookSentences(
  SupabaseClient client,
  String isbn13,
) async {
  try {
    final rows = await client
        .from('global_book_sentences')
        .select(
          'sentence_id, content, thought, created_at, username, display_name, '
          'avatar_url, like_count',
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
          'id, sentence_id, content, like_count, created_at, '
          'profiles!sentence_comments_user_id_fkey(username, display_name, avatar_url)',
        )
        .inFilter('sentence_id', sentenceIds)
        .order('created_at', ascending: false)
        .limit(80);

    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return _BookComment(
        id: row['id'] as String,
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

Future<List<_BookReview>> _fetchBookReviews(
  SupabaseClient client,
  String globalBookId,
) async {
  try {
    final rows = await client
        .from('book_reviews')
        .select(
          'id, star_rating, memorable_line, legacy, created_at, '
          'profiles!book_reviews_user_id_fkey(username, display_name, avatar_url)',
        )
        .eq('global_book_id', globalBookId)
        .order('created_at', ascending: false)
        .limit(30);

    return (rows as List).cast<Map<String, dynamic>>().map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return _BookReview(
        id: row['id'] as String,
        username: _displayName(profile),
        avatarUrl: profile?['avatar_url'] as String?,
        starRating: (row['star_rating'] as num?)?.toInt() ?? 0,
        memorableLine: row['memorable_line'] as String?,
        legacy: row['legacy'] as String?,
        createdAt: _parseDate(row['created_at']),
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

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
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
                      // 뒤로가기
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

                      // 책 표지
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
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
                          radius: 14,
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
                        overflow: _descExpanded ? null : TextOverflow.ellipsis,
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

          if (isbn.isNotEmpty) _ReviewsSection(isbn: isbn),

          if (isbn.isNotEmpty) _CommentsSection(isbn: isbn),

          // ── 독자들의 문장 콘텐츠 ─────────────────────────────────────
          if (isbn.isNotEmpty) _SentencesSection(isbn: isbn),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

// ─── 서재 추가 CTA 버튼 ────────────────────────────────────────────────────────

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
            borderRadius: BorderRadius.circular(999),
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
          child: _SectionSkeleton(title: '사용자 평가'),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: _SectionError(title: '사용자 평가', message: '평가를 불러오지 못했어요'),
      ),
      data: (data) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: '사용자 평가',
                trailing: data.averageRating == null
                    ? null
                    : '${data.averageRating!.toStringAsFixed(1)} · ${data.reviews.length}명',
              ),
              const SizedBox(height: 12),
              if (data.reviews.isEmpty)
                const _EmptyCommunityState(
                  icon: Icons.star_outline_rounded,
                  title: '아직 공개 평가가 없어요',
                  body: '완독 후 남긴 별점과 감상이 여기에 모여요',
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
                child: Text(
                  review.username,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                child: Text(
                  comment.username,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextTertiary,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  borderRadius: BorderRadius.circular(2),
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
              Text(
                sentence.username,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
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
