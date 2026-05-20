import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/features/home/controller/recommended_books_provider.dart';

void main() {
  // ── extractAuthorFromSentences ─────────────────────────────────────────
  group('extractAuthorFromSentences', () {
    test('가장 많은 문장이 달린 책의 저자 반환', () {
      final sentences = [
        {'book_id': 'b1', 'books': {'author': '한강', 'title': '채식주의자'}},
        {'book_id': 'b1', 'books': {'author': '한강', 'title': '채식주의자'}},
        {'book_id': 'b2', 'books': {'author': '손원평', 'title': '아몬드'}},
      ];
      expect(extractAuthorFromSentences(sentences), '한강');
    });

    test('book_id 없는 문장은 무시', () {
      final sentences = [
        {'book_id': null, 'books': null},
        {'book_id': 'b1', 'books': {'author': '김영하', 'title': '살인자의 기억법'}},
      ];
      expect(extractAuthorFromSentences(sentences), '김영하');
    });

    test('문장 없으면 null', () {
      expect(extractAuthorFromSentences([]), isNull);
    });
  });

  // ── extractTopBookTitleFromSentences ──────────────────────────────────
  group('extractTopBookTitleFromSentences', () {
    test('가장 많은 문장이 달린 책 제목 반환', () {
      final sentences = [
        {'book_id': 'b1', 'books': {'author': '한강', 'title': '채식주의자'}},
        {'book_id': 'b1', 'books': {'author': '한강', 'title': '채식주의자'}},
        {'book_id': 'b2', 'books': {'author': '손원평', 'title': '아몬드'}},
      ];
      expect(extractTopBookTitleFromSentences(sentences), '채식주의자');
    });

    test('문장 없으면 null', () {
      expect(extractTopBookTitleFromSentences([]), isNull);
    });
  });

  // ── extractKeywordsFromSentences ──────────────────────────────────────
  group('extractKeywordsFromSentences', () {
    test('빈도 순으로 상위 3개 반환', () {
      final sentences = [
        {'content': '사랑 사랑 사랑 희망 희망 고통'},
        {'content': '사랑 고통 고통'},
      ];
      final result = extractKeywordsFromSentences(sentences);
      expect(result[0], '사랑'); // 4회
      expect(result[1], '고통'); // 3회
      expect(result[2], '희망'); // 2회
    });

    test('불용어 제외', () {
      final sentences = [
        {'content': '그리고 또한 하지만 사랑 사랑'},
      ];
      final result = extractKeywordsFromSentences(sentences);
      expect(result, ['사랑']);
    });

    test('2자 미만 토큰 제외', () {
      final sentences = [
        {'content': '나 그 이 사랑'},
      ];
      final result = extractKeywordsFromSentences(sentences);
      expect(result, ['사랑']);
    });

    test('문장 없으면 빈 리스트', () {
      expect(extractKeywordsFromSentences([]), isEmpty);
    });
  });
}
