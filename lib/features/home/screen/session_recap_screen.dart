import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/repositories/book_repository.dart';

// ─── 리캡 데이터 모델 ─────────────────────────────────────────────────
class RecapData {
  final int seconds;
  final String bookTitle;
  final String bookAuthor;
  final List<CollectedSentence> sentences;

  /// 페이지 진행 기록용 — 없으면 DB 저장 생략
  final String? bookId;
  final int startPage;
  final int totalPages;
  final DateTime? sessionStartedAt;

  const RecapData({
    required this.seconds,
    required this.bookTitle,
    required this.bookAuthor,
    required this.sentences,
    this.bookId,
    this.startPage = 0,
    this.totalPages = 0,
    this.sessionStartedAt,
  });
}

enum _SentenceTag { overlap, popular, unique }

// 문장 분석 태그 — 실제 서비스에서는 서버 응답, MVP에서는 결정적 해시로 배정
_SentenceTag _analyzeTag(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  switch (h % 3) {
    case 0:
      return _SentenceTag.overlap;
    case 1:
      return _SentenceTag.popular;
    default:
      return _SentenceTag.unique;
  }
}

int _overlapCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 2 + (h % 5);
}

int _empathyCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 24 + (h % 80);
}

// 세션 점수: 시간 + 문장 수 기반
int _calcScore(int seconds, int sentenceCount) {
  final timePts = (seconds / 90).clamp(0.0, 40.0).toInt();
  final sentPts = (sentenceCount * 3).clamp(0, 15);
  return (45 + timePts + sentPts).clamp(0, 100);
}

String _evalText(int score, int sentenceCount) {
  if (score >= 90) return '오늘은 정말 깊이 있는 독서를 했어요.\n최고의 집중력을 보여줬어요!';
  if (score >= 75) return '훌륭한 독서 세션이었어요.\n꾸준히 이 페이스를 유지해봐요.';
  if (score >= 60) {
    if (sentenceCount > 0) return '좋은 독서였어요. 수집한 문장들이\n피드에 올라갔어요!';
    return '좋은 시작이에요. 다음엔 문장도\n한 번 수집해봐요!';
  }
  return '짧지만 의미 있는 독서였어요.\n오늘도 잘 했어요.';
}

// ─── 리캡 스크린 ──────────────────────────────────────────────────────
class SessionRecapScreen extends ConsumerStatefulWidget {
  final RecapData data;
  const SessionRecapScreen({super.key, required this.data});

  @override
  ConsumerState<SessionRecapScreen> createState() =>
      _SessionRecapScreenState();
}

