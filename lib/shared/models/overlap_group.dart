/// 겹문장 비교 결과 유형
enum OverlapType {
  contained, // A가 B에 완전 포함 (또는 그 반대)
  partial,   // 토큰/LCS 기반 부분 일치
  none,      // 겹치지 않음
}

/// 원본 텍스트 내 하이라이트 구간
class HighlightRange {
  final int start;
  final int end;

  const HighlightRange(this.start, this.end);

  int get length => end - start;
}

/// 두 문장 간 비교 결과
class OverlapResult {
  final bool isOverlapping;
  final double ratio;        // 겹침 비율 (0.0 ~ 1.0)
  final OverlapType type;
  final String commonPhrase; // 공통 문구
  final List<HighlightRange> highlightsA; // 문장 A 내 하이라이트 구간
  final List<HighlightRange> highlightsB; // 문장 B 내 하이라이트 구간

  const OverlapResult({
    required this.isOverlapping,
    required this.ratio,
    required this.type,
    required this.commonPhrase,
    required this.highlightsA,
    required this.highlightsB,
  });

  const OverlapResult.none()
      : isOverlapping = false,
        ratio = 0.0,
        type = OverlapType.none,
        commonPhrase = '',
        highlightsA = const [],
        highlightsB = const [];
}

/// 겹문장 그룹 내 개별 멤버
class OverlapMember {
  final String sentenceId;
  final String content;
  final String username;
  final String bookTitle;
  final String? coverUrl;
  final double overlapRatio;
  final List<HighlightRange> highlights;

  const OverlapMember({
    required this.sentenceId,
    required this.content,
    required this.username,
    required this.bookTitle,
    this.coverUrl,
    required this.overlapRatio,
    required this.highlights,
  });
}

/// 겹문장 그룹 — 유사한 문장들의 묶음
class OverlapGroup {
  final String id;
  final String commonPhrase;         // 공통 핵심 문구
  final OverlapMember baseMember;    // 기준 문장 (가장 긴 원문)
  final List<OverlapMember> members; // 그룹 내 모든 멤버 (base 포함)

  const OverlapGroup({
    required this.id,
    required this.commonPhrase,
    required this.baseMember,
    required this.members,
  });

  int get memberCount => members.length;
}
