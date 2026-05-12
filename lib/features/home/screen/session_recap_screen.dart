import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';

// ─── 리캡 데이터 모델 ─────────────────────────────────────────────────
class RecapData {
  final int seconds;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final List<CollectedSentence> sentences;

  /// 페이지 진행 기록용 — 없으면 DB 저장 생략
  final String? bookId;
  final int startPage;
  final int totalPages;
  final DateTime? sessionStartedAt;

  /// 이탈 횟수 / 이탈 누적 시간(초)
  final int exitCount;
  final int exitDurationSeconds;

  const RecapData({
    required this.seconds,
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    required this.sentences,
    this.bookId,
    this.startPage = 0,
    this.totalPages = 0,
    this.sessionStartedAt,
    this.exitCount = 0,
    this.exitDurationSeconds = 0,
  });
}

// 특별한 순간 타입 — 실제 서비스에서는 서버 응답으로 대체
enum _SentenceTag {
  resonance, // 많은 독자가 독립적으로 같은 문장을 발견
  rare, // 거의 아무도 발견하지 않은 희귀한 구절
  peak, // 이 책에서 가장 많이 수집된 문장
  viral, // 피드에서 폭발적으로 공유된 구절
  normal, // 일반 수집
}

// MVP: 결정적 해시로 타입 배정
_SentenceTag _analyzeTag(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return switch (h % 5) {
    0 => _SentenceTag.resonance,
    1 => _SentenceTag.rare,
    2 => _SentenceTag.peak,
    3 => _SentenceTag.viral,
    _ => _SentenceTag.normal,
  };
}

int _resonanceCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 100 + (h % 500);
}

int _rareCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 1 + (h % 4);
}

