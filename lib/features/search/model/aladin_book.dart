import '../../../shared/models/reading_session.dart';
import '../../../shared/utils/book_genre.dart';

/// 알라딘 Open API 검색 결과 단일 책 모델
class AladinBook {
  final String title;
  final String author;
  final String publisher;
  final String? coverUrl;
  final String? isbn13;
  final String? description;
  final int totalPages;
  final String? genre;

  /// 알라딘 원본 저자 문자열 — "한강 (지은이), 데버라 스미스 (옮긴이)" 형태.
  /// 책 정보 화면의 저자·옮긴이 행 파싱용. [author]는 첫 저자명만 담는다.
  final String? rawAuthor;

  /// 알라딘 원본 출판일 — "2022-03-28" 형태(ISO 날짜). 파싱 실패해도 무시.
  final String? pubDate;

  const AladinBook({
    required this.title,
    required this.author,
    required this.publisher,
    this.coverUrl,
    this.isbn13,
    this.description,
    this.totalPages = 0,
    this.genre,
    this.rawAuthor,
    this.pubDate,
  });

  factory AladinBook.fromJson(Map<String, dynamic> json) {
    // 부제 제거 (예: "채식주의자 - 한강 소설" → "채식주의자")
    final rawTitle = json['title'] as String? ?? '';
    final title = rawTitle.contains(' - ')
        ? rawTitle.substring(0, rawTitle.lastIndexOf(' - ')).trim()
        : rawTitle.trim();

    // 저자 정제 (예: "한강 (지은이), 홍길동 (옮긴이)" → "한강")
    final rawAuthor = json['author'] as String? ?? '';
    final author = rawAuthor
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .split(',')
        .first
        .trim();

    final subInfo = json['subInfo'] as Map<String, dynamic>?;
    final totalPages = (subInfo?['itemPage'] as num?)?.toInt() ?? 0;

    return AladinBook(
      title: title.isEmpty ? (json['title'] as String? ?? '') : title,
      author: author.isEmpty ? rawAuthor : author,
      publisher: json['publisher'] as String? ?? '',
      coverUrl: json['cover'] as String?,
      isbn13: json['isbn13'] as String?,
      description: json['description'] as String?,
      totalPages: totalPages,
      genre: _parseGenre(json['categoryName'] as String?),
      rawAuthor: rawAuthor.trim().isEmpty ? null : rawAuthor.trim(),
      pubDate: json['pubDate'] as String?,
    );
  }

  // 알라딘 categoryName ("국내도서>소설/시/희곡>한국현대소설") → 표준 장르.
  // 가장 구체적인(뒤쪽) 세그먼트부터 분류해 공통 버킷("소설/시/희곡")의
  // 모호함을 피한다. 어느 세그먼트도 매칭 안 되면 null(미분류).
  static String? _parseGenre(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) return null;
    final parts = categoryName
        .split(RegExp(r'[>/]'))
        .map((p) => p.trim())
        .toList();
    for (final seg in parts.reversed) {
      final genre = classifyBookGenre(seg);
      if (genre != unclassifiedGenre) return genre;
    }
    return null;
  }

  /// 앱의 Book 모델로 변환
  Book toBook(ReadingStatus status) {
    return Book(
      id: isbn13 != null && isbn13!.isNotEmpty
          ? isbn13!
          : 'aladin_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      author: author,
      coverUrl: coverUrl,
      isbn: isbn13,
      status: status,
      totalPages: totalPages,
      genre: genre,
      description: description,
    );
  }
}
