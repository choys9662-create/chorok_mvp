import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../core/services/db_service.dart';
import '../models/overlap_group.dart';
import '../utils/overlap_detector.dart';
import '../utils/overlap_text_merger.dart';

/// 겹문장 한 건 — 내 문장과 팔로잉 독자의 문장이 같은 책에서 겹친 결과.
class FollowOverlap {
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final String? isbn13;
  final String? bookId;
  final String? globalBookId;

  final String mySentenceId;
  final String myContent;
  final int? myPage;

  final String neighborUserId;
  final String neighborName;
  final String? neighborHandle;
  final String? neighborAvatar;
  final String neighborSentenceId;
  final String neighborContent;
  final String? neighborThought;
  final DateTime neighborCreatedAt;

  final double ratio;
  final String commonPhrase;
  final String mergedContent;
  final HighlightRange mergedHighlight;

  const FollowOverlap({
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    this.isbn13,
    this.bookId,
    this.globalBookId,
    required this.mySentenceId,
    required this.myContent,
    this.myPage,
    required this.neighborUserId,
    required this.neighborName,
    this.neighborHandle,
    this.neighborAvatar,
    required this.neighborSentenceId,
    required this.neighborContent,
    this.neighborThought,
    required this.neighborCreatedAt,
    required this.ratio,
    required this.commonPhrase,
    required this.mergedContent,
    required this.mergedHighlight,
  });
}

String _compact(String? value) {
  if (value == null) return '';
  return value.toLowerCase().replaceAll(
    RegExp(r'[\s\p{P}\p{S}]+', unicode: true),
    '',
  );
}

class FollowOverlapNotifier extends AsyncNotifier<List<FollowOverlap>> {
  // 비교 폭주 방지 — 책당 비교 대상 문장 수 상한.
  static const int _perBookCap = 30;

  @override
  Future<List<FollowOverlap>> build() async {
    if (kUseMock) return _mockOverlaps();

    try {
      final data = await ref
          .read(dbServiceProvider)
          .fetchFollowOverlapCandidates();
      if (data.mine.isEmpty || data.neighbors.isEmpty) return const [];
      return _detect(data.mine, data.neighbors);
    } catch (_) {
      return const [];
    }
  }

  List<FollowOverlap> _detect(
    List<Map<String, dynamic>> mine,
    List<Map<String, dynamic>> neighbors,
  ) {
    // 책 키로 버킷팅.
    final myByBook = <String, List<Map<String, dynamic>>>{};
    for (final s in mine) {
      (myByBook[_bookKey(s)] ??= []).add(s);
    }
    final neighborByBook = <String, List<Map<String, dynamic>>>{};
    for (final s in neighbors) {
      (neighborByBook[_bookKey(s)] ??= []).add(s);
    }

    // neighborSentenceId 기준으로 최고 ratio 한 건만 유지.
    final best = <String, FollowOverlap>{};

    for (final entry in myByBook.entries) {
      final neighborList = neighborByBook[entry.key];
      if (neighborList == null) continue;

      final myList = entry.value.take(_perBookCap);
      final theirList = neighborList.take(_perBookCap).toList();

      for (final mineRow in myList) {
        final myContent = (mineRow['content'] as String? ?? '').trim();
        if (myContent.isEmpty) continue;

        for (final neighborRow in theirList) {
          final neighborContent = (neighborRow['content'] as String? ?? '')
              .trim();
          if (neighborContent.isEmpty) continue;

          final result = OverlapDetector.compare(myContent, neighborContent);
          if (!result.isOverlapping) continue;

          final overlap = _build(mineRow, neighborRow, result);
          final existing = best[overlap.neighborSentenceId];
          if (existing == null || overlap.ratio > existing.ratio) {
            best[overlap.neighborSentenceId] = overlap;
          }
        }
      }
    }

    final list = best.values.toList()
      ..sort((a, b) {
        final r = b.ratio.compareTo(a.ratio);
        if (r != 0) return r;
        return b.neighborCreatedAt.compareTo(a.neighborCreatedAt);
      });
    return list;
  }

