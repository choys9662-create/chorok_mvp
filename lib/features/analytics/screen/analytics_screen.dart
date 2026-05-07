import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../controller/analytics_provider.dart';
import '../widgets/bullet_graph_widget.dart';
import '../widgets/habit_radar_chart_widget.dart';
import '../widgets/heatmap_calendar_widget.dart';
import '../widget/analytics_charts.dart';
import '../widget/analytics_summary_cards.dart';
import '../widget/analytics_persona_cards.dart';
import '../widget/analytics_lists.dart';
import '../widget/analytics_community_cards.dart';
import '../widget/analytics_ui_elements.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// ─── Mock 데이터 ─────────────────────────────────────────────────────────

class AnalyticsMockData {
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

  static const List<double> currentMonthRadar  = [0.80, 0.65, 0.83, 0.70, 0.90];
  static const List<double> previousMonthRadar = [0.55, 0.45, 0.60, 0.50, 0.70];
  static const double weekBulletGoal  = 14.0;
  static const double monthBulletGoal = 50.0;
}

// ─── 헬퍼 함수 ────────────────────────────────────────────────────────────────

String _mainVal(int secs) => secs >= 3600 ? '${secs ~/ 3600}' : '${secs ~/ 60}';

String _mainUnit(int secs) {
  if (secs >= 3600) {
    final m = (secs % 3600) ~/ 60;
    return m > 0 ? '시간 $m분' : '시간';
  }
  return '분';
}

String _fmtDur(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분';
  return '$secs초';
}

String _pct(int curr, int prev) {
  if (prev == 0) return curr > 0 ? '+100%' : '0%';
  final p = ((curr - prev) / prev * 100).round();
  return p >= 0 ? '+$p%' : '$p%';
}

String _focusDesc(int score) {
  if (score >= 90) return '최고예요! 집중도가 매우 높아요.';
  if (score >= 80) return '훌륭해요! 지난주보다 집중력이 높아졌어요.';
  if (score >= 70) return '꾸준히 읽고 있어요. 조금만 더 집중해 볼까요?';
  return '독서를 시작해 볼까요?';
}

