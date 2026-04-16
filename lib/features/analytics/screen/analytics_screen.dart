import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_stat_cell.dart';
import '../../../shared/widgets/gradient_text.dart';
import '../widgets/bullet_graph_widget.dart';
import '../widgets/habit_radar_chart_widget.dart';
import '../widgets/heatmap_calendar_widget.dart';

// ─── Mock 데이터 ─────────────────────────────────────────────────────────
// TODO: Isar 연동 시 이 클래스를 Provider/Repository로 교체

class AnalyticsMockData {
  // 히트맵: 2026년 독서 기록 (날짜 → 분)
  static final Map<DateTime, int> heatmap2026 = {
    DateTime(2026, 1,  3): 45,  DateTime(2026, 1,  5): 90,
    DateTime(2026, 1,  8): 30,  DateTime(2026, 1, 12): 120,
    DateTime(2026, 1, 15): 60,  DateTime(2026, 1, 19): 90,
    DateTime(2026, 1, 22): 150, DateTime(2026, 1, 26): 45,
    DateTime(2026, 2,  2): 60,  DateTime(2026, 2,  5): 90,
    DateTime(2026, 2,  9): 120, DateTime(2026, 2, 13): 30,
    DateTime(2026, 2, 17): 90,  DateTime(2026, 2, 21): 180,
    DateTime(2026, 2, 25): 60,  DateTime(2026, 2, 28): 90,
    DateTime(2026, 3,  1): 120, DateTime(2026, 3,  3): 45,
    DateTime(2026, 3,  5): 90,  DateTime(2026, 3,  8): 60,
    DateTime(2026, 3, 10): 180, DateTime(2026, 3, 12): 75,
    DateTime(2026, 3, 14): 150, DateTime(2026, 3, 15): 90,
    DateTime(2026, 3, 17): 200, DateTime(2026, 3, 19): 120,
    DateTime(2026, 3, 20): 45,  DateTime(2026, 3, 21): 180,
    DateTime(2026, 3, 22): 60,  DateTime(2026, 3, 24): 90,
    DateTime(2026, 3, 26): 240, DateTime(2026, 3, 27): 150,
    DateTime(2026, 3, 29): 75,  DateTime(2026, 3, 31): 120,
    DateTime(2026, 4,  1): 60,  DateTime(2026, 4,  3): 90,
    DateTime(2026, 4,  7): 120, DateTime(2026, 4, 10): 45,
    DateTime(2026, 4, 14): 90,
  };

  // 레이더: 5축 (0.0~1.0) — [독서시간, 초서수, 집중도, 완독률, 연속성]
  static const List<double> currentMonthRadar  = [0.80, 0.65, 0.83, 0.70, 0.90];
  static const List<double> previousMonthRadar = [0.55, 0.45, 0.60, 0.50, 0.70];

  // 불릿 그래프
  static const double weekBulletCurrent = 9.6;
  static const double weekBulletGoal    = 14.0;
  static const double monthBulletCurrent = 38.2;
  static const double monthBulletGoal    = 50.0;

}

