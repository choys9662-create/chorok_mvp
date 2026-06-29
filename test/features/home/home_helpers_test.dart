import 'package:chorok_app/features/home/widget/home_helpers.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dailyHomeMessage is stable for the same day and changes by date', () {
    const books = [
      Book(
        id: 'book-1',
        title: '파친코',
        author: '이민진',
        status: ReadingStatus.reading,
      ),
    ];

    final first = dailyHomeMessage(
      now: DateTime(2026, 6, 29, 9),
      weeklyMinutes: const [0, 0, 0, 0, 0, 0, 0],
      todayMinutes: 12,
      books: books,
    );
    final sameDay = dailyHomeMessage(
      now: DateTime(2026, 6, 29, 21),
      weeklyMinutes: const [0, 0, 0, 0, 0, 0, 0],
      todayMinutes: 12,
      books: books,
    );
    final nextDay = dailyHomeMessage(
      now: DateTime(2026, 6, 30, 9),
      weeklyMinutes: const [0, 0, 0, 0, 0, 0, 0],
      todayMinutes: 12,
      books: books,
    );

    expect(sameDay, first);
    expect(nextDay, isNot(first));
  });

  test(
    'dailyHomeMessage prefers a nearly finished book before generic nudge',
    () {
      final message = dailyHomeMessage(
        now: DateTime(2026, 6, 29),
        weeklyMinutes: const [0, 0, 0, 0, 0, 0, 0],
        todayMinutes: 0,
        books: const [
          Book(
            id: 'book-1',
            title: '채식주의자',
            author: '한강',
            status: ReadingStatus.reading,
            totalPages: 200,
            currentPage: 180,
          ),
        ],
      );

      expect(message, '완독까지 조금만');
    },
  );

  test('sessionEntryPrompt uses progress context', () {
    final message = sessionEntryPrompt(
      bookTitle: '파친코',
      currentPage: 650,
      totalPages: 688,
      now: DateTime(2026, 6, 29),
    );

    expect([
      '마지막에 어떤 문장이 남을까요?',
      '이 책은 어떤 감정으로 닫힐까요?',
      '끝까지 읽으면 무엇이 달라질까요?',
    ], contains(message));
  });

  test('sessionEntryPrompt prefers popular sentence thoughts', () {
    final message = sessionEntryPrompt(
      bookTitle: '파친코',
      currentPage: 10,
      totalPages: 688,
      now: DateTime(2026, 6, 29),
      seeds: const [
        SessionPromptSeed(
          sentence: '고향이라는 말은 늘 도착보다 떠남에 가까웠다.',
          thought: '떠난 뒤에야 고향이 선명해진다',
          weight: 30,
        ),
      ],
    );

    expect(message, '“떠난 뒤에야 고향이 선명해진다” 이 생각은 어디서 시작됐을까요?');
  });
}
