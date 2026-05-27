import 'dart:async' show unawaited;
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
import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/isar/isar_book.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../../feed/controller/feed_provider.dart';
import '../../library/screen/library_screen.dart';
import '../controller/weekly_minutes_provider.dart';
import '../controller/recommended_books_provider.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/page_slider_card.dart';

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
  late final String _sessionId;

  // 페이지 기록 상태
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
    _sessionId =
        'session_${(widget.data.sessionStartedAt ?? DateTime.now()).millisecondsSinceEpoch}_${widget.data.bookId ?? 'free'}';

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
      _autoSaveSession();
    });
  }

  Future<void> _uploadToSupabase(
    String bookId,
    List<CollectedSentence> sentences,
    int pagesRead,
  ) async {
    try {
      final dbService = ref.read(dbServiceProvider);
      await dbService.saveSession(
        bookId: bookId,
        durationSeconds: widget.data.seconds,
        sentences: sentences.map((e) => e.content).toList(),
        thoughts: sentences
            .map((e) => e.thought.isNotEmpty ? e.thought : null)
            .toList(),
        sentenceCount: widget.data.sentences.length,
        score: _score,
        startedAt: widget.data.sessionStartedAt,
        pagesRead: pagesRead,
        exitCount: widget.data.exitCount,
        exitDurationSeconds: widget.data.exitDurationSeconds,
        clientSessionId: _sessionId,
      );
    } catch (e) {
      debugPrint('Supabase session upload failed: $e');
    }
  }

  Future<void> _autoSaveSession() async {
    if (widget.data.seconds <= 0) return;
    final repo = ref.read(bookRepositoryProvider);
    final bookId = widget.data.bookId;
    final validSentences = widget.data.sentences
        .where((e) => e.content.isNotEmpty)
        .toList();

    try {
      if (repo != null) {
        await repo.saveSessionOnly(
          sessionId: _sessionId,
          bookId: bookId,
          durationSeconds: widget.data.seconds,
          choseoCount: validSentences.length,
          startedAt: widget.data.sessionStartedAt,
          exitCount: widget.data.exitCount,
          exitDurationSeconds: widget.data.exitDurationSeconds,
        );

        if (bookId != null && validSentences.isNotEmpty) {
          await Future.wait(
            validSentences.map(
              (entry) => repo.saveChoseo(
                bookId: bookId,
                bookTitle: widget.data.bookTitle,
                bookAuthor: widget.data.bookAuthor,
                content: entry.content,
                myThought: entry.thought.isEmpty ? null : entry.thought,
              ),
            ),
          );
        }
      }

      if (bookId != null) {
        unawaited(_uploadToSupabase(bookId, validSentences, 0));
      }
    } catch (e) {
      debugPrint('Session auto-save failed: $e');
    } finally {
      ref.invalidate(analyticsProvider);
      ref.invalidate(readingStreakProvider);
      ref.invalidate(weeklyMinutesProvider);
      ref.invalidate(readingLogsProvider);
      ref.invalidate(feedProvider);
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  // ─── 페이지 기록 저장 ───────────────────────────────────────────────
  Future<void> _savePage(int newPage) async {
    final bookId = widget.data.bookId;
    if (bookId == null) return;

    setState(() => _isSavingPage = true);
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(bookRepositoryProvider);
      if (repo == null) {
        // DB 미초기화 (목업 모드 등) — 저장 없이 완료 처리
        if (!mounted) return;
        // 동일하게 인메모리 상태도 갱신
        ref.read(libraryProvider.notifier).updateCurrentPage(bookId, newPage);
        unawaited(
          _uploadToSupabase(
            bookId,
            const [],
            (newPage - widget.data.startPage).clamp(0, 999999),
          ),
        );
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
        existingSessionId: _sessionId,
      );

      if (!mounted) return;

      // libraryProvider 인메모리 상태 즉시 반영 (홈/서재 화면 기닥 없이 업데이트)
      ref.read(libraryProvider.notifier).updateCurrentPage(bookId, newPage);
      unawaited(
        _uploadToSupabase(
          bookId,
          const [],
          (newPage - widget.data.startPage).clamp(0, 999999),
        ),
      );
      ref.invalidate(analyticsProvider);
      ref.invalidate(readingStreakProvider);
      ref.invalidate(readingLogsProvider);

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
      // updateProgress가 성공했을 수 있으므로 통계 갱신 시도
      ref.invalidate(analyticsProvider);
      ref.invalidate(readingStreakProvider);
      ref.invalidate(readingLogsProvider);
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
                        // 통합 히어로: 책 + 시간/문장 + 집중도/점수 한 카드
                        _RecapHeroCard(
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          coverUrl: widget.data.coverUrl,
                          timeText: _timeText,
                          sentenceCount: widget.data.sentences.length,
                          focusPercent: _focusPercent,
                          score: _score,
                          evalText: _evalText(
                            _score,
                            widget.data.sentences.length,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 수집 문장 분석 (있을 때만)
                        if (widget.data.sentences.isNotEmpty) ...[
                          _SentencesSection(
                            sentences: widget.data.sentences,
                            overlapBadge: kUseMock
                                ? '${(widget.data.sentences.length * 1.8).ceil().clamp(1, 99)}개 겹침'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 페이지 기록 카드 (bookId 있을 때만)
                        if (widget.data.bookId != null) ...[
                          _PageRecordCard(
                            initialPage: widget.data.startPage,
                            totalPages: widget.data.totalPages,
                            isRecorded: _pageRecorded,
                            isSaving: _isSavingPage,
                            onSave: _savePage,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _ChainLightningSection(),
                        const SizedBox(height: 24),

                        // 공유용 영수증 — 화면 밖에서 캡처 전용
                        Offstage(
                          offstage: true,
                          child: RepaintBoundary(
                            key: _shareKey,
                            child: _ReceiptCapture(
                              bookTitle: widget.data.bookTitle,
                              bookAuthor: widget.data.bookAuthor,
                              timeText: _timeText,
                              focusPercent: _focusPercent,
                              score: _score,
                              firstSentence: widget.data.sentences.isNotEmpty
                                  ? widget.data.sentences.first.content
                                  : null,
                            ),
                          ),
                        ),
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

// ─── 통합 리캡 히어로 카드 ───────────────────────────────────────────────
class _RecapHeroCard extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final String timeText;
  final int sentenceCount;
  final double focusPercent;
  final int score;
  final String evalText;

  const _RecapHeroCard({
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    required this.timeText,
    required this.sentenceCount,
    required this.focusPercent,
    required this.score,
    required this.evalText,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookCover(
                coverUrl: coverUrl,
                gradientIndex:
                    bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
                width: 64,
                height: 86,
                radius: 10,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.headingSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bookAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroPill(
                          icon: Icons.schedule_rounded,
                          label: timeText,
                        ),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RecapStat(
                  icon: Icons.center_focus_strong_rounded,
                  label: '집중도',
                  value: '${focusPercent.round()}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RecapStat(
                  icon: Icons.auto_awesome_rounded,
                  label: '점수',
                  value: '$score점',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            evalText,
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RecapStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: AppTheme.smoothBox(
        color: Colors.white.withValues(alpha: 0.14),
        radius: 14,
        side: BorderSide.none,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionSmall.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppTheme.captionLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 공유용 영수증 캡처 ─────────────────────────────────────────────────
class _ReceiptCapture extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final String timeText;
  final double focusPercent;
  final int score;
  final String? firstSentence;

  const _ReceiptCapture({
    required this.bookTitle,
    required this.bookAuthor,
    required this.timeText,
    required this.focusPercent,
    required this.score,
    this.firstSentence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.receiptBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
            bookTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bookAuthor,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: AppTheme.spaceMD),
          const SizedBox(height: 24),
          _ReceiptRow('DATE', time_fmt.formatDate(DateTime.now())),
          const SizedBox(height: 8),
          _ReceiptRow('TIME', timeText),
          const SizedBox(height: 8),
          _ReceiptRow('FOCUS', '${focusPercent.toInt()}%'),
          const SizedBox(height: 8),
          _ReceiptRow('SCORE', '$score PTS'),
          const SizedBox(height: 24),
          const SizedBox(height: AppTheme.spaceMD),
          const SizedBox(height: 24),
          if (firstSentence != null) ...[
            Text(
              '"$firstSentence"',
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
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
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
    );
  }
}

// ─── 수집 문장 섹션 ───────────────────────────────────────────────────
class _SentencesSection extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final String? overlapBadge;
  const _SentencesSection({required this.sentences, this.overlapBadge});

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
            if (overlapBadge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: AppTheme.smoothBox(
                  color: context.appCardElevated,
                  radius: 10,
                ),
                child: Text(
                  overlapBadge!,
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
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
    final tag = kUseMock ? _analyzeTag(entry.content) : _SentenceTag.normal;

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
      decoration: AppTheme.smoothBox(color: context.appCard, radius: 16),
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

// ─── 하단 액션 버튼 ───────────────────────────────────────────────────
class _RecapActions extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final Future<void> Function() onShare;
  const _RecapActions({required this.sentences, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(color: context.appBg),
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
  final int initialPage;
  final int totalPages;
  final bool isRecorded;
  final bool isSaving;
  final Future<void> Function(int page) onSave;

  const _PageRecordCard({
    required this.initialPage,
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
            const SizedBox(width: 12),
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

    return PageSliderCard(
      initialPage: initialPage,
      totalPages: totalPages,
      title: '오늘 몇 쪽까지 읽었나요?',
      saveLabel: '기록',
      isSaving: isSaving,
      onSave: onSave,
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
                gradient: context.appReadingGradient,
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
                    gradient: context.appReadingGradient,
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
    if (widget.focusPercent >= 50) return context.appAccentColor;
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

// ─── 체인 라이트닝 ─────────────────────────────────────────────────────────
class _ChainLightningSection extends ConsumerWidget {
  const _ChainLightningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(recommendedBooksProvider);

    return booksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (books) {
        if (books.isEmpty) return const SizedBox.shrink();
        final book = books.first;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: context.appPrimaryAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '체인 라이트닝',
                  style: AppTheme.headingSmall.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenCardGradient,
                radius: 20,
                side: BorderSide.none,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                    coverUrl: book.coverUrl.isEmpty ? null : book.coverUrl,
                    gradientIndex: book.gradientIndex,
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
                          '다음으로 읽을 책',
                          style: AppTheme.captionSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.title,
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author,
                          style: AppTheme.captionLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            context.go(
                              AppConstants.routeSession,
                              extra: SessionExtra(
                                bookTitle: book.title,
                                bookAuthor: book.author,
                                coverUrl: book.coverUrl.isEmpty
                                    ? null
                                    : book.coverUrl,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: context.appPrimaryAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '바로 읽기',
                                  style: AppTheme.captionLarge.copyWith(
                                    color: context.appPrimaryAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
