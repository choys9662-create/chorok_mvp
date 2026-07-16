class SentenceNormalizer {
  SentenceNormalizer._();

  /// 겹침으로 인정하는 문장 단위의 최소 길이(정규화 후).
  ///
  /// 이보다 짧으면 "그렇다" 같은 흔한 표현이라 겹쳐도 의미가 없다.
  /// ponytail: 오탐이 잦으면 이 숫자만 올린다. 단, DB 트리거
  /// `notify_on_overlap` 에 같은 값이 박혀 있으므로 함께 움직여야 한다.
  static const int minOverlapUnitLength = 8;

  /// 겹침 비교에 쓸 문장 단위만 남긴다.
  static List<String> overlapUnits(String text) => tokenizeAndNormalize(
    text,
  ).where((u) => u.length >= minOverlapUnitLength).toList();

  static List<String> tokenize(String text) {
    return text
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String normalize(String sentence) {
    return sentence.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '').toLowerCase();
  }

  static List<String> tokenizeAndNormalize(String text) {
    return tokenize(text).map(normalize).where((s) => s.isNotEmpty).toList();
  }
}
