import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

final _bookReadingTimesProvider =
    FutureProvider.autoDispose<List<({String title, double hours})>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  if (repo == null) return const [];
  return repo.getBookReadingTimes();
});

List<({String name, Color color, int cells})> buildWaffleItems(
  BuildContext context,
) => [
  (name: '소설', color: context.appPrimaryAccent, cells: 60),
  (name: '문학', color: const Color(0xFF81C784), cells: 22),
  (name: '인문', color: const Color(0xFF2E7D32), cells: 11),
  (name: '자기계발', color: const Color(0xFFCCFF90), cells: 7),
];

// ─── 통계 탭 — 책별 비중 · 장르 비율 ──────────────────────────────────────
class LibraryStatsView extends ConsumerWidget {
  final ScrollController? scrollController;

  const LibraryStatsView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timesAsync = ref.watch(_bookReadingTimesProvider);
    final items = timesAsync.valueOrNull ?? const [];

    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        16,
        AppTheme.screenPadding,
        40,
      ),
      children: [
        const ChorokSectionHeader(title: '책별 독서 비중'),
        const SizedBox(height: AppTheme.spaceMD),
        BookTreemapWidget(items: items),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '장르 비율'),
        const SizedBox(height: AppTheme.spaceMD),
        WaffleChartWidget(genres: buildWaffleItems(context)),
      ],
    );
  }
}
