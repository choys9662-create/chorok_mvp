import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:smooth_corner/smooth_corner.dart';
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
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../../feed/controller/feed_provider.dart';
import '../../library/screen/library_screen.dart';
import 'session_score.dart';
import '../controller/session_firefly_provider.dart';
import '../controller/weekly_minutes_provider.dart';
import '../controller/recommended_books_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';

const _recapBg = Color(0xFF000000);
const _recapActionBg = Color(0xFF080808);
const _recapLine = Color(0xFF252525);
const _recapBlue = Color(0xFF9CC8FF);
const _recapBlueMuted = Color(0xFF86ACE0);

// ─── 리캡 데이터 모델 ─────────────────────────────────────────────────
class RecapData {
  final int seconds;
  final String bookTitle;
  final String bookAuthor;
  final String? bookPublisher;
  final String? publishedYear;
  final String? coverUrl;
  final List<CollectedSentence> sentences;

  /// 페이지 진행 기록용 — 없으면 DB 저장 생략
  final String? bookId;
  final int startPage;
  final int totalPages;
  final int? progressPercent;
  final DateTime? sessionStartedAt;

  /// 이탈 횟수 / 이탈 누적 시간(초)
  final int exitCount;
  final int exitDurationSeconds;

  const RecapData({
    required this.seconds,
    required this.bookTitle,
    required this.bookAuthor,
    this.bookPublisher,
    this.publishedYear,
    this.coverUrl,
    required this.sentences,
    this.bookId,
    this.startPage = 0,
    this.totalPages = 0,
    this.progressPercent,
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

// ─── 리캡 스크린 ──────────────────────────────────────────────────────
class SessionRecapScreen extends ConsumerStatefulWidget {
  final RecapData data;
  const SessionRecapScreen({super.key, required this.data});

  @override
  ConsumerState<SessionRecapScreen> createState() => _SessionRecapScreenState();
}

class _SessionRecapScreenState extends ConsumerState<SessionRecapScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final int _score;
  late final String _sessionId;

  // 완독 시 다음 책 제안 노출 상태/애니메이션 (완독 감지 재연결 시 setState로 토글)
  // ignore: prefer_final_fields
  bool _showNextBookSuggestion = false;
  late final AnimationController _suggestCtrl;
  late final Animation<double> _suggestFade;
  late final Animation<Offset> _suggestSlide;

  // 공유 카드 캡처용 키
  final _shareKey = GlobalKey();

  // 집중도 (0~100)
  double get _focusPercent => sessionFocusPercent(
    readSeconds: widget.data.seconds,
    exitDurationSeconds: widget.data.exitDurationSeconds,
  );

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
    _score = sessionScore(
      seconds: widget.data.seconds,
      sentenceCount: widget.data.sentences.length,
      focusPercent: _focusPercent,
    );
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

    _suggestCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _suggestFade = CurvedAnimation(parent: _suggestCtrl, curve: Curves.easeOut);
    _suggestSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _suggestCtrl, curve: Curves.easeOutCubic),
        );

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
    _suggestCtrl.dispose();
    super.dispose();
  }

  String get _timeText {
    final h = widget.data.seconds ~/ 3600;
    final m = (widget.data.seconds % 3600) ~/ 60;
    final s = widget.data.seconds % 60;
    if (h > 0) return '$h시간 $m분';
    if (m > 0) return '$m분 $s초';
    return '$s초';
  }

  // 세션 요약용 — HH:MM:SS 형식
  String get _clockText {
    final h = widget.data.seconds ~/ 3600;
    final m = (widget.data.seconds % 3600) ~/ 60;
    final s = widget.data.seconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}';
  }

  String get _oneLineText {
    if (_focusPercent >= 95 && widget.data.seconds >= 1800) {
      final startedAt = widget.data.sessionStartedAt ?? DateTime.now();
      final part = switch (startedAt.hour) {
        >= 5 && < 12 => '오전',
        >= 12 && < 18 => '오후',
        _ => '밤',
      };
      return '깊고 집중한 $part의 독서';
    }
    return sessionEvalText(
      _score,
      widget.data.sentences.length,
      _focusPercent,
    ).split('\n').first;
  }

  @override
  Widget build(BuildContext context) {
    final firefly = ref.watch(sessionFireflyProvider).valueOrNull;
    final companions = firefly?.mutuals ?? const <UserProfile>[];

    return Scaffold(
      backgroundColor: _recapBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SizedBox(
                  height: 57,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text('세션 요약', style: _labelStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const _SummaryDivider(),

                // ─── 스크롤 콘텐츠 ────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 책 정보 행
                        _SummaryBookHeader(
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          bookPublisher: widget.data.bookPublisher,
                          publishedYear: widget.data.publishedYear,
                          coverUrl: widget.data.coverUrl,
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.schedule_rounded,
                          label: '독서 시간',
                          child: Text(_clockText, style: _valueStyle()),
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.adjust_rounded,
                          label: '집중도',
                          child: Text(
                            '${_focusPercent.round()}%',
                            style: _valueStyle(),
                          ),
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.pie_chart_rounded,
                          label: '진행도',
                          child: _ProgressValue(
                            current: widget.data.startPage,
                            total: widget.data.totalPages,
                            percentOverride: widget.data.progressPercent,
                            color: _recapBlue,
                          ),
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.format_quote_rounded,
                          label: '초서 기록',
                          child: _ChoseoValue(
                            sentenceCount: widget.data.sentences.length,
                            recordCount: widget.data.sentences
                                .where((s) => s.thought.isNotEmpty)
                                .length,
                            color: _recapBlue,
                          ),
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.thumb_up_alt_rounded,
                          label: '한줄평',
                          child: Text(
                            _oneLineText,
                            textAlign: TextAlign.right,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _valueStyle().copyWith(
                              fontSize: 22,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const _SummaryDivider(),
                        _SummaryRow(
                          icon: Icons.radio_button_checked_rounded,
                          label: '함께 읽은',
                          child: _CompanionsValue(companions: companions),
                        ),
                        const _SummaryDivider(),

                        if (_showNextBookSuggestion) ...[
                          const SizedBox(height: 20),
                          FadeTransition(
                            opacity: _suggestFade,
                            child: SlideTransition(
                              position: _suggestSlide,
                              child: const _NextBookSuggestion(),
                            ),
                          ),
                        ],

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
                _RecapActions(onShare: _share),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

// 세션 요약 — 큰 숫자 값 스타일 (독서시간/집중도/진행도/초서기록/한줄평 공용)
TextStyle _valueStyle({Color color = _recapBlue, double fontSize = 36}) =>
    TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w300,
      color: color,
      height: 1,
      letterSpacing: 0,
    );

TextStyle _labelStyle({double fontSize = 10}) => TextStyle(
  fontFamily: AppTheme.fontFamily,
  fontSize: fontSize,
  fontWeight: FontWeight.w400,
  color: _recapBlueMuted,
  height: 1.25,
  letterSpacing: 0,
);

// ─── 세션 요약: 책 헤더 ───────────────────────────────────────────────
class _SummaryBookHeader extends StatelessWidget {
  final String bookTitle;
  final String bookAuthor;
  final String? bookPublisher;
  final String? publishedYear;
  final String? coverUrl;

  const _SummaryBookHeader({
    required this.bookTitle,
    required this.bookAuthor,
    this.bookPublisher,
    this.publishedYear,
    this.coverUrl,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      bookAuthor,
      if (bookPublisher != null && bookPublisher!.isNotEmpty) bookPublisher!,
      if (publishedYear != null && publishedYear!.isNotEmpty) publishedYear!,
    ].join(' | ');

    return SizedBox(
      height: 175,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BookCover(
              coverUrl: coverUrl,
              gradientIndex:
                  bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
              width: 88,
              height: 135,
              radius: 4,
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bookTitle,
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: _recapBlue,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    textAlign: TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 세션 요약: 구분선 ───────────────────────────────────────────────
class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: _recapLine);
  }
}

// ─── 세션 요약: 한 행 (아이콘+라벨 | 값) ──────────────────────────────
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: _recapBlue),
                const SizedBox(height: 5),
                Text(label, style: _labelStyle()),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 세션 요약: 진행도 값 (196 / 267  70%) ───────────────────────────
class _ProgressValue extends StatelessWidget {
  final int current;
  final int total;
  final int? percentOverride;
  final Color color;

  const _ProgressValue({
    required this.current,
    required this.total,
    this.percentOverride,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent =
        percentOverride ?? (total > 0 ? (current / total * 100).round() : 0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (total > 0) ...[
          Text(
            '$current / $total',
            style: _labelStyle(
              fontSize: 10,
            ).copyWith(color: _recapBlueMuted.withValues(alpha: 0.86)),
          ),
          const SizedBox(width: 9),
        ],
        Text('$percent%', style: _valueStyle(color: color)),
      ],
    );
  }
}

// ─── 세션 요약: 초서 기록 값 (문장 10  기록 5) ───────────────────────
class _ChoseoValue extends StatelessWidget {
  final int sentenceCount;
  final int recordCount;
  final Color color;

  const _ChoseoValue({
    required this.sentenceCount,
    required this.recordCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    Widget pillNum(String label, int value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _recapBlue.withValues(alpha: 0.7)),
            ),
            child: Text(
              label,
              style: _labelStyle(
                fontSize: 11,
              ).copyWith(color: _recapBlueMuted.withValues(alpha: 0.95)),
            ),
          ),
          const SizedBox(width: 5),
          Text('$value', style: _valueStyle(color: color)),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pillNum('문장', sentenceCount),
        const SizedBox(width: 11),
        pillNum('기록', recordCount),
        const SizedBox(width: 2),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
      ],
    );
  }
}

// ─── 세션 요약: 함께 읽은 값 (아바타 + 이름) ─────────────────────────
class _CompanionsValue extends StatelessWidget {
  final List<UserProfile> companions;

  const _CompanionsValue({required this.companions});

  @override
  Widget build(BuildContext context) {
    final shown = companions.take(2).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          _CompanionChip(profile: shown[i]),
        ],
      ],
    );
  }
}

