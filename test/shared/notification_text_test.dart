import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/models/app_notification.dart';

void main() {
  test('follow notification renders title with actor name', () {
    final n = AppNotification(
      id: '1',
      type: NotificationType.follow,
      actorName: '준석',
      isRead: false,
      createdAt: DateTime.now(),
    );
    expect(n.title, '준석님이 회원님을 팔로우해요');
  });

  test('like notification renders body with snippet', () {
    final n = AppNotification(
      id: '2',
      type: NotificationType.like,
      actorName: '민재',
      sentenceContent: '나는 채식주의자가 되기로 했다.',
      isRead: true,
      createdAt: DateTime.now(),
    );
    expect(n.title, '민재님이 내 문장을 좋아해요');
    expect(n.body, contains('채식주의자'));
  });

  test('overlap notification title mentions 겹침', () {
    final n = AppNotification(
      id: '3',
      type: NotificationType.overlap,
      actorName: '지현',
      isRead: false,
      createdAt: DateTime.now(),
    );
    expect(n.title, contains('같은 문장'));
  });

  test('fromRow maps actor display_name, falls back to username', () {
    final n = AppNotification.fromRow({
      'id': 'x',
      'type': 'comment',
      'sentence_id': 's1',
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
      'actor': {'id': 'a1', 'username': 'uname', 'display_name': ''},
      'sentence': {'content': '문장 내용'},
    });
    expect(n.actorName, 'uname');
    expect(n.type, NotificationType.comment);
    expect(n.body, '"문장 내용"');
  });
}
