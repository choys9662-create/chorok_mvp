import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

final _bookReadingTimesProvider =
    FutureProvider.autoDispose<List<({String title, double hours})>>((ref) async {
  if (kIsWeb) return _loadBookReadingTimesFromSupabase();
  final repo = ref.watch(bookRepositoryProvider);
  if (repo == null) return const [];
  return repo.getBookReadingTimes();
});

Future<List<({String title, double hours})>>
    _loadBookReadingTimesFromSupabase() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const [];
  final rows = await client
      .from('reading_sessions')
      .select('duration_seconds, books(title)')
      .eq('user_id', userId);
  final byTitle = <String, int>{};
  for (final row in rows as List) {
    final map = row as Map<String, dynamic>;
    final book = map['books'] as Map<String, dynamic>?;
    final title = book?['title'] as String?;
    if (title == null || title.isEmpty) continue;
    final dur = (map['duration_seconds'] as num?)?.toInt() ?? 0;
    byTitle[title] = (byTitle[title] ?? 0) + dur;
  }
  final list = byTitle.entries
      .map((e) => (title: e.key, hours: e.value / 3600.0))
      .toList()
    ..sort((a, b) => b.hours.compareTo(a.hours));
  return list;
}

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
        if (kUseMock) ...[
          const SizedBox(height: AppTheme.spaceXL),
          const ChorokSectionHeader(title: '장르 비율'),
          const SizedBox(height: AppTheme.spaceMD),
          WaffleChartWidget(genres: buildWaffleItems(context)),
        ],
      ],
    );
  }
}
