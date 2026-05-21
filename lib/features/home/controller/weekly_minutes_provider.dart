import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../shared/repositories/book_repository.dart';
import '../widget/home_helpers.dart';

final weeklyMinutesProvider = FutureProvider.autoDispose<List<int>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  if (repo == null) return kUseMock ? kWeeklyMinutes : List.filled(7, 0);
  return repo.getWeeklyMinutes();
});
