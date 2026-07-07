import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
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
import '../../../shared/providers/library_provider.dart';
import '../../analytics/controller/analytics_provider.dart';
import '../../feed/controller/feed_provider.dart';
import '../../library/screen/library_screen.dart';
import 'session_score.dart';
import '../controller/session_firefly_provider.dart';
import '../controller/session_overlap_provider.dart';
import '../controller/weekly_minutes_provider.dart';
import '../controller/recommended_books_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/utils/sentence_normalizer.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../../shared/widgets/book_cover.dart';

const _recapBg = Color(0xFF000000);
const _recapActionBg = AppTheme.darkCard;
const _recapBlue = AppTheme.primaryLight;
const _recapCard = AppTheme.darkCard;
const _recapText = AppTheme.textPrimary;
const _recapMuted = AppTheme.textTertiary;

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
  final int? endPage;
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
    this.endPage,
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

int _rareCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 1 + (h % 4);
}

int _viralCount(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 50 + (h % 200);
}

int _resonancePercent(String sentence) {
  final h = sentence.codeUnits.fold(0, (a, b) => a + b);
  return 60 + (h % 35);
}

CollectedSentence? _featuredSentence(List<CollectedSentence> sentences) {
  if (!kUseMock) return null;
  for (final sentence in sentences) {
    if (_analyzeTag(sentence.content) != _SentenceTag.normal) return sentence;
  }
  return sentences.isEmpty ? null : sentences.first;
}

List<Color> _recapBookGradientColors(String bookTitle) {
  const palettes = [
    [Color(0xFFE8F8E8), Color(0xFF8DFF54)],
    [Color(0xFFE7FFF6), Color(0xFF61DDB2)],
    [Color(0xFFFFF2DD), Color(0xFFFFB761)],
    [Color(0xFFFFECEC), Color(0xFFFF8C8C)],
    [Color(0xFFE9F2FF), Color(0xFF88AEFF)],
    [Color(0xFFF4EDFF), Color(0xFFB58CFF)],
    [Color(0xFFEAFDF8), Color(0xFF8CB5FF)],
    [Color(0xFFFFF6E8), Color(0xFFFFD37A)],
  ];
  final h = bookTitle.codeUnits.fold(0, (a, b) => a + b);
  return palettes[h % palettes.length];
}

