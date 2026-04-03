import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../timer/controller/timer_controller.dart';

// ─── 목업 데이터 ──────────────────────────────────────────────────────────

typedef _BookData = ({
  String title,
  String author,
  int currentPage,
  int totalPages,
  String lastRead,
  int gradientIndex,
});

typedef _RecommendedBook = ({
  String title,
  String author,
  String reason,
  int gradientIndex,
  double matchScore,
});

const List<_RecommendedBook> _kRecommendedBooks = [
  (
    title: '소년이 온다',
    author: '한강',
    reason: '"채식주의자"에서 수집한 문장과 비슷한 감성',
    gradientIndex: 3,
    matchScore: 0.94,
  ),
  (
    title: '아몬드',
    author: '손원평',
    reason: '감정과 공감에 대한 문장을 자주 기록하셨어요',
    gradientIndex: 4,
    matchScore: 0.89,
  ),
  (
    title: '작별하지 않는다',
    author: '한강',
    reason: '"파친코"에서 저장한 가족 서사와 닮은 이야기',
    gradientIndex: 5,
    matchScore: 0.86,
  ),
  (
    title: '불편한 편의점',
    author: '김호연',
    reason: '따뜻한 일상 문장을 좋아하시는 취향에 맞춰',
    gradientIndex: 6,
    matchScore: 0.82,
  ),
];

const List<_BookData> _kReadingBooks = [
  (
    title: '채식주의자',
    author: '한강',
    currentPage: 186,
    totalPages: 300,
    lastRead: '오늘',
    gradientIndex: 0,
  ),
  (
    title: '파친코',
    author: '이민진',
    currentPage: 234,
    totalPages: 688,
    lastRead: '어제',
    gradientIndex: 1,
  ),
  (
    title: '지구 끝의 온실',
    author: '김초엽',
    currentPage: 88,
    totalPages: 304,
    lastRead: '3일 전',
    gradientIndex: 2,
  ),
];



// ─── 홈 스크린 ────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkSurface,
      body: const SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeAppBar(),
            Expanded(
              child: CustomScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ① 이번 주 독서 현황
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: _WeeklyStatusCard(),
                    ),
                  ),
                  // ② 지금 읽는 책
                  SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _ReadingBooksSection(),
                  ),
                  // ③ 문장 기반 추천
                  SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: _RecommendedBooksSection(),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 앱바 ─────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return '좋은 아침이에요';
    if (h < 18) return '좋은 오후예요';
    if (h < 22) return '좋은 저녁이에요';
    return '오늘도 수고했어요';
  }

  String _subtext(TimerData timer) {
    const goalSec = 30 * 60;
    final elapsed = timer.seconds;
    if (elapsed >= goalSec) return '오늘 목표를 달성했어요 🎉';
    final remain = (goalSec - elapsed) ~/ 60;
    if (elapsed > 0) return '목표까지 $remain분 남았어요';
    return '오늘 첫 독서를 시작해볼까요?';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _greeting,
                style: AppTheme.captionLarge.copyWith(
                  color: AppTheme.textTertiary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtext(timer),
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          // 검색 버튼
          Semantics(
            label: '책 검색',
            button: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeExplore);
                },
                child: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textTertiary,
                  size: 22,
                ),
              ),
            ),
          ),
          // 알림 버튼
          Semantics(
            label: '알림',
            button: true,
            child: SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeNotifications);
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        color: AppTheme.textTertiary, size: 22),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryLight.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ① 이번 주 독서 현황 ─────────────────────────────────────────────────

// 주간 목업 데이터 (월~일, 분 단위)
const List<int> _kWeeklyMinutes = [42, 28, 55, 0, 35, 18, 0];
const List<String> _kWeekLabels = ['월', '화', '수', '목', '금', '토', '일'];

class _WeeklyStatusCard extends ConsumerWidget {
  const _WeeklyStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final isInSession = !timer.isIdle;