/// 분석 스크린: 이번 주 / 이번 달 / 올해 탭 구조
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _tab = 0; // 0: 이번 주, 1: 이번 달, 2: 올해
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ref.read(tabScrollControllersProvider)[2];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding, 20,
            AppTheme.screenPadding, 40,
          ),
          children: [
            Text('분석', style: AppTheme.headingLarge.copyWith(color: context.appTextPrimary)),
            const SizedBox(height: 16),
            _TabSelector(selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 24),
            ...(_tab == 0
                ? _buildWeekContent()
                : _tab == 1
                    ? _buildMonthContent()
                    : _buildYearContent()),
          ],
        ),
      ),
    );
  }

  // ─── 이번 주 콘텐츠 ─────────────────────────────────────────────────
  List<Widget> _buildWeekContent() => [
        ChorokSectionHeader(
          title: '이번 주 독서',
          subtitle: '3월 23일 – 29일',
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _SummaryCard(
          mainValue: '9',
          mainUnit: '시간 38분',
          stats: const [
            (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '5일', color: null),
            (icon: Icons.format_quote_rounded, label: '수집 문장', value: '47개', color: AppTheme.accent),
            (icon: Icons.trending_up_rounded, label: '전주 대비', value: '+23%', color: AppTheme.primaryLight),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 목표'),
        const SizedBox(height: AppTheme.spaceMD),
        const BulletGraphWidget(
          label: '주간 독서 목표',
          currentHours: AnalyticsMockData.weekBulletCurrent,
          goalHours: AnalyticsMockData.weekBulletGoal,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '요일별 독서 시간'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: _BarChart(
            labels: const ['월', '화', '수', '목', '금', '토', '일'],
            values: const [85, 42, 120, 65, 30, 153, 83],
            highlightIndex: DateTime.now().weekday - 1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '요일별 독서 리듬'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: _BarChart(
            labels: const ['월', '화', '수', '목', '금', '토', '일'],
            values: const [85, 42, 120, 65, 30, 153, 83],
            highlightIndex: DateTime.now().weekday - 1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '시간대별 독서 패턴'),
        const SizedBox(height: AppTheme.spaceMD),
        const _TimeOfDayChart(
          slots: [
            (label: '새벽', range: '00–06', minutes: 12),
            (label: '오전', range: '06–12', minutes: 65),
            (label: '오후', range: '12–18', minutes: 148),
            (label: '저녁', range: '18–24', minutes: 353),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '집중도',
          trailing: Text('이번 주 83점',
              style: AppTheme.captionLarge.copyWith(color: AppTheme.primaryLight)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _FocusCard(
          score: 83,
          label: '이번 주 집중도',
          description: '훌륭해요! 지난주보다 집중력이 높아졌어요.',
          stat1Label: '최장 연속',
          stat1Value: '2시간 15분',
          stat2Label: '평균 세션',
          stat2Value: '38분',
          stat3Label: '평균 속도',
          stat3Value: '분당 14p',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '독서 습관 레이더'),
        const SizedBox(height: AppTheme.spaceMD),
        const HabitRadarChartWidget(
          current:  AnalyticsMockData.currentMonthRadar,
          previous: AnalyticsMockData.previousMonthRadar,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '최근 독서 세션',
          trailing: TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _showAllSessions(context);
            },
            child: Text('전체', style: AppTheme.captionLarge.copyWith(color: AppTheme.primaryLight)),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        const _SessionList(sessions: [
          (title: '채식주의자', author: '한강', duration: '1시간 23분', date: '오늘'),
          (title: '82년생 김지영', author: '조남주', duration: '52분', date: '어제'),
          (title: '아몬드', author: '손원평', duration: '1시간 8분', date: '2일 전'),
          (title: '채식주의자', author: '한강', duration: '41분', date: '3일 전'),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 수집 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const _HighlightPreview(highlights: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강'),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평'),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '내 문장에 온 반응'),
        const SizedBox(height: AppTheme.spaceMD),
        const _SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 34, isTop: true),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평', reactions: 21, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _CommunityHighlightsCard(highlights: [
          (text: '어떤 책이든 결국은 사람 이야기야. 우리가 살아가는 이야기.', book: '파친코 — 이민진', reactions: 128),
          (text: '고통이 있는 곳에 이야기가 있고, 이야기가 있는 곳에 위로가 있다.', book: '소년이 온다 — 한강', reactions: 97),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 독서 성향'),
        const SizedBox(height: AppTheme.spaceMD),
        const _ReadingPersonaCard(
          persona: '저녁형 독서가',
          icon: Icons.nights_stay_rounded,
          description: '하루의 끝자락, 고요한 밤에 책장을 펼치는 사람이에요. 저녁 독서 비중이 61%로, 일상의 마무리 루틴이 확실하게 자리잡혔어요. 이 루틴이 계속되는 한, 집중도는 자연스럽게 높아질 거예요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _QualitativeInsightCard(
          icon: Icons.auto_awesome_rounded,
          message: '5일 연속 책을 펼쳤어요. 독서가 더 이상 \'해야 할 일\'이 아닌 자연스러운 하루의 일부가 된 것 같아요. 특히 수요일엔 2시간 넘게 집중했는데, 그 몰입의 순간이 이번 주를 빛나게 했어요.',
        ),
      ];

  // ─── 이번 달 콘텐츠 ─────────────────────────────────────────────────
  List<Widget> _buildMonthContent() => [
        const ChorokSectionHeader(
          title: '이번 달 독서',
          subtitle: '2026년 3월',
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _SummaryCard(
          mainValue: '38',
          mainUnit: '시간 12분',
          stats: const [
            (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '18일', color: null),
            (icon: Icons.format_quote_rounded, label: '수집 문장', value: '183개', color: AppTheme.accent),
            (icon: Icons.trending_up_rounded, label: '전월 대비', value: '+8%', color: AppTheme.primaryLight),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '독서 캘린더'),
        const SizedBox(height: AppTheme.spaceMD),
        HeatmapCalendarWidget(
          year: 2026,
          data: AnalyticsMockData.heatmap2026,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '독서 밀도'),
        const SizedBox(height: AppTheme.spaceMD),
        const _ReadingDensityCard(
          readDays: 18,
          totalDays: 31,
          maxStreak: 5,
          streakDescription: '이틀에 한 번 이상 책을 펼쳤어요. 독서가 삶의 자연스러운 리듬으로 스며들고 있어요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '집중도',
          trailing: Text('이번 달 79점',
              style: AppTheme.captionLarge.copyWith(color: AppTheme.primaryLight)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _FocusCard(
          score: 79,
          label: '이번 달 집중도',
          description: '꾸준히 읽고 있어요. 조금만 더 집중해 볼까요?',
          stat1Label: '최장 연속',
          stat1Value: '3시간 42분',
          stat2Label: '평균 세션',
          stat2Value: '44분',
          stat3Label: '평균 속도',
          stat3Value: '분당 15p',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 완독'),
        const SizedBox(height: AppTheme.spaceSM),
        const _FinishedBookList(books: [
          (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
          (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 베스트 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const _SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 89, isTop: true),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평', reactions: 54, isTop: false),
          (text: '역사는 우리가 어떻게 살았는지를 기억한다.', book: '파친코 — 이민진', reactions: 31, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _CommunityHighlightsCard(highlights: [
          (text: '삶은 우리가 원하는 대로 흘러가지 않는다. 하지만 그 흐름 속에서 우리는 자신을 발견한다.', book: '채식주의자 — 한강', reactions: 312),
          (text: '누군가를 사랑한다는 것은 그 사람의 이야기를 끝까지 듣는 것이다.', book: '아몬드 — 손원평', reactions: 241),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _QualitativeInsightCard(
          icon: Icons.auto_awesome_rounded,
          message: '18일, 그러니까 이틀에 한 번 이상 책을 펼쳤어요. 이번 달엔 한강과 손원평의 이야기 속으로 완전히 빠져들었고, 두 권을 완독했어요. 지난달보다 더 깊이, 더 오래 읽고 있어요.',
          subMessage: '같은 시간에 더 많은 페이지를 읽었다는 건, 집중력이 자라고 있다는 신호예요.',
        ),
      ];

  // ─── 올해 콘텐츠 ────────────────────────────────────────────────────
  List<Widget> _buildYearContent() => [
        const ChorokSectionHeader(
          title: '올해 독서',
          subtitle: '2026년',
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _SummaryCard(
          mainValue: '142',
          mainUnit: '시간',
          stats: const [
            (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '68일', color: null),
            (icon: Icons.menu_book_rounded, label: '완독', value: '9권', color: AppTheme.accent),
            (icon: Icons.format_quote_rounded, label: '수집 문장', value: '712개', color: null),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '연간 목표'),
        const SizedBox(height: AppTheme.spaceMD),
        const _GoalProgressCard(current: 9, goal: 20),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '월별 독서 시간'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: _BarChart(
            labels: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
            values: const [620, 480, 560, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            highlightIndex: DateTime.now().month - 1,
            labelSuffix: '월',
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '월별 활동 다이얼'),
        const SizedBox(height: AppTheme.spaceMD),
        _YearMonthDials(
          values: const [620, 480, 560, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          highlightIndex: DateTime.now().month - 1,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '집중도',
          trailing: Text('올해 평균 81점',
              style: AppTheme.captionLarge.copyWith(color: AppTheme.primaryLight)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        _FocusCard(
          score: 81,
          label: '올해 평균 집중도',
          description: '올해도 좋은 독서 습관을 유지하고 있어요.',
          stat1Label: '최장 연속일',
          stat1Value: '14일',
          stat2Label: '평균 세션',
          stat2Value: '41분',
          stat3Label: '평균 속도',
          stat3Value: '분당 15p',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 완독한 책'),
        const SizedBox(height: AppTheme.spaceSM),
        const _FinishedBookList(books: [
          (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
          (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
          (title: '82년생 김지영', author: '조남주', date: '2월 8일', pages: 190),
          (title: '달러구트 꿈 백화점', author: '이미예', date: '1월 21일', pages: 304),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '장르 분포'),
        const SizedBox(height: AppTheme.spaceMD),
        _GenreChart(
          genres: [
            (name: '소설', count: 6, color: AppTheme.primaryLight),
            (name: '에세이', count: 2, color: AppTheme.accent),
            (name: '자기계발', count: 1, color: context.appTextSecondary),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해의 독서 정체성'),
        const SizedBox(height: AppTheme.spaceMD),
        const _ReaderIdentityCard(
          identity: '소설 탐험가',
          icon: Icons.explore_rounded,
          description: '올해 읽은 9권 중 6권이 소설이에요. 인물의 내면을 따라가며 세상을 이해하는 당신만의 방식이 느껴져요. 한강, 손원평, 이민진의 문장들 속에서 당신은 타인의 삶을 깊이 들여다보고 있었어요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 가장 공감받은 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const _SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 341, isTop: true),
          (text: '역사는 우리가 어떻게 살았는지를 기억한다.', book: '파친코 — 이민진', reactions: 189, isTop: false),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어.', book: '아몬드 — 손원평', reactions: 124, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _CommunityHighlightsCard(highlights: [
          (text: '삶은 우리가 원하는 대로 흘러가지 않는다. 하지만 그 흐름 속에서 우리는 자신을 발견한다.', book: '채식주의자 — 한강', reactions: 2841),
          (text: '어떤 책이든 결국은 사람 이야기야. 우리가 살아가는 이야기.', book: '파친코 — 이민진', reactions: 1932),
          (text: '고통이 있는 곳에 이야기가 있고, 이야기가 있는 곳에 위로가 있다.', book: '소년이 온다 — 한강', reactions: 1547),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _QualitativeInsightCard(
          icon: Icons.emoji_events_rounded,
          message: '142시간. 그 숫자보다 더 의미 있는 건, 매달 꼬박 책장을 넘겼다는 사실이에요. 어떤 달은 조금 느리게, 어떤 달은 힘차게 — 그 흐름 자체가 올해 당신의 독서 이야기예요.',
          subMessage: '연간 목표의 45%를 3개월 만에 달성했어요. 이 속도라면 연말엔 목표를 훌쩍 넘어설 거예요.',
        ),
      ];

  void _showAllSessions(BuildContext context) {
    const allSessions = [
      (title: '채식주의자', author: '한강', duration: '1시간 23분', date: '오늘'),
      (title: '82년생 김지영', author: '조남주', duration: '52분', date: '어제'),
      (title: '아몬드', author: '손원평', duration: '1시간 8분', date: '2일 전'),
      (title: '채식주의자', author: '한강', duration: '41분', date: '3일 전'),
      (title: '파친코', author: '이민진', duration: '2시간 15분', date: '4일 전'),
      (title: '채식주의자', author: '한강', duration: '35분', date: '5일 전'),
      (title: '아몬드', author: '손원평', duration: '48분', date: '6일 전'),
      (title: '82년생 김지영', author: '조남주', duration: '1시간 2분', date: '1주 전'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('전체 독서 세션',
                      style: AppTheme.headingMedium
                          .copyWith(color: context.appTextPrimary)),
                  const Spacer(),
                  Text('${allSessions.length}회',
                      style: AppTheme.captionLarge
                          .copyWith(color: AppTheme.accent)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                itemCount: allSessions.length,
                separatorBuilder: (_, i) => Divider(
                    color: context.appBorder, height: 1, indent: 64),
                itemBuilder: (_, i) {
                  final s = allSessions[i];
                  return _SessionTile(
                    title: s.title,
                    author: s.author,
                    duration: s.duration,
                    date: s.date,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 탭 선택 ───────────────────────────────────────────────────────────
class _TabSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _TabSelector({required this.selected, required this.onChanged});

  static const double _trackHeight = 48;

  @override
  Widget build(BuildContext context) {
    const tabs = ['이번 주', '이번 달', '올해'];
    return SizedBox(
      height: _trackHeight,
      child: Container(
        decoration: AppTheme.smoothPill(
          color: context.appCard,
          side: BorderSide(color: context.appBorder),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final isSelected = e.key == selected;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(e.key);
                  },
                  customBorder: const StadiumBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: AppTheme.smoothPill(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : context.appTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── 요약 카드 (공통) ──────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String mainValue;
  final String mainUnit;
  final List<({IconData icon, String label, String value, Color? color})> stats;

  const _SummaryCard({
    required this.mainValue,
    required this.mainUnit,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GradientText(mainValue,
                  style: AppTheme.displayLarge,
                  gradient: AppTheme.greenGradientVertical),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: GradientText(mainUnit,
                    style: AppTheme.headingMedium,
                    gradient: AppTheme.greenGradient),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: stats.asMap().entries.expand((e) => [
              Expanded(
                child: ChorokStatCell(
                  label: e.value.label,
                  value: e.value.value,
                  icon: e.value.icon,
                  valueColor: e.value.color,
                ),
              ),
              if (e.key < stats.length - 1)
                const SizedBox(width: AppTheme.spaceMD),
            ]).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── 바 차트 (공통) ────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final int highlightIndex;
  final String labelSuffix;

  const _BarChart({
    required this.labels,
    required this.values,
    required this.highlightIndex,
    this.labelSuffix = '',
  });

  // 바 최대 높이 고정 — LayoutBuilder 없이 비율 기반 계산
  static const double _kBarMaxH = 100.0;

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(labels.length, (i) {
        final ratio = maxVal == 0 ? 0.0 : values[i] / maxVal;
        final isHighlight = i == highlightIndex;
        final mins = values[i];

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHighlight && mins > 0)
                  Text(
                    mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m',
                    style: AppTheme.captionSmall.copyWith(color: AppTheme.accent),
                  ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  height: _kBarMaxH * ratio,
                  decoration: BoxDecoration(
                    color: isHighlight
                        ? AppTheme.primaryLight
                        : AppTheme.primary.withValues(alpha: 0.35),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${labels[i]}$labelSuffix',
                  style: AppTheme.captionSmall.copyWith(
                    fontSize: labels.length > 8 ? 10 : null,
                    color: isHighlight ? AppTheme.primaryLight : context.appTextTertiary,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ─── 집중도 카드 (공통) ────────────────────────────────────────────────
class _FocusCard extends StatelessWidget {
  final int score;
  final String label;
  final String description;
  final String stat1Label;
  final String stat1Value;
  final String stat2Label;
  final String stat2Value;
  final String stat3Label;
  final String stat3Value;

  const _FocusCard({
    required this.score,
    required this.label,
    required this.description,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
    required this.stat3Label,
    required this.stat3Value,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor: context.appBorder,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primaryLight),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text('$score',
                          style: AppTheme.displaySmall.copyWith(color: AppTheme.primaryLight)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceXL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTheme.headingSmall.copyWith(color: context.appTextPrimary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: [
              Expanded(
                child: ChorokStatCell(
                  label: stat1Label, value: stat1Value, icon: Icons.timer_rounded),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: ChorokStatCell(
                  label: stat2Label, value: stat2Value,
                  valueColor: AppTheme.accent, icon: Icons.schedule_rounded),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: ChorokStatCell(
                  label: stat3Label, value: stat3Value,
                  valueColor: AppTheme.primaryLight, icon: Icons.speed_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 최근 세션 목록 ────────────────────────────────────────────────────
class _SessionList extends StatelessWidget {
  final List<({String title, String author, String duration, String date})> sessions;
  const _SessionList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(sessions.length, (i) {
          final s = sessions[i];
          return Column(
            children: [
              _SessionTile(
                  title: s.title, author: s.author,
                  duration: s.duration, date: s.date),
              if (i < sessions.length - 1)
                Divider(height: 1, color: context.appBorder, indent: 64),
            ],
          );
        }),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String title, author, duration, date;
  const _SessionTile({
    required this.title, required this.author,
    required this.duration, required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPaddingMD, vertical: AppTheme.spaceMD),
      child: Row(
        children: [
          Container(
            width: 36, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.menu_book_rounded, color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                const SizedBox(height: 2),
                Text(author, style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(duration, style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(date, style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 시간대별 독서 패턴 ─────────────────────────────────────────────────
class _TimeOfDayChart extends StatelessWidget {
  final List<({String label, String range, int minutes})> slots;

  const _TimeOfDayChart({required this.slots});

  @override
  Widget build(BuildContext context) {
    final maxMins = slots.map((s) => s.minutes).reduce((a, b) => a > b ? a : b);
    final total = slots.fold(0, (sum, s) => sum + s.minutes);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        children: List.generate(slots.length, (i) {
          final s = slots[i];
          final ratio = maxMins == 0 ? 0.0 : s.minutes / maxMins;
          final pct = total == 0 ? 0 : (s.minutes / total * 100).round();
          final isLast = i == slots.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.label,
                          style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
                      Text(s.range,
                          style: AppTheme.captionSmall.copyWith(
                            fontSize: 10,
                            color: context.appTextTertiary,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(
                        ratio >= 0.8
                            ? AppTheme.primaryLight
                            : ratio >= 0.4
                                ? AppTheme.accent
                                : AppTheme.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: AppTheme.captionSmall.copyWith(
                      color: ratio >= 0.8 ? AppTheme.primaryLight : context.appTextTertiary,
                      fontWeight: ratio >= 0.8 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── 정성적 인사이트 카드 ─────────────────────────────────────────────
class _QualitativeInsightCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const _QualitativeInsightCard({
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: AppTheme.smoothBox(
                  gradient: AppTheme.greenGradient,
                  radius: AppTheme.radiusMD,
                ),
                child: Icon(icon, color: Colors.black, size: 18),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: context.appTextPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.smoothBox(
                color: AppTheme.primary.withValues(alpha: 0.2),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                radius: AppTheme.radiusMD,
              ),
              child: Text(
                subMessage!,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 수집 문장 미리보기 ────────────────────────────────────────────────
class _HighlightPreview extends StatelessWidget {
  final List<({String text, String book})> highlights;

  const _HighlightPreview({required this.highlights});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(highlights.length, (i) {
          final h = highlights[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: IntrinsicHeight(
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
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\u201c${h.text}\u201d',
                              style: AppTheme.bodySmall.copyWith(
                                color: context.appTextSecondary,
                                height: 1.6,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.spaceSM),
                            Text(
                              '— ${h.book}',
                              style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < highlights.length - 1)
                Divider(height: 1, color: context.appBorder, indent: 35),
            ],
          );
        }),
      ),
    );
  }
}

// ─── 연간 목표 진행 ───────────────────────────────────────────────────
class _GoalProgressCard extends StatelessWidget {
  final int current;
  final int goal;

  const _GoalProgressCard({required this.current, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = (current / goal).clamp(0.0, 1.0);
    final remaining = goal - current;
    final pct = (progress * 100).round();

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('연간 독서 목표',
                        style: AppTheme.captionLarge.copyWith(color: context.appTextTertiary)),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GradientText(
                          '$current',
                          style: AppTheme.displaySmall,
                          gradient: AppTheme.greenGradientVertical,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            '/ $goal권',
                            style: AppTheme.headingSmall.copyWith(color: context.appTextTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: AppTheme.smoothPill(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  side: BorderSide(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$pct%',
                  style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.appBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryLight),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            remaining > 0
                ? '목표까지 $remaining권 남았어요. 이 속도라면 충분히 달성할 수 있어요!'
                : '올해 목표를 달성했어요! 정말 대단해요!',
            style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── 장르 분포 ────────────────────────────────────────────────────────
class _GenreChart extends StatelessWidget {
  final List<({String name, int count, Color color})> genres;

  const _GenreChart({required this.genres});

  @override
  Widget build(BuildContext context) {
    final total = genres.fold(0, (sum, g) => sum + g.count);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        children: List.generate(genres.length, (i) {
          final g = genres[i];
          final ratio = total == 0 ? 0.0 : g.count / total;
          final isLast = i == genres.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: g.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: Text(g.name,
                      style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(g.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text('${g.count}권',
                      textAlign: TextAlign.right,
                      style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── 완독 책 목록 ──────────────────────────────────────────────────────
class _FinishedBookList extends StatelessWidget {
  final List<({String title, String author, String date, int pages})> books;
  const _FinishedBookList({required this.books});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(books.length, (i) {
          final b = books[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.cardPaddingMD, vertical: AppTheme.spaceMD),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.check_rounded, color: AppTheme.primaryLight, size: 18),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.title, style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600, color: context.appTextPrimary)),
                          const SizedBox(height: 2),
                          Text(b.author,
                              style: AppTheme.captionLarge.copyWith(color: context.appTextSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(b.date, style: AppTheme.captionLarge.copyWith(
                            color: AppTheme.primaryLight, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('${b.pages}p',
                            style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < books.length - 1)
                Divider(height: 1, color: context.appBorder, indent: 64),
            ],
          );
        }),
      ),
    );
  }
}

// ─── 이번 주 독서 성향 카드 ────────────────────────────────────────────
class _ReadingPersonaCard extends StatelessWidget {
  final String persona;
  final IconData icon;
  final String description;

  const _ReadingPersonaCard({
    required this.persona,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: AppTheme.smoothBox(
              gradient: AppTheme.greenGradient,
              radius: AppTheme.radiusMD,
            ),
            child: Icon(icon, color: Colors.black, size: 24),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  persona,
                  style: AppTheme.headingMedium.copyWith(color: AppTheme.primaryLight),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextSecondary,
                    height: 1.6,
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

// ─── 이번 달 독서 밀도 카드 ───────────────────────────────────────────
class _ReadingDensityCard extends StatelessWidget {
  final int readDays;
  final int totalDays;
  final int maxStreak;
  final String streakDescription;

  const _ReadingDensityCard({
    required this.readDays,
    required this.totalDays,
    required this.maxStreak,
    required this.streakDescription,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = readDays / totalDays;
    final pct = (ratio * 100).round();

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '독서한 날',
                      style: AppTheme.captionLarge.copyWith(color: context.appTextTertiary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GradientText(
                          '$readDays',
                          style: AppTheme.displaySmall,
                          gradient: AppTheme.greenGradientVertical,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 4),
                          child: Text(
                            '/ $totalDays일',
                            style: AppTheme.headingSmall.copyWith(color: context.appTextTertiary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('최장 연속', style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary)),
                  const SizedBox(height: 4),
                  Text('$maxStreak일', style: AppTheme.headingSmall.copyWith(color: AppTheme.accent)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: context.appBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryLight),
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '$pct%의 날을 책과 함께했어요',
            style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: AppTheme.smoothBox(
              color: AppTheme.primary.withValues(alpha: 0.2),
              side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
              radius: AppTheme.radiusMD,
            ),
            child: Text(
              streakDescription,
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 올해의 독서 정체성 카드 ──────────────────────────────────────────
class _ReaderIdentityCard extends StatelessWidget {
  final String identity;
  final IconData icon;
  final String description;

  const _ReaderIdentityCard({
    required this.identity,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: AppTheme.smoothBox(
                  gradient: AppTheme.greenGradient,
                  radius: AppTheme.radiusMD,
                ),
                child: Icon(icon, color: Colors.black, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Text(
                '올해 나는',
                style: AppTheme.captionLarge.copyWith(color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          GradientText(
            identity,
            style: AppTheme.displaySmall.copyWith(height: 1.1),
            gradient: AppTheme.greenGradientVertical,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 내 문장 반응 카드 ────────────────────────────────────────────────
class _SentenceReactionsCard extends StatelessWidget {
  final List<({String text, String book, int reactions, bool isTop})> sentences;

  const _SentenceReactionsCard({required this.sentences});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(sentences.length, (i) {
          final s = sentences[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: s.isTop
                            ? AppTheme.greenGradientVertical
                            : LinearGradient(
                                colors: [
                                  AppTheme.primary.withValues(alpha: 0.6),
                                  AppTheme.primary.withValues(alpha: 0.3),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u201c${s.text}\u201d',
                            style: AppTheme.bodySmall.copyWith(
                              color: context.appTextSecondary,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '— ${s.book}',
                            style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (s.isTop)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: AppTheme.smoothPill(
                              gradient: AppTheme.greenGradient,
                            ),
                            child: Text(
                              'TOP',
                              style: AppTheme.captionSmall.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 12, color: AppTheme.primaryLight),
                            const SizedBox(width: 3),
                            Text(
                              '${s.reactions}',
                              style: AppTheme.captionSmall.copyWith(
                                color: AppTheme.primaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < sentences.length - 1)
                Divider(height: 1, color: context.appBorder, indent: 19),
            ],
          );
        }),
      ),
    );
  }
}

// ─── 커뮤니티 하이라이트 카드 ─────────────────────────────────────────
class _CommunityHighlightsCard extends StatelessWidget {
  final List<({String text, String book, int reactions})> highlights;

  const _CommunityHighlightsCard({required this.highlights});

  String _formatReactions(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(highlights.length, (i) {
          final h = highlights[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.captionLarge.copyWith(
                            color: AppTheme.primaryLight,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\u201c${h.text}\u201d',
                            style: AppTheme.bodySmall.copyWith(
                              color: context.appTextPrimary,
                              height: 1.55,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '— ${h.book}',
                                style: AppTheme.captionSmall.copyWith(
                                    color: context.appTextTertiary),
                              ),
                              const Spacer(),
                              const Icon(Icons.favorite_rounded,
                                  size: 11, color: AppTheme.accent),
                              const SizedBox(width: 3),
                              Text(
                                _formatReactions(h.reactions),
                                style: AppTheme.captionSmall.copyWith(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < highlights.length - 1)
                Divider(height: 1, color: context.appBorder, indent: 64),
            ],
          );
        }),
      ),
    );
  }
}

// ─── 연간: 월별 원형 다이얼 차트 ─────────────────────────────────────────
class _YearMonthDials extends StatelessWidget {
  final List<int> values; // 12 months, reading minutes each
  final int highlightIndex; // current month index (0–11)

  const _YearMonthDials({
    required this.values,
    required this.highlightIndex,
  });

  static const _monthLabels = [
    '1월', '2월', '3월', '4월',
    '5월', '6월', '7월', '8월',
    '9월', '10월', '11월', '12월',
  ];

  @override
  Widget build(BuildContext context) {
    final maxVal = values
        .where((v) => v > 0)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppTheme.spaceMD,
          crossAxisSpacing: AppTheme.spaceSM,
          childAspectRatio: 0.88,
        ),
        itemCount: 12,
        itemBuilder: (_, i) {
          final mins = values[i];
          final isFuture = i > highlightIndex;
          final isCurrent = i == highlightIndex;
          final ratio = isFuture ? 0.0 : (mins / maxVal).clamp(0.0, 1.0);

          final dialColor = isCurrent
              ? AppTheme.primaryLight
              : mins > 0
                  ? AppTheme.accent.withValues(alpha: 0.4 + 0.6 * ratio)
                  : context.appBorder.withValues(alpha: 0.4);

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: isCurrent ? 5.0 : 3.5,
                      backgroundColor: context.appBorder.withValues(alpha: 0.35),
                      valueColor: AlwaysStoppedAnimation(dialColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Text(
                      _monthLabels[i],
                      style: AppTheme.captionSmall.copyWith(
                        fontSize: 10,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent
                            ? AppTheme.primaryLight
                            : isFuture
                                ? context.appTextTertiary.withValues(alpha: 0.5)
                                : context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                isFuture || mins == 0
                    ? '—'
                    : mins >= 60
                        ? '${mins ~/ 60}h'
                        : '${mins}m',
                style: AppTheme.captionSmall.copyWith(
                  fontSize: 10,
                  color: isCurrent ? AppTheme.accent : context.appTextTertiary,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
