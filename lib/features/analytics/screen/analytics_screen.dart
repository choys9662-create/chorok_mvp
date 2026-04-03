import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_stat_cell.dart';
import '../../../shared/widgets/gradient_text.dart';

/// 분석 스크린: 이번 주 / 이번 달 / 올해 탭 구조
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _tab = 0; // 0: 이번 주, 1: 이번 달, 2: 올해

  @override
  Widget build(BuildContext context) {
    final content = [
      Text('분석', style: AppTheme.headingLarge.copyWith(color: AppTheme.textPrimary)),
      const SizedBox(height: 16),
      _TabSelector(selected: _tab, onChanged: (i) => setState(() => _tab = i)),
      const SizedBox(height: 24),
      ...(_tab == 0
          ? _buildWeekContent()
          : _tab == 1
              ? _buildMonthContent()
              : _buildYearContent()),
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding, 20,
            AppTheme.screenPadding, 40,
          ),
          itemCount: content.length,
          itemBuilder: (_, i) => content[i],
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

  @override
  Widget build(BuildContext context) {
    const tabs = ['이번 주', '이번 달', '올해'];
    return Container(
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 10,
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(e.key);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
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
          );
        }).toList(),
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

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (i) {
          final ratio = maxVal == 0 ? 0.0 : values[i] / maxVal;
          final isHighlight = i == highlightIndex;
          final mins = values[i];

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isHighlight && mins > 0)
                    Text(
                      mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m',
                      style: AppTheme.captionSmall.copyWith(color: AppTheme.accent),
                    ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: LayoutBuilder(
                      builder: (_, c) => Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          height: c.maxHeight * ratio,
                          decoration: BoxDecoration(
                            color: isHighlight
                                ? AppTheme.primaryLight
                                : AppTheme.primary.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${labels[i]}$labelSuffix',
                    style: AppTheme.captionSmall.copyWith(
                      fontSize: labels.length > 8 ? 9 : null,
                      color: isHighlight ? AppTheme.primaryLight : AppTheme.textTertiary,
                      fontWeight: isHighlight ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
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
