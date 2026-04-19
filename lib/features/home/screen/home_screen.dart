import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/utils/reading_insight_engine.dart';
import '../widget/session_goal_sheet.dart';
import 'book_detail_screen.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../../timer/controller/timer_controller.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';

// ─── 홈 전용 Provider ────────────────────────────────────────────────────────

final _timeCapsuleProvider = FutureProvider<IsarChoseo?>((ref) async {
  return ref.read(bookRepositoryProvider)?.getTimeCapsuleChoseo();
});

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

// ─── 위시리스트 목업 ──────────────────────────────────────────────────────────
typedef _WishlistBook = ({
  String title,
  String author,
  int addedDays,
  int gradientIndex,
  int totalPages,
});

const List<_WishlistBook> _kWishlistBooks = [
  (
    title: '소년이 온다',
    author: '한강',
    addedDays: 3,
    gradientIndex: 3,
    totalPages: 216,
  ),
  (
    title: '불편한 편의점',
    author: '김호연',
    addedDays: 7,
    gradientIndex: 6,
    totalPages: 312,
  ),
  (
    title: '달러구트 꿈 백화점',
    author: '이미예',
    addedDays: 14,
    gradientIndex: 1,
    totalPages: 304,
  ),
];

// ─── 책별 독서 통계 (목업) ──────────────────────────────────────────────────
const List<BookReadingStats> _kBookStats = [
  BookReadingStats(
    title: '채식주의자',
    currentPage: 186,
    totalPages: 300,
    avgPagesPerHour: 25.0,
    savedSentences: 7,
    streakDays: 5,
    totalReadingHours: 12.4,
  ),
  BookReadingStats(
    title: '파친코',
    currentPage: 234,
    totalPages: 688,
    avgPagesPerHour: 18.0,
    savedSentences: 12,
    streakDays: 3,
    totalReadingHours: 8.2,
  ),
  BookReadingStats(
    title: '지구 끝의 온실',
    currentPage: 88,
    totalPages: 304,
    avgPagesPerHour: 30.0,
    savedSentences: 3,
    streakDays: 1,
    totalReadingHours: 4.6,
  ),
];

