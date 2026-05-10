import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../analytics/widgets/book_treemap_widget.dart';
import '../../analytics/widgets/waffle_chart_widget.dart';

// ─── 통계 목업 데이터 (TODO: Isar 연동 시 Repository/Provider로 교체) ────
const kTreemapItems = <({String title, double hours})>[
  (title: '채식주의자', hours: 12.4),
  (title: '파친코', hours: 8.2),
  (title: '아몬드', hours: 6.7),
  (title: '지구 끝의 온실', hours: 4.6),
  (title: '82년생 김지영', hours: 3.1),
  (title: '달러구트 꿈 백화점', hours: 2.8),
];

List<({String name, Color color, int cells})> buildWaffleItems(BuildContext context) => [
  (name: '소설', color: context.appPrimaryAccent, cells: 60),
  (name: '문학', color: const Color(0xFF81C784), cells: 22), // Light pastel green
  (name: '인문', color: const Color(0xFF2E7D32), cells: 11), // Deep forest green
  (name: '자기계발', color: const Color(0xFFCCFF90), cells: 7), // Neon yellowish-green
];

// ─── 통계 탭 — 책별 비중 · 장르 비율 ──────────────────────────────────────
class LibraryStatsView extends StatelessWidget {
  final ScrollController? scrollController;

  const LibraryStatsView({super.key, this.scrollController});

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppTheme.screenPadding, 16, AppTheme.screenPadding, 40),
      children: [
        const ChorokSectionHeader(title: '책별 독서 비중'),
        const SizedBox(height: AppTheme.spaceMD),
        const BookTreemapWidget(items: kTreemapItems),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '장르 비율'),
        const SizedBox(height: AppTheme.spaceMD),
        WaffleChartWidget(genres: buildWaffleItems(context)),
      ],
    );
  }
}