class _CompanionChip extends StatelessWidget {
  final UserProfile profile;

  const _CompanionChip({required this.profile});

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A1A1A),
            border: Border.all(color: _recapBlue.withValues(alpha: 0.22)),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatar != null && avatar.isNotEmpty
              ? Image.network(avatar, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    profile.displayName.isNotEmpty
                        ? profile.displayName.characters.first
                        : '?',
                    style: _labelStyle(
                      fontSize: 12,
                    ).copyWith(color: _recapBlue),
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(profile.displayName, style: _labelStyle(fontSize: 12)),
      ],
    );
  }
}

// ─── 통합 리캡 히어로 카드 ───────────────────────────────────────────────
// ignore: unused_element — 구 리캡 레이아웃. 공유 카드 재구성 시 재사용 예정
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
    // ignore: unused_element_parameter
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
        radius: 10,
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
        radius: 10,
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
                fontWeight: FontWeight.w400,
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
        borderRadius: BorderRadius.circular(10),
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
              fontSize: 30,
              fontWeight: FontWeight.w400,
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
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bookAuthor,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
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
                fontSize: 16,
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
// ignore: unused_element — 구 리캡 레이아웃. 초서 분석 화면 재구성 시 재사용 예정
class _SentencesSection extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final String? overlapBadge;
  const _SentencesSection({
    required this.sentences,
    // ignore: unused_element_parameter
    this.overlapBadge,
  });

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
                  fontWeight: FontWeight.w400,
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
                    fontWeight: FontWeight.w400,
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
      decoration: AppTheme.smoothBox(color: context.appCard, radius: 10),
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
                smoothness: 0.6,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
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
                      fontWeight: isSpecial ? FontWeight.w400 : FontWeight.w400,
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
  final Future<void> Function() onShare;
  const _RecapActions({required this.onShare});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      color: _recapActionBg,
      padding: const EdgeInsets.only(top: 20),
      alignment: Alignment.topCenter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 공유하기
          _RecapActionButton(
            width: 122,
            icon: Icons.redo_rounded,
            label: '공유하기',
            filled: true,
            onTap: () {
              unawaited(onShare());
            },
          ),
          const SizedBox(width: 10),
          // 홈
          _RecapActionButton(
            width: 70,
            icon: Icons.home_rounded,
            label: '홈',
            onTap: () {
              HapticFeedback.mediumImpact();
              context.go(AppConstants.routeHome);
            },
          ),
          const SizedBox(width: 10),
          // 서재
          _RecapActionButton(
            width: 84,
            icon: Icons.menu_book_rounded,
            label: '서재',
            onTap: () {
              HapticFeedback.mediumImpact();
              context.go(AppConstants.routeLibrary);
            },
          ),
        ],
      ),
    );
  }
}

// ─── 세션 요약 하단 버튼 (테두리 박스) ────────────────────────────────
class _RecapActionButton extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _RecapActionButton({
    required this.width,
    required this.icon,
    required this.label,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? _recapActionBg : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: fg,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element — 완독 감지 재연결 시 사용 예정
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
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: context.appTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              '"$bookTitle"을(를)\n끝까지 읽으셨군요!',
              style: TextStyle(
                fontSize: 16,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
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
            fontSize: 12,
            letterSpacing: 1,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w400,
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
        radius: 10,
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
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 다음 책 제안 (완독 시) ─────────────────────────────────────────────────
class _NextBookSuggestion extends ConsumerWidget {
  const _NextBookSuggestion();

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
            Container(
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenCardGradient,
                radius: 10,
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
                    radius: 10,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '다음엔 이 책 어때요?',
                          style: AppTheme.captionSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          book.title,
                          style: AppTheme.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
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
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 14,
                                  color: context.appPrimaryAccent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '바로 읽기',
                                  style: AppTheme.captionLarge.copyWith(
                                    color: context.appPrimaryAccent,
                                    fontWeight: FontWeight.w400,
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