List<Color> _coverGradientFromPixels(ByteData data, int width, int height) {
  final stepX = (width / 24).ceil().clamp(1, width).toInt();
  final stepY = (height / 24).ceil().clamp(1, height).toInt();
  var r = 0;
  var g = 0;
  var b = 0;
  var count = 0;

  for (var y = 0; y < height; y += stepY) {
    for (var x = 0; x < width; x += stepX) {
      final i = (y * width + x) * 4;
      final a = data.getUint8(i + 3);
      if (a < 128) continue;
      final pr = data.getUint8(i);
      final pg = data.getUint8(i + 1);
      final pb = data.getUint8(i + 2);
      final luma = pr * 0.299 + pg * 0.587 + pb * 0.114;
      if (luma < 24 || luma > 232) continue;
      r += pr;
      g += pg;
      b += pb;
      count++;
    }
  }

  if (count == 0) {
    return const [AppTheme.textPrimary, AppTheme.primaryLight];
  }

  final base = Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
  final hsl = HSLColor.fromColor(base);
  final saturation = (hsl.saturation * 1.25).clamp(0.28, 0.86).toDouble();
  return [
    hsl.withSaturation(saturation).withLightness(0.78).toColor(),
    hsl.withSaturation(saturation).withLightness(0.56).toColor(),
  ];
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

  // 체인 라이트닝 — 완독 후 홈/서재 이탈 시점에 다음 책 팝업 (세션당 1회)
  bool _chainLightningShown = false;

  // 공유 카드 캡처용 키
  final _shareKey = GlobalKey();
  bool _isChoseoExpanded = false;
  bool _isCompanionsExpanded = false;

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
    _isChoseoExpanded = widget.data.sentences.isNotEmpty;
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
        pageNumbers: sentences.map((e) => e.pageNumber).toList(),
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

  int get _currentPage => widget.data.endPage ?? widget.data.startPage;

  int get _pagesRead {
    final endPage = widget.data.endPage;
    if (endPage == null) return 0;
    return (endPage - widget.data.startPage).clamp(0, 999999);
  }

  /// 종료 슬라이더를 끝까지 밀었으면 완독으로 간주한다 (체인 라이트닝 트리거).
  bool get _isCompletedRead =>
      widget.data.totalPages > 0 &&
      (widget.data.endPage ?? 0) >= widget.data.totalPages;

  ChainLightningQuery get _chainQuery =>
      (title: widget.data.bookTitle, author: widget.data.bookAuthor);

  /// 홈/서재 이탈 시 — 완독이면 다음 책 추천 팝업을 먼저 띄운다.
  void _navigateAfterRecap(String route) {
    HapticFeedback.mediumImpact();
    if (!_isCompletedRead || _chainLightningShown) {
      context.go(route);
      return;
    }
    // build에서 프리페치해 둔 추천. 아직 로딩 중이거나 없으면 그냥 이동.
    final book = ref.read(chainLightningProvider(_chainQuery)).valueOrNull;
    if (book == null) {
      context.go(route);
      return;
    }
    _chainLightningShown = true;
    showDialog(
      context: context,
      builder: (dialogCtx) => _ChainLightningDialog(
        book: book,
        onRead: () {
          HapticFeedback.mediumImpact();
          Navigator.of(dialogCtx).pop();
          context.go(
            AppConstants.routeSession,
            extra: SessionExtra(
              bookTitle: book.title,
              bookAuthor: book.author,
              coverUrl: book.coverUrl.isEmpty ? null : book.coverUrl,
            ),
          );
        },
        onLater: () {
          Navigator.of(dialogCtx).pop();
          context.go(route);
        },
      ),
    );
  }

  /// 5분 미만 독서는 기록하지 않는다 (실수로 켰다 끈 세션 컷).
  static const _minRecordSeconds = 5 * 60;

  Future<void> _autoSaveSession() async {
    final bookId = widget.data.bookId;
    final endPage = widget.data.endPage;
    // 페이지 확정(완독 포함)은 세션 길이와 무관하게 반영한다.
    // 5분 컷은 세션 '기록'만 거른다 — 여기까지 스킵하면 완독한 책이
    // '읽고 있는 책'·북피커 리스트에 계속 남는다.
    if (bookId != null && endPage != null) {
      ref.read(libraryProvider.notifier).updateCurrentPage(bookId, endPage);
    }
    if (widget.data.seconds < _minRecordSeconds) return;
    final repo = ref.read(bookRepositoryProvider);
    final pagesRead = _pagesRead;
    final validSentences = widget.data.sentences
        .where((e) => e.content.isNotEmpty)
        .toList();

    try {
      if (repo != null) {
        if (bookId != null && endPage != null) {
          await repo.updateProgress(
            bookId: bookId,
            newCurrentPage: endPage,
            durationSeconds: widget.data.seconds,
            choseoCount: validSentences.length,
            startedAt: widget.data.sessionStartedAt,
            exitCount: widget.data.exitCount,
            exitDurationSeconds: widget.data.exitDurationSeconds,
            existingSessionId: _sessionId,
          );
        } else {
          await repo.saveSessionOnly(
            sessionId: _sessionId,
            bookId: bookId,
            durationSeconds: widget.data.seconds,
            choseoCount: validSentences.length,
            startedAt: widget.data.sessionStartedAt,
            exitCount: widget.data.exitCount,
            exitDurationSeconds: widget.data.exitDurationSeconds,
          );
        }

        if (bookId != null && validSentences.isNotEmpty) {
          await Future.wait(
            validSentences.map(
              (entry) => repo.saveChoseo(
                bookId: bookId,
                bookTitle: widget.data.bookTitle,
                bookAuthor: widget.data.bookAuthor,
                content: entry.content,
                myThought: entry.thought.isEmpty ? null : entry.thought,
                pageNumber: entry.pageNumber,
              ),
            ),
          );
        }
      }

      if (bookId != null) {
        unawaited(_uploadToSupabase(bookId, validSentences, pagesRead));
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
    // 완독 세션이면 이탈 전에 미리 추천을 받아 둔다 (탭 시점엔 캐시 읽기만).
    if (_isCompletedRead) {
      ref.watch(chainLightningProvider(_chainQuery));
    }
    final firefly = ref.watch(sessionFireflyProvider).valueOrNull;
    final companions = firefly?.mutuals ?? const <UserProfile>[];
    final companionFriendCount = kUseMock
        ? 3
        : firefly?.mutualCount ?? companions.length;
    final nearbyCount = kUseMock ? 22 : firefly?.nearbyCount ?? 0;
    final featuredSentence = _featuredSentence(widget.data.sentences);

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
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryBookHeader(
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          bookPublisher: widget.data.bookPublisher,
                          publishedYear: widget.data.publishedYear,
                          coverUrl: widget.data.coverUrl,
                        ),
                        const SizedBox(height: 20),
                        if (featuredSentence != null) ...[
                          _FeaturedSentenceCard(
                            sentence: featuredSentence,
                            bookTitle: widget.data.bookTitle,
                            coverUrl: widget.data.coverUrl,
                            isExpanded: _isChoseoExpanded,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _isChoseoExpanded = !_isChoseoExpanded;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                        _SummaryRow(
                          icon: Icons.schedule_rounded,
                          label: '독서 시간',
                          child: Text(_clockText, style: _valueStyle()),
                        ),
                        _SummaryRow(
                          icon: Icons.adjust_rounded,
                          label: '집중도',
                          child: Text(
                            '${_focusPercent.round()}%',
                            style: _valueStyle(),
                          ),
                        ),
                        _SummaryRow(
                          icon: Icons.pie_chart_rounded,
                          label: '진행도',
                          child: _ProgressValue(
                            current: _currentPage,
                            total: widget.data.totalPages,
                            percentOverride: widget.data.progressPercent,
                            color: _recapText,
                          ),
                        ),
                        _ChoseoSummarySection(
                          sentences: widget.data.sentences,
                          isExpanded: _isChoseoExpanded,
                          bookTitle: widget.data.bookTitle,
                          bookAuthor: widget.data.bookAuthor,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isChoseoExpanded = !_isChoseoExpanded;
                            });
                          },
                        ),
                        _SummaryRow(
                          icon: Icons.thumb_up_alt_rounded,
                          label: '세션평가',
                          child: Text(
                            _oneLineText,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _valueStyle().copyWith(
                              fontSize: 18,
                              height: 1.1,
                            ),
                          ),
                        ),
                        _CompanionSummarySection(
                          companions: companions,
                          friendCount: companionFriendCount,
                          nearbyCount: nearbyCount,
                          isExpanded: _isCompanionsExpanded,
                          onToggle: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isCompanionsExpanded = !_isCompanionsExpanded;
                            });
                          },
                        ),

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
                _RecapActions(onShare: _share, onNavigate: _navigateAfterRecap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 세션 요약 — 큰 숫자 값 스타일 (독서시간/집중도/진행도/초서기록/한줄평 공용)
TextStyle _valueStyle({Color color = _recapText, double fontSize = 28}) =>
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
  color: _recapMuted,
  height: 1.25,
  letterSpacing: 0,
);

