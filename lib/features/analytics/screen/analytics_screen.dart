import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../widgets/bullet_graph_widget.dart';
import '../widgets/habit_radar_chart_widget.dart';
import '../widgets/heatmap_calendar_widget.dart';
import '../widget/analytics_charts.dart';
import '../widget/analytics_summary_cards.dart';
import '../widget/analytics_persona_cards.dart';
import '../widget/analytics_lists.dart';
import '../widget/analytics_community_cards.dart';
import '../widget/analytics_ui_elements.dart';


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
    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: ListView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppTheme.screenPadding, topPad + 20,
          AppTheme.screenPadding, 40,
        ),
          children: [
            Text('분석', style: AppTheme.headingLarge.copyWith(color: context.appTextPrimary)),
            const SizedBox(height: 16),
            TabSelector(selected: _tab, onChanged: (i) => setState(() => _tab = i)),
            const SizedBox(height: 24),
            ...(_tab == 0
                ? _buildWeekContent()
                : _tab == 1
                    ? _buildMonthContent()
                    : _buildYearContent()),
        ],
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
        SummaryCard(
          mainValue: '9',
          mainUnit: '시간 38분',
          stats: [
            (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '5일', color: null),
            (icon: Icons.format_quote_rounded, label: '수집 문장', value: '47개', color: context.appAccentColor),
            (icon: Icons.trending_up_rounded, label: '전주 대비', value: '+23%', color: context.appPrimaryAccent),
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
          child: BarChart(
            labels: const ['월', '화', '수', '목', '금', '토', '일'],
            values: const [85, 42, 120, 65, 30, 153, 83],
            highlightIndex: DateTime.now().weekday - 1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '요일별 독서 리듬'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: LineRhythmChart(
            labels: const ['월', '화', '수', '목', '금', '토', '일'],
            values: const [85, 42, 120, 65, 30, 153, 83],
            highlightIndex: DateTime.now().weekday - 1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '시간대별 독서 패턴'),
        const SizedBox(height: AppTheme.spaceMD),
        const TimeOfDayChart(
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
              style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        FocusCard(
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
            child: Text('전체', style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        const SessionList(sessions: [
          (title: '채식주의자', author: '한강', duration: '1시간 23분', date: '오늘'),
          (title: '82년생 김지영', author: '조남주', duration: '52분', date: '어제'),
          (title: '아몬드', author: '손원평', duration: '1시간 8분', date: '2일 전'),
          (title: '채식주의자', author: '한강', duration: '41분', date: '3일 전'),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 수집 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const HighlightPreview(highlights: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강'),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평'),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '내 문장에 온 반응'),
        const SizedBox(height: AppTheme.spaceMD),
        const SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 34, isTop: true),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평', reactions: 21, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const CommunityHighlightsCard(highlights: [
          (text: '어떤 책이든 결국은 사람 이야기야. 우리가 살아가는 이야기.', book: '파친코 — 이민진', reactions: 128),
          (text: '고통이 있는 곳에 이야기가 있고, 이야기가 있는 곳에 위로가 있다.', book: '소년이 온다 — 한강', reactions: 97),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 독서 성향'),
        const SizedBox(height: AppTheme.spaceMD),
        const ReadingPersonaCard(
          persona: '저녁형 독서가',
          icon: Icons.nights_stay_rounded,
          description: '하루의 끝자락, 고요한 밤에 책장을 펼치는 사람이에요. 저녁 독서 비중이 61%로, 일상의 마무리 루틴이 확실하게 자리잡혔어요. 이 루틴이 계속되는 한, 집중도는 자연스럽게 높아질 거예요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 주 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const QualitativeInsightCard(
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
        SummaryCard(
          mainValue: '38',
          mainUnit: '시간 12분',
          stats: [
            (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '18일', color: null),
            (icon: Icons.format_quote_rounded, label: '수집 문장', value: '183개', color: context.appAccentColor),
            (icon: Icons.trending_up_rounded, label: '전월 대비', value: '+8%', color: context.appPrimaryAccent),
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
        const ReadingDensityCard(
          readDays: 18,
          totalDays: 31,
          maxStreak: 5,
          streakDescription: '이틀에 한 번 이상 책을 펼쳤어요. 독서가 삶의 자연스러운 리듬으로 스며들고 있어요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '집중도',
          trailing: Text('이번 달 79점',
              style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        FocusCard(
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
        const FinishedBookList(books: [
          (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
          (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 베스트 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 89, isTop: true),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평', reactions: 54, isTop: false),
          (text: '역사는 우리가 어떻게 살았는지를 기억한다.', book: '파친코 — 이민진', reactions: 31, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const CommunityHighlightsCard(highlights: [
          (text: '삶은 우리가 원하는 대로 흘러가지 않는다. 하지만 그 흐름 속에서 우리는 자신을 발견한다.', book: '채식주의자 — 한강', reactions: 312),
          (text: '누군가를 사랑한다는 것은 그 사람의 이야기를 끝까지 듣는 것이다.', book: '아몬드 — 손원평', reactions: 241),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const QualitativeInsightCard(
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
        SummaryCard(
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
        const GoalProgressCard(current: 9, goal: 20),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '월별 독서 시간'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: BarChart(
            labels: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
            values: const [620, 480, 560, 0, 0, 0, 0, 0, 0, 0, 0, 0],
            highlightIndex: DateTime.now().month - 1,
            labelSuffix: '월',
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '월별 활동 다이얼'),
        const SizedBox(height: AppTheme.spaceMD),
        YearMonthDials(
          values: const [620, 480, 560, 0, 0, 0, 0, 0, 0, 0, 0, 0],
          highlightIndex: DateTime.now().month - 1,
        ),
        const SizedBox(height: AppTheme.spaceXL),

        ChorokSectionHeader(
          title: '집중도',
          trailing: Text('올해 평균 81점',
              style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        FocusCard(
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
        const FinishedBookList(books: [
          (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
          (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
          (title: '82년생 김지영', author: '조남주', date: '2월 8일', pages: 190),
          (title: '달러구트 꿈 백화점', author: '이미예', date: '1월 21일', pages: 304),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '장르 분포'),
        const SizedBox(height: AppTheme.spaceMD),
        GenreChart(
          genres: [
            (name: '소설', count: 6, color: context.appPrimaryAccent),
            (name: '에세이', count: 2, color: AppTheme.accent),
            (name: '자기계발', count: 1, color: context.appTextSecondary),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해의 독서 정체성'),
        const SizedBox(height: AppTheme.spaceMD),
        const ReaderIdentityCard(
          identity: '소설 탐험가',
          icon: Icons.explore_rounded,
          description: '올해 읽은 9권 중 6권이 소설이에요. 인물의 내면을 따라가며 세상을 이해하는 당신만의 방식이 느껴져요. 한강, 손원평, 이민진의 문장들 속에서 당신은 타인의 삶을 깊이 들여다보고 있었어요.',
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 가장 공감받은 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        const SentenceReactionsCard(sentences: [
          (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강', reactions: 341, isTop: true),
          (text: '역사는 우리가 어떻게 살았는지를 기억한다.', book: '파친코 — 이민진', reactions: 189, isTop: false),
          (text: '나는 살아있다고 느끼는 순간이 거의 없었어.', book: '아몬드 — 손원평', reactions: 124, isTop: false),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 커뮤니티 하이라이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const CommunityHighlightsCard(highlights: [
          (text: '삶은 우리가 원하는 대로 흘러가지 않는다. 하지만 그 흐름 속에서 우리는 자신을 발견한다.', book: '채식주의자 — 한강', reactions: 2841),
          (text: '어떤 책이든 결국은 사람 이야기야. 우리가 살아가는 이야기.', book: '파친코 — 이민진', reactions: 1932),
          (text: '고통이 있는 곳에 이야기가 있고, 이야기가 있는 곳에 위로가 있다.', book: '소년이 온다 — 한강', reactions: 1547),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const QualitativeInsightCard(
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
      shape: SmoothRectangleBorder(
        borderRadius: SmoothBorderRadius.only(
          topLeft: SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.6),
          topRight: SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.6),
        ),
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
                  return SessionTile(
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


// ─── 요약 카드 (공통) ──────────────────────────────────────────────────


// ─── 바 차트 (공통) ────────────────────────────────────────────────────


// ─── 라인 리듬 차트 ────────────────────────────────────────────────────




// ─── 집중도 카드 (공통) ────────────────────────────────────────────────


// ─── 최근 세션 목록 ────────────────────────────────────────────────────




// ─── 시간대별 독서 패턴 ─────────────────────────────────────────────────


// ─── 정성적 인사이트 카드 ─────────────────────────────────────────────


// ─── 수집 문장 미리보기 ────────────────────────────────────────────────


// ─── 연간 목표 진행 ───────────────────────────────────────────────────


// ─── 장르 분포 ────────────────────────────────────────────────────────


// ─── 완독 책 목록 ──────────────────────────────────────────────────────


// ─── 이번 주 독서 성향 카드 ────────────────────────────────────────────


// ─── 이번 달 독서 밀도 카드 ───────────────────────────────────────────


// ─── 올해의 독서 정체성 카드 ──────────────────────────────────────────


// ─── 내 문장 반응 카드 ────────────────────────────────────────────────


// ─── 커뮤니티 하이라이트 카드 ─────────────────────────────────────────


// ─── 연간: 월별 원형 다이얼 차트 ─────────────────────────────────────────

