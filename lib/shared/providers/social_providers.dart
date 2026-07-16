import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../models/book_memo.dart';
import '../models/comment.dart';
import '../models/other_reader_sentence.dart';
import '../repositories/comment_repository.dart';
import '../repositories/community_repository.dart';
import '../repositories/memo_repository.dart';
import '../repositories/notification_repository.dart';

/// 문장 댓글 (sentenceId 기준)
final commentsProvider = FutureProvider.autoDispose
    .family<List<Comment>, String>((ref, sentenceId) async {
      return ref.read(commentRepositoryProvider).fetchComments(sentenceId);
    });

/// 같은 책 다른 독자 문장 (isbn 기준, null이면 빈 목록)
final otherReadersProvider = FutureProvider.autoDispose
    .family<List<OtherReaderSentence>, String?>((ref, isbn) async {
      return ref
          .read(communityRepositoryProvider)
          .fetchOtherReaders(isbn: isbn);
    });

/// 책 메모 조회 키 (global_book_id 우선, 없으면 로컬 book_id)
typedef MemoKey = ({String? globalBookId, String? bookId});

final memosProvider = FutureProvider.autoDispose
    .family<List<BookMemo>, MemoKey>((ref, key) async {
      return ref
          .read(memoRepositoryProvider)
          .fetchMemos(globalBookId: key.globalBookId, bookId: key.bookId);
    });

/// 내 알림 목록
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) async {
    return ref.read(notificationRepositoryProvider).fetch();
  },
);