class _FeaturedSentenceCard extends StatefulWidget {
  final CollectedSentence sentence;
  final String bookTitle;
  final String? coverUrl;
  final bool isExpanded;
  final VoidCallback onTap;

  const _FeaturedSentenceCard({
    required this.sentence,
    required this.bookTitle,
    this.coverUrl,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_FeaturedSentenceCard> createState() => _FeaturedSentenceCardState();
}

class _FeaturedSentenceCardState extends State<_FeaturedSentenceCard> {
  List<Color>? _coverColors;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  String? _resolvedUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCoverPalette();
  }

  @override
  void didUpdateWidget(_FeaturedSentenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _coverColors = null;
      _resolvedUrl = null;
      _resolveCoverPalette();
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    super.dispose();
  }

  void _resolveCoverPalette() {
    final url = widget.coverUrl;
    if (url == null || url.isEmpty || _resolvedUrl == url) return;
    _resolvedUrl = url;

    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);

    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(createLocalImageConfiguration(context));
    _stream = stream;
    _listener = ImageStreamListener((info, _) async {
      final data = await info.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (!mounted || data == null) return;
      setState(() {
        _coverColors = _coverGradientFromPixels(
          data,
          info.image.width,
          info.image.height,
        );
      });
    });
    stream.addListener(_listener!);
  }

