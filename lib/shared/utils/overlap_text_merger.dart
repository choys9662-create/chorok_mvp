import '../models/overlap_group.dart';

class MergedOverlapText {
  final String content;
  final HighlightRange highlight;

  const MergedOverlapText({required this.content, required this.highlight});
}

/// 두 발췌문의 공통 구간을 한 번만 두고, 양쪽의 더 긴 앞뒤 문맥을 붙인다.
MergedOverlapText mergeOverlapText({
  required String mine,
  required String neighbor,
  required OverlapResult result,
}) {
  if (result.highlightsA.isEmpty || result.highlightsB.isEmpty) {
    return _fallback(mine, neighbor, result.commonPhrase);
  }

  final myRange = result.highlightsA.first;
  final neighborRange = result.highlightsB.first;
  if (!_isValid(myRange, mine) || !_isValid(neighborRange, neighbor)) {
    return _fallback(mine, neighbor, result.commonPhrase);
  }

  final myPrefix = mine.substring(0, myRange.start);
  final neighborPrefix = neighbor.substring(0, neighborRange.start);
  final mySuffix = mine.substring(myRange.end);
  final neighborSuffix = neighbor.substring(neighborRange.end);
  final prefix = _longerContext(myPrefix, neighborPrefix);
  final suffix = _longerContext(mySuffix, neighborSuffix);
  final common = result.commonPhrase.trim().isNotEmpty
      ? result.commonPhrase.trim()
      : neighbor.substring(neighborRange.start, neighborRange.end);
  final content = '$prefix$common$suffix';

  return MergedOverlapText(
    content: content,
    highlight: HighlightRange(prefix.length, prefix.length + common.length),
  );
}

bool _isValid(HighlightRange range, String text) =>
    range.start >= 0 && range.end >= range.start && range.end <= text.length;

String _longerContext(String a, String b) =>
    a.trim().length >= b.trim().length ? a : b;

MergedOverlapText _fallback(String mine, String neighbor, String commonPhrase) {
  final content = mine.length >= neighbor.length ? mine : neighbor;
  final common = commonPhrase.trim();
  final start = common.isEmpty ? -1 : content.indexOf(common);
  return MergedOverlapText(
    content: content,
    highlight: start < 0
        ? const HighlightRange(0, 0)
        : HighlightRange(start, start + common.length),
  );
}
