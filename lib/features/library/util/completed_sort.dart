import '../../../shared/models/reading_session.dart';

/// 완독 화면 정렬 기준. Book 모델에 있는 필드로 가능한 것만 둔다.
/// ponytail: 신작 순(출간일 필드 없음)·인기 순(global_books 카운트 미집계)·
/// 친구가 많이 읽은 순(팔로우 그래프 집계 필요)은 데이터가 생기면 추가.
enum CompletedSort {
  recent('최근에 완독한 순'),
  title('가나다 순'),
  pages('페이지 순');

  final String label;
  const CompletedSort(this.label);
}

int compareCompletedBooks(CompletedSort sort, Book a, Book b) {
  switch (sort) {
    case CompletedSort.recent:
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    case CompletedSort.title:
      return a.title.compareTo(b.title);
    case CompletedSort.pages:
      return b.totalPages.compareTo(a.totalPages);
  }
}
