import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../shared/providers/library_provider.dart';
import '../../search/controller/book_search_controller.dart';

typedef RecommendedBook = ({
  String title,
  String author,
  String reason,
  int gradientIndex,
  double matchScore,
  String coverUrl,
});

// ── 불용어 ─────────────────────────────────────────────────────────────────
const Set<String> kKoreanStopwords = {
  '나', '너', '그', '그녀', '우리', '저', '당신', '이것', '저것', '그것', '여기', '거기',
  '에서', '으로', '에게', '부터', '까지', '처럼', '보다', '라고', '이라고',
  '그리고', '그러나', '하지만', '그래서', '따라서', '또한', '그런데', '그러므로',
  '매우', '정말', '아주', '너무', '모두', '항상', '자주', '가장', '조금',
  '것', '수', '때', '말', '이런', '저런', '그런', '어떤', '모든', '이미',
  '있다', '없다', '하다', '되다', '같다', '알다', '모르다',
  '사람', '마음', '생각', '시간', '세상', '이후', '나는', '그는', '그녀는',
};

// ── 순수 알고리즘 함수 (테스트 가능하도록 package-accessible) ──────────────────

/// 문장 목록에서 가장 많이 기록된 책의 저자를 반환한다.
String? extractAuthorFromSentences(List<Map<String, dynamic>> sentences) {
  final counts = <String, int>{};
  final authorMap = <String, String>{};

  for (final s in sentences) {
    final bookId = s['book_id'] as String?;
    if (bookId == null) continue;
    counts[bookId] = (counts[bookId] ?? 0) + 1;
    final books = s['books'] as Map<String, dynamic>?;
    if (books != null) {
      final author = books['author'] as String? ?? '';
      if (author.isNotEmpty) authorMap[bookId] = author;
    }
  }

  if (counts.isEmpty) return null;
  final topId =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return authorMap[topId];
}

/// 가장 많이 기록된 책의 제목을 반환한다 (추천 이유 문구 생성용).
String? extractTopBookTitleFromSentences(List<Map<String, dynamic>> sentences) {
  final counts = <String, int>{};
  final titleMap = <String, String>{};

  for (final s in sentences) {
    final bookId = s['book_id'] as String?;
    if (bookId == null) continue;
    counts[bookId] = (counts[bookId] ?? 0) + 1;
    final books = s['books'] as Map<String, dynamic>?;
    if (books != null) {
      final title = books['title'] as String? ?? '';
      if (title.isNotEmpty) titleMap[bookId] = title;
    }
  }

  if (counts.isEmpty) return null;
  final topId =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return titleMap[topId];
}

/// 문장 내용에서 빈도 높은 의미 키워드 최대 3개를 추출한다.
List<String> extractKeywordsFromSentences(List<Map<String, dynamic>> sentences) {
  final freq = <String, int>{};
  for (final s in sentences) {
    final content = s['content'] as String? ?? '';
    for (final raw in content.split(RegExp(r'\s+'))) {
      final word = raw.replaceAll(RegExp(r'[^가-힣a-zA-Z]'), '').trim();
      if (word.length < 2) continue;
      if (kKoreanStopwords.contains(word)) continue;
      freq[word] = (freq[word] ?? 0) + 1;
    }
  }
  final sorted = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(3).map((e) => e.key).toList();
}

// ── 내부 타입 ──────────────────────────────────────────────────────────────
typedef _SearchResult = ({
  String isbn,
  String title,
  String author,
  String coverUrl,
  String source,
  int rank,
});

Future<List<_SearchResult>> _searchAladin(
  String query,
  String queryType,
  String source,
) async {
  try {
    final books = await BookSearchNotifier.invoke({
      'query': query,
      'queryType': queryType,
    });
    return books.asMap().entries
        .map(
          (e) => (
            isbn: e.value.isbn13 ?? '${e.value.title}_${e.value.author}',
            title: e.value.title,
            author: e.value.author,
            coverUrl: e.value.coverUrl ?? '',
            source: source,
            rank: e.key,
          ),
        )
        .toList();
  } catch (_) {
    return [];
  }
}

