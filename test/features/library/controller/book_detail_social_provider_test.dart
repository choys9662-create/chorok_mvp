import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/library/controller/book_detail_social_provider.dart';

void main() {
  test('normalizeSentence는 문자와 숫자를 남기고 공백을 정리한다', () {
    expect(normalizeSentence('  “산다는  것은!” Weird-123  '), '산다는 것은 weird 123');
  });

  test('여러 독자의 포함 문장을 하나의 생각이 모인 대목으로 묶는다', () {
    final thoughts = [
      _thought(
        id: 'sentence-1',
        userId: 'reader-1',
        sentence: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
        thought: '평범하다는 판단이 일방적으로 느껴졌다.',
        likes: 7,
        createdAt: DateTime(2026, 1, 1),
      ),
      _thought(
        id: 'sentence-2',
        userId: 'reader-2',
        sentence: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다. 그저 평범하다고 여겼다.',
        thought: '타인의 시선 안에서 한 사람이 납작해지는 순간이었다.',
        likes: 12,
        createdAt: DateTime(2026, 1, 2),
      ),
      _thought(
        id: 'sentence-short',
        userId: 'reader-3',
        sentence: '짧은 말',
        thought: '이 문장은 제외되어야 한다.',
        likes: 100,
        createdAt: DateTime(2026, 1, 3),
      ),
      _thought(
        id: 'sentence-other',
        userId: 'reader-4',
        sentence: '완전히 다른 장면에서 바람이 창문을 세차게 두드렸다.',
        thought: '다른 대목이다.',
        likes: 1,
        createdAt: DateTime(2026, 1, 4),
      ),
    ];

    final passages = buildDiscussedPassages(thoughts);

    expect(passages, hasLength(1));
    expect(passages.single.thoughtCount, 2);
    expect(passages.single.readerCount, 2);
    expect(passages.single.members, hasLength(2));
    expect(passages.single.previewThoughts.first.sentenceId, 'sentence-2');
    expect(passages.single.representativeText, contains('그저 평범하다고 여겼다'));
  });

  test('같은 독자가 남긴 비슷한 문장만으로는 대목을 만들지 않는다', () {
    final passages = buildDiscussedPassages([
      _thought(
        id: 'sentence-1',
        userId: 'reader-1',
        sentence: '산다는 것은 이상한 일이라고 그 웃음의 끝에 그녀는 생각한다.',
        thought: '첫 번째 생각',
        likes: 2,
        createdAt: DateTime(2026, 1, 1),
      ),
      _thought(
        id: 'sentence-2',
        userId: 'reader-1',
        sentence: '그 웃음의 끝에 그녀는 생각한다.',
        thought: '두 번째 생각',
        likes: 1,
        createdAt: DateTime(2026, 1, 2),
      ),
    ]);

    expect(passages, isEmpty);
  });

  test('공통 구간으로 묶고 최근 활동 순으로 최대 5개만 반환한다', () {
    const seeds = [
      'aaaaaaaaaaaa',
      'bbbbbbbbbbbb',
      'cccccccccccc',
      'dddddddddddd',
      'eeeeeeeeeeee',
      'ffffffffffff',
    ];
    final thoughts = <BookSocialThought>[];
    for (var index = 0; index < seeds.length; index++) {
      thoughts.addAll([
        _thought(
          id: 'sentence-$index-a',
          userId: 'reader-$index-a',
          sentence: '앞${seeds[index]}뒤',
          thought: '첫 번째 생각',
          likes: 1,
          createdAt: DateTime(2026, 1, index + 1),
        ),
        _thought(
          id: 'sentence-$index-b',
          userId: 'reader-$index-b',
          sentence: '다른앞${seeds[index]}다른뒤',
          thought: '두 번째 생각',
          likes: 1,
          createdAt: DateTime(2026, 1, index + 1, 1),
        ),
      ]);
    }

    final passages = buildDiscussedPassages(thoughts);

    expect(passages, hasLength(5));
    expect(passages.first.representativeText, contains('ffffffffffff'));
    expect(
      passages.any(
        (passage) => passage.representativeText.contains('aaaaaaaaaaaa'),
      ),
      isFalse,
    );
  });
}

BookSocialThought _thought({
  required String id,
  required String userId,
  required String sentence,
  required String thought,
  required int likes,
  required DateTime createdAt,
}) {
  return BookSocialThought(
    sentenceId: id,
    userId: userId,
    displayName: userId,
    username: userId,
    avatarUrl: null,
    sentence: sentence,
    thought: thought,
    pageNumber: 9,
    likeCount: likes,
    commentCount: 0,
    createdAt: createdAt,
    isFollowing: false,
    sourceType: BookSocialThoughtSource.sentence,
  );
}