  @override
  Widget build(BuildContext context) {
    final tag = _analyzeTag(widget.sentence.content);
    final (String title, String meta) = switch (tag) {
      _SentenceTag.rare => (
        '탁월 문장 발견!',
        '아직 ${_rareCount(widget.sentence.content)}명만 수집',
      ),
      _SentenceTag.peak => ('탁월 문장 발견!', '이 책에서 가장 많이 수집'),
      _SentenceTag.viral => (
        '탁월 문장 발견!',
        '${_viralCount(widget.sentence.content)}명이 함께 봄',
      ),
      _ => (
        '탁월 문장 발견!',
        '독자의 ${_resonancePercent(widget.sentence.content)}%가 수집',
      ),
    };
    final colors = _coverColors ?? _recapBookGradientColors(widget.bookTitle);
    final hasCover = widget.coverUrl != null && widget.coverUrl!.isNotEmpty;

    return Semantics(
      button: true,
      label: widget.isExpanded ? '수집 문장 접기' : '수집 문장 펼치기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 70,
            decoration: AppTheme.smoothBox(
              radius: 10,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: colors,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Transform.scale(
                      scale: 1.22,
                      child: CachedNetworkImage(
                        imageUrl: widget.coverUrl!,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 160),
                        errorWidget: (context, url, error) =>
                            const SizedBox.shrink(),
                        placeholder: (context, url) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: hasCover
                          ? [
                              Colors.white.withValues(alpha: 0.62),
                              colors.last.withValues(alpha: 0.72),
                            ]
                          : colors,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 17,
                        color: Color(0xFF101510),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF101510),
                            height: 1.2,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF1D2A1F),
                          height: 1.2,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: Color(0xFF101510),
                        ),
                      ),
                    ],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('6번째 세션 요약', style: _labelStyle(fontSize: 12)),
        const SizedBox(height: 12),
        BookCover(
          coverUrl: coverUrl,
          gradientIndex:
              bookTitle.hashCode.abs() % AppTheme.coverGradients.length,
          width: 80,
          height: 122,
          radius: 6,
        ),
        const SizedBox(height: 14),
        Text(
          bookTitle,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            color: _recapText,
            height: 1.25,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          meta,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _labelStyle(fontSize: 12),
        ),
      ],
    );
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
    return Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _recapCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 94,
            child: Row(
              children: [
                Icon(icon, size: 16, color: _recapMuted),
                const SizedBox(width: 8),
                Text(label, style: _labelStyle(fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: child),
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
            ).copyWith(color: _recapMuted.withValues(alpha: 0.86)),
          ),
          const SizedBox(width: 9),
        ],
        Text('$percent%', style: _valueStyle(color: color)),
      ],
    );
  }
}

// ─── 세션 요약: 초서 기록 값 (문장 10  기록 5) ───────────────────────
class _ChoseoSummarySection extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final bool isExpanded;
  final String bookTitle;
  final String bookAuthor;
  final VoidCallback onToggle;

  const _ChoseoSummarySection({
    required this.sentences,
    required this.isExpanded,
    required this.bookTitle,
    required this.bookAuthor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final recordCount = sentences.where((s) => s.thought.isNotEmpty).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _recapCard,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 116,
                    child: Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          size: 16,
                          color: _recapMuted,
                        ),
                        const SizedBox(width: 8),
                        Text('초서기록', style: _labelStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ChoseoValue(
                        sentenceCount: sentences.length,
                        recordCount: recordCount,
                        color: _recapText,
                        isExpanded: isExpanded,
                        onToggle: onToggle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ChoseoRecordsPanel(
            sentences: sentences,
            isExpanded: isExpanded,
            bookTitle: bookTitle,
            bookAuthor: bookAuthor,
          ),
        ],
      ),
    );
  }
}