// ── Provider ───────────────────────────────────────────────────────────────
final recommendedBooksProvider =
    FutureProvider.autoDispose<List<RecommendedBook>>((ref) async {
  if (kUseMock) {
    return [
      (
        title: '흰',
        author: '한강',
        reason: '"채식주의자"과 같은 한강의 다른 작품',
        gradientIndex: 1,
        matchScore: 0.94,
        coverUrl:
            'https://image.aladin.co.kr/product/10920/22/cover500/8936434349_2.jpg',
      ),
      (
        title: '소년이 온다',
        author: '한강',
        reason: '"채식주의자"과 같은 한강의 다른 작품',
        gradientIndex: 2,
        matchScore: 0.93,
        coverUrl:
            'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg',
      ),
      (
        title: '아몬드',
        author: '손원평',
        reason: "'삶', '고통' 감성을 자주 기록하셨어요",
        gradientIndex: 3,
        matchScore: 0.88,
        coverUrl:
            'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg',
      ),
      (
        title: '82년생 김지영',
        author: '조남주',
        reason: "'삶', '고통' 감성을 자주 기록하셨어요",
        gradientIndex: 4,
        matchScore: 0.86,
        coverUrl:
            'https://image.aladin.co.kr/product/10743/98/cover500/8954637930_2.jpg',
      ),
    ];
  }

  final db = ref.read(dbServiceProvider);
  final library = ref.watch(libraryProvider);

  final raw = await db.fetchMySentences();
  if (raw.length < 3) return const [];

  final author = extractAuthorFromSentences(raw);
  final topBookTitle = extractTopBookTitleFromSentences(raw);
  final keywords = extractKeywordsFromSentences(raw);

  final futures = <Future<List<_SearchResult>>>[];

  if (author != null && author.isNotEmpty) {
    futures.add(_searchAladin(author, 'Author', 'author'));
  }

  final keywordQuery = keywords.take(2).join(' ');
  if (keywordQuery.isNotEmpty) {
    futures.add(_searchAladin(keywordQuery, 'Keyword', 'keyword'));
  }

  if (futures.isEmpty) return const [];

  final results = (await Future.wait(futures)).expand((l) => l).toList();

  final ownedTitles =
      library.map((b) => b.title.trim().toLowerCase()).toSet();

  // isbn 기준 중복 제거 — author 출처 우선
  final seen = <String, _SearchResult>{};
  for (final r in results) {
    final existing = seen[r.isbn];
    if (existing == null ||
        (r.source == 'author' && existing.source != 'author')) {
      seen[r.isbn] = r;
    }
  }

  final candidates = seen.values
      .where((r) => !ownedTitles.contains(r.title.trim().toLowerCase()))
      .toList();

  double calcScore(_SearchResult r) => r.source == 'author'
      ? (0.95 - r.rank * 0.01).clamp(0.75, 0.95)
      : (0.90 - r.rank * 0.015).clamp(0.70, 0.90);

  String buildReason(_SearchResult r) {
    if (r.source == 'author') {
      return topBookTitle != null
          ? '"$topBookTitle"과 같은 ${author ?? ''}의 다른 작품'
          : '${author ?? ''}의 다른 작품';
    }
    return keywords.isNotEmpty
        ? "'${keywords.take(2).join("', '")}' 감성을 자주 기록하셨어요"
        : '취향에 맞는 책';
  }

  candidates.sort((a, b) => calcScore(b).compareTo(calcScore(a)));

  return candidates.take(4).toList().asMap().entries.map(
    (e) => (
      title: e.value.title,
      author: e.value.author,
      reason: buildReason(e.value),
      gradientIndex: (e.key % 6) + 1,
      matchScore: calcScore(e.value),
      coverUrl: e.value.coverUrl,
    ),
  ).toList();
});
