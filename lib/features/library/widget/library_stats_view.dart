import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/utils/book_genre.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

final genreReadingTimesProvider =
    FutureProvider.autoDispose<List<({String label, double hours})>>((
      ref,
    ) async {
      if (kUseMock) {
        return _buildGenreReadingTimesFromBooks(ref.watch(libraryProvider));
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return const [];
      return _loadGenreReadingTimesFromSupabase(userId);
    });

/// 다른 사용자(팔로우한 사람)의 장르별 독서시간 — 항상 Supabase.
final _genreReadingTimesByUserProvider = FutureProvider.autoDispose
    .family<List<({String label, double hours})>, String>((ref, userId) async {
      return _loadGenreReadingTimesFromSupabase(userId);
    });

Future<List<({String label, double hours})>> _loadGenreReadingTimesFromSupabase(
  String userId,
) async {
  final client = Supabase.instance.client;
  // 장르는 books에 컬럼이 없고 global_books.category(알라딘 분류)에 있다.
  final rows = await client
      .from('reading_sessions')
      .select('duration_seconds, books(title, global_books(category))')
      .eq('user_id', userId);
  final byGenre = <String, int>{};
  for (final map in rows) {
    final book = map['books'] as Map<String, dynamic>?;
    final globalBook = book?['global_books'] as Map<String, dynamic>?;
    final genre = _genreLabel(
      globalBook?['category'] as String?,
      fallbackTitle: book?['title'] as String?,
    );
    final dur = (map['duration_seconds'] as num?)?.toInt() ?? 0;
    byGenre[genre] = (byGenre[genre] ?? 0) + dur;
  }
  final list =
      byGenre.entries
          .map((e) => (label: e.key, hours: e.value / 3600.0))
          .toList()
        ..sort((a, b) => b.hours.compareTo(a.hours));
  return list;
}

List<({String label, double hours})> _buildGenreReadingTimesFromBooks(
  List<Book> books,
) {
  final byGenre = <String, double>{};
  for (final book in books) {
    if (book.totalReadingHours <= 0) continue;
    final genre = _genreLabel(book.genre, fallbackTitle: book.title);
    byGenre[genre] = (byGenre[genre] ?? 0) + book.totalReadingHours;
  }
  final list =
      byGenre.entries.map((e) => (label: e.key, hours: e.value)).toList()
        ..sort((a, b) => b.hours.compareTo(a.hours));
  return list;
}

String _genreLabel(String? genre, {String? fallbackTitle}) {
  final byGenre = classifyBookGenre(genre);
  if (byGenre != unclassifiedGenre) return byGenre;
  return _genreFromKnownTitle(fallbackTitle) ?? unclassifiedGenre;
}

// 장르 정보가 비어 있는 소수의 알려진 책만 제목으로 보정한다.
// (그 외에는 '소설'로 단정하지 않고 미분류로 둔다)
String? _genreFromKnownTitle(String? title) {
  final t = title?.trim();
  if (t == null || t.isEmpty) return null;
  if (t.contains('지구 끝의 온실')) return 'SF';
  if (t.contains('파친코')) return '역사소설';
  if (t.contains('달러구트')) return '판타지';
  return null;
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
  final bool fullScreen;
  final bool embedded;

  /// 다른 사용자의 통계를 볼 때 그 사용자 id. null이면 내 통계.
  final String? userId;

  const LibraryStatsView({
    super.key,
    this.scrollController,
    this.fullScreen = false,
    this.embedded = false,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timesAsync = userId != null
        ? ref.watch(_genreReadingTimesByUserProvider(userId!))
        : ref.watch(genreReadingTimesProvider);
    if (embedded) {
      final items = timesAsync.valueOrNull ?? const [];
      return BookTreemapWidget(items: items, height: 260);
    }

    if (fullScreen) {
      return timesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const _GenreReadingTimesEmpty(message: '독서 취향을 불러오지 못했어요'),
        data: (items) => _GenreReadingTimesList(
          items: items,
          scrollController: scrollController,
        ),
      );
    }

    final items = timesAsync.valueOrNull ?? const [];

    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 40),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: ChorokSectionHeader(
            title: '장르별 독서 비중',
            subtitle: '읽은 시간 기준으로 취향을 묶었어요',
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: BookTreemapWidget(items: items, height: 260),
        ),
        if (kUseMock) ...[
          const SizedBox(height: AppTheme.spaceXL),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            child: ChorokSectionHeader(title: '장르 비율'),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: WaffleChartWidget(genres: buildWaffleItems(context)),
          ),
        ],
      ],
    );
  }
}

class _GenreReadingTimesList extends StatelessWidget {
  final List<({String label, double hours})> items;
  final ScrollController? scrollController;

  const _GenreReadingTimesList({
    required this.items,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _GenreReadingTimesEmpty(message: '아직 독서 기록이 없어요');
    }

    final sorted = [...items]..sort((a, b) => b.hours.compareTo(a.hours));
    final totalMinutes = sorted.fold<int>(
      0,
      (sum, item) => sum + (item.hours * 60).round(),
    );

    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        0,
        AppTheme.screenPadding,
        MediaQuery.paddingOf(context).bottom + 32,
      ),
      itemCount: sorted.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 16) : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            '읽은 시간 기준',
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          );
        }

        final item = sorted[index - 1];
        final minutes = (item.hours * 60).round();
        final percent = totalMinutes == 0 ? 0.0 : minutes / totalMinutes * 100;
        return _GenreReadingTimeRow(
          rank: index,
          label: item.label,
          minutes: minutes,
          percent: percent,
        );
      },
    );
  }
}

class _GenreReadingTimeRow extends StatelessWidget {
  final int rank;
  final String label;
  final int minutes;
  final double percent;

  const _GenreReadingTimeRow({
    required this.rank,
    required this.label,
    required this.minutes,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 10,
        side: BorderSide(color: context.appBorderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatGenreMinutes(minutes),
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreReadingTimesEmpty extends StatelessWidget {
  final String message;

  const _GenreReadingTimesEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: AppTheme.bodySmall.copyWith(color: context.appTextTertiary),
      ),
    );
  }
}

String _formatGenreMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
