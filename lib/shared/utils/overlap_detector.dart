import '../models/overlap_group.dart';

/// 겹문장 식별 알고리즘
///
/// 두 문장 간의 포함 관계와 부분 일치를 3단계로 분석한다:
///   1단계: 정규화 후 포함(containment) 검사 — O(m + n)
///   2단계: 토큰 기반 Jaccard 유사도 — O(m + n)
///   3단계: 최장 공통 부분 문자열(LCS) — O(m × n)
///
/// 성능 분석:
///   - N개 문장 간 전수 비교: O(N²) 쌍
///   - 각 쌍의 비교: 1~2단계에서 조기 결정되면 O(L),
///     3단계까지 가면 O(L²) (L = 평균 문장 길이)
///   - 일반적 사용(N ≤ 500, L ≤ 100): 실시간 처리 가능
///   - 대규모 데이터(N > 1000): 해시 기반 사전 필터링 권장
class OverlapDetector {
  static const double defaultThreshold = 0.7;

  OverlapDetector._();

  // ─── 공개 API ──────────────────────────────────────────────────

  /// 두 문장을 비교하여 겹침 결과를 반환한다.
  static OverlapResult compare(
    String a,
    String b, {
    double threshold = defaultThreshold,
  }) {
    if (a.isEmpty || b.isEmpty) return const OverlapResult.none();

    final normA = normalize(a);
    final normB = normalize(b);

    if (normA.isEmpty || normB.isEmpty) return const OverlapResult.none();

    // ── 1단계: 완전 일치 ──────────────────────────────────────────
    if (normA == normB) {
      return OverlapResult(
        isOverlapping: true,
        ratio: 1.0,
        type: OverlapType.contained,
        commonPhrase: a.length >= b.length ? a : b,
        highlightsA: [HighlightRange(0, a.length)],
        highlightsB: [HighlightRange(0, b.length)],
      );
    }

    // ── 2단계: 포함 관계 검사 (짧은 문장이 긴 문장에 포함) ────────
    final (shorter, longer, shortOrig, longOrig) = normA.length <= normB.length
        ? (normA, normB, a, b)
        : (normB, normA, b, a);

    if (longer.contains(shorter)) {
      final ratio = shorter.length / longer.length;
      final hlLong = _findInOriginal(longOrig, shortOrig);
      final isAB = normA.length <= normB.length;

      return OverlapResult(
        isOverlapping: true,
        ratio: ratio.clamp(0.0, 1.0),
        type: OverlapType.contained,
        commonPhrase: shortOrig,
        highlightsA: isAB
            ? [HighlightRange(0, a.length)]
            : (hlLong != null ? [hlLong] : [HighlightRange(0, a.length)]),
        highlightsB: isAB
            ? (hlLong != null ? [hlLong] : [HighlightRange(0, b.length)])
            : [HighlightRange(0, b.length)],
      );
    }

    // ── 3단계: 토큰 기반 유사도 ───────────────────────────────────
    final tokenRatio = tokenOverlapRatio(a, b);

    if (tokenRatio >= threshold) {
      final lcs = longestCommonSubstring(a, b);
      return OverlapResult(
        isOverlapping: true,
        ratio: tokenRatio,
        type: OverlapType.partial,
        commonPhrase: lcs.substring,
        highlightsA: lcs.substring.isNotEmpty
            ? [HighlightRange(lcs.startA, lcs.endA)]
            : [],
        highlightsB: lcs.substring.isNotEmpty
            ? [HighlightRange(lcs.startB, lcs.endB)]
            : [],
      );
    }

    // ── 4단계: LCS 폴백 (토큰 비율은 낮지만 긴 공통 부분 문자열 존재) ──
    final lcs = longestCommonSubstring(a, b);
    final lcsRatio = _lcsRatioToShorter(lcs.length, a.length, b.length);

    if (lcsRatio >= threshold) {
      return OverlapResult(
        isOverlapping: true,
        ratio: lcsRatio,
        type: OverlapType.partial,
        commonPhrase: lcs.substring,
        highlightsA: [HighlightRange(lcs.startA, lcs.endA)],
        highlightsB: [HighlightRange(lcs.startB, lcs.endB)],
      );
    }

    return const OverlapResult.none();
  }

