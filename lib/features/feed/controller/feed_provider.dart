import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/repositories/book_repository.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

FeedSentence _toFeedSentence(IsarChoseo c) => FeedSentence(
      id: c.choseoId,
      content: c.content,
      thought: c.myThought,
      bookTitle: c.bookTitle.isNotEmpty ? c.bookTitle : '알 수 없는 책',
      bookAuthor: c.bookAuthor,
      username: '나',
      savedAt: c.createdAt,
    );

class FeedNotifier extends AsyncNotifier<List<FeedSentence>> {
  @override
  Future<List<FeedSentence>> build() async {
    if (_useMock) return const [];
    return _load();
  }

  Future<List<FeedSentence>> _load() async {
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return const [];
    final all = await repo.getAllChoseo(limit: 50);
    return all.map(_toFeedSentence).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }
}

final feedProvider =
    AsyncNotifierProvider<FeedNotifier, List<FeedSentence>>(FeedNotifier.new);