    // 오늘 요일 (월=0)
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);
    // 오늘 값은 타이머 실시간 반영
    final todayMin = timer.seconds ~/ 60;

    const goalMin = 30;
    final weekTotal = _kWeeklyMinutes
            .sublist(0, todayIndex)
            .fold<int>(0, (a, b) => a + b) +
        todayMin;
    final daysAchieved = _kWeeklyMinutes
            .sublist(0, todayIndex)
            .where((m) => m >= goalMin)
            .length +
        (todayMin >= goalMin ? 1 : 0);
    final maxMin = [..._kWeeklyMinutes.sublist(0, todayIndex), todayMin]
        .fold<int>(goalMin, (a, b) => a > b ? a : b);

    final weekTotalText = weekTotal >= 60
        ? '${weekTotal ~/ 60}시간 ${weekTotal % 60}분'
        : '$weekTotal분';

    return ChorokCard(
      borderColor: AppTheme.darkBorder,
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 왼쪽: 주간 통계 ────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Text(
                      '이번 주',
                      style: AppTheme.captionLarge
                          .copyWith(color: AppTheme.textTertiary),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primaryLight.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysAchieved일 달성',
                        style: AppTheme.captionSmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 주간 총 시간
                GradientText(
                  weekTotalText,
                  style: AppTheme.displayLarge.copyWith(fontSize: 28),
                  gradient: AppTheme.greenGradientVertical,
                ),
                const SizedBox(height: 16),
                // 주간 바 차트
                SizedBox(
                  height: 56,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final min = i == todayIndex
                          ? todayMin
                          : (i < todayIndex ? _kWeeklyMinutes[i] : 0);
                      final ratio =
                          maxMin > 0 ? (min / maxMin).clamp(0.0, 1.0) : 0.0;
                      final isToday = i == todayIndex;
                      final isFuture = i > todayIndex;
                      final achieved = min >= goalMin;

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: i < 6 ? 4 : 0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // 바
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: FractionallySizedBox(
                                    heightFactor:
                                        isFuture ? 0.08 : (ratio < 0.08 ? 0.08 : ratio),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        color: isFuture
                                            ? AppTheme.darkBorder
                                            : null,
                                        gradient: isFuture
                                            ? null
                                            : LinearGradient(
                                                begin:
                                                    Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                                colors: achieved
                                                    ? [
                                                        AppTheme.primary,
                                                        AppTheme
                                                            .primaryLight,
                                                      ]
                                                    : [
                                                        AppTheme.primary
                                                            .withValues(
                                                                alpha: 0.5),
                                                        AppTheme.primary
                                                            .withValues(
                                                                alpha: 0.3),
                                                      ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              // 요일 라벨
                              Text(
                                _kWeekLabels[i],
                                style: AppTheme.captionSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  fontSize: 10,
                                  color: isToday
                                      ? AppTheme.primaryLight
                                      : AppTheme.textTertiary,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                // 통계 링크
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go(AppConstants.routeAnalytics);
                  },
                  child: SizedBox(
                    height: 32,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '자세한 통계 보기',
                          style: AppTheme.captionLarge.copyWith(
                            fontFamily: 'Pretendard',
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: AppTheme.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // ── 오른쪽: 독서 시작 버튼 (세로 확장) ─────────────
          Semantics(
            label: isInSession ? '세션으로 돌아가기' : '독서 시작',
            button: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.push(AppConstants.routeSession);
              },
              child: Container(
                width: 64,
                height: 148,
                decoration: AppTheme.smoothBox(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary,
                      Color(0xFF0A5C3A),
                    ],
                  ),
                  radius: 16,
                  side: BorderSide(
                    color:
                        AppTheme.primaryLight.withValues(alpha: 0.25),
                  ),
                  shadows: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isInSession) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryLight
                                  .withValues(alpha: 0.7),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '이어\n하기',
                        textAlign: TextAlign.center,
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 24,
                          color: AppTheme.primaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '독서\n시작',
                        textAlign: TextAlign.center,
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ② 지금 읽는 책 ──────────────────────────────────────────────────────

class _ReadingBooksSection extends StatelessWidget {
  const _ReadingBooksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding),
          child: Row(
            children: [
              Text(
                '지금 읽는 책',
                style: AppTheme.headingSmall.copyWith(
                  fontFamily: 'Pretendard',
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_kReadingBooks.length}권',
                style: AppTheme.captionLarge.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 가로 스크롤 카드
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding),
            itemCount: _kReadingBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                    right: index < _kReadingBooks.length - 1 ? 12 : 0),
                child: _ReadingBookCard(book: _kReadingBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ReadingBookCard extends StatefulWidget {
  final _BookData book;
  const _ReadingBookCard({required this.book});

  @override
  State<_ReadingBookCard> createState() => _ReadingBookCardState();
}

class _ReadingBookCardState extends State<_ReadingBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final progress = b.currentPage / b.totalPages;
    final gradColors =
        AppTheme.coverGradients[b.gradientIndex % AppTheme.coverGradients.length];

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 160,
          decoration: AppTheme.smoothBox(
            color: AppTheme.darkCard,
            radius: 16,
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 표지
              Container(
                height: 110,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 64,
                        color:
                            AppTheme.primaryLight.withValues(alpha: 0.08),
                      ),
                    ),
                    // 진행률 배지
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.darkSurface.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 책 정보
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProgressBar(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${b.currentPage} / ${b.totalPages}쪽',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 이어 읽기 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Semantics(
                  label: '${b.title} 이어 읽기',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.push(AppConstants.routeSession);
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        color: AppTheme.primary.withValues(alpha: 0.5),
                        radius: 10,
                        side: BorderSide(
                          color:
                              AppTheme.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '이어 읽기',
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ③ 문장 기반 추천 ────────────────────────────────────────────────────

class _RecommendedBooksSection extends StatelessWidget {
  const _RecommendedBooksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내 문장이 이끄는 책',
                      style: AppTheme.headingSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '기록한 문장을 분석해 취향에 맞는 책을 추천해요',
                      style: AppTheme.captionLarge.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryLight.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 12, color: AppTheme.primaryLight),
                    const SizedBox(width: 4),
                    Text(
                      'AI',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 가로 스크롤 추천 카드
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding),
            itemCount: _kRecommendedBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                    right:
                        index < _kRecommendedBooks.length - 1 ? 12 : 0),
                child: _RecommendedBookCard(
                    book: _kRecommendedBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendedBookCard extends StatefulWidget {
  final _RecommendedBook book;
  const _RecommendedBookCard({required this.book});

  @override
  State<_RecommendedBookCard> createState() => _RecommendedBookCardState();
}

class _RecommendedBookCardState extends State<_RecommendedBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors = AppTheme
        .coverGradients[b.gradientIndex % AppTheme.coverGradients.length];

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${b.title} 상세 정보 (곧 지원)'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 240,
          decoration: AppTheme.smoothBox(
            color: AppTheme.darkCard,
            radius: 16,
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          child: Row(
            children: [
              // 표지 썸네일
              Container(
                width: 88,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(15)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color:
                            AppTheme.primaryLight.withValues(alpha: 0.08),
                      ),
                    ),
                    // 매칭 점수
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface
                              .withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(b.matchScore * 100).round()}%',
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 책 정보
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: AppTheme.bodySmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.author,
                        style: AppTheme.captionSmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 추천 이유
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.format_quote_rounded,
                                size: 12,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                b.reason,
                                style: AppTheme.captionSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // 서재에 추가 버튼
                      Semantics(
                        label: '${b.title} 서재에 추가',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${b.title}을(를) 읽고 싶은 책에 추가했어요'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primary.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primaryLight
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded,
                                    size: 14,
                                    color: AppTheme.primaryLight),
                                const SizedBox(width: 4),
                                Text(
                                  '서재에 추가',
                                  style: AppTheme.captionSmall.copyWith(
                                    fontFamily: 'Pretendard',
                                    color: AppTheme.primaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 공용: 진행 바 ────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.darkBorder,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: c.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: AppTheme.greenGradient,
            ),
          ),
        ),
      ),
    );
  }
}