/// 분석 스크린: 이번 주 / 이번 달 / 올해 탭 구조
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _tab = 0;
  late final ScrollController _scrollCtrl;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ref.read(tabScrollControllersProvider)[2];
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final AnalyticsState? a =
        _useMock ? null : ref.watch(analyticsProvider).valueOrNull;

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekSubtitle = weekEnd.month == weekStart.month
        ? '${weekStart.month}월 ${weekStart.day}일 – ${weekEnd.day}일'
        : '${weekStart.month}월 ${weekStart.day}일 – ${weekEnd.month}월 ${weekEnd.day}일';

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
              ? _buildWeekContent(a, weekSubtitle, now)
              : _tab == 1
                  ? _buildMonthContent(a, now)
                  : _buildYearContent(a, now)),
        ],
      ),
    );
  }

  // ─── 이번 주 콘텐츠 ─────────────────────────────────────────────────
  List<Widget> _buildWeekContent(AnalyticsState? a, String subtitle, DateTime now) {
    final totalSecs   = a?.weekTotalSeconds      ?? (9 * 3600 + 38 * 60);
    final readDays    = a?.weekReadDays           ?? 5;
    final choseoCount = a?.weekChoseoCount        ?? 47;
    final prevSecs    = a?.prevWeekTotalSeconds   ?? (7 * 3600 + 50 * 60);
    final dailyMin    = a?.weekDailyMinutes       ?? const [85, 42, 120, 65, 30, 153, 83];
    final timeOfDay   = a?.weekTimeOfDay          ?? const [
      (label: '새벽', range: '00–06', minutes: 12),
      (label: '오전', range: '06–12', minutes: 65),
      (label: '오후', range: '12–18', minutes: 148),
      (label: '저녁', range: '18–24', minutes: 353),
    ];
    final focusScore  = a?.weekFocusScore         ?? 83;
    final maxSessMin  = a?.weekMaxSessionMinutes  ?? 135;
    final avgSessMin  = a?.weekAvgSessionMinutes  ?? 38;
    final radar       = a?.weekRadar              ?? AnalyticsMockData.currentMonthRadar;
    final prevRadar   = _useMock
        ? AnalyticsMockData.previousMonthRadar
        : const <double>[0.0, 0.0, 0.0, 0.0, 0.0];
    final sessions    = a?.weekSessions           ?? const [
      (title: '채식주의자', author: '한강', duration: '1시간 23분', date: '오늘'),
      (title: '82년생 김지영', author: '조남주', duration: '52분', date: '어제'),
      (title: '아몬드', author: '손원평', duration: '1시간 8분', date: '2일 전'),
      (title: '채식주의자', author: '한강', duration: '41분', date: '3일 전'),
    ];
    final allSessions = a?.allRecentSessions      ?? const [
      (title: '채식주의자', author: '한강', duration: '1시간 23분', date: '오늘'),
      (title: '82년생 김지영', author: '조남주', duration: '52분', date: '어제'),
      (title: '아몬드', author: '손원평', duration: '1시간 8분', date: '2일 전'),
      (title: '채식주의자', author: '한강', duration: '41분', date: '3일 전'),
      (title: '파친코', author: '이민진', duration: '2시간 15분', date: '4일 전'),
      (title: '채식주의자', author: '한강', duration: '35분', date: '5일 전'),
      (title: '아몬드', author: '손원평', duration: '48분', date: '6일 전'),
      (title: '82년생 김지영', author: '조남주', duration: '1시간 2분', date: '1주 전'),
    ];
    final highlights = a != null
        ? a.weekChoseo.take(2).map((c) => (
              text: c.content,
              book: c.bookTitle.isNotEmpty
                  ? '${c.bookTitle}${c.bookAuthor.isNotEmpty ? ' — ${c.bookAuthor}' : ''}'
                  : '알 수 없는 책',
            )).toList()
        : const [
            (text: '나는 채식을 한다. 그게 다야. 나한테 피해 주지 않잖아.', book: '채식주의자 — 한강'),
            (text: '나는 살아있다고 느끼는 순간이 거의 없었어. 어릴 때부터 죽은 것처럼 살아왔어.', book: '아몬드 — 손원평'),
          ];

    return [
      ChorokSectionHeader(title: '이번 주 독서', subtitle: subtitle),
      const SizedBox(height: AppTheme.spaceMD),
      SummaryCard(
        mainValue: _mainVal(totalSecs),
        mainUnit: _mainUnit(totalSecs),
        stats: [
          (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '$readDays일', color: null),
          (icon: Icons.format_quote_rounded, label: '수집 문장', value: '$choseoCount개', color: context.appAccentColor),
          (icon: Icons.trending_up_rounded, label: '전주 대비', value: _pct(totalSecs, prevSecs), color: context.appPrimaryAccent),
        ],
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '이번 주 목표'),
      const SizedBox(height: AppTheme.spaceMD),
      BulletGraphWidget(
        label: '주간 독서 목표',
        currentHours: totalSecs / 3600.0,
        goalHours: AnalyticsMockData.weekBulletGoal,
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '요일별 독서 시간'),
      const SizedBox(height: AppTheme.spaceMD),
      ChorokCard(
        child: BarChart(
          labels: const ['월', '화', '수', '목', '금', '토', '일'],
          values: dailyMin,
          highlightIndex: now.weekday - 1,
        ),
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '요일별 독서 리듬'),
      const SizedBox(height: AppTheme.spaceMD),
      ChorokCard(
        child: LineRhythmChart(
          labels: const ['월', '화', '수', '목', '금', '토', '일'],
          values: dailyMin,
          highlightIndex: now.weekday - 1,
        ),
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '시간대별 독서 패턴'),
      const SizedBox(height: AppTheme.spaceMD),
      TimeOfDayChart(slots: timeOfDay),
      const SizedBox(height: AppTheme.spaceXL),

      ChorokSectionHeader(
        title: '집중도',
        trailing: Text('이번 주 $focusScore점',
            style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
      ),
      const SizedBox(height: AppTheme.spaceMD),
      FocusCard(
        score: focusScore,
        label: '이번 주 집중도',
        description: _useMock
            ? '훌륭해요! 지난주보다 집중력이 높아졌어요.'
            : _focusDesc(focusScore),
        stat1Label: '최장 연속',
        stat1Value: _fmtDur(maxSessMin * 60),
        stat2Label: '평균 세션',
        stat2Value: _fmtDur(avgSessMin * 60),
        stat3Label: '평균 속도',
        stat3Value: '분당 14p',
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '독서 습관 레이더'),
      const SizedBox(height: AppTheme.spaceMD),
      HabitRadarChartWidget(current: radar, previous: prevRadar),
      const SizedBox(height: AppTheme.spaceXL),

      ChorokSectionHeader(
        title: '최근 독서 세션',
        trailing: TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            _showAllSessions(context, allSessions);
          },
          child: Text('전체', style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
        ),
      ),
      const SizedBox(height: AppTheme.spaceSM),
      SessionList(sessions: sessions),
      const SizedBox(height: AppTheme.spaceXL),

      if (highlights.isNotEmpty) ...[
        const ChorokSectionHeader(title: '이번 주 수집 문장'),
        const SizedBox(height: AppTheme.spaceMD),
        HighlightPreview(highlights: highlights),
        const SizedBox(height: AppTheme.spaceXL),
      ],

      if (_useMock) ...[
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
      ],
    ];
  }

  // ─── 이번 달 콘텐츠 ─────────────────────────────────────────────────
  List<Widget> _buildMonthContent(AnalyticsState? a, DateTime now) {
    final totalSecs    = a?.monthTotalSeconds     ?? (38 * 3600 + 12 * 60);
    final readDays     = a?.monthReadDays          ?? 18;
    final choseoCount  = a?.monthChoseoCount       ?? 183;
    final prevSecs     = a?.prevMonthTotalSeconds  ?? (35 * 3600 + 20 * 60);
    final heatmap      = a?.heatmap                ?? AnalyticsMockData.heatmap2026;
    final totalDays    = a?.monthTotalDays         ?? 31;
    final maxStreak    = a?.monthMaxStreak         ?? 5;
    final focusScore   = a?.monthFocusScore        ?? 79;
    final maxSessMin   = a?.monthMaxSessionMinutes ?? 222;
    final avgSessMin   = a?.monthAvgSessionMinutes ?? 44;
    final monthSubtitle = _useMock ? '2026년 3월' : '${now.year}년 ${now.month}월';
    final heatmapYear   = _useMock ? 2026 : now.year;

    final monthBooks = a != null
        ? a.completedBooks
            .where((b) => b.updatedAt.year == now.year && b.updatedAt.month == now.month)
            .map((b) => (
                  title: b.title,
                  author: b.author,
                  date: '${b.updatedAt.month}월 ${b.updatedAt.day}일',
                  pages: b.totalPages,
                )).toList()
        : const <({String title, String author, String date, int pages})>[
            (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
            (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
          ];

    return [
      ChorokSectionHeader(title: '이번 달 독서', subtitle: monthSubtitle),
      const SizedBox(height: AppTheme.spaceMD),
      SummaryCard(
        mainValue: _mainVal(totalSecs),
        mainUnit: _mainUnit(totalSecs),
        stats: [
          (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '$readDays일', color: null),
          (icon: Icons.format_quote_rounded, label: '수집 문장', value: '$choseoCount개', color: context.appAccentColor),
          (icon: Icons.trending_up_rounded, label: '전월 대비', value: _pct(totalSecs, prevSecs), color: context.appPrimaryAccent),
        ],
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '독서 캘린더'),
      const SizedBox(height: AppTheme.spaceMD),
      HeatmapCalendarWidget(year: heatmapYear, data: heatmap),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '독서 밀도'),
      const SizedBox(height: AppTheme.spaceMD),
      ReadingDensityCard(
        readDays: readDays,
        totalDays: totalDays,
        maxStreak: maxStreak,
        streakDescription: '이틀에 한 번 이상 책을 펼쳤어요. 독서가 삶의 자연스러운 리듬으로 스며들고 있어요.',
      ),
      const SizedBox(height: AppTheme.spaceXL),

      ChorokSectionHeader(
        title: '집중도',
        trailing: Text('이번 달 $focusScore점',
            style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
      ),
      const SizedBox(height: AppTheme.spaceMD),
      FocusCard(
        score: focusScore,
        label: '이번 달 집중도',
        description: _useMock
            ? '꾸준히 읽고 있어요. 조금만 더 집중해 볼까요?'
            : _focusDesc(focusScore),
        stat1Label: '최장 연속',
        stat1Value: _fmtDur(maxSessMin * 60),
        stat2Label: '평균 세션',
        stat2Value: _fmtDur(avgSessMin * 60),
        stat3Label: '평균 속도',
        stat3Value: '분당 15p',
      ),
      const SizedBox(height: AppTheme.spaceXL),

      if (monthBooks.isNotEmpty) ...[
        const ChorokSectionHeader(title: '이번 달 완독'),
        const SizedBox(height: AppTheme.spaceSM),
        FinishedBookList(books: monthBooks),
        const SizedBox(height: AppTheme.spaceXL),
      ],

      if (_useMock) ...[
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
      ],
    ];
  }

  // ─── 올해 콘텐츠 ────────────────────────────────────────────────────
  List<Widget> _buildYearContent(AnalyticsState? a, DateTime now) {
    final totalSecs      = a?.yearTotalSeconds     ?? (142 * 3600);
    final readDays       = a?.yearReadDays          ?? 68;
    final choseoCount    = a?.yearChoseoCount       ?? 712;
    final completedCount = a?.completedBooks.length ?? 9;
    final monthlyMin     = a?.yearMonthlyMinutes    ?? const [620, 480, 560, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    final focusScore     = a?.yearFocusScore        ?? 81;
    final yearSubtitle   = _useMock ? '2026년' : '${now.year}년';

    final allBooks = a != null
        ? a.completedBooks.map((b) => (
              title: b.title,
              author: b.author,
              date: '${b.updatedAt.month}월 ${b.updatedAt.day}일',
              pages: b.totalPages,
            )).toList()
        : const <({String title, String author, String date, int pages})>[
            (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
            (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
            (title: '82년생 김지영', author: '조남주', date: '2월 8일', pages: 190),
            (title: '달러구트 꿈 백화점', author: '이미예', date: '1월 21일', pages: 304),
          ];

    return [
      ChorokSectionHeader(title: '올해 독서', subtitle: yearSubtitle),
      const SizedBox(height: AppTheme.spaceMD),
      SummaryCard(
        mainValue: _mainVal(totalSecs),
        mainUnit: _mainUnit(totalSecs),
        stats: [
          (icon: Icons.calendar_today_rounded, label: '독서 일수', value: '$readDays일', color: null),
          (icon: Icons.menu_book_rounded, label: '완독', value: '$completedCount권', color: AppTheme.accent),
          (icon: Icons.format_quote_rounded, label: '수집 문장', value: '$choseoCount개', color: null),
        ],
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '연간 목표'),
      const SizedBox(height: AppTheme.spaceMD),
      GoalProgressCard(current: completedCount, goal: 20),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '월별 독서 시간'),
      const SizedBox(height: AppTheme.spaceMD),
      ChorokCard(
        child: BarChart(
          labels: const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'],
          values: monthlyMin,
          highlightIndex: now.month - 1,
          labelSuffix: '월',
        ),
      ),
      const SizedBox(height: AppTheme.spaceXL),

      const ChorokSectionHeader(title: '월별 활동 다이얼'),
      const SizedBox(height: AppTheme.spaceMD),
      YearMonthDials(values: monthlyMin, highlightIndex: now.month - 1),
      const SizedBox(height: AppTheme.spaceXL),

      ChorokSectionHeader(
        title: '집중도',
        trailing: Text('올해 평균 $focusScore점',
            style: AppTheme.captionLarge.copyWith(color: context.appPrimaryAccent)),
      ),
      const SizedBox(height: AppTheme.spaceMD),
      FocusCard(
        score: focusScore,
        label: '올해 평균 집중도',
        description: _useMock
            ? '올해도 좋은 독서 습관을 유지하고 있어요.'
            : _focusDesc(focusScore),
        stat1Label: '최장 연속일',
        stat1Value: '14일',
        stat2Label: '평균 세션',
        stat2Value: '41분',
        stat3Label: '평균 속도',
        stat3Value: '분당 15p',
      ),
      const SizedBox(height: AppTheme.spaceXL),

      if (allBooks.isNotEmpty) ...[
        const ChorokSectionHeader(title: '올해 완독한 책'),
        const SizedBox(height: AppTheme.spaceSM),
        FinishedBookList(books: allBooks),
        const SizedBox(height: AppTheme.spaceXL),
      ],

      if (_useMock) ...[
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
      ],
    ];
  }

  void _showAllSessions(BuildContext context, List<SessionEntry> sessions) {
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
                  Text('${sessions.length}회',
                      style: AppTheme.captionLarge
                          .copyWith(color: AppTheme.accent)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: sessions.length,
                separatorBuilder: (_, i) =>
                    Divider(color: context.appBorder, height: 1, indent: 64),
                itemBuilder: (_, i) {
                  final s = sessions[i];
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