  /// 문장 목록에서 겹문장 그룹을 추출한다.
  ///
  /// Union-Find로 O(N²) 쌍을 비교한 뒤 그룹핑한다.
  /// 각 그룹의 base는 가장 긴 원문 문장으로 선정된다.
  static List<OverlapGroup> findGroups(
    List<SentenceEntry> sentences, {
    double threshold = defaultThreshold,
  }) {
    final n = sentences.length;
    if (n < 2) return [];

    // Union-Find
    final parent = List<int>.generate(n, (i) => i);

    int find(int x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]];
        x = parent[x];
      }
      return x;
    }

    void union(int x, int y) {
      final px = find(x);
      final py = find(y);
      if (px != py) parent[px] = py;
    }

    // 쌍별 비교 결과 캐시
    final results = <(int, int), OverlapResult>{};

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        final result = compare(
          sentences[i].content,
          sentences[j].content,
          threshold: threshold,
        );
        if (result.isOverlapping) {
          union(i, j);
          results[(i, j)] = result;
        }
      }
    }

    // 그룹핑
    final groupMap = <int, List<int>>{};
    for (int i = 0; i < n; i++) {
      groupMap.putIfAbsent(find(i), () => []).add(i);
    }

    // 2명 이상인 그룹만 반환
    final groups = <OverlapGroup>[];

    for (final entry in groupMap.entries) {
      final indices = entry.value;
      if (indices.length < 2) continue;

      // 가장 긴 문장을 base로 선정
      indices.sort((a, b) =>
          sentences[b].content.length.compareTo(sentences[a].content.length));
      final baseIdx = indices.first;
      final baseSentence = sentences[baseIdx];

      // 공통 문구 추출: base와 각 멤버의 LCS 중 최장 선택
      String commonPhrase = '';
      final members = <OverlapMember>[];

      for (final idx in indices) {
        final s = sentences[idx];
        if (idx == baseIdx) {
          members.add(OverlapMember(
            sentenceId: s.id,
            content: s.content,
            username: s.username,
            bookTitle: s.bookTitle,
            overlapRatio: 1.0,
            highlights: [HighlightRange(0, s.content.length)],
          ));
          continue;
        }

        final key = baseIdx < idx ? (baseIdx, idx) : (idx, baseIdx);
        final result = results[key];

        if (result != null) {
          if (result.commonPhrase.length > commonPhrase.length) {
            commonPhrase = result.commonPhrase;
          }

          final hl = baseIdx < idx ? result.highlightsB : result.highlightsA;
          members.add(OverlapMember(
            sentenceId: s.id,
            content: s.content,
            username: s.username,
            bookTitle: s.bookTitle,
            overlapRatio: result.ratio,
            highlights: hl,
          ));
        }
      }

      if (commonPhrase.isEmpty) {
        commonPhrase = baseSentence.content;
      }

      groups.add(OverlapGroup(
        id: 'group_${entry.key}',
        commonPhrase: commonPhrase,
        baseMember: members.first,
        members: members,
      ));
    }

    return groups;
  }

  // ─── 텍스트 전처리 ─────────────────────────────────────────────

  /// 비교용 텍스트 정규화
  /// - 따옴표, 구두점, 공백 제거
  /// - 소문자 변환 (영문 혼합 시)
  static String normalize(String text) {
    return text
        .replaceAll(RegExp('[\u201C\u201D\u2018\u2019""\'\']+'), '') // 따옴표
        .replaceAll(RegExp(r'[.,!?;:…—\-–()\[\]{}]'), '')           // 구두점
        .replaceAll(RegExp(r'\s+'), '')                              // 공백
        .toLowerCase();
  }

  /// 의미 단위 토큰 분리
  static List<String> tokenize(String text) {
    return text
        .replaceAll(RegExp('[\u201C\u201D\u2018\u2019""\'\'.,!?;:…\u2014\\-\\u2013()\\[\\]{}]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length > 1) // 1글자 조사/접속사 제외
        .map((t) => t.toLowerCase())
        .toList();
  }

  // ─── 토큰 기반 유사도 ──────────────────────────────────────────

  /// 두 문장의 토큰 기반 겹침 비율 (수정 Jaccard)
  ///
  /// 짧은 쪽 토큰 집합 대비 교집합 비율을 반환한다.
  /// 이렇게 해야 "A가 B에 포함"되는 경우에도 높은 비율이 나온다.
  static double tokenOverlapRatio(String a, String b) {
    final tokensA = tokenize(a).toSet();
    final tokensB = tokenize(b).toSet();
    if (tokensA.isEmpty || tokensB.isEmpty) return 0.0;

    final intersection = tokensA.intersection(tokensB);
    final smaller =
        tokensA.length <= tokensB.length ? tokensA.length : tokensB.length;

    return intersection.length / smaller;
  }

  // ─── LCS (최장 공통 부분 문자열) ───────────────────────────────

  /// DP 기반 최장 공통 부분 문자열
  ///
  /// 시간 복잡도: O(m × n)
  /// 공간 복잡도: O(min(m, n)) — 2-row 롤링 배열 최적화
  static LcsResult longestCommonSubstring(String a, String b) {
    if (a.isEmpty || b.isEmpty) return LcsResult.empty;

    // 공간 최적화: 짧은 쪽을 내부 루프로
    final (s1, s2, swapped) =
        a.length <= b.length ? (a, b, false) : (b, a, true);
    final m = s1.length;
    final n = s2.length;

    var prev = List<int>.filled(m + 1, 0);
    var curr = List<int>.filled(m + 1, 0);

    int maxLen = 0;
    int endPos1 = 0;
    int endPos2 = 0;

    for (int j = 1; j <= n; j++) {
      for (int i = 1; i <= m; i++) {
        if (s1[i - 1].toLowerCase() == s2[j - 1].toLowerCase()) {
          curr[i] = prev[i - 1] + 1;
          if (curr[i] > maxLen) {
            maxLen = curr[i];
            endPos1 = i;
            endPos2 = j;
          }
        } else {
          curr[i] = 0;
        }
      }
      final temp = prev;
      prev = curr;
      curr = temp;
      for (int i = 0; i <= m; i++) {
        curr[i] = 0;
      }
    }

    if (maxLen == 0) return LcsResult.empty;

    final startInS1 = endPos1 - maxLen;
    final startInS2 = endPos2 - maxLen;

    return LcsResult(
      substring: s1.substring(startInS1, endPos1),
      length: maxLen,
      startA: swapped ? startInS2 : startInS1,
      endA: swapped ? endPos2 : endPos1,
      startB: swapped ? startInS1 : startInS2,
      endB: swapped ? endPos1 : endPos2,
    );
  }

  // ─── 내부 헬퍼 ─────────────────────────────────────────────────

  /// 원본 텍스트에서 검색 문자열의 위치를 찾는다.
  /// 정규화 후 비교하되 원본 인덱스를 반환한다.
  static HighlightRange? _findInOriginal(String original, String search) {
    // 1차: 원본에서 직접 검색
    final directIdx = original.indexOf(search);
    if (directIdx >= 0) {
      return HighlightRange(directIdx, directIdx + search.length);
    }

    // 2차: 구두점 제거 후 매핑
    final normSearch = normalize(search);
    final origChars = <int>[]; // 원본 인덱스 매핑
    final buf = StringBuffer();

    for (int i = 0; i < original.length; i++) {
      final ch = original[i];
      final normCh = ch
          .replaceAll(RegExp('[\u201C\u201D\u2018\u2019""\'\'.,!?;:…\u2014\\-\u2013()\\[\\]{}\\s]'), '');
      if (normCh.isNotEmpty) {
        buf.write(normCh.toLowerCase());
        origChars.add(i);
      }
    }

    final normOrig = buf.toString();
    final idx = normOrig.indexOf(normSearch);
    if (idx >= 0 && idx + normSearch.length <= origChars.length) {
      return HighlightRange(
        origChars[idx],
        origChars[idx + normSearch.length - 1] + 1,
      );
    }

    return null;
  }

  /// LCS 길이의 짧은 쪽 대비 비율
  static double _lcsRatioToShorter(int lcsLen, int lenA, int lenB) {
    final shorter = lenA < lenB ? lenA : lenB;
    return shorter == 0 ? 0.0 : lcsLen / shorter;
  }
}

/// LCS 계산 결과
class LcsResult {
  final String substring;
  final int length;
  final int startA;
  final int endA;
  final int startB;
  final int endB;

  const LcsResult({
    required this.substring,
    required this.length,
    required this.startA,
    required this.endA,
    required this.startB,
    required this.endB,
  });

  static const LcsResult empty = LcsResult(
    substring: '',
    length: 0,
    startA: 0,
    endA: 0,
    startB: 0,
    endB: 0,
  );
}

/// findGroups에 전달할 문장 엔트리
class SentenceEntry {
  final String id;
  final String content;
  final String username;
  final String bookTitle;

  const SentenceEntry({
    required this.id,
    required this.content,
    required this.username,
    required this.bookTitle,
  });
}
