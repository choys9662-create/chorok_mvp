import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/features/profile/util/sentence_row_parser.dart';

void main() {
  group('parseSentenceRow', () {
    test('global_books 우선으로 책 정보 추출', () {
      final row = {
        'id': 's1',
        'content': '문장 내용',
        'thought': '내 생각',
        'created_at': '2026-05-01T10:00:00Z',
        'profiles': {'username': 'reader', 'display_name': '독자'},
        'books': {'title': '로컬책', 'author': '로컬저자', 'cover_url': null},
        'global_books': {
          'title': '글로벌책',
          'author': '글로벌저자',
          'cover_url': 'http://cover',
        },
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.id, 's1');
      expect(s.content, '문장 내용');
      expect(s.thought, '내 생각');
      expect(s.bookTitle, '글로벌책');
      expect(s.bookAuthor, '글로벌저자');
      expect(s.coverUrl, 'http://cover');
      expect(s.username, '독자');
    });

    test('global_books 없으면 books 사용', () {
      final row = {
        'id': 's2',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'books': {'title': '로컬책', 'author': '로컬저자'},
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.bookTitle, '로컬책');
      expect(s.bookAuthor, '로컬저자');
    });

    test('profiles 없으면 fallbackUsername 사용', () {
      final row = {
        'id': 's3',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
      };
      final s = parseSentenceRow(row, fallbackUsername: '용성');
      expect(s.username, '용성');
      expect(s.bookTitle, '알 수 없는 책');
    });

    test('display_name 없으면 username 사용', () {
      final row = {
        'id': 's4',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'profiles': {'username': 'janice', 'display_name': null},
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.username, 'janice');
    });

    test('sentence_likes count 추출', () {
      final row = {
        'id': 's5',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'sentence_likes': [
          {'count': 7},
        ],
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.empathyCount, 7);
    });

    test('잘못된 created_at은 현재 시각으로 폴백', () {
      final row = {'id': 's6', 'content': 'c', 'created_at': 'invalid'};
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.savedAt, isA<DateTime>());
    });
  });
}
