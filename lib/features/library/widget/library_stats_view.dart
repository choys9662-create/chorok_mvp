import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/book_genre.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

// ponytail: 디자인 레퍼런스 고정값 — 분류기에 없는 라벨(철학/시/종교)이라 책 목록에서
// 유도하지 않고 직접 지정. 책이 늘어도 이 화면 값은 안 바뀐다.
const _kMockGenreReadingTimes = [
  (label: '문학', hours: 14.5),
  (label: '철학', hours: 4 + 20 / 60),
  (label: '시', hours: 2 + 10 / 60),
  (label: '역사', hours: 1 + 40 / 60),
  (label: '종교', hours: 50 / 60),
];

final genreReadingTimesProvider =
    FutureProvider.autoDispose<List<({String label, double hours})>>((
      ref,
    ) async {
      if (kUseMock) {
        return _kMockGenreReadingTimes;
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
      return _EmbeddedGenreMosaic(items: items);
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

class _EmbeddedGenreMosaic extends StatelessWidget {
  static const _gap = 8.0;

  final List<({String label, double hours})> items;

  const _EmbeddedGenreMosaic({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: AppTheme.smoothBox(color: context.appCard, radius: 8),
        child: Text(
          '아직 독서 기록이 없어요',
          style: AppTheme.bodySmall.copyWith(color: context.appTextTertiary),
        ),
      );
    }

    final sorted = [...items]..sort((a, b) => b.hours.compareTo(a.hours));
    final totalMinutes = sorted.fold<int>(
      0,
      (sum, item) => sum + (item.hours * 60).round(),
    );
    // ponytail: 3% 미만 장르는 프리뷰에서 숨김 — 전체 목록은 '자세히 보기'에서
    const minSharePercent = 3;
    var visible = sorted
        .where(
          (i) => (i.hours * 60).round() * 100 >= totalMinutes * minSharePercent,
        )
        .take(5)
        .toList();
    if (visible.isEmpty) visible = [sorted.first];

    // ponytail: sqrt 가중 — 비중을 반영하되 작은 장르가 슬리버로 뭉개지지 않게 완화
    int weight(({String label, double hours}) i) =>
        math.max(1, (math.sqrt(i.hours * 60) * 10).round());

    const colors = [
      Color(0xFF8DFF54),
      Color(0xFFF0FAF0),
      Color(0xFFA5B9A7),
      Color(0xFF808A80),
      Color(0xFF4F574F),
    ];
    const textColors = [
      Colors.black,
      Colors.black,
      Colors.black,
      Colors.white,
      Colors.white,
    ];
    const percentAlphas = [0.22, 0.22, 0.24, 0.22, 0.28];

    Widget card(int i) => _EmbeddedGenreCard(
      item: visible[i],
      totalMinutes: totalMinutes,
      color: colors[i],
      textColor: textColors[i],
      percentColor: Colors.black.withValues(alpha: percentAlphas[i]),
    );

    Widget row(List<int> idxs) => Row(
      children: [
        for (final (j, i) in idxs.indexed) ...[
          if (j > 0) const SizedBox(width: _gap),
          Expanded(flex: weight(visible[i]), child: card(i)),
        ],
      ],
    );

    if (visible.length <= 2) {
      return AspectRatio(
        aspectRatio: 1.8,
        child: row([for (var i = 0; i < visible.length; i++) i]),
      );
    }

    final topWeight = weight(visible[0]) + weight(visible[1]);
    final bottomIdxs = [for (var i = 2; i < visible.length; i++) i];
    final bottomWeight = bottomIdxs.fold<int>(
      0,
      (s, i) => s + weight(visible[i]),
    );

    return AspectRatio(
      aspectRatio: 1.11,
      child: Column(
        children: [
          Expanded(flex: topWeight, child: row([0, 1])),
          const SizedBox(height: _gap),
          // 하단 줄 최소 높이 ~30% 보장 — 폰트가 뭉개지지 않는 하한
          Expanded(
            flex: math.max(
              bottomWeight,
              ((topWeight + bottomWeight) * 0.3).round(),
            ),
            child: row(bottomIdxs),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedGenreCard extends StatelessWidget {
  final ({String label, double hours}) item;
  final int totalMinutes;
  final Color color;
  final Color textColor;
  final Color percentColor;

  const _EmbeddedGenreCard({
    required this.item,
    required this.totalMinutes,
    required this.color,
    required this.percentColor,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = (item.hours * 60).round();
    final percent = totalMinutes == 0
        ? 0
        : (minutes / totalMinutes * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 150;
        final tight = constraints.maxWidth < 120;
        // 최소 노출 비중(3%) 카드 기준으로 확정한 크기.
        // 카드가 그보다 작아지면 FittedBox가 비율 그대로 축소한다.
        const titleSize = 30.0;
        const timeSize = 16.0;
        const percentSize = 30.0;

        return Container(
          padding: EdgeInsets.fromLTRB(
            tight ? 14 : 20,
            compact ? 14 : 20,
            tight ? 12 : 16,
            compact ? 12 : 16,
          ),
          decoration: AppTheme.smoothBox(color: color, radius: 18),
          // 제목·시간(위) / 퍼센트(아래) 영역 분리 — 텍스트 겹침 원천 차단
          child: Column(
            children: [
              Expanded(
                flex: 7,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: titleSize,
                            height: 0.95,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 12),
                        Text(
                          _formatGenreMinutes(minutes),
                          style: TextStyle(
                            fontSize: timeSize,
                            height: 1.0,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w400,
                            color: textColor.withValues(alpha: 0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: percentSize,
                        height: 1.0,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w400,
                        color: percentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
