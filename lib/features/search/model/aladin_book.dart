import '../../../shared/models/reading_session.dart';

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

  const AladinBook({
    required this.title,
    required this.author,
    required this.publisher,
    this.coverUrl,
    this.isbn13,
    this.description,
    this.totalPages = 0,
    this.genre,
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
    );
  }

  // 알라딘 categoryName ("국내도서>소설/시/희곡>한국현대소설") → 정규화 장르
  static String? _parseGenre(String? categoryName) {
    if (categoryName == null || categoryName.isEmpty) return null;
    final parts = categoryName.split('>');
    if (parts.length < 2) return null;
    final seg = parts[1].trim();
    if (seg.contains('소설') || seg.contains('시/') || seg.contains('희곡')) return '소설';
    if (seg.contains('인문')) return '인문';
    if (seg.contains('자기계발')) return '자기계발';
    if (seg.contains('에세이')) return '에세이';
    if (seg.contains('과학')) return '과학';
    if (seg.contains('역사') || seg.contains('문화')) return '역사·문화';
    if (seg.contains('경제') || seg.contains('경영')) return '경제·경영';
    if (seg.contains('사회') || seg.contains('정치')) return '사회·정치';
    if (seg.contains('예술') || seg.contains('대중문화')) return '예술';
    if (seg.contains('종교') || seg.contains('철학')) return '철학·종교';
    if (seg.contains('컴퓨터') || seg.contains('IT')) return 'IT·컴퓨터';
    if (seg.contains('어린이') || seg.contains('청소년')) return '어린이·청소년';
    if (seg.contains('외국어') || seg.contains('언어')) return '외국어';
    return seg;
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
    );
  }
}
