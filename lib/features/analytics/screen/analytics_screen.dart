import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/tab_scroll_controllers.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_stat_cell.dart';
import '../../../shared/widgets/gradient_text.dart';

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
            Text('분석', style: AppTheme.headingLarge.copyWith(color: AppTheme.textPrimary)),
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

        const ChorokSectionHeader(title: '이번 주 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _RichInsightCard(
          deltas: [
            (label: 'vs 지난주', value: '+23%', isPositive: true),
            (label: '독서일', value: '+1일', isPositive: true),
            (label: '수집 문장', value: '+9개', isPositive: true),
          ],
          icon: Icons.nights_stay_rounded,
          message: '저녁 독서 비중(61%)이 지난주와 비슷하게 유지됐어요. 규칙적인 루틴 덕분에 집중도도 83점으로 올랐어요!',
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

        const ChorokSectionHeader(title: '주차별 독서 시간'),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          child: _BarChart(
            labels: const ['1주', '2주', '3주', '4주', '5주'],
            values: const [320, 480, 560, 410, 390],
            highlightIndex: 3,
          ),
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '독서 캘린더'),
        const SizedBox(height: AppTheme.spaceMD),
        const _CalendarHeatmap(
          year: 2026,
          month: 3,
          readingMinutes: {
            1: 45, 3: 120, 5: 90, 8: 60, 10: 180,
            12: 75, 14: 150, 15: 90, 17: 200, 19: 120,
            20: 45, 21: 180, 22: 60, 24: 90, 26: 240,
            27: 150, 29: 75, 31: 120,
          },
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
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 완독'),
        const SizedBox(height: AppTheme.spaceSM),
        const _FinishedBookList(books: [
          (title: '채식주의자', author: '한강', date: '3월 12일', pages: 247),
          (title: '아몬드', author: '손원평', date: '3월 25일', pages: 264),
        ]),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '이번 달 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _RichInsightCard(
          deltas: [
            (label: '독서 시간', value: '+8%', isPositive: true),
            (label: '독서일', value: '+3일', isPositive: true),
            (label: '페이지/분', value: '+0.4p', isPositive: true),
          ],
          icon: Icons.auto_awesome_rounded,
          message: '같은 시간에 더 많은 페이지를 읽었어요. 지난달보다 집중도가 높아진 것 같아요!',
          qualitative: _ReadingQuality.moreEfficient,
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
        const _GenreChart(
          genres: [
            (name: '소설', count: 6, color: AppTheme.primaryLight),
            (name: '에세이', count: 2, color: AppTheme.accent),
            (name: '자기계발', count: 1, color: AppTheme.textSecondary),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXL),

        const ChorokSectionHeader(title: '올해 인사이트'),
        const SizedBox(height: AppTheme.spaceMD),
        const _RichInsightCard(
          deltas: [
            (label: '총 독서 시간', value: '142h', isPositive: true),
            (label: '완독', value: '9권', isPositive: true),
            (label: '목표 달성률', value: '45%', isPositive: true),
          ],
          icon: Icons.emoji_events_rounded,
          message: '올해 142시간을 독서에 투자했어요. 매달 꾸준히 완독하며 연간 목표의 45%를 달성했어요!',
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
      backgroundColor: AppTheme.darkCard,
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
                  color: AppTheme.darkBorder,
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
                          .copyWith(color: AppTheme.textPrimary)),
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
                separatorBuilder: (_, _) => Divider(
                    color: AppTheme.darkBorder, height: 1, indent: 64),
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
          color: AppTheme.darkCard,
          side: const BorderSide(color: AppTheme.darkBorder),
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
                        color: isSelected ? Colors.white : AppTheme.textTertiary,
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
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: stats.expand((s) => [
              ChorokStatCell(
                label: s.label,
                value: s.value,
                icon: s.icon,
                valueColor: s.color,
              ),
              const SizedBox(width: AppTheme.space3XL),
            ]).toList()
              ..removeLast(),
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
                    color: isHighlight ? AppTheme.primaryLight : AppTheme.textTertiary,
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

  const _FocusCard({
    required this.score,
    required this.label,
    required this.description,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Label,
    required this.stat2Value,
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
                      backgroundColor: AppTheme.darkBorder,
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
                        style: AppTheme.headingSmall.copyWith(color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(description,
                        style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            children: [
              ChorokStatCell(label: stat1Label, value: stat1Value, icon: Icons.timer_rounded),
              const SizedBox(width: AppTheme.space3XL),
              ChorokStatCell(
                  label: stat2Label, value: stat2Value,
                  valueColor: AppTheme.accent, icon: Icons.schedule_rounded),
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
                const Divider(height: 1, color: AppTheme.darkBorder, indent: 64),
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
                    fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(author, style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(duration, style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(date, style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary)),
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
                          style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary)),
                      Text(s.range,
                          style: AppTheme.captionSmall.copyWith(
                            fontSize: 10,
                            color: AppTheme.textTertiary,
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
                      backgroundColor: AppTheme.darkBorder,
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
                      color: ratio >= 0.8 ? AppTheme.primaryLight : AppTheme.textTertiary,
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

// ─── 독서 효율 평가 (정성 피드백용) ──────────────────────────────────────
enum _ReadingQuality {
  moreEfficient,  // 같은 시간에 더 많은 페이지
  lessEfficient,  // 같은 시간에 더 적은 페이지 → "어려운 책이었나봐요"
  moreTime,       // 더 많은 시간 투자
  lessTime,       // 더 적은 시간 투자
}

// ─── 인사이트 카드 (수치 델타 + 정성 피드백) ──────────────────────────────
class _RichInsightCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final List<({String label, String value, bool isPositive})> deltas;
  final _ReadingQuality? qualitative;

  const _RichInsightCard({
    required this.icon,
    required this.message,
    required this.deltas,
    this.qualitative,
  });

  String? get _qualitativeMessage => switch (qualitative) {
    _ReadingQuality.moreEfficient => '같은 시간에 더 많은 페이지를 읽었어요. 집중도가 올라간 것 같아요!',
    _ReadingQuality.lessEfficient => '시간 대비 페이지 수가 줄었어요. 어려운 책이었나봐요.',
    _ReadingQuality.moreTime      => '지난 기간보다 더 많은 시간을 독서에 쏟았어요. 대단해요!',
    _ReadingQuality.lessTime      => '읽는 시간이 조금 줄었어요. 다음엔 더 여유를 만들어봐요.',
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final qualMsg = _qualitativeMessage;
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 델타 수치 행
          Row(
            children: deltas.expand((d) => [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.value,
                      style: AppTheme.headingSmall.copyWith(
                        color: d.isPositive ? AppTheme.primaryLight : AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(d.label,
                        style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary)),
                  ],
                ),
              ),
            ]).toList(),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          const Divider(color: AppTheme.darkBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          // 아이콘 + 메시지
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
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // 정성 피드백 배지 (qualitative 있을 때만)
          if (qualMsg != null) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.smoothBox(
                color: AppTheme.primary.withValues(alpha: 0.35),
                side: BorderSide(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
                radius: AppTheme.radiusMD,
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_rounded, size: 14, color: AppTheme.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      qualMsg,
                      style: AppTheme.captionLarge.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
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
                                color: AppTheme.textSecondary,
                                height: 1.6,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppTheme.spaceSM),
                            Text(
                              '— ${h.book}',
                              style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < highlights.length - 1)
                const Divider(height: 1, color: AppTheme.darkBorder, indent: 35),
            ],
          );
        }),
      ),
    );
  }
}

// ─── 독서 캘린더 히트맵 ────────────────────────────────────────────────
class _CalendarHeatmap extends StatelessWidget {
  final int year;
  final int month;
  final Map<int, int> readingMinutes;

  const _CalendarHeatmap({
    required this.year,
    required this.month,
    required this.readingMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startOffset = (DateTime(year, month, 1).weekday - 1) % 7;
    const headers = ['월', '화', '수', '목', '금', '토', '일'];
    final rows = ((startOffset + daysInMonth) / 7).ceil();

    // LayoutBuilder 대신 MediaQuery로 셀 크기 계산 —
    // layout 단계에서 위젯 트리를 재생성하지 않아 스크롤 중 freeze 방지
    final screenW = MediaQuery.sizeOf(context).width;
    final cellSize = (screenW
            - AppTheme.screenPadding * 2   // 화면 좌우 패딩
            - AppTheme.cardPaddingMD * 2)  // 카드 내부 패딩
        / 7;

    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: headers.map((d) => SizedBox(
              width: cellSize,
              child: Center(
                child: Text(d,
                    style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary)),
              ),
            )).toList(),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...List.generate(rows, (row) => Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return SizedBox(width: cellSize, height: cellSize);
              }
              return _DayCell(
                day: day,
                minutes: readingMinutes[day] ?? 0,
                size: cellSize,
              );
            }),
          )),
          const SizedBox(height: AppTheme.spaceSM),
          _CalendarLegend(),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final int minutes;
  final double size;

  const _DayCell({required this.day, required this.minutes, required this.size});

  Color _bgColor() {
    if (minutes == 0) return AppTheme.darkBorder.withValues(alpha: 0.25);
    if (minutes < 30) return AppTheme.primary.withValues(alpha: 0.5);
    if (minutes < 60) return AppTheme.accent.withValues(alpha: 0.55);
    if (minutes < 120) return AppTheme.accent;
    return AppTheme.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '$day',
            style: AppTheme.captionSmall.copyWith(
              fontSize: 10,
              color: minutes > 0 ? Colors.black.withValues(alpha: 0.75) : AppTheme.textTertiary,
              fontWeight: minutes >= 120 ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      (color: AppTheme.darkBorder.withValues(alpha: 0.25), label: '없음'),
      (color: AppTheme.primary.withValues(alpha: 0.5), label: '30분↓'),
      (color: AppTheme.accent.withValues(alpha: 0.55), label: '1시간'),
      (color: AppTheme.accent, label: '2시간'),
      (color: AppTheme.primaryLight, label: '2시간+'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: steps.expand((s) => [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(s.label,
            style: AppTheme.captionSmall.copyWith(fontSize: 10, color: AppTheme.textTertiary)),
        const SizedBox(width: 8),
      ]).toList()
        ..removeLast(),
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
                        style: AppTheme.captionLarge.copyWith(color: AppTheme.textTertiary)),
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
                            style: AppTheme.headingSmall.copyWith(color: AppTheme.textTertiary),
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
              backgroundColor: AppTheme.darkBorder,
              valueColor: const AlwaysStoppedAnimation(AppTheme.primaryLight),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            remaining > 0
                ? '목표까지 $remaining권 남았어요. 이 속도라면 충분히 달성할 수 있어요!'
                : '올해 목표를 달성했어요! 정말 대단해요!',
            style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary),
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
                      style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 8,
                      backgroundColor: AppTheme.darkBorder,
                      valueColor: AlwaysStoppedAnimation(g.color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text('${g.count}권',
                      textAlign: TextAlign.right,
                      style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary)),
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
                              fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text(b.author,
                              style: AppTheme.captionLarge.copyWith(color: AppTheme.textSecondary)),
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
                            style: AppTheme.captionSmall.copyWith(color: AppTheme.textTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < books.length - 1)
                const Divider(height: 1, color: AppTheme.darkBorder, indent: 64),
            ],
          );
        }),
      ),
    );
  }
}
