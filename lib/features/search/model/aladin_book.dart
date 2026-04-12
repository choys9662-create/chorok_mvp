import '../../../shared/models/reading_session.dart';

/// 알라딘 Open API 검색 결과 단일 책 모델
class AladinBook {
  final String title;
  final String author;
  final String publisher;
  final String? coverUrl;
  final String? isbn13;
  final String? description;

  const AladinBook({
    required this.title,
    required this.author,
    required this.publisher,
    this.coverUrl,
    this.isbn13,
    this.description,
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

    return AladinBook(
      title: title.isEmpty ? (json['title'] as String? ?? '') : title,
      author: author.isEmpty ? rawAuthor : author,
      publisher: json['publisher'] as String? ?? '',
      coverUrl: json['cover'] as String?,
      isbn13: json['isbn13'] as String?,
      description: json['description'] as String?,
    );
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
    );
  }
}