class _SessionRecapScreenState extends ConsumerState<SessionRecapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final int _score;

  // 페이지 기록 상태
  late final TextEditingController _pageCtrl;
  bool _pageRecorded = false;
  bool _isSavingPage = false;

  @override
  void initState() {
    super.initState();
    _score = _calcScore(widget.data.seconds, widget.data.sentences.length);
    _pageCtrl = TextEditingController(
      text: widget.data.startPage > 0 ? '${widget.data.startPage}' : '',
    );

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _enterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ─── 페이지 기록 저장 ───────────────────────────────────────────────
  Future<void> _savePage() async {
    final bookId = widget.data.bookId;
    if (bookId == null) return;

    final pageText = _pageCtrl.text.trim();
    final newPage = int.tryParse(pageText);
    if (newPage == null || newPage < 0) return;

    setState(() => _isSavingPage = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(bookRepositoryProvider);
      if (repo == null) return;
      final result = await repo.updateProgress(
        bookId: bookId,
        newCurrentPage: newPage,
        durationSeconds: widget.data.seconds,
        choseoCount: widget.data.sentences.length,
        startedAt: widget.data.sessionStartedAt,
      );

      // 초서 문장 개별 저장
      for (final entry in widget.data.sentences) {
        if (entry.content.isNotEmpty) {
          await repo.saveChoseo(
            bookId: bookId,
            bookTitle: widget.data.bookTitle,
            bookAuthor: widget.data.bookAuthor,
            content: entry.content,
            myThought: entry.thought.isEmpty ? null : entry.thought,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _isSavingPage = false;
        _pageRecorded = true;
      });

      if (result.justCompleted) {
        await _showCompletionDialog(result.book);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSavingPage = false);
    }
  }

  Future<void> _showCompletionDialog(IsarBook? book) async {
    HapticFeedback.heavyImpact();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompletionDialog(
        bookTitle: widget.data.bookTitle,
        onReflect: () {
          Navigator.of(context).pop();
          context.pushReplacement(
            AppConstants.routeReflection,
            extra: Book(
              id: widget.data.bookId ?? '',
              title: widget.data.bookTitle,
              author: widget.data.bookAuthor,
              totalPages: widget.data.totalPages,
              currentPage: widget.data.totalPages,
              status: ReadingStatus.completed,
            ),
          );
        },
        onLater: () {
          Navigator.of(context).pop();
          context.go('/home');
        },
      ),
    );
  }

  String get _timeText {
    final h = widget.data.seconds ~/ 3600;
    final m = (widget.data.seconds % 3600) ~/ 60;
    final s = widget.data.seconds % 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분 $s초';
    return '$s초';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Column(
              children: [
                // ─── 헤더 ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('독서 완료',
                              style: AppTheme.captionLarge
                                  .copyWith(color: AppTheme.textTertiary)),
                          Text('오늘의 독서 리캡',
                              style: AppTheme.headingLarge
                                  .copyWith(color: AppTheme.textPrimary)),
                        ],
                      ),
                      const Spacer(),
                      // 건너뛰기
                      Semantics(
                        label: '건너뛰고 홈으로',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.go('/home');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Text(
                              '건너뛰기',
                              style: AppTheme.captionLarge.copyWith(
                                color: AppTheme.textTertiary,
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 닫기
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.go('/home');
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.darkCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.darkBorder),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── 스크롤 콘텐츠 ────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 세션 히어로 카드
                        _SessionHeroCard(
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          timeText: _timeText,
                          sentenceCount: widget.data.sentences.length,
                        ),
                        const SizedBox(height: 16),

                        // 점수 카드
                        _ScoreCard(
                          score: _score,
                          evalText: _evalText(
                              _score, widget.data.sentences.length),
                        ),
                        const SizedBox(height: 16),

                        // 수집 문장 분석
                        if (widget.data.sentences.isNotEmpty) ...[
                          _SentencesSection(
                              sentences: widget.data.sentences),
                          const SizedBox(height: 12),
                          // 겹문장 힌트 카드
                          _OverlapHintCard(
                              sentenceCount: widget.data.sentences.length),
                          const SizedBox(height: 16),
                        ] else ...[
                          _EmptySentenceCard(),
                          const SizedBox(height: 16),
                        ],

                        // 독서 통계 행
                        _StatsRow(
                          seconds: widget.data.seconds,
                          sentenceCount: widget.data.sentences.length,
                        ),
                        const SizedBox(height: 16),

                        // 페이지 기록 카드 (bookId 있을 때만)
                        if (widget.data.bookId != null)
                          _PageRecordCard(
                            controller: _pageCtrl,
                            totalPages: widget.data.totalPages,
                            isRecorded: _pageRecorded,
                            isSaving: _isSavingPage,
                            onSave: _savePage,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ─── 하단 CTA ────────────────────────────────────
                _RecapActions(sentences: widget.data.sentences),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 세션 히어로 카드 ─────────────────────────────────────────────────
class _SessionHeroCard extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final String timeText;
  final int sentenceCount;

  const _SessionHeroCard({
    required this.bookTitle,
    required this.bookAuthor,
    required this.timeText,
    required this.sentenceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        gradient: AppTheme.greenCardGradient,
        radius: 20,
        side: BorderSide(
            color: AppTheme.primaryLight.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // 책 아이콘
          Container(
            width: 56,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.primaryLight.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.menu_book_rounded,
                color: AppTheme.primaryLight, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bookTitle,
                    style: AppTheme.headingSmall
                        .copyWith(color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(bookAuthor,
                    style: AppTheme.captionLarge
                        .copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HeroPill(
                      icon: Icons.schedule_rounded,
                      label: timeText,
                    ),
                    const SizedBox(width: 8),
                    if (sentenceCount > 0)
                      _HeroPill(
                        icon: Icons.format_quote_rounded,
                        label: '$sentenceCount문장',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: AppTheme.smoothBox(
        color: AppTheme.primaryLight.withValues(alpha: 0.12),
        radius: 12,
        side: BorderSide(
            color: AppTheme.primaryLight.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primaryLight),
          const SizedBox(width: 4),
          Text(label,
              style: AppTheme.captionSmall.copyWith(
                  color: AppTheme.primaryLight,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── 점수 카드 ────────────────────────────────────────────────────────
class _ScoreCard extends StatefulWidget {
  final int score;
  final String evalText;
  const _ScoreCard({required this.score, required this.evalText});

  @override
  State<_ScoreCard> createState() => _ScoreCardState();
}

class _ScoreCardState extends State<_ScoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _progressAnim = Tween<double>(begin: 0, end: widget.score / 100)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _scoreLabel {
    if (widget.score >= 90) return '탁월해요';
    if (widget.score >= 75) return '훌륭해요';
    if (widget.score >= 60) return '좋아요';
    return '시작이에요';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 20,
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('세션 평가',
                  style: AppTheme.captionLarge
                      .copyWith(color: AppTheme.textTertiary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: AppTheme.smoothBox(
                  color: AppTheme.primaryLight.withValues(alpha: 0.1),
                  radius: 12,
                ),
                child: Text(_scoreLabel,
                    style: AppTheme.captionSmall.copyWith(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnim,
            builder: (_, _) {
              final progress = _progressAnim.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(progress * widget.score).round()}',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFF00FF00),
                                Color(0xFF00CC6A)
                              ],
                            ).createShader(
                                const Rect.fromLTWH(0, 0, 100, 60)),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6, left: 2),
                        child: Text('점',
                            style: AppTheme.headingSmall.copyWith(
                                color: AppTheme.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.darkBorder,
                      valueColor: AlwaysStoppedAnimation(
                        Color.lerp(AppTheme.accent, AppTheme.primaryLight,
                            progress)!,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            widget.evalText,
            style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─── 수집 문장 섹션 ───────────────────────────────────────────────────
class _SentencesSection extends StatelessWidget {
  final List<CollectedSentence> sentences;
  const _SentencesSection({required this.sentences});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('수집한 문장',
                style: AppTheme.headingSmall
                    .copyWith(color: AppTheme.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: AppTheme.smoothBox(
                color: AppTheme.primaryLight.withValues(alpha: 0.1),
                radius: 10,
              ),
              child: Text('${sentences.length}',
                  style: AppTheme.captionSmall.copyWith(
                      color: AppTheme.primaryLight,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sentences.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SentenceAnalysisCard(
                entry: e.value,
                index: e.key,
              ),
            )),
      ],
    );
  }
}

class _SentenceAnalysisCard extends StatelessWidget {
  final CollectedSentence entry;
  final int index;
  const _SentenceAnalysisCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final tag = _analyzeTag(entry.content);

    final (String tagLabel, Color tagColor, IconData tagIcon,
        String tagDesc) = switch (tag) {
      _SentenceTag.overlap => (
          '겹문장',
          AppTheme.primaryLight,
          Icons.join_inner_rounded,
          '${_overlapCount(entry.content)}명이 함께 수집한 문장이에요',
        ),
      _SentenceTag.popular => (
          '인기 문장',
          AppTheme.accent,
          Icons.local_fire_department_rounded,
          '공감 ${_empathyCount(entry.content)}개를 받은 유명한 문장이에요',
        ),
      _SentenceTag.unique => (
          '유니크',
          const Color(0xFF7B9EFF),
          Icons.auto_awesome_rounded,
          '아직 아무도 수집하지 않은 희귀한 발견이에요!',
        ),
    };

    return Container(
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 16,
        side: BorderSide(
          color: tag == _SentenceTag.overlap
              ? tagColor.withValues(alpha: 0.35)
              : AppTheme.darkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 분석 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(tagIcon, size: 14, color: tagColor),
                const SizedBox(width: 6),
                Text(tagLabel,
                    style: AppTheme.captionLarge.copyWith(
                        color: tagColor, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('·  $tagDesc',
                      style: AppTheme.captionSmall
                          .copyWith(color: tagColor.withValues(alpha: 0.7)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),

          // 문장 + 내 생각
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 수집한 문장
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCardElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border(
                      left: BorderSide(color: tagColor, width: 3),
                    ),
                  ),
                  child: Text('"${entry.content}"',
                      style: AppTheme.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textPrimary,
                        height: 1.6,
                      )),
                ),
                // 내 생각 (있을 때만)
                if (entry.thought.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.edit_note_rounded,
                          size: 14,
                          color: AppTheme.accent.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(entry.thought,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            )),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 문장 없을 때 ─────────────────────────────────────────────────────
class _EmptySentenceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 16,
        side: BorderSide(
            color: AppTheme.darkBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_quote_rounded,
              color: AppTheme.textTertiary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('다음엔 문장도 수집해봐요',
                    style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                    '문장 기록 버튼으로 마음에 드는 문장을\n저장하면 겹문장 분석을 볼 수 있어요',
                    style: AppTheme.captionLarge
                        .copyWith(color: AppTheme.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 독서 통계 행 ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int seconds;
  final int sentenceCount;
  const _StatsRow({required this.seconds, required this.sentenceCount});

  @override
  Widget build(BuildContext context) {
    final overlapCount = sentenceCount > 0
        ? (sentenceCount * 0.6).round().clamp(0, sentenceCount)
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 16,
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.schedule_rounded,
            value: _fmtSec(seconds),
            label: '독서 시간',
          ),
          _Divider(),
          _StatItem(
            icon: Icons.format_quote_rounded,
            value: '$sentenceCount',
            label: '수집 문장',
            highlight: true,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.join_inner_rounded,
            value: '$overlapCount',
            label: '겹문장',
            highlight: overlapCount > 0,
          ),
        ],
      ),
    );
  }

  String _fmtSec(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분';
    return '$s초';
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 16,
              color: highlight
                  ? AppTheme.primaryLight
                  : AppTheme.textTertiary),
          const SizedBox(height: 4),
          Text(value,
              style: AppTheme.bodyLarge.copyWith(
                color: highlight
                    ? AppTheme.primaryLight
                    : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: AppTheme.captionSmall
                  .copyWith(color: AppTheme.textTertiary)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.darkBorder,
    );
  }
}

// ─── 하단 액션 버튼 ───────────────────────────────────────────────────
class _RecapActions extends StatelessWidget {
  final List<CollectedSentence> sentences;
  const _RecapActions({required this.sentences});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          // 공유하기
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('공유 기능은 준비 중이에요'),
                    backgroundColor: AppTheme.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('공유하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.darkBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppTheme.smoothShape(radius: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 홈으로
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                context.go('/home');
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('홈으로'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.primaryLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppTheme.smoothShape(radius: 14),
                side: BorderSide(
                    color: AppTheme.primaryLight.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── 페이지 기록 카드 ─────────────────────────────────────────────────
class _PageRecordCard extends StatelessWidget {
  final TextEditingController controller;
  final int totalPages;
  final bool isRecorded;
  final bool isSaving;
  final VoidCallback onSave;

  const _PageRecordCard({
    required this.controller,
    required this.totalPages,
    required this.isRecorded,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (isRecorded) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.smoothBox(
          color: AppTheme.darkCard,
          radius: AppTheme.radiusLG,
          side: BorderSide(
              color: AppTheme.primaryLight.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppTheme.primaryLight, size: 20),
            SizedBox(width: 12),
            Text(
              '페이지 기록이 저장됐어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryLight,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: AppTheme.radiusLG,
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  color: AppTheme.primaryLight, size: 18),
              const SizedBox(width: 8),
              const Text(
                '오늘 몇 쪽까지 읽었나요?',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (totalPages > 0)
                Text(
                  '/ $totalPages쪽',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.textTertiary,
                    height: 1.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: AppTheme.smoothBox(
                    color: AppTheme.darkCardElevated,
                    radius: AppTheme.radiusSM,
                    side: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: '현재 페이지',
                      hintStyle: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textTertiary,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixText: '쪽',
                      suffixStyle: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    cursorColor: AppTheme.primaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: '페이지 기록 저장',
                child: GestureDetector(
                  onTap: isSaving ? null : onSave,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: AppTheme.smoothBox(
                      gradient: AppTheme.greenGradient,
                      radius: AppTheme.radiusSM,
                    ),
                    alignment: Alignment.center,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.darkBg,
                            ),
                          )
                        : const Text(
                            '기록',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkBg,
                              height: 1.4,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 완독 축하 다이얼로그 ─────────────────────────────────────────────
class _CompletionDialog extends StatelessWidget {
  final String bookTitle;
  final VoidCallback onReflect;
  final VoidCallback onLater;

  const _CompletionDialog({
    required this.bookTitle,
    required this.onReflect,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.smoothBox(
          color: AppTheme.darkCard,
          radius: AppTheme.radiusXL,
          side: BorderSide(
              color: AppTheme.primaryLight.withValues(alpha: 0.25)),
          shadows: [
            BoxShadow(
              color: AppTheme.primaryLight.withValues(alpha: 0.08),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 72,
              height: 72,
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenGradient,
                radius: AppTheme.radiusLG,
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: AppTheme.darkBg,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              '완독을 축하해요! 🎉',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              '"$bookTitle"을(를)\n끝까지 읽으셨군요!',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 감상 남기기
            Semantics(
              button: true,
              label: '감상 남기기',
              child: GestureDetector(
                onTap: onReflect,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: AppTheme.smoothBox(
                    gradient: AppTheme.greenGradient,
                    radius: AppTheme.radiusMD,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '감상 남기기',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.darkBg,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 나중에
            Semantics(
              button: true,
              label: '나중에',
              child: GestureDetector(
                onTap: onLater,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  child: const Text(
                    '나중에',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 겹문장 힌트 카드 ─────────────────────────────────────────────────────────
class _OverlapHintCard extends StatelessWidget {
  final int sentenceCount;
  const _OverlapHintCard({required this.sentenceCount});

  @override
  Widget build(BuildContext context) {
    // 모의 겹침 수: 문장 수 × 랜덤 계수 (실제 연동 전 UI 확인용)
    final overlapCount = (sentenceCount * 1.8).ceil().clamp(1, 99);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: AppTheme.primary.withValues(alpha: 0.15),
        radius: 16,
        side: BorderSide(
          color: AppTheme.primaryLight.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '이 중 $overlapCount개',
                        style: const TextStyle(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(
                        text: '의 문장을 다른 독자도 기록했어요',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '피드에서 같은 문장을 찾아보세요',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                    height: 1.4,
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
