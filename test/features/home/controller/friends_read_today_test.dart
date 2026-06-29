import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/features/home/controller/friends_read_today_provider.dart';
import 'package:chorok_app/shared/models/user_profile.dart';

void main() {
  const a = UserProfile(id: 'a', username: 'a', displayName: '에이');
  const b = UserProfile(id: 'b', username: 'b', displayName: '비');
  final byId = {'a': a, 'b': b};

  test('친구별 합산 + 대표 책(최근) + 많이 읽은 순 정렬', () {
    // rows는 ended_at desc 가정. a: 20+10분=30분, 대표=최근 책 '신간'. b: 50분.
    final rows = <Map<String, dynamic>>[
      {
        'user_id': 'a',
        'duration_seconds': 1200,
        'books': {'title': '신간', 'cover_url': 'x'},
      },
      {
        'user_id': 'b',
        'duration_seconds': 3000,
        'books': {'title': '비책', 'cover_url': null},
      },
      {
        'user_id': 'a',
        'duration_seconds': 600,
        'books': {'title': '구간', 'cover_url': 'y'},
      },
    ];

    final out = aggregateFriendReads(rows, byId);

    expect(out.map((e) => e.friend.id).toList(), ['b', 'a']); // 50분 > 30분
    final aRow = out.firstWhere((e) => e.friend.id == 'a');
    expect(aRow.seconds, 1800); // 30분
    expect(aRow.bookTitle, '신간'); // 가장 최근 세션의 책
    expect(aRow.coverUrl, 'x');
  });

  test('맞팔 아닌 user_id는 제외, 책 null이면 폴백 제목', () {
    final rows = <Map<String, dynamic>>[
      {'user_id': 'c', 'duration_seconds': 9999, 'books': null}, // 비맞팔
      {'user_id': 'b', 'duration_seconds': 300, 'books': null},
    ];

    final out = aggregateFriendReads(rows, byId);

    expect(out.length, 1);
    expect(out.single.friend.id, 'b');
    expect(out.single.bookTitle, '읽은 책');
  });
}