int _viralCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 50 + (h % 200);
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
  ConsumerState<SessionRecapScreen> createState() => _SessionRecapScreenState();
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

  // 공유 카드 캡처용 키
  final _shareKey = GlobalKey();

  // 집중도 (0~100)
  double get _focusPercent {
    final total = widget.data.seconds + widget.data.exitDurationSeconds;
    if (total <= 0) return 100.0;
    return (widget.data.seconds / total * 100).clamp(0.0, 100.0);
  }

  // 집중도 기반 인사이트
  String get _focusInsightText {
    final exits = widget.data.exitCount;
    final focus = _focusPercent;
    if (exits == 0) return '한 번도 이탈하지 않은 완벽한 집중이에요! 🎯';
    if (focus >= 90) return '대단해요! 거의 완벽한 집중을 유지했어요 ✨';
    if (focus >= 70) return '좋은 집중력이에요. 이탈이 있었지만 금방 돌아왔어요 👍';
    if (focus >= 50) return '집중과 이탈이 반반이었어요. 다음엔 더 잘할 수 있어요 💪';
    return '오늘은 집중이 쉽지 않았지만, 책을 펼친 것만으로도 훌륭해요 🌱';
  }

  Future<void> _share() async {
    HapticFeedback.selectionClick();
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null || !mounted) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chorok_session.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([
        XFile(file.path),
      ], subject: '$_timeText 독서 완료! 📚');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          chorokSnackBar(context, '공유 준비 중 오류가 발생했어요', success: false),
        );
      }
    }
  }

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
      if (repo == null) {
        // DB 미초기화 (목업 모드 등) — 저장 없이 완료 처리
        if (!mounted) return;
        // 동일하게 인메모리 상태도 갱신
        ref.read(libraryProvider.notifier).updateCurrentPage(bookId, newPage);
        setState(() {
          _isSavingPage = false;
          _pageRecorded = true;
        });
        return;
      }

      final result = await repo.updateProgress(
        bookId: bookId,
        newCurrentPage: newPage,
        durationSeconds: widget.data.seconds,
        choseoCount: widget.data.sentences.length,
        startedAt: widget.data.sessionStartedAt,
        exitCount: widget.data.exitCount,
        exitDurationSeconds: widget.data.exitDurationSeconds,
      );

      // 초서 문장 병렬 저장
      await Future.wait(
        widget.data.sentences
            .where((entry) => entry.content.isNotEmpty)
            .map(
              (entry) => repo.saveChoseo(
                bookId: bookId,
                bookTitle: widget.data.bookTitle,
                bookAuthor: widget.data.bookAuthor,
                content: entry.content,
                myThought: entry.thought.isEmpty ? null : entry.thought,
              ),
            ),
      );

      if (!mounted) return;

      // libraryProvider 인메모리 상태 즉시 반영 (홈/서재 화면 기닥 없이 업데이트)
      ref.read(libraryProvider.notifier).updateCurrentPage(bookId, newPage);

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
          context.go(AppConstants.routeHome);
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
      backgroundColor: context.appBg,
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
                          Text(
                            '독서 완료',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                          Text(
                            '오늘의 독서 리캡',
                            style: AppTheme.headingLarge.copyWith(
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceMD),
                      const Spacer(),
                      // 건너뛰기
                      Semantics(
                        label: '건너뛰고 홈으로',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.go(AppConstants.routeHome);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              '건너뛰기',
                              style: AppTheme.captionLarge.copyWith(
                                color: context.appTextTertiary,
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
                          context.go(AppConstants.routeHome);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: context.appCard,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: context.appTextTertiary,
                          ),
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
                        // 1. 기존 리캡 컴포넌트 뷰
                        _SessionHeroCard(
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          coverUrl: widget.data.coverUrl,
                          timeText: _timeText,
                          sentenceCount: widget.data.sentences.length,
                        ),
                        const SizedBox(height: 16),
                        _FocusGaugeCard(
                          focusPercent: _focusPercent,
                          exitCount: widget.data.exitCount,
                          insightText: _focusInsightText,
                        ),
                        const SizedBox(height: 16),
                        _ScoreCard(
                          score: _score,
                          evalText: _evalText(
                            _score,
                            widget.data.sentences.length,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // 2. 공유용 영수증 캡처 영역 (새 버전)
                        RepaintBoundary(
                          key: _shareKey,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F7F1),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 32,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'C H O R O K',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'READING RECEIPT',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const SizedBox(height: AppTheme.spaceMD),
                                const SizedBox(height: 24),

                                Text(
                                  widget.data.bookTitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.data.bookAuthor,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const SizedBox(height: AppTheme.spaceMD),
                                const SizedBox(height: 24),

                                _ReceiptRow(
                                  'DATE',
                                  time_fmt.formatDate(DateTime.now()),
                                ),
                                const SizedBox(height: 8),
                                _ReceiptRow('TIME', _timeText),
                                const SizedBox(height: 8),
                                _ReceiptRow(
                                  'FOCUS',
                                  '${_focusPercent.toInt()}%',
                                ),
                                const SizedBox(height: 8),
                                _ReceiptRow('SCORE', '$_score PTS'),
                                const SizedBox(height: 24),
                                const SizedBox(height: AppTheme.spaceMD),
                                const SizedBox(height: 24),

                                if (widget.data.sentences.isNotEmpty) ...[
                                  Text(
                                    '"${widget.data.sentences.first.content}"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                   const SizedBox(height: 24),
                                ],

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    40,
                                    (index) => Container(
                                      width: (index * 7 % 3 + 1) * 1.2,
                                      height: 45,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5,
                                      ),
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'THANK YOU FOR READING',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 수집 문장 분석
                        if (widget.data.sentences.isNotEmpty) ...[
                          _SentencesSection(sentences: widget.data.sentences),
                          const SizedBox(height: 12),
                          // 겹문장 힌트 카드
                          _OverlapHintCard(
                            sentenceCount: widget.data.sentences.length,
                          ),
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
                _RecapActions(
                  sentences: widget.data.sentences,
                  onShare: _share,
                ),
              ],
            ),
          ),
        ),
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
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _progressAnim = Tween<double>(
      begin: 0,
      end: widget.score / 100,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
        color: context.appCard,
        radius: 20,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '세션 평가',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: AppTheme.smoothBox(
                  color: context.appPrimaryAccent.withValues(alpha: 0.1),
                  radius: 12,
                ),
                child: Text(
                  _scoreLabel,
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                          foreground:
                              Theme.of(context).brightness == Brightness.dark
                              ? (Paint()
                                  ..shader =
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFF00FF00),
                                          Color(0xFF00CC6A),
                                        ],
                                      ).createShader(
                                        const Rect.fromLTWH(0, 0, 100, 60),
                                      ))
                              : null,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? null
                              : context.appPrimaryAccent,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 2),
                        child: Text(
                          '점',
                          style: AppTheme.headingSmall.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: context.appBorder,
                      valueColor: AlwaysStoppedAnimation(
                        context.appPrimaryAccent,
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
              color: context.appTextSecondary,
              height: 1.6,
            ),
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
            Text(
              '수집한 문장',
              style: AppTheme.headingSmall.copyWith(
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: AppTheme.smoothBox(
                color: context.appPrimaryAccent.withValues(alpha: 0.1),
                radius: 10,
              ),
              child: Text(
                '${sentences.length}',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...sentences.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SentenceAnalysisCard(entry: e.value, index: e.key),
          ),
        ),
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

    final (Color tagColor, IconData tagIcon, String tagDesc) = switch (tag) {
      _SentenceTag.resonance => (
        context.appPrimaryAccent,
        Icons.people_rounded,
        '${_resonanceCount(entry.content)}명의 독자가 이 문장에 밑줄을 그었어요',
      ),
      _SentenceTag.rare => (
        const Color(0xFF7B9EFF),
        Icons.explore_rounded,
        '이 문장을 발견한 독자는 아직 ${_rareCount(entry.content)}명뿐이에요',
      ),
      _SentenceTag.peak => (
        const Color(0xFFFB923C),
        Icons.menu_book_rounded,
        '이 책에서 가장 많이 수집된 문장이에요',
      ),
      _SentenceTag.viral => (
        const Color(0xFFF87171),
        Icons.local_fire_department_rounded,
        '${_viralCount(entry.content)}명이 이 문장을 공유했어요',
      ),
      _SentenceTag.normal => (
        context.appTextTertiary,
        Icons.format_quote_rounded,
        '수집한 문장',
      ),
    };

    final isSpecial = tag != _SentenceTag.normal;

    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 분석 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: tagColor.withValues(alpha: isSpecial ? 0.09 : 0.05),
              shape: SmoothRectangleBorder(
                borderRadius: SmoothBorderRadius.only(
                  topLeft: SmoothRadius(cornerRadius: 15, cornerSmoothing: 0.6),
                  topRight: SmoothRadius(
                    cornerRadius: 15,
                    cornerSmoothing: 0.6,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(tagIcon, size: 14, color: tagColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tagDesc,
                    style: AppTheme.captionSmall.copyWith(
                      color: tagColor,
                      fontWeight: isSpecial ? FontWeight.w500 : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
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
                    color: context.appCardElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '"${entry.content}"',
                    style: AppTheme.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: context.appTextPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                // 내 생각 (있을 때만)
                if (entry.thought.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 14,
                        color: context.appAccentColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.thought,
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextSecondary,
                            height: 1.5,
                          ),
                        ),
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
        color: context.appCard,
        radius: 16,
      ),
      child: Row(
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: context.appTextTertiary,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '다음엔 문장도 수집해봐요',
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '문장 기록 버튼으로 마음에 드는 문장을\n저장하면 겹문장 분석을 볼 수 있어요',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
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
        color: context.appCard,
        radius: 16,
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.schedule_rounded,
            value: _fmtSec(seconds),
            label: '독서 시간',
          ),
          _StatItem(
            icon: Icons.format_quote_rounded,
            value: '$sentenceCount',
            label: '수집 문장',
            highlight: true,
          ),
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
          Icon(
            icon,
            size: 16,
            color: highlight
                ? context.appPrimaryAccent
                : context.appTextTertiary,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyLarge.copyWith(
              color: highlight
                  ? context.appPrimaryAccent
                  : context.appTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.captionSmall.copyWith(
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── 하단 액션 버튼 ───────────────────────────────────────────────────
class _RecapActions extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final Future<void> Function() onShare;
  const _RecapActions({required this.sentences, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.appBg,
      ),
      child: Row(
        children: [
          // 공유하기
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('공유하기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.appTextSecondary,
                side: BorderSide.none,
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
                context.go(AppConstants.routeHome);
              },
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('홈으로'),
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppTheme.smoothShape(radius: 14),
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
          color: context.appCard,
          radius: AppTheme.radiusLG,
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: context.appPrimaryAccent,
              size: 20,
            ),
            SizedBox(width: 12),
            Text(
              '페이지 기록이 저장됐어요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.appPrimaryAccent,
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
        color: context.appCard,
        radius: AppTheme.radiusLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bookmark_rounded,
                color: context.appPrimaryAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '오늘 몇 쪽까지 읽었나요?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appTextPrimary,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              if (totalPages > 0)
                Text(
                  '/ $totalPages쪽',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: context.appTextTertiary,
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
                    color: context.appCardElevated,
                    radius: AppTheme.radiusSM,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: '현재 페이지',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: context.appTextTertiary,
                        height: 1.4,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixText: '쪽',
                      suffixStyle: TextStyle(
                        fontSize: 14,
                        color: context.appTextSecondary,
                      ),
                    ),
                    cursorColor: context.appPrimaryAccent,
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
          color: context.appCard,
          radius: AppTheme.radiusXL,
          shadows: [
            BoxShadow(
              color: context.appPrimaryAccent.withValues(alpha: 0.08),
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

            Text(
              '완독을 축하해요! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              '"$bookTitle"을(를)\n끝까지 읽으셨군요!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.appTextSecondary,
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
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.appTextTertiary,
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
        color: context.appPrimaryAccent.withValues(alpha: 0.08),
        radius: 16,
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
                    style: TextStyle(
                      fontSize: 13,
                      color: context.appTextPrimary,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '이 중 $overlapCount개',
                        style: TextStyle(
                          color: context.appPrimaryAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '의 문장을 다른 독자도 기록했어요'),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '피드에서 같은 문장을 찾아보세요',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextTertiary,
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

// ─── 집중도 게이지 카드 ────────────────────────────────────────────────
class _FocusGaugeCard extends StatefulWidget {
  final double focusPercent;
  final int exitCount;
  final String insightText;

  const _FocusGaugeCard({
    required this.focusPercent,
    required this.exitCount,
    required this.insightText,
  });

  @override
  State<_FocusGaugeCard> createState() => _FocusGaugeCardState();
}

class _FocusGaugeCardState extends State<_FocusGaugeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _anim = Tween<double>(
      begin: 0,
      end: widget.focusPercent / 100,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _gaugeColor {
    if (widget.focusPercent >= 80) return context.appPrimaryAccent;
    if (widget.focusPercent >= 50) return AppTheme.accent;
    return const Color(0xFFFF7B7B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 20,
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          // 원형 게이지
          AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _FocusArcPainter(
                  progress: _anim.value,
                  color: _gaugeColor,
                  trackColor: context.appBorder,
                ),
                child: Center(
                  child: Text(
                    '${(_anim.value * 100).round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _gaugeColor,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '집중도',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    if (widget.exitCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: AppTheme.smoothBox(
                          color: context.appCardElevated,
                          radius: 8,
                          side: BorderSide.none,
                        ),
                        child: Text(
                          '이탈 ${widget.exitCount}회',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.insightText,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextSecondary,
                    height: 1.5,
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

class _FocusArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _FocusArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 6;
    const startAngle = -math.pi / 2;

    // 트랙
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // 진행 호
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        startAngle,
        math.pi * 2 * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_FocusArcPainter old) =>
      old.progress != progress || old.color != color;
}


class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReceiptRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── 세션 히어로 카드 (이전 버전) ───────────────────────────────────────────
class _SessionHeroCard extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final String timeText;
  final int sentenceCount;

  const _SessionHeroCard({
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
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
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          BookCover(
            coverUrl: coverUrl,
            gradientIndex:
                bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
            width: 56,
            height: 72,
            radius: 8,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: AppTheme.headingSmall.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  bookAuthor,
                  style: AppTheme.captionLarge.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _HeroPill(icon: Icons.schedule_rounded, label: timeText),
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
        color: Colors.white.withValues(alpha: 0.15),
        radius: 12,
        side: BorderSide.none,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.captionSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