// ─── 홈 스크린 ────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollCtrl = ref.read(tabScrollControllersProvider)[0];
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _HomeAppBar(),
            Expanded(
              child: CustomScrollView(
                controller: scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 스트릭 배너 (2일 이상일 때만)
                  SliverToBoxAdapter(child: _StreakBanner()),
                  // ① 이번 주 독서 현황
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: const _WeeklyStatusCard(),
                    ),
                  ),
                  // ② 지금 읽는 책
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const SliverToBoxAdapter(child: _ReadingBooksSection()),
                  // ③ 문장 기반 추천
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const SliverToBoxAdapter(child: _RecommendedBooksSection()),
                  // ④ 다음에 읽을 책
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const SliverToBoxAdapter(child: _WishlistSection()),
                  // ⑤ 피드 하이라이트
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  const SliverToBoxAdapter(child: _FeedHighlightSection()),
                  // ⑤ 타임캡슐 문장
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  const SliverToBoxAdapter(child: _TimeCapsuleSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 홈 메시지 풀 ─────────────────────────────────────────────────────────

const _kGoalMessages = [
  '오늘 목표 완료! 멈추라고는 안 했어요',
  '30분 달성! 이 기세 계속 가요',
  '오늘의 독서 완료. 내일도 이 기세로요',
  '훌륭해요. 이게 쌓이면 습관이 돼요',
];

const _kStreakSuffix = ['오늘 빠지면 너무 아깝잖아요', '이 기록, 오늘도 이어가요', '여기서 멈추실 건 아니죠?'];

const _kSlackMessages = [
  '요즘 바쁘신가봐요?',
  '채식주의자가 186페이지에서 기다리고 있어요',
  '책이 먼지 쌓이기 시작했어요',
  '독서는 하루 건너뛰면 이틀 잊어요',
  '오늘 딱 5분만요. 딱 5분',
];

const _kNudgeMessages = ['오늘 첫 독서를 시작해볼까요?', '딱 10분만 읽어볼까요?', '책이 기다리고 있어요'];

// 연속 달성일 수 계산 (오늘 제외, 어제부터 역산)
int _calcReadStreak(int todayIndex) {
  int streak = 0;
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (_kWeeklyMinutes[i] >= 30) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

// 마지막으로 읽은 뒤 며칠 지났는지
int _daysSinceLastRead(int todayIndex) {
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (_kWeeklyMinutes[i] > 0) return todayIndex - i;
  }
  return todayIndex + 1;
}

// ─── 앱바 ─────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar();

  String _subtext(TimerData timer) {
    final now = DateTime.now();
    final todayIndex = (now.weekday - 1).clamp(0, 6);
    final todayMin = timer.seconds ~/ 60;
    final isInSession = !timer.isIdle;
    const goalMin = 30;
    final seed = now.day;

    if (isInSession) return '지금 읽는 중이에요';

    if (todayMin >= goalMin) {
      return _kGoalMessages[seed % _kGoalMessages.length];
    }

    if (todayMin > 0) {
      final remain = goalMin - todayMin;
      return '$remain분만 더요, 거의 다 왔어요';
    }

    // 오늘 아직 안 읽은 상태
    final streak = _calcReadStreak(todayIndex);
    if (streak >= 3) {
      final suffix = _kStreakSuffix[seed % _kStreakSuffix.length];
      return '$streak일 연속! $suffix';
    }

    final readYesterday =
        todayIndex > 0 && _kWeeklyMinutes[todayIndex - 1] >= goalMin;
    if (readYesterday) return '어제는 읽으셨는데, 오늘은요?';

    final daysSince = _daysSinceLastRead(todayIndex);
    if (daysSince >= 3) {
      return _kSlackMessages[seed % _kSlackMessages.length];
    }

    return _kNudgeMessages[seed % _kNudgeMessages.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _subtext(timer),
                style: AppTheme.headingLarge.copyWith(
                  color: context.appTextPrimary,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
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
                child: Icon(
                  Icons.search_rounded,
                  color: context.appTextSecondary,
                  size: 24,
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
                    Icon(
                      Icons.notifications_none_rounded,
                      color: context.appTextSecondary,
                      size: 24,
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.appPrimaryAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.appPrimaryAccent.withValues(
                                alpha: 0.6,
                              ),
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
    final weekTotal =
        _kWeeklyMinutes.sublist(0, todayIndex).fold<int>(0, (a, b) => a + b) +
        todayMin;
    final daysAchieved =
        _kWeeklyMinutes
            .sublist(0, todayIndex)
            .where((m) => m >= goalMin)
            .length +
        (todayMin >= goalMin ? 1 : 0);
    final maxMin = [
      ..._kWeeklyMinutes.sublist(0, todayIndex),
      todayMin,
    ].fold<int>(goalMin, (a, b) => a > b ? a : b);

    final weekTotalText = weekTotal >= 60
        ? '${weekTotal ~/ 60}시간 ${weekTotal % 60}분'
        : '$weekTotal분';

    // 오늘 인사이트 (목업 mockup exitCount=0 기준)
    final insight = _todayInsightText(todayMin, 0);

    return ChorokCard(
      borderColor: context.appBorder,
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 헤더: 라벨 + 뱃지 + 독서 시작 버튼 ──────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '이번 주',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: ShapeDecoration(
                  color: context.appPrimaryAccent.withValues(alpha: 0.08),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: 8,
                      cornerSmoothing: 0.6,
                    ),
                  ),
                ),
                child: Text(
                  '$daysAchieved일 달성',
                  style: AppTheme.captionSmall.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // 독서 시작 — 헤더 우측 pill 버튼
              Semantics(
                label: isInSession ? '세션으로 돌아가기' : '독서 시작',
                button: true,
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    if (isInSession) {
                      context.push(AppConstants.routeSession);
                      return;
                    }
                    final goal = await showModalBottomSheet<SessionGoal>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SessionGoalSheet(
                        currentPage: 186,
                        totalPages: 300,
                        bookTitle: '채식주의자',
                      ),
                    );
                    if (goal != null && context.mounted) {
                      context.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          goal: goal,
                          bookId: '1',
                          bookTitle: '채식주의자',
                          bookAuthor: '한강',
                          startPage: 186,
                          totalPages: 300,
                        ),
                      );
                    }
                  },
                  child: _PulsingReadButton(isInSession: isInSession),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── 주간 총 시간 ──────────────────────────────────────
          GradientText(
            weekTotalText,
            style: AppTheme.displayLarge.copyWith(fontSize: 28),
            gradient: AppTheme.greenGradientVertical,
          ),
          const SizedBox(height: 20),
          // ── 주간 바 차트 (풀 너비) ────────────────────────────
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.go(AppConstants.routeAnalytics);
            },
            child: SizedBox(
              height: 72,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final min = i == todayIndex
                      ? todayMin
                      : (i < todayIndex ? _kWeeklyMinutes[i] : 0);
                  final ratio = maxMin > 0
                      ? (min / maxMin).clamp(0.0, 1.0)
                      : 0.0;
                  final isToday = i == todayIndex;
                  final isFuture = i > todayIndex;
                  final achieved = min >= goalMin;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 4 : 0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: isFuture
                                    ? 0.08
                                    : (ratio < 0.08 ? 0.08 : ratio),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: isFuture ? context.appBorder : null,
                                    gradient: isFuture
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: achieved
                                                ? [
                                                    AppTheme.primary,
                                                    context.appPrimaryAccent,
                                                  ]
                                                : [
                                                    AppTheme.primary.withValues(
                                                      alpha: 0.5,
                                                    ),
                                                    AppTheme.primary.withValues(
                                                      alpha: 0.3,
                                                    ),
                                                  ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _kWeekLabels[i],
                            style: AppTheme.captionSmall.copyWith(
                              fontFamily: 'Pretendard',
                              color: isToday
                                  ? context.appPrimaryAccent
                                  : context.appTextTertiary,
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
          ),
          // ── 오늘의 인사이트 ───────────────────────────────────
          if (insight.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: ShapeDecoration(
                color: context.appPrimaryAccent.withValues(alpha: 0.06),
                shape: SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius(
                    cornerRadius: AppTheme.radiusMD,
                    cornerSmoothing: 0.6,
                  ),
                ),
              ),
              child: Text(
                insight,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 독서 시작 버튼 (Breathing Glow 애니메이션) ─────────────────────────────

class _PulsingReadButton extends StatefulWidget {
  final bool isInSession;
  const _PulsingReadButton({required this.isInSession});

  @override
  State<_PulsingReadButton> createState() => _PulsingReadButtonState();
}

class _PulsingReadButtonState extends State<_PulsingReadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, Color(0xFF0A5C3A)],
          ),
          shape: StadiumBorder(
            side: BorderSide(
              color: context.appPrimaryAccent.withValues(alpha: 0.25),
            ),
          ),
          shadows: [
            BoxShadow(
              color: context.appPrimaryAccent.withValues(
                alpha: 0.12 + _glow.value * 0.28,
              ),
              blurRadius: 6 + _glow.value * 18,
              spreadRadius: _glow.value * 3,
            ),
            const BoxShadow(
              color: Color(0x661A3D2B),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isInSession) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: context.appPrimaryAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.appPrimaryAccent.withValues(alpha: 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '이어하기',
              style: AppTheme.captionSmall.copyWith(
                fontFamily: 'Pretendard',
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Icon(
              Icons.play_arrow_rounded,
              size: 14,
              color: context.appPrimaryAccent,
            ),
            const SizedBox(width: 4),
            Text(
              '독서 시작',
              style: AppTheme.captionSmall.copyWith(
                fontFamily: 'Pretendard',
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 오늘의 인사이트 문구 (WeeklyStatusCard 내부 참조용) ──────────────────────

String _todayInsightText(int todayMinutes, int exitCount) {
  if (todayMinutes <= 0) return '';
  if (exitCount == 0 && todayMinutes >= 30) return '한 번도 안 나가셨어요. 완전한 몰입이었어요';
  if (exitCount == 0) return '중간에 한 번도 안 나가셨네요. 훌륭해요';
  if (todayMinutes > 45) return '평소보다 오래 읽으셨어요. 재밌는 장면이었나요?';
  return '오늘도 읽으셨어요. 이게 전부예요';
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
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Text(
                '지금 읽는 책',
                style: AppTheme.headingSmall.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_kReadingBooks.length}권',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // ── 인사이트 메시지 ────────────────────────────────────────
        if (_kBookStats.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              8,
              AppTheme.screenPadding,
              12,
            ),
            child: _InsightChip(
              insight: ReadingInsightEngine.generateForBook(_kBookStats.first),
            ),
          ),

        // 가로 스크롤 카드
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: _kReadingBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _kReadingBooks.length - 1 ? 12 : 0,
                ),
                child: _ReadingBookCard(book: _kReadingBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── 인사이트 칩 ─────────────────────────────────────────────────────────

class _InsightChip extends StatelessWidget {
  final ReadingInsight insight;

  const _InsightChip({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: AppTheme.smoothBox(
        color: AppTheme.primary.withValues(alpha: 0.2),
        radius: AppTheme.radiusMD,
        side: BorderSide(
          color: context.appPrimaryAccent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(insight.icon, size: 16, color: context.appPrimaryAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.message,
              style: AppTheme.captionLarge.copyWith(
                color: context.appPrimaryAccent,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (insight.subMessage != null) ...[
            const SizedBox(width: 8),
            Text(
              insight.subMessage!,
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ],
        ],
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.book;
    final progress = b.currentPage / b.totalPages;
    final gradColors = AppTheme
        .coverGradients[b.gradientIndex % AppTheme.coverGradients.length];

    return GestureDetector(
      onTap: () {
        context.push(
          AppConstants.routeBookDetail,
          extra: BookDetailExtra(
            title: b.title,
            author: b.author,
            currentPage: b.currentPage,
            totalPages: b.totalPages,
            lastRead: b.lastRead,
            gradientIndex: b.gradientIndex,
          ),
        );
      },
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
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 24,
            side: BorderSide(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 표지
              Container(
                height: 110,
                decoration: BoxDecoration(
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
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                      ),
                    ),
                    // 진행률 배지
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.75),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          '${(progress * 100).round()}%',
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appPrimaryAccent,
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
                        color: context.appTextPrimary,
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
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProgressBar(value: progress),
                    const SizedBox(height: 4),
                    Text(
                      '${b.currentPage} / ${b.totalPages}쪽',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextTertiary,
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
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final goal = await showModalBottomSheet<SessionGoal>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SessionGoalSheet(
                          currentPage: b.currentPage,
                          totalPages: b.totalPages,
                          bookTitle: b.title,
                        ),
                      );
                      if (goal != null && context.mounted) {
                        context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            goal: goal,
                            bookId: b.title.hashCode.toString(),
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: b.currentPage,
                            totalPages: b.totalPages,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        color: isDark
                            ? AppTheme.primary.withValues(alpha: 0.5)
                            : AppTheme.lightPrimaryAccent,
                        radius: 10,
                        side: BorderSide(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Text(
                        '이어 읽기',
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: isDark ? context.appPrimaryAccent : Colors.white,
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
            horizontal: AppTheme.screenPadding,
          ),
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
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '기록한 문장을 분석해 취향에 맞는 책을 추천해요',
                      style: AppTheme.captionLarge.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: ShapeDecoration(
                  color: context.appPrimaryAccent.withValues(alpha: 0.08),
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: 8,
                      cornerSmoothing: 0.6,
                    ),
                    side: BorderSide(
                      color: context.appPrimaryAccent.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI',
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appPrimaryAccent,
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
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: _kRecommendedBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _kRecommendedBooks.length - 1 ? 12 : 0,
                ),
                child: _RecommendedBookCard(book: _kRecommendedBooks[index]),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 16,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              // 표지 썸네일
              Container(
                width: 88,
                decoration: BoxDecoration(
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
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                      ),
                    ),
                    // 매칭 점수
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.8),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 6,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          '${(b.matchScore * 100).round()}%',
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w700,
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
                          color: context.appTextPrimary,
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
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 추천 이유
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: ShapeDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 8,
                              cornerSmoothing: 0.6,
                            ),
                            side: BorderSide(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.format_quote_rounded,
                                size: 12,
                                color: context.appPrimaryAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                b.reason,
                                style: AppTheme.captionSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: context.appTextSecondary,
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
                                content: Text('${b.title}을(를) 읽고 싶은 책에 추가했어요'),
                                backgroundColor: AppTheme.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            height: 32,
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: isDark
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : AppTheme.lightPrimaryAccent,
                              shape: SmoothRectangleBorder(
                                borderRadius: SmoothBorderRadius(
                                  cornerRadius: 8,
                                  cornerSmoothing: 0.6,
                                ),
                                side: BorderSide(
                                  color: context.appPrimaryAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: isDark ? context.appPrimaryAccent : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '서재에 추가',
                                  style: AppTheme.captionSmall.copyWith(
                                    fontFamily: 'Pretendard',
                                    color: isDark ? context.appPrimaryAccent : Colors.white,
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

// ─── ④ 피드 하이라이트 ───────────────────────────────────────────────────

class _HighlightSentence {
  final String content;
  final String bookTitle;
  final String author;
  final int recordCount;
  final int empathyCount;
  final bool isOverlap;
  final int gradientIndex;

  const _HighlightSentence({
    required this.content,
    required this.bookTitle,
    required this.author,
    required this.recordCount,
    required this.empathyCount,
    this.isOverlap = false,
    this.gradientIndex = 0,
  });
}

const _kHighlightSentences = [
  _HighlightSentence(
    content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
    bookTitle: '채식주의자',
    author: '한강',
    recordCount: 142,
    empathyCount: 384,
    isOverlap: true,
    gradientIndex: 0,
  ),
  _HighlightSentence(
    content: '우리는 모두 누군가의 이민자다. 다만 시간이 다를 뿐.',
    bookTitle: '파친코',
    author: '이민진',
    recordCount: 98,
    empathyCount: 271,
    isOverlap: false,
    gradientIndex: 2,
  ),
  _HighlightSentence(
    content: '사랑한다는 것은 서로의 고독을 인정하는 것이다.',
    bookTitle: '노르웨이의 숲',
    author: '무라카미 하루키',
    recordCount: 214,
    empathyCount: 512,
    isOverlap: true,
    gradientIndex: 4,
  ),
];

class _FeedHighlightSection extends StatelessWidget {
  const _FeedHighlightSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지금 많이 기록된 문장',
                      style: AppTheme.headingSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '독자들이 가장 많이 수집한 문장이에요',
                      style: AppTheme.captionLarge.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/feed'),
                child: Text(
                  '피드 보기 ›',
                  style: AppTheme.captionLarge.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 문장 카드 리스트
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Column(
            children: _kHighlightSentences
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(
                      bottom: e.key < _kHighlightSentences.length - 1 ? 10 : 0,
                    ),
                    child: _HighlightCard(sentence: e.value),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final _HighlightSentence sentence;
  const _HighlightCard({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final gradColors =
        AppTheme.coverGradients[sentence.gradientIndex %
            AppTheme.coverGradients.length];

    return Semantics(
      label: '${sentence.bookTitle} 문장 보기',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/feed');
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusLG,
            side: BorderSide(color: context.appBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 책 표지 컬러 바 — stretch로 카드 전체 높이 채움
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradColors,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 문장 + 메타
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 겹문장 배지
                        if (sentence.isOverlap)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: ShapeDecoration(
                                color: context.appPrimaryAccent.withValues(
                                  alpha: 0.08,
                                ),
                                shape: SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius(
                                    cornerRadius: 6,
                                    cornerSmoothing: 0.6,
                                  ),
                                  side: BorderSide(
                                    color: context.appPrimaryAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.join_inner_rounded,
                                    size: 11,
                                    color: context.appPrimaryAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '겹문장 · ${sentence.recordCount}명 수집',
                                    style: AppTheme.captionSmall.copyWith(
                                      fontFamily: 'Pretendard',
                                      color: context.appPrimaryAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 문장 본문
                        Text(
                          '"${sentence.content}"',
                          style: AppTheme.bodySmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextPrimary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // 책 정보 + 공감
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${sentence.bookTitle} · ${sentence.author}',
                                style: AppTheme.captionSmall.copyWith(
                                  fontFamily: 'Pretendard',
                                  color: context.appTextTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: context.appAccentColor.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${sentence.empathyCount}',
                              style: AppTheme.captionSmall.copyWith(
                                fontFamily: 'Pretendard',
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
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
    );
  }
}

// ─── 공용: 진행 바 ────────────────────────────────────────────────────────

// ─── 스트릭 배너 ──────────────────────────────────────────────────────────────

class _StreakBanner extends ConsumerWidget {
  const _StreakBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(readingStreakProvider);
    return streak.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (days) {
        if (days < 2) return const SizedBox.shrink();
        final today = DateTime.now();
        // 오늘 독서 여부 — 주간 목업 데이터 기반
        final todayIndex = (today.weekday - 1).clamp(0, 6);
        final todayMin = _kWeeklyMinutes[todayIndex];
        final hasReadToday = todayMin > 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: ShapeDecoration(
              color: hasReadToday
                  ? AppTheme.warningColor.withValues(alpha: 0.08)
                  : context.appCard,
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius(
                  cornerRadius: AppTheme.radiusMD * 1.8,
                  cornerSmoothing: 0.6,
                ),
                side: BorderSide(
                  color: hasReadToday
                      ? AppTheme.warningColor.withValues(alpha: 0.3)
                      : context.appBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  hasReadToday ? '🔥' : '⏰',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasReadToday
                        ? '$days일 연속 독서 중'
                        : '오늘 아직 안 읽었어요. 스트릭이 끊길 수도 있어요.',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasReadToday
                          ? AppTheme.warningColor
                          : context.appTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── 타임캡슐 문장 섹션 ───────────────────────────────────────────────────────

class _TimeCapsuleSection extends ConsumerWidget {
  const _TimeCapsuleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsule = ref.watch(_timeCapsuleProvider);
    return capsule.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (choseo) {
        if (choseo == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Text('⏳', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      '1년 전 오늘, 당신이 붙잡은 문장',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                decoration: ShapeDecoration(
                  color: context.appCard,
                  shape: SmoothRectangleBorder(
                    borderRadius: SmoothBorderRadius(
                      cornerRadius: AppTheme.radiusLG * 1.8,
                      cornerSmoothing: 0.6,
                    ),
                    side: BorderSide(color: context.appBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 3,
                            decoration: BoxDecoration(
                              gradient: AppTheme.greenGradientVertical,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '"${choseo.content}"',
                              style: AppTheme.bodyMedium.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '— ${choseo.bookTitle}  ·  ${choseo.bookAuthor}',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(AppConstants.routeChoseoList);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.08,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(color: context.appBorder),
                          ),
                        ),
                        child: Text(
                          '그때의 나는 무슨 생각을 했을까?',
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── ④ 다음에 읽을 책 ────────────────────────────────────────────────────────

class _WishlistSection extends StatelessWidget {
  const _WishlistSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Row(
            children: [
              Text(
                '다음에 읽을 책',
                style: AppTheme.headingSmall.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_kWishlistBooks.length}권',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            itemCount: _kWishlistBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _kWishlistBooks.length - 1 ? 12 : 0,
                ),
                child: _WishlistBookCard(book: _kWishlistBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WishlistBookCard extends StatefulWidget {
  final _WishlistBook book;
  const _WishlistBookCard({required this.book});

  @override
  State<_WishlistBookCard> createState() => _WishlistBookCardState();
}

class _WishlistBookCardState extends State<_WishlistBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors =
        AppTheme.coverGradients[b.gradientIndex % AppTheme.coverGradients.length];
    final daysText = b.addedDays == 0 ? '오늘' : '${b.addedDays}일 전';

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
          width: 150,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 20,
            side: BorderSide(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
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
                        Icons.bookmark_rounded,
                        size: 56,
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.75),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 6,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          daysText,
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
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
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Semantics(
                  label: '${b.title} 읽기 시작',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final goal = await showModalBottomSheet<SessionGoal>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SessionGoalSheet(
                          currentPage: 0,
                          totalPages: b.totalPages,
                          bookTitle: b.title,
                        ),
                      );
                      if (goal != null && context.mounted) {
                        context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            goal: goal,
                            bookId: b.title.hashCode.toString(),
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: 0,
                            totalPages: b.totalPages,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        radius: 10,
                        side: BorderSide(
                          color: context.appPrimaryAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: context.appPrimaryAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '읽기 시작',
                            style: AppTheme.captionLarge.copyWith(
                              fontFamily: 'Pretendard',
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

// ─── 공용: 진행 바 ────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) => Container(
        height: 5,
        decoration: BoxDecoration(
          color: context.appBorder,
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