class _ChoseoValue extends StatelessWidget {
  final int sentenceCount;
  final int recordCount;
  final Color color;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _ChoseoValue({
    required this.sentenceCount,
    required this.recordCount,
    required this.color,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '문장 $sentenceCount | 생각 $recordCount',
            style: _labelStyle(fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text('$sentenceCount개', style: _valueStyle(color: color)),
          Semantics(
            button: true,
            label: isExpanded ? '내 초서 기록 접기' : '내 초서 기록 펼치기',
            child: InkResponse(
              onTap: onToggle,
              radius: 18,
              child: SizedBox(
                width: 30,
                height: 30,
                child: AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 세션 요약: 수집한 문장 목록 ──────────────────────────────────────
class _ChoseoRecordsPanel extends ConsumerWidget {
  final List<CollectedSentence> sentences;
  final bool isExpanded;
  final String bookTitle;
  final String bookAuthor;

  const _ChoseoRecordsPanel({
    required this.sentences,
    required this.isExpanded,
    required this.bookTitle,
    required this.bookAuthor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlapAsync = ref.watch(sessionOverlapInsightsProvider(sentences));
    final insightsByNormalized = overlapAsync.maybeWhen(
      data: (insights) => {
        for (final insight in insights) insight.normalizedText: insight,
      },
      orElse: () => const <String, SessionOverlapInsight>{},
    );

    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity),
      secondChild: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: sentences.isEmpty
            ? Text(
                '아직 기록한 문장이 없어요',
                textAlign: TextAlign.right,
                style: _labelStyle(fontSize: 12),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < sentences.length; i++) ...[
                    _ChoseoRecordItem(
                      sentence: sentences[i],
                      overlapInsight:
                          insightsByNormalized[SentenceNormalizer.normalize(
                            sentences[i].content,
                          )],
                      bookTitle: bookTitle,
                      bookAuthor: bookAuthor,
                    ),
                    if (i < sentences.length - 1) const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
      crossFadeState: isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      sizeCurve: Curves.easeOutCubic,
    );
  }
}

class _ChoseoRecordItem extends StatefulWidget {
  final CollectedSentence sentence;
  final SessionOverlapInsight? overlapInsight;
  final String bookTitle;
  final String bookAuthor;

  const _ChoseoRecordItem({
    required this.sentence,
    required this.overlapInsight,
    required this.bookTitle,
    required this.bookAuthor,
  });

  @override
  State<_ChoseoRecordItem> createState() => _ChoseoRecordItemState();
}

class _ChoseoRecordItemState extends State<_ChoseoRecordItem> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final sentence = widget.sentence;
    final insight = widget.overlapInsight;
    final hasOverlap = insight != null;
    final thought = sentence.thought.trim();
    final hasThought = thought.isNotEmpty;
    final hasDetails = hasThought || hasOverlap;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(20, 17, 22, 17),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F1B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isOpen
                  ? Colors.white.withValues(alpha: 0.44)
                  : Colors.white.withValues(alpha: 0.03),
              width: _isOpen ? 1.1 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  sentence.pageNumber != null ? '${sentence.pageNumber}' : '',
                  style: _labelStyle(fontSize: 13).copyWith(
                    color: _recapMuted.withValues(alpha: 0.82),
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sentence.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(fontSize: 17).copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.48,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isOpen) _ChoseoRecordDropdown(thought: thought, insight: insight),
      ],
    );

    if (!hasDetails) return body;

    return Semantics(
      button: true,
      label: _isOpen ? '문장 기록 접기' : '문장 기록 펼치기',
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _isOpen = !_isOpen);
        },
        borderRadius: BorderRadius.circular(6),
        child: body,
      ),
    );
  }
}

class _ChoseoRecordDropdown extends StatelessWidget {
  final String thought;
  final SessionOverlapInsight? insight;

  const _ChoseoRecordDropdown({required this.thought, required this.insight});

