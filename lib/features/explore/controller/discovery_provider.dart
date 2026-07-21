import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../search/model/aladin_book.dart';

// 내 표시 이름은 홈에서도 쓰므로 shared 로 옮겼다.
export '../../../shared/providers/profile_provider.dart'
    show myDisplayNameProvider;

/// 검색 탭 디스커버리(검색어 없을 때) 데이터.
///
/// 검색 로그 테이블이 아직 없어 "인기"는 기존 데이터로 근사한다:
/// - 인기 책: global_books.reader_count(서재에 담은 유저 수) 내림차순
/// - 인기 작가: 작가별 reader_count 합계 (popular_authors RPC)

// ── 인기 작가 ────────────────────────────────────────────────────────────────
typedef PopularAuthor = ({String name, List<String> titles});

final popularBooksProvider = FutureProvider.autoDispose<List<AladinBook>>((
  ref,
) async {
  if (kUseMock) {
    return const [
      AladinBook(
        title: '채식주의자 (리마스터링)',
        author: '한강',
        rawAuthor: '한강 (지은이), 김한강 (옮긴이)',
        publisher: '창비',
        coverUrl:
            'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg',
        isbn13: '9788936434595',
        description:
            '2016년 인터내셔널 부커상을 수상하며 한국문학의 입지를 한 단계 확장시킨 한강의 장편소설. '
            '출간 15년 만에 새로운 장정으로 선보인다. 상처받은 영혼의 고통과 식물적 상상력, '
            '그리고 인간의 폭력성을 섬세하고 강렬하게 그려낸 작품이다.',
        totalPages: 276,
        genre: '소설',
        pubDate: '2022-03-28',
      ),
      AladinBook(
        title: '안녕이라 그랬어',
        author: '김애란',
        publisher: '문학동네',
        coverUrl:
            'https://image.aladin.co.kr/product/35135/2/cover500/k932934927_1.jpg',
        isbn13: '9788954699907',
      ),
      AladinBook(
        title: '바다에서 온 소년',
        author: '개릿 카',
        publisher: '북하우스',
        coverUrl:
            'https://image.aladin.co.kr/product/34882/8/cover500/k182933544_1.jpg',
        isbn13: '9791168341234',
      ),
      AladinBook(
        title: '불안',
        author: '알랭 드 보통',
        publisher: '은행나무',
        coverUrl:
            'https://image.aladin.co.kr/product/49/16/cover500/8956601542_1.jpg',
        isbn13: '9788956601540',
      ),
    ];
  }

  final res = await Supabase.instance.client.rpc(
    'popular_books',
    params: {'limit_count': 10},
  );

  return (res as List)
      .cast<Map<String, dynamic>>()
      .map(
        (m) => AladinBook(
          title: m['title'] as String? ?? '',
          author: m['author'] as String? ?? '',
          publisher: m['publisher'] as String? ?? '',
          coverUrl: m['cover_url'] as String?,
          isbn13: m['isbn13'] as String?,
          totalPages: (m['total_pages'] as num?)?.toInt() ?? 0,
        ),
      )
      .toList();
});

final popularAuthorsProvider = FutureProvider.autoDispose<List<PopularAuthor>>((
  ref,
) async {
  if (kUseMock) {
    return const [
      (name: '한강', titles: ['채식주의자', '소년이 온다']),
      (name: '다자이 오사무', titles: ['인간실격', '사양']),
      (name: '앙투안 드 생텍쥐페리', titles: ['어린왕자']),
    ];
  }

  final res = await Supabase.instance.client.rpc(
    'popular_authors',
    params: {'limit_count': 5},
  );

  return (res as List).cast<Map<String, dynamic>>().map((m) {
    final titles = (m['titles'] as List?)?.cast<String>() ?? const <String>[];
    return (name: m['author'] as String? ?? '', titles: titles);
  }).toList();
});
