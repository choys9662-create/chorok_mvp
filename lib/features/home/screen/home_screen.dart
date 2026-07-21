import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';

import '../widget/home_stat_cards.dart';
import '../widget/reading_books_section.dart';
import '../widget/recommended_books_section.dart';
import '../widget/reading_friends_section.dart';
import '../widget/friends_read_today_section.dart';
import '../widget/overlap_section.dart';
import '../widget/home_app_bar.dart';

import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_refresh.dart';
import '../controller/weekly_minutes_provider.dart';

// ─── 홈 전용 Provider ────────────────────────────────────────────────────────

// ─── 추천 책 목업 (커뮤니티 기반 추천 — 실데이터 연동 전 placeholder) ──────────

// ─── 홈 스크린 ────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollCtrl = ref.read(tabScrollControllersProvider)[0];
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topPad),
          const HomeAppBar(),
          Expanded(
            child: CustomScrollView(
              controller: scrollCtrl,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                ChorokSliverRefreshControl(
                  onRefresh: () => ref.refresh(weeklyMinutesProvider.future),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.spaceLG),
                ),
                const SliverToBoxAdapter(child: HomeStatCards()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppTheme.sectionGap),
                ),
                const SliverToBoxAdapter(child: ReadingBooksSection()),
                const SliverToBoxAdapter(child: RecommendedBooksSection()),
                // ponytail: 아래 세 섹션은 비면 통째로 숨는다. 간격을 각 섹션이
                // 직접 들고 있어야 숨을 때 여백도 같이 사라진다.
                const SliverToBoxAdapter(child: ReadingFriendsSection()),
                const SliverToBoxAdapter(child: FriendsReadTodaySection()),
                const SliverToBoxAdapter(child: OverlapSection()),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 112,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 홈 메시지 풀 ─────────────────────────────────────────────────────────

// 연속 달성일 수 계산 (오늘 제외, 어제부터 역산)

// 마지막으로 읽은 뒤 며칠 지났는지

// ─── 앱바 ─────────────────────────────────────────────────────────────────

// ─── ① 이번 주 독서 현황 ─────────────────────────────────────────────────

// 주간 목업 데이터 (월~일, 분 단위)

// ─── 오늘의 인사이트 문구 (WeeklyStatusCard 내부 참조용) ──────────────────────

// ─── ② 지금 읽는 책 ──────────────────────────────────────────────────────

// ─── 빈 상태 카드 (신규 사용자용) ────────────────────────────────────────

// ─── 인사이트 칩 (현재 사용 안 함 — 책별 통계 Supabase 연동 후 복귀 예정) ──────

// ignore: unused_element

// ─── ③ 문장 기반 추천 ────────────────────────────────────────────────────

// ─── ④ 피드 하이라이트 ───────────────────────────────────────────────────

// ─── 공용: 진행 바 ────────────────────────────────────────────────────────

// ─── 스트릭 배너 ──────────────────────────────────────────────────────────────

// ─── 타임캡슐 문장 섹션 ───────────────────────────────────────────────────────

// ─── ④ 다음에 읽을 책 ────────────────────────────────────────────────────────

// ─── 공용: 진행 바 ────────────────────────────────────────────────────────────