  @override
  Widget build(BuildContext context) {
    final insight = this.insight;
    final overlapThoughts =
        insight?.thoughts.take(2).toList() ?? const <OverlapThought>[];

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(52, 17, 22, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF161B16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.045)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thought.isNotEmpty)
              Text(
                thought,
                style: _labelStyle(
                  fontSize: 16,
                ).copyWith(color: _recapBlue, height: 1.5),
              ),
            if (insight != null && overlapThoughts.isNotEmpty) ...[
              if (thought.isNotEmpty) const SizedBox(height: 18),
              Text(
                '${insight.readerCount}명의 독자가 이 문장에 남긴 생각',
                style: _labelStyle(fontSize: 12).copyWith(
                  color: _recapBlue.withValues(alpha: 0.82),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in overlapThoughts) ...[
                Text(
                  item.thought,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle(fontSize: 13).copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.displayNameOrUsername,
                  style: _labelStyle(fontSize: 11).copyWith(
                    color: _recapMuted.withValues(alpha: 0.82),
                    height: 1.2,
                  ),
                ),
                if (item != overlapThoughts.last)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

const _mockCompanionFriends = ['마고', '용성군', '온더그라운드'];
const _mockNearbyReaders = [
  '콩콩',
  '삼성',
  '엘지전자',
  '하이닉스남',
  '아마도스',
  '가라도스',
  '붉은가라도스',
  '익명의 은행나무',
  '늘푸른대학',
  '양평동교회',
  '양화공원',
  '비온다',
  '익명의 참나무',
  '익명의 소나무',
];

// ─── 세션 요약: 함께 읽은 사람 ───────────────────────────────────────
class _CompanionSummarySection extends StatelessWidget {
  final List<UserProfile> companions;
  final int friendCount;
  final int nearbyCount;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _CompanionSummarySection({
    required this.companions,
    required this.friendCount,
    required this.nearbyCount,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final friendNames = kUseMock
        ? _mockCompanionFriends
        : companions.map((p) => p.displayName).take(3).toList();
    final nearbyNames = kUseMock
        ? _mockNearbyReaders
        : companions.map((p) => p.displayName).skip(3).toList();
    final totalCount = friendCount + nearbyCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _recapCard,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: isExpanded ? '함께 읽은 사람 접기' : '함께 읽은 사람 펼치기',
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                height: 68,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 116,
                        child: Row(
                          children: [
                            Icon(
                              Icons.radio_button_checked_rounded,
                              size: 16,
                              color: _recapMuted,
                            ),
                            const SizedBox(width: 8),
                            Text('함께 읽은', style: _labelStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _CompanionValue(
                            friendCount: friendCount,
                            nearbyCount: nearbyCount,
                            totalCount: totalCount,
                            isExpanded: isExpanded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _CompanionNamesPanel(
              friendNames: friendNames,
              nearbyNames: nearbyNames,
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            reverseDuration: const Duration(milliseconds: 140),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _CompanionValue extends StatelessWidget {
  final int friendCount;
  final int nearbyCount;
  final int totalCount;
  final bool isExpanded;

  const _CompanionValue({
    required this.friendCount,
    required this.nearbyCount,
    required this.totalCount,
    required this.isExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '친구 $friendCount | 이웃 $nearbyCount',
            style: _labelStyle(fontSize: 11),
          ),
          const SizedBox(width: 10),
          Text('$totalCount명', style: _valueStyle(color: _recapText)),
          SizedBox(
            width: 30,
            height: 30,
            child: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: _recapText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionNamesPanel extends StatelessWidget {
  final List<String> friendNames;
  final List<String> nearbyNames;

  const _CompanionNamesPanel({
    required this.friendNames,
    required this.nearbyNames,
  });

  @override
  Widget build(BuildContext context) {
    final left = <String>[];
    final right = <String>[];
    for (var i = 0; i < nearbyNames.length; i++) {
      (i.isEven ? left : right).add(nearbyNames[i]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 26),
      child: Column(
        children: [
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          if (friendNames.isNotEmpty) ...[
            const SizedBox(height: 28),
            for (final name in friendNames) ...[
              Text(
                name,
                textAlign: TextAlign.center,
                style: _labelStyle(
                  fontSize: 20,
                ).copyWith(color: _recapBlue, height: 1.24),
              ),
              if (name != friendNames.last) const SizedBox(height: 10),
            ],
            const SizedBox(height: 28),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          ],
          if (nearbyNames.isNotEmpty) ...[
            const SizedBox(height: 26),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _CompanionNameColumn(names: left)),
                const SizedBox(width: 32),
                Expanded(child: _CompanionNameColumn(names: right)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanionNameColumn extends StatelessWidget {
  final List<String> names;

  const _CompanionNameColumn({required this.names});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final name in names) ...[
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(fontSize: 13).copyWith(
              color: _recapMuted.withValues(alpha: 0.86),
              height: 1.25,
            ),
          ),
          if (name != names.last) const SizedBox(height: 13),
        ],
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
            child: _SentenceAnalysisCard(
              entry: e.value,
              index: e.key,
              bookTitle: e.value.content,
            ),
          ),
        ),
      ],
    );
  }
}

class _SentenceAnalysisCard extends StatelessWidget {
  final CollectedSentence entry;
  final int index;
  final String bookTitle;
  const _SentenceAnalysisCard({
    required this.entry,
    required this.index,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    final tag = kUseMock ? _analyzeTag(entry.content) : _SentenceTag.normal;

    final (Color tagColor, IconData tagIcon, String tagDesc) = switch (tag) {
      _SentenceTag.resonance => (
        _recapText,
        Icons.auto_awesome_rounded,
        '독자의 ${_resonancePercent(entry.content)}%가 수집',
      ),
      _SentenceTag.rare => (
        _recapText,
        Icons.explore_rounded,
        '아직 ${_rareCount(entry.content)}명만 발견',
      ),
      _SentenceTag.peak => (
        _recapText,
        Icons.menu_book_rounded,
        '이 책에서 가장 많이 수집',
      ),
      _SentenceTag.viral => (
        _recapText,
        Icons.local_fire_department_rounded,
        '${_viralCount(entry.content)}명이 함께 본 문장',
      ),
      _SentenceTag.normal => (
        context.appTextTertiary,
        Icons.format_quote_rounded,
        '수집한 문장',
      ),
    };

    final isSpecial = tag != _SentenceTag.normal;
    final bookGradient = _recapBookGradientColors(bookTitle);
    final specialGradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        bookGradient.first.withValues(alpha: 0.22),
        bookGradient.last.withValues(alpha: 0.82),
      ],
    );

    return Container(
      decoration: AppTheme.smoothBox(
        color: isSpecial ? null : context.appCard,
        gradient: isSpecial ? specialGradient : null,
        radius: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 분석 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: ShapeDecoration(
              color: isSpecial
                  ? Colors.white.withValues(alpha: 0.12)
                  : tagColor.withValues(alpha: 0.05),
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
  final void Function(String route) onNavigate;
  const _RecapActions({required this.onShare, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      color: _recapActionBg,
      padding: const EdgeInsets.only(top: 18),
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
          const SizedBox(width: 8),
          // 홈
          _RecapActionButton(
            width: 70,
            icon: Icons.home_rounded,
            label: '홈',
            onTap: () => onNavigate(AppConstants.routeHome),
          ),
          const SizedBox(width: 8),
          // 서재
          _RecapActionButton(
            width: 84,
            icon: Icons.menu_book_rounded,
            label: '서재',
            onTap: () => onNavigate(AppConstants.routeLibrary),
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
    const fg = Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 32,
        decoration: BoxDecoration(
          color: filled ? AppTheme.primaryLight : _recapText,
          borderRadius: BorderRadius.circular(6),
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

// ─── 체인 라이트닝 — 완독 후 다음 책 추천 팝업 ──────────────────────────────
class _ChainLightningDialog extends StatelessWidget {
  final RecommendedBook book;
  final VoidCallback onRead;
  final VoidCallback onLater;

  const _ChainLightningDialog({
    required this.book,
    required this.onRead,
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
            Text(
              '다음 책으로 이건 어떠세요?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: context.appTextPrimary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 추천 책
            Row(
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
                        book.title,
                        style: AppTheme.bodyLarge.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.reason,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 바로 읽기
            Semantics(
              button: true,
              label: '바로 읽기',
              child: GestureDetector(
                onTap: onRead,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: AppTheme.smoothBox(
                    gradient: context.appReadingGradient,
                    radius: AppTheme.radiusMD,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '바로 읽기',
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

            // 나중에요
            Semantics(
              button: true,
              label: '나중에요',
              child: GestureDetector(
                onTap: onLater,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  child: Text(
                    '나중에요',
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
