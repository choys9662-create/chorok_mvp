import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/library_provider.dart';
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

  const _BookSentence({
    required this.id,
    required this.content,
    this.thought,
    required this.username,
    this.avatarUrl,
    required this.savedAt,
  });
}

// ─── Provider: isbn13 기준 커뮤니티 문장 조회 ─────────────────────────────────

final _bookInfoSentencesProvider =
    FutureProvider.family<List<_BookSentence>, String>((ref, isbn13) async {
  final client = Supabase.instance.client;

  final sentenceRows = await client
      .from('sentences')
      .select('id, content, thought, created_at, user_id')
      .eq('book_id', isbn13)
      .order('created_at', ascending: false)
      .limit(30);

  final rows = (sentenceRows as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return const [];

  // 유저 프로필 일괄 조회
  final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
  final profileRows = await client
      .from('profiles')
      .select('id, username, display_name, avatar_url')
      .inFilter('id', userIds);

  final profileMap = <String, Map<String, dynamic>>{
    for (final p in (profileRows as List).cast<Map<String, dynamic>>())
      p['id'] as String: p,
  };

  // thought 있는 것 먼저, 없는 것 나중
  final withThought = <_BookSentence>[];
  final withoutThought = <_BookSentence>[];

  for (final row in rows) {
    final profile = profileMap[row['user_id'] as String];
    final sentence = _BookSentence(
      id: row['id'] as String,
      content: row['content'] as String,
      thought: row['thought'] as String?,
      username: profile?['display_name'] as String? ??
          profile?['username'] as String? ??
          '독자',
      avatarUrl: profile?['avatar_url'] as String?,
      savedAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
    if (sentence.thought != null && sentence.thought!.isNotEmpty) {
      withThought.add(sentence);
    } else {
      withoutThought.add(sentence);
    }
  }

  return [...withThought, ...withoutThought];
});

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
      ScaffoldMessenger.of(context).showSnackBar(
        chorokSnackBar(context, '"${book.title}"을(를) 서재에서 삭제했어요'),
      );
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

    final gradientIndex = book.title.hashCode.abs() % AppTheme.coverGradients.length;
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
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
                          fontSize: 14,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appTextTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _descExpanded = !_descExpanded),
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
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // ── 독자들의 문장 헤더 ────────────────────────────────────────
          if (isbn.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '독자들의 문장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── 독자들의 문장 콘텐츠 ─────────────────────────────────────
          if (isbn.isNotEmpty)
            _SentencesSection(isbn: isbn),

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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

// ─── 커뮤니티 문장 섹션 ────────────────────────────────────────────────────────

class _SentencesSection extends ConsumerWidget {
  final String isbn;

  const _SentencesSection({required this.isbn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_bookInfoSentencesProvider(isbn));

    return state.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _SentenceShimmer(),
          ),
          childCount: 3,
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Center(
            child: Text(
              '문장을 불러오지 못했어요',
              style: TextStyle(
                fontSize: 13,
                color: context.appTextTertiary,
              ),
            ),
          ),
        ),
      ),
      data: (sentences) {
        if (sentences.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 40,
                    color: context.appTextTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '아직 기록된 문장이 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '첫 번째로 문장을 남겨보세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _SentenceCard(sentence: sentences[i]),
            ),
            childCount: sentences.length,
          ),
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
                    fontSize: 13,
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
                  fontSize: 11,
                  color: context.appTextTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '·',
                style: TextStyle(
                  fontSize: 11,
                  color: context.appTextTertiary,
                ),
              ),
              const SizedBox(width: 6),
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
          fontSize: 9,
          fontWeight: FontWeight.w700,
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
