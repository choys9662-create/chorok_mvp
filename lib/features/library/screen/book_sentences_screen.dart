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
import '../../../shared/widgets/chorok_card.dart';
import '../../feed/screen/sentence_detail_screen.dart';

const _kQuoteHighlightBg = Color(0xFF222422);
const _kThoughtBorder = Color(0xFF222422);

typedef _BookSentenceQuery = ({
  String bookId,
  String title,
  String author,
  String? isbn,
});

typedef _SentenceCard = ({
  String id,
  String content,
  String? thought,
  int? pageNumber,
  int likeCount,
  int commentCount,
});

// ponytail: kUseRemoteDb=false(레거시 로컬 SQLite 롤백 경로)는 상수가 항상 true라
// 다루지 않음 — 되돌릴 일 있으면 book_detail_screen.dart의 분기를 참고해 추가.
final _bookSentenceCardsProvider =
    FutureProvider.family<List<_SentenceCard>, _BookSentenceQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return _mockCardsFor(query.title);
      try {
        final rows = await ref
            .read(dbServiceProvider)
            .fetchMySentencesForBook(
              query.bookId,
              title: query.title,
              author: query.author,
              isbn: query.isbn,
            );
        final ids = rows.map((r) => r['id'] as String).toList();
        final client = Supabase.instance.client;
        final likeCounts = await _countBySentence(
          client,
          'sentence_likes',
          ids,
        );
        final commentCounts = await _countBySentence(
          client,
          'sentence_comments',
          ids,
        );
        final cards =
            rows.map((r) {
              final id = r['id'] as String;
              return (
                id: id,
                content: r['content'] as String,
                thought: r['thought'] as String?,
                pageNumber: (r['page_number'] as num?)?.toInt(),
                likeCount: likeCounts[id] ?? 0,
                commentCount: commentCounts[id] ?? 0,
              );
            }).toList()..sort((a, b) {
              final pa = a.pageNumber;
              final pb = b.pageNumber;
              if (pa == null && pb == null) return 0;
              if (pa == null) return 1;
              if (pb == null) return -1;
              return pb.compareTo(pa);
            });
        return cards;
      } catch (_) {
        return const [];
      }
    });

Future<Map<String, int>> _countBySentence(
  SupabaseClient client,
  String table,
  List<String> sentenceIds,
) async {
  if (sentenceIds.isEmpty) return const {};
  final rows = await client
      .from(table)
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

List<_SentenceCard> _mockCardsFor(String title) {
  if (!title.contains('채식주의자')) return const [];
  return const [
    (
      id: 'mock_9',
      content: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      thought:
          '"특별한 사람이라고 생각한 적이 없었다"는 무심한 단언이지만, 문장 첫머리의 "아내가 채식을 시작하기 전까지"가 '
          '모든 걸 뒤집는다. 평범함에 대한 진술이 아니라, 그 평범함이 끝났다는 예고이기 때문이다. 화자는 아내를 '
          '무난함으로만 규정해왔고, 그래서 그녀의 변화를 끝내 이해하지 못할 인물임을 첫 문장이 미리 드러낸다. '
          '안온한 일상이 곧 깨질 것이라는 불길함이 담담한 어조 아래 깔려 있다.',
      pageNumber: 9,
      likeCount: 3,
      commentCount: 2,
    ),
    (
      id: 'mock_12',
      content:
          '크지도 작지도 않은 키, 길지도 짧지도 않은 단발머리, 각질이 일어난 노르스름한 피부, 외꺼풀 눈에 약간 '
          '튀어나온 광대뼈, 개성있어 보이는 것을 두려워하는 듯한 무채색의 옷차림.',
      thought: null,
      pageNumber: 12,
      likeCount: 24,
      commentCount: 0,
    ),
    (
      id: 'mock_52',
      content: '빠르지도, 느리지도, 힘있지도, 가냘프지도 않은 걸음걸이로.',
      thought: null,
      pageNumber: 52,
      likeCount: 2,
      commentCount: 3,
    ),
    (
      id: 'mock_123',
      content:
          '마침내는 언젠가 통했던 그런 필사적인 노력이 오히려 그녀에게 죄책감을 일으켜, 그녀의 웃음이 결국 '
          '흐려져버린다는 것을 지우가 알 리 없다.',
      thought: null,
      pageNumber: 123,
      likeCount: 2,
      commentCount: 3,
    ),
    (
      id: 'mock_202',
      content: '산다는 것은 이상한 일이라고, 그 웃음의 끝에 그녀는 생각한다.',
      thought: null,
      pageNumber: 202,
      likeCount: 2,
      commentCount: 3,
    ),
  ];
}

// ─── 화면 ────────────────────────────────────────────────────────────────────

class BookSentencesScreen extends ConsumerWidget {
  final Book book;

  const BookSentencesScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final _BookSentenceQuery query = (
      bookId: book.id,
      title: book.title,
      author: book.author,
      isbn: book.isbn,
    );
    final async = ref.watch(_bookSentenceCardsProvider(query));

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(bookTitle: book.title),
            Expanded(
              child: async.when(
                data: (cards) => cards.isEmpty
                    ? const _EmptyView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: cards.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) =>
                            _SentenceCardView(book: book, card: cards[i]),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const _EmptyView(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상단 바 ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final String bookTitle;
  const _TopBar({required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '뒤로가기',
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.appTextSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '나의 문장·생각',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.appTextPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            bookTitle,
            style: TextStyle(
              fontSize: 12,
              color: context.appTextTertiary,
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── 초서 카드 ────────────────────────────────────────────────────────────────

class _SentenceCardView extends StatelessWidget {
  final Book book;
  final _SentenceCard card;

  const _SentenceCardView({required this.book, required this.card});

  bool get _hasThought =>
      card.thought != null && card.thought!.trim().isNotEmpty;

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: card.content,
        bookTitle: book.title,
        bookAuthor: book.author,
        page: card.pageNumber,
        collectorThought: card.thought,
        sentenceId: card.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: ChorokCard(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: AppTheme.smoothBox(
                color: _hasThought ? _kQuoteHighlightBg : context.appCard,
                radius: 6,
                side: _hasThought
                    ? BorderSide(color: context.appTextSecondary)
                    : BorderSide.none,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      card.pageNumber?.toString() ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      card.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasThought) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: AppTheme.smoothBox(
                  color: context.appCard,
                  radius: 6,
                  side: const BorderSide(color: _kThoughtBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 26 + 12),
                    Expanded(
                      child: Text(
                        card.thought!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  size: 14,
                  color: context.appPrimaryAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  '${card.likeCount}',
                  style: TextStyle(fontSize: 14, color: context.appTextPrimary),
                ),
                const SizedBox(width: 22),
                Icon(
                  Icons.chat_bubble_rounded,
                  size: 13,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${card.commentCount}',
                  style: TextStyle(fontSize: 14, color: context.appTextPrimary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 빈 상태 ─────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.format_quote_rounded,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 기록한 문장이 없어요',
            style: TextStyle(fontSize: 16, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}
