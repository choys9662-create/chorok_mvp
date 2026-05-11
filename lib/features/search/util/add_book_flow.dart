import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../controller/book_search_controller.dart';
import '../model/aladin_book.dart';

/// 상태 enum → 사용자 라벨
String readingStatusLabel(ReadingStatus status) => switch (status) {
  ReadingStatus.reading => '읽는 중',
  ReadingStatus.completed => '읽음',
  ReadingStatus.wantToRead => '읽고 싶어요',
};

/// 책을 서재에 추가하고, 페이지 수가 없으면 ISBN 으로 비동기 보강
///
/// 반환값: 실제로 새로 추가됐는지 여부 (false면 이미 서재에 있던 책)
bool addBookAndFetchPages(
  WidgetRef ref,
  AladinBook book,
  ReadingStatus status,
) {
  final added = ref.read(libraryProvider.notifier).addBook(book.toBook(status));
  if (added && book.totalPages == 0 && (book.isbn13?.isNotEmpty ?? false)) {
    unawaited(
      fetchTotalPagesByIsbn(book.isbn13!).then((pages) {
        if (pages == null) return;
        ref
            .read(libraryProvider.notifier)
            .updateTotalPages(book.isbn13!, pages);
      }),
    );
  }
  return added;
}
