class SentenceNormalizer {
  SentenceNormalizer._();

  static List<String> tokenize(String text) {
    return text
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static String normalize(String sentence) {
    return sentence
        .replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '')
        .toLowerCase();
  }

  static List<String> tokenizeAndNormalize(String text) {
    return tokenize(text)
        .map(normalize)
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