  FollowOverlap _build(
    Map<String, dynamic> mineRow,
    Map<String, dynamic> neighborRow,
    OverlapResult result,
  ) {
    final book =
        (neighborRow['global_books'] as Map<String, dynamic>?) ??
        (neighborRow['books'] as Map<String, dynamic>?);
    final profile = neighborRow['profiles'] as Map<String, dynamic>?;
    final neighborName =
        (profile?['display_name'] as String?)?.trim().isNotEmpty == true
        ? profile!['display_name'] as String
        : (profile?['username'] as String? ?? '독자');
    final myContent = (mineRow['content'] as String? ?? '').trim();
    final neighborContent = (neighborRow['content'] as String? ?? '').trim();
    final common = result.commonPhrase.trim().isNotEmpty
        ? result.commonPhrase.trim()
        : (myContent.length <= neighborContent.length
              ? myContent
              : neighborContent);
    final merged = mergeOverlapText(
      mine: myContent,
      neighbor: neighborContent,
      result: result,
    );

    return FollowOverlap(
      bookTitle: book?['title'] as String? ?? '알 수 없는 책',
      bookAuthor: book?['author'] as String? ?? '',
      coverUrl: book?['cover_url'] as String?,
      isbn13: (book?['isbn13'] ?? book?['isbn']) as String?,
      bookId: neighborRow['book_id'] as String?,
      globalBookId: neighborRow['global_book_id'] as String?,
      mySentenceId: mineRow['id'] as String? ?? '',
      myContent: myContent,
      myPage: (mineRow['page_number'] as num?)?.toInt(),
      neighborUserId:
          neighborRow['user_id'] as String? ?? profile?['id'] as String? ?? '',
      neighborName: neighborName,
      neighborHandle: (profile?['username'] as String?)?.trim(),
      neighborAvatar: profile?['avatar_url'] as String?,
      neighborSentenceId: neighborRow['id'] as String? ?? '',
      neighborContent: neighborContent,
      neighborThought:
          (neighborRow['thought'] as String?)?.trim().isNotEmpty == true
          ? neighborRow['thought'] as String
          : null,
      neighborCreatedAt:
          DateTime.tryParse(neighborRow['created_at'] as String? ?? '') ??
          DateTime.now(),
      ratio: result.ratio,
      commonPhrase: common,
      mergedContent: merged.content,
      mergedHighlight: merged.highlight,
    );
  }

  String _bookKey(Map<String, dynamic> row) {
    final gid = row['global_book_id'] as String?;
    if (gid != null && gid.isNotEmpty) return 'g:$gid';
    final gb = row['global_books'] as Map<String, dynamic>?;
    final lb = row['books'] as Map<String, dynamic>?;
    final isbn = _compact((gb?['isbn13'] ?? lb?['isbn']) as String?);
    if (isbn.isNotEmpty) return 'i:$isbn';
    final title = _compact((gb?['title'] ?? lb?['title']) as String?);
    final author = _compact((gb?['author'] ?? lb?['author']) as String?);
    return 't:$title|$author';
  }
}

final followOverlapProvider =
    AsyncNotifierProvider<FollowOverlapNotifier, List<FollowOverlap>>(
      FollowOverlapNotifier.new,
    );

// ─── 목업 ──────────────────────────────────────────────────────────────────
// feed_activity_provider의 _mockActivities(해진짱짱 · 데미안)와 정합되도록 맞춰,
// 디자인 앱에서 홈 섹션·피드 배지가 동일 데이터로 동작하게 한다.
List<FollowOverlap> _mockOverlaps() {
  final now = DateTime.now();
  const demianCover =
      'https://image.aladin.co.kr/product/206/48/cover500/893643361x_1.jpg';
  return [
    FollowOverlap(
      bookTitle: '데미안',
      bookAuthor: '헤르만 헤세',
      coverUrl: demianCover,
      bookId: 'mock_demian',
      mySentenceId: 'mock_my_1',
      myContent: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      myPage: 12,
      neighborUserId: 'mock_haejin',
      neighborName: '해진짱짱',
      neighborHandle: 'haejin_jjang',
      neighborAvatar: null,
      neighborSentenceId: 'mock_nb_1',
      neighborContent: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      neighborThought: '거부의 시작이 꿈이라는 건, 의지가 아닌 무의식의 선택이라는 뜻.',
      neighborCreatedAt: now.subtract(const Duration(minutes: 16)),
      ratio: 1.0,
      commonPhrase: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      mergedContent: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
      mergedHighlight: HighlightRange(0, 24),
    ),
    FollowOverlap(
      bookTitle: '데미안',
      bookAuthor: '헤르만 헤세',
      coverUrl: demianCover,
      bookId: 'mock_demian',
      mySentenceId: 'mock_my_2',
      myContent: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      myPage: 9,
      neighborUserId: 'mock_haejin',
      neighborName: '해진짱짱',
      neighborHandle: 'haejin_jjang',
      neighborAvatar: null,
      neighborSentenceId: 'mock_nb_2',
      neighborContent: '나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      neighborThought: '평범함에 대한 진술이 아니라 곧 닥칠 균열의 예고편이다.',
      neighborCreatedAt: now.subtract(const Duration(hours: 1)),
      ratio: 0.78,
      commonPhrase: '나는 그녀가 특별한 사람이라고 생각한 적이 없었다',
      mergedContent: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      mergedHighlight: HighlightRange(17, 44),
    ),
  ];
}
