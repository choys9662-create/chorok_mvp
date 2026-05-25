import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../core/services/stt_service.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/session_firefly_provider.dart';
import '../widget/chosu_sheet.dart';
import 'session_recap_screen.dart';

// 세션 화면은 항상 다크 — AppTheme 상수를 직접 alias
const _kGreen = AppTheme.primaryLight;
const _kSurface = AppTheme.darkSurface;
const _kSurfaceElevated = AppTheme.darkCardElevated;
const _kTextSecondary = AppTheme.textSecondary;
const _kFont = '조선굴림체';

const List<String> _kTopics = [
  '이 책의 제목이 품고 있는 의미는 무엇일까요?',
  '저자가 이 책을 쓴 이유는 무엇이었을까요?',
  '오늘 독서에서 어떤 문장을 초서하고 싶은가요?',
  '이 책이 나의 삶에 어떤 질문을 던질까요?',
  '읽기 전, 이 책에서 기대하는 한 가지는 무엇인가요?',
  '이 책의 주인공은 지금 어떤 상황에 있을까요?',
  '저자가 가장 전하고 싶은 것은 무엇일까요?',
  '이 책에서 가장 기억될 순간은 어디일까요?',
  '이 책을 읽고 나면 무엇이 달라져 있을까요?',
  '지금 내가 이 책을 읽는 이유는 무엇인가요?',
  '이 책이 다루는 세계는 나의 현실과 어떻게 다를까요?',
  '오늘 독서에서 배울 가장 소중한 것은 무엇일까요?',
  '마음에 가장 먼저 남을 문장은 어떤 모습일까요?',
  '이 책이 던지는 첫 번째 질문은 무엇일까요?',
  '책장을 넘기며 처음 느낄 감정은 무엇일까요?',
];

String _generateTopic(String bookTitle) {
  final h = bookTitle.codeUnits.fold(0, (a, b) => a + b);
  return _kTopics[h % _kTopics.length];
}

/// 독서 세션 화면
class ReadingSessionScreen extends ConsumerStatefulWidget {
  final SessionGoal? goal;

  /// 페이지 기록용 — 없으면 RecapData.bookId가 null이어서 DB 저장 생략
  final String? bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final int startPage;
  final int totalPages;

  const ReadingSessionScreen({
    super.key,
    this.goal,
    this.bookId,
    this.bookTitle = '채식주의자',
    this.bookAuthor = '한강',
    this.coverUrl,
    this.startPage = 0,
    this.totalPages = 0,
  });

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

enum UiVisibility { hidden, minimal, controls }

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _moveCtrl;

  UiVisibility _uiState = UiVisibility.minimal;
  Timer? _uiHideTimer;
  bool _goalReachedNotified = false;

  void _resetUiTimer({bool toControls = true}) {
    setState(() {
      _uiState = toControls ? UiVisibility.controls : UiVisibility.minimal;
    });
    _uiHideTimer?.cancel();

    _uiHideTimer = Timer(const Duration(seconds: 4), () {
      final t = ref.read(timerProvider);
      if (mounted && t.isRunning) {
        if (_uiState == UiVisibility.controls) {
          setState(() => _uiState = UiVisibility.minimal);
          _resetUiTimer(toControls: false);
        } else if (_uiState == UiVisibility.minimal) {
          setState(() => _uiState = UiVisibility.hidden);
        }
      }
    });
  }

  void _onScreenTap() {
    if (_uiState == UiVisibility.controls) {
      _resetUiTimer(toControls: false);
    } else {
      _resetUiTimer(toControls: true);
    }
  }

  void _dismissTopicAndStart() {
    setState(() => _showTopic = false);
    final timer = ref.read(timerProvider);
    if (timer.isIdle) {
      ref.read(timerProvider.notifier).start(goal: widget.goal);
    }
    _resetUiTimer();
  }

  void _openReadersSheet() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ReadersSheet(),
    ).then((_) => _resetUiTimer());
  }

  void _openCollectedSentencesSheet() {
    if (_collectedSentences.isEmpty) return;
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CollectedSentencesSheet(
        sentences: List.unmodifiable(_collectedSentences),
      ),
    ).then((_) => _resetUiTimer());
  }

  final List<CollectedSentence> _collectedSentences = [];
  late final DateTime _sessionStartedAt;

  bool _isRecording = false;
  bool _showSlideToStop = false;
  bool _showTopic = true;
  String _recognizedText = '';

  Future<void> _openOcr() async {
    ref.read(timerProvider.notifier).pause();
    _uiHideTimer?.cancel();
    final result = await Navigator.of(context).push<OcrResult>(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => const _OcrCaptureScreen(),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    _resetUiTimer();
    switch (result ?? const OcrCancelled()) {
      case OcrSuccess(text: final text):
        _openChosuSheet(initialText: text);
      case OcrNoText():
        ref.read(timerProvider.notifier).resume();
        _showOcrSnack('텍스트를 인식하지 못했어요. 더 또렷한 사진으로 다시 시도해 보세요.');
      case OcrError(message: final message):
        ref.read(timerProvider.notifier).resume();
        _showOcrSnack(message);
      case OcrCancelled():
        ref.read(timerProvider.notifier).resume();
    }
  }

  void _showOcrSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: _kFont)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleRecording() async {
    final stt = ref.read(sttServiceProvider);
    if (_isRecording) {
      await stt.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (_recognizedText.isEmpty) {
        ref.read(timerProvider.notifier).resume();
        return;
      }
      final text = _recognizedText;
      _recognizedText = '';
      _openChosuSheet(initialText: text);
    } else {
      final initialized = await stt.initialize();
      if (!initialized && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '마이크를 사용할 수 없습니다.',
              style: TextStyle(fontFamily: _kFont),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ref.read(timerProvider.notifier).pause();
      setState(() {
        _isRecording = true;
        _recognizedText = '';
      });
      await stt.listen(
        listenFor: const Duration(seconds: 30),
        onResult: (text) {
          if (mounted) setState(() => _recognizedText = text);
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _resetUiTimer();
    _sessionStartedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = ref.read(timerProvider);
      if (!timer.isIdle) {
        // 타이머 이미 실행 중 — 화두 오버레이 건너뜀
        setState(() => _showTopic = false);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(timerProvider.notifier).syncFromWallClock();
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    _uiHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pulseCtrl.dispose();
    _moveCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  Future<void> _openChosuSheet({String initialText = ''}) async {
    ref.read(timerProvider.notifier).pause();
    final result = await showModalBottomSheet<CollectedSentence>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ChosuSheet(initialText: initialText, bookTitle: widget.bookTitle),
    );
    if (!mounted) return;
    if (result != null && result.content.isNotEmpty) {
      setState(() => _collectedSentences.add(result));
    }
    ref.read(timerProvider.notifier).resume();
  }

  void _onStop() {
    HapticFeedback.mediumImpact();
    final seconds = ref.read(timerProvider).seconds;
    ref.read(timerProvider.notifier).stop();
    _navigateToRecap(seconds);
  }

  void _showSlideToUnlock() {
    HapticFeedback.mediumImpact();
    ref.read(timerProvider.notifier).pause();
    setState(() => _showSlideToStop = true);
  }

  void _dismissSlideToUnlock() {
    setState(() => _showSlideToStop = false);
    ref.read(timerProvider.notifier).resume();
  }

  void _navigateToRecap(int seconds) {
    if (!mounted) return;
    context.pushReplacement(
      AppConstants.routeRecap,
      extra: RecapData(
        seconds: seconds,
        bookTitle: widget.bookTitle,
        bookAuthor: widget.bookAuthor,
        coverUrl: widget.coverUrl,
        sentences: List.from(_collectedSentences),
        bookId: widget.bookId,
        startPage: widget.startPage,
        totalPages: widget.totalPages,
        sessionStartedAt: _sessionStartedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final firefly = ref.watch(sessionFireflyProvider).valueOrNull;
    final mutualCount = firefly?.mutualCount ?? 0;
    final nearbyCount = firefly?.nearbyCount ?? 0;
    final readersCount = mutualCount + nearbyCount;
    final mutuals = firefly?.mutuals ?? const [];

    if (timer.goalReached && !_goalReachedNotified) {
      _goalReachedNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '목표를 달성했어요! 🎉',
              style: TextStyle(
                fontFamily: _kFont,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF0D1A0D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    return Theme(
      data: AppTheme.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ① 배경
              const _SessionBackground(),

              // ② 반딧불이 + 독자 오브 + 중심 오브
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _moveCtrl]),
                builder: (_, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _FireflyPainter(
                        pulse: _pulseAnim.value,
                        time: _moveCtrl.value,
                        mutualCount: mutualCount,
                        nearbyCount: nearbyCount,
                      ),
                    ),
                    _NamedReaderOrbs(mutuals: mutuals, time: _moveCtrl.value),
                    Center(
                      child: _GlowOrb(
                        scale: _pulseAnim.value,
                        isPaused: timer.isPaused,
                      ),
                    ),
                  ],
                ),
              ),

              // ③ 화면 터치 감지 (상태 전환)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onScreenTap,
                child: Container(color: Colors.transparent),
              ),

              // ④ UI 레이어
              SafeArea(
                child: Stack(
                  children: [
                    // ─── Minimal 모드 (Pill Timer + CTA) ───
                    AnimatedOpacity(
                      opacity: _uiState == UiVisibility.minimal ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: _uiState != UiVisibility.minimal,
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Controls 모드 (Full UI) ───
                    AnimatedOpacity(
                      opacity: _uiState == UiVisibility.controls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: IgnorePointer(
                        ignoring: _uiState != UiVisibility.controls,
                        child: Stack(
                          children: [
                            // 상단 영역: 컨트롤 타이머
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                padding: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 1.0],
                                  ),
                                ),
                                child: _TimerTopBar(
                                  timer: timer,
                                  onTogglePause: () {
                                    HapticFeedback.mediumImpact();
                                    final ctrl = ref.read(
                                      timerProvider.notifier,
                                    );
                                    timer.isPaused
                                        ? ctrl.resume()
                                        : ctrl.pause();
                                    _resetUiTimer();
                                  },
                                  onStopPress: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '꾹 눌러서 세션을 종료하세요',
                                          style: TextStyle(
                                            fontFamily: _kFont,
                                            color: Colors.white,
                                          ),
                                        ),
                                        duration: Duration(milliseconds: 1500),
                                        backgroundColor: Color(0xFF0D1A0D),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  onStopLongPress: _showSlideToUnlock,
                                ),
                              ),
                            ),

                            // 하단 영역: 책 정보 + 기록 버튼 3종
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: EdgeInsets.fromLTRB(
                                  32,
                                  64,
                                  32,
                                  MediaQuery.of(context).padding.bottom + 32,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.95),
                                      Colors.black.withValues(alpha: 0.75),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.6, 1.0],
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.bookTitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: _kFont,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.bookAuthor,
                                      style: TextStyle(
                                        color: _kGreen.withValues(alpha: 0.8),
                                        fontSize: 14,
                                        fontFamily: _kFont,
                                      ),
                                    ),
                                    if (_collectedSentences.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      _SessionSentencePreview(
                                        sentences: _collectedSentences,
                                        onTap: _openCollectedSentencesSheet,
                                      ),
                                      const SizedBox(height: 24),
                                    ] else
                                      const SizedBox(height: 32),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _ActionButton(
                                          icon: Icons.people_alt_rounded,
                                          onTap: _openReadersSheet,
                                        ),
                                        _ActionButton(
                                          icon: Icons.title_rounded,
                                          onTap: () => _openChosuSheet(),
                                        ),
                                        _ActionButton(
                                          icon: Icons.camera_alt_rounded,
                                          onTap: _openOcr,
                                        ),
                                        _ActionButton(
                                          icon: _isRecording
                                              ? Icons.stop_rounded
                                              : Icons.graphic_eq_rounded,
                                          onTap: _toggleRecording,
                                          isActive: _isRecording,
                                          activeColor: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ⑤ 녹음 오버레이
              if (_isRecording)
                _RecordingOverlay(
                  recognizedText: _recognizedText,
                  onStop: _toggleRecording,
                ),

              // ⑥ 슬라이드 종료 오버레이
              if (_showSlideToStop)
                _SlideToStopOverlay(
                  onConfirm: () {
                    setState(() => _showSlideToStop = false);
                    _onStop();
                  },
                  onDismiss: _dismissSlideToUnlock,
                ),

              // ⑦ 화두 오버레이
              if (_showTopic)
                _TodaysTopicOverlay(
                  bookTitle: widget.bookTitle,
                  onStart: _dismissTopicAndStart,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 상단 pill 타이머 + 컨트롤 ────────────────────────────────────────────
class _TimerTopBar extends StatelessWidget {
  final TimerData timer;
  final VoidCallback onTogglePause;
  final VoidCallback onStopPress;
  final VoidCallback onStopLongPress;

  const _TimerTopBar({
    required this.timer,
    required this.onTogglePause,
    required this.onStopPress,
    required this.onStopLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // 종료 버튼 (꾹 누름)
          GestureDetector(
            onTap: onStopPress,
            onLongPress: onStopLongPress,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.stop_rounded,
                color: Colors.white.withValues(alpha: 0.35),
                size: 18,
              ),
            ),
          ),

          const Spacer(),

          // 중앙 pill 타이머
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _kGreen.withValues(alpha: timer.isPaused ? 0.25 : 0.45),
                width: 1,
              ),
              color: Colors.transparent,
            ),
            child: Text(
              timer.formattedTime,
              style: TextStyle(
                fontSize: 15,
                color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontFamily: _kFont,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          const Spacer(),

          // 일시정지/재개 버튼
          GestureDetector(
            onTap: onTogglePause,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: timer.isPaused
                      ? _kGreen.withValues(alpha: 0.40)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                color: timer.isPaused
                    ? _kGreen.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Icon(
                timer.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: timer.isPaused
                    ? _kGreen
                    : Colors.white.withValues(alpha: 0.35),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 중앙 pill 타이머 (단독 표시용) ────────────────────────────────────────────
class _PillTimerOnly extends StatelessWidget {
  final TimerData timer;

  const _PillTimerOnly({required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.25 : 0.45),
          width: 1,
        ),
        color: Colors.black, // Fireflies 가림
      ),
      child: Text(
        timer.formattedTime,
        style: TextStyle(
          fontSize: 15,
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
          fontFamily: _kFont,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── 함께 읽는 독자 CTA ────────────────────────────────────────────────────

// ─── 이름 있는 독자 오브 레이어 ──────────────────────────────────────────
class _NamedReaderOrbs extends StatelessWidget {
  final List<UserProfile> mutuals;
  final double time;

  const _NamedReaderOrbs({required this.mutuals, required this.time});

  static const _areas = [
    Offset(0.15, 0.25),
    Offset(0.78, 0.35),
    Offset(0.32, 0.75),
    Offset(0.65, 0.45),
    Offset(0.15, 0.65),
    Offset(0.84, 0.20),
    Offset(0.50, 0.85),
    Offset(0.82, 0.65),
  ];

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final tp = time * 2 * math.pi;

    return Stack(
      fit: StackFit.expand,
      children: List.generate(math.min(mutuals.length, _areas.length), (i) {
        final user = mutuals[i];
        final area = _areas[i];
        final seed = user.username.hashCode.abs();
        final rng = math.Random(seed);

        final driftAmp = 7.0 + rng.nextDouble() * 10.0;
        final phX = rng.nextDouble() * 2 * math.pi;
        final phY = rng.nextDouble() * 2 * math.pi;
        final orbR = 14.0 + rng.nextDouble() * 16.0;

        final cx = area.dx * size.width;
        final cy = area.dy * size.height;
        final dx = driftAmp * math.sin(tp + phX);
        final dy = driftAmp * math.cos(tp + phY);

        return Positioned(
          left: cx + dx - orbR,
          top: cy + dy - orbR,
          child: _SingleNamedOrb(name: user.displayName, radius: orbR),
        );
      }),
    );
  }
}

class _SingleNamedOrb extends StatelessWidget {
  final String name;
  final double radius;

  const _SingleNamedOrb({required this.name, required this.radius});

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: d,
          height: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kGreen.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: d * 0.65,
                height: d * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kGreen.withValues(alpha: 0.38),
                      _kGreen.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              ),
              Container(
                width: d * 0.32,
                height: d * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreen,
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.85),
                      blurRadius: radius * 0.7,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            color: _kGreen.withValues(alpha: 0.80),
            fontFamily: _kFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── 이번 세션에 기록한 문장 미리보기 ─────────────────────────────────────
class _SessionSentencePreview extends StatelessWidget {
  final List<CollectedSentence> sentences;
  final VoidCallback onTap;

  const _SessionSentencePreview({required this.sentences, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latest = sentences.last;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0B100B).withValues(alpha: 0.86),
          border: Border.all(color: _kGreen.withValues(alpha: 0.18), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 15,
                  color: _kGreen.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 6),
                Text(
                  '기록한 문장',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: _kFont,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: _kGreen.withValues(alpha: 0.13),
                  ),
                  child: Text(
                    '${sentences.length}',
                    style: TextStyle(
                      color: _kGreen.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: _kFont,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.42),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '"${latest.content}"',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
                fontStyle: FontStyle.italic,
                fontFamily: _kFont,
              ),
            ),
            if (latest.thought.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 14,
                    color: _kGreen.withValues(alpha: 0.58),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      latest.thought,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kTextSecondary.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.35,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CollectedSentencesSheet extends StatelessWidget {
  final List<CollectedSentence> sentences;

  const _CollectedSentencesSheet({required this.sentences});

  @override
  Widget build(BuildContext context) {
    final ordered = sentences.reversed.toList(growable: false);
    final maxListHeight = MediaQuery.of(context).size.height * 0.56;

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    color: _kGreen.withValues(alpha: 0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '이번 세션 문장',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: _kFont,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${sentences.length}',
                    style: TextStyle(
                      color: _kGreen.withValues(alpha: 0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: _kFont,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: ordered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return _CollectedSentenceTile(
                      sentence: ordered[index],
                      number: sentences.length - index,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectedSentenceTile extends StatelessWidget {
  final CollectedSentence sentence;
  final int number;

  const _CollectedSentenceTile({required this.sentence, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _kSurfaceElevated,
        border: Border.all(color: _kGreen.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number번째 문장',
            style: TextStyle(
              color: _kGreen.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: _kFont,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${sentence.content}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.6,
              fontStyle: FontStyle.italic,
              fontFamily: _kFont,
            ),
          ),
          if (sentence.thought.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: _kGreen.withValues(alpha: 0.62),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    sentence.thought,
                    style: TextStyle(
                      color: _kTextSecondary.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.55,
                      fontFamily: _kFont,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 테두리 없는 사각 액션 버튼 ──────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor = _kGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF161616),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive
              ? activeColor
              : const Color(0xFFFFFFFF).withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

// ─── 반딧불이 CustomPainter ────────────────────────────────────────────────
class _FireflyPainter extends CustomPainter {
  final double pulse;
  final double time;
  final int mutualCount;
  final int nearbyCount;

  const _FireflyPainter({
    required this.pulse,
    required this.time,
    this.mutualCount = 60,
    this.nearbyCount = 0,
  });

  static const int _count = 500;
  static const double _ref = 60.0;

  static final double _sizeScale = math.pow(_ref / _count, 0.35).toDouble();
  static final double _opacityScale = math.pow(_ref / _count, 0.28).toDouble();
  static final double _spreadMult = math.min(
    math.pow(_count / _ref, 0.22).toDouble(),
    1.5,
  );

  static final _flies = _buildFireflies();

  static List<
    ({
      double angle,
      double r,
      double baseSize,
      double baseOpacity,
      int type,
      double driftAmp,
      double driftPhX,
      double driftPhY,
      double driftFreq,
      double pulsePh,
      double pulseFreq,
    })
  >
  _buildFireflies() {
    final rng = math.Random(42);
    const globalMinR = 0.04;
    final globalMaxR = math.min(1.05 * _spreadMult, 1.22);

    return List.generate(_count, (i) {
      final u = rng.nextDouble();
      final r = math.sqrt(
        globalMinR * globalMinR +
            u * (globalMaxR * globalMaxR - globalMinR * globalMinR),
      );

      final type = r < 0.42
          ? 0
          : r < 0.84
          ? 1
          : 2;

      final driftFreq = (1 + rng.nextInt(3)).toDouble();
      final pulseFreq = (1 + rng.nextInt(5)).toDouble();

      final df = (1.0 - r * 0.42).clamp(0.45, 1.0);

      return (
        angle: rng.nextDouble() * 2 * math.pi,
        r: r,
        baseSize: (2.8 + rng.nextDouble() * 5.0) * _sizeScale * df,
        baseOpacity: (0.32 + rng.nextDouble() * 0.52) * _opacityScale * df,
        type: type,
        driftAmp: (4.0 + rng.nextDouble() * 9.0) * math.sqrt(_sizeScale) * df,
        driftPhX: rng.nextDouble() * 2 * math.pi,
        driftPhY: rng.nextDouble() * 2 * math.pi,
        driftFreq: driftFreq,
        pulsePh: rng.nextDouble() * 2 * math.pi,
        pulseFreq: pulseFreq,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tp = time * 2 * math.pi;

    final flies = _flies;
    for (int i = 0; i < flies.length; i++) {
      final f = flies[i];
      final baseX = cx + f.r * cx * math.cos(f.angle);
      final baseY = cy + f.r * cy * math.sin(f.angle);
      final dx = f.driftAmp * math.sin(tp * f.driftFreq + f.driftPhX);
      final dy = f.driftAmp * math.cos(tp * f.driftFreq + f.driftPhY);
      final x = baseX + dx;
      final y = baseY + dy;

      final pulseFactor = (math.sin(tp * f.pulseFreq + f.pulsePh) + 1) / 2;
      final op = f.baseOpacity * (0.3 + 0.7 * pulseFactor);
      if (op < 0.01) continue;
      final sz = f.baseSize * (0.7 + 0.3 * pulseFactor);

      const c = _kGreen;
      if (f.type == 0) {
        canvas.drawCircle(
          Offset(x, y),
          sz * 4.5,
          Paint()
            ..color = c.withValues(alpha: op * 0.10)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(3.0, 9.0 * _sizeScale),
            ),
        );
        canvas.drawCircle(
          Offset(x, y),
          sz * 2.4,
          Paint()
            ..color = c.withValues(alpha: op * 0.28)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(2.0, 4.0 * _sizeScale),
            ),
        );
        canvas.drawCircle(
          Offset(x, y),
          sz,
          Paint()..color = c.withValues(alpha: op),
        );
      } else if (f.type == 1) {
        canvas.drawCircle(
          Offset(x, y),
          sz * 2.8,
          Paint()
            ..color = c.withValues(alpha: op * 0.22)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(2.0, 6.0 * _sizeScale),
            ),
        );
        canvas.drawCircle(
          Offset(x, y),
          sz,
          Paint()..color = c.withValues(alpha: op),
        );
      } else {
        canvas.drawCircle(
          Offset(x, y),
          sz * 1.8,
          Paint()..color = c.withValues(alpha: op * 0.28),
        );
        canvas.drawCircle(
          Offset(x, y),
          sz,
          Paint()..color = c.withValues(alpha: op),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) =>
      old.pulse != pulse ||
      old.time != time ||
      old.mutualCount != mutualCount ||
      old.nearbyCount != nearbyCount;
}

// ─── 배경 (순수 블랙) ──────────────────────────────────────────────────────
class _SessionBackground extends StatelessWidget {
  const _SessionBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF050805), Color(0xFF000000)],
        ),
      ),
    );
  }
}

// ─── 나 — 중심 발광 오브 (5단 링) ────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double scale;
  final bool isPaused;

  const _GlowOrb({required this.scale, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final size = screenW * 0.55;
    final c = isPaused ? const Color(0xFF2A7A3D) : _kGreen;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: scale,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ring 1: 가장 바깥
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [c.withValues(alpha: 0.07), Colors.transparent],
                    ),
                  ),
                ),
                // Ring 2: 외곽 글로우
                Container(
                  width: size * 0.72,
                  height: size * 0.72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [c.withValues(alpha: 0.14), Colors.transparent],
                    ),
                  ),
                ),
                // Ring 3: 중간 글로우
                Container(
                  width: size * 0.50,
                  height: size * 0.50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [c.withValues(alpha: 0.26), Colors.transparent],
                    ),
                  ),
                ),
                // Ring 4: 내부 밝은 링
                Container(
                  width: size * 0.30,
                  height: size * 0.30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.withValues(alpha: 0.52),
                        c.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // Ring 5: 코어 도트
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.95),
                        blurRadius: 22,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: c.withValues(alpha: 0.45),
                        blurRadius: 55,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── OCR 촬영 화면 ───────────────────────────────────────────────────────
class _OcrCaptureScreen extends ConsumerStatefulWidget {
  const _OcrCaptureScreen();

  @override
  ConsumerState<_OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends ConsumerState<_OcrCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraCtrl;
  late final AnimationController _pulseCtrl;
  bool _initializing = true;
  bool _processing = false;
  bool _torchOn = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _statusMessage = '사용할 수 있는 카메라가 없어요';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _cameraCtrl = controller;

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() => _initializing = false);
    } on CameraException catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _statusMessage = '카메라를 열 수 없어요';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _cameraCtrl;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _processing) {
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      final result = await ref
          .read(ocrServiceProvider)
          .extractTextFromBytes(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusMessage = '촬영 중 문제가 생겼어요. 다시 시도해 주세요';
      });
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraCtrl;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }

    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _torchOn = next);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = '플래시를 사용할 수 없어요');
    }
  }

  void _close() {
    Navigator.of(context).pop(const OcrCancelled());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraCtrl;
    final cameraReady = controller?.value.isInitialized == true;
    final canCapture = cameraReady && !_processing && _statusMessage == null;

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (cameraReady && controller != null)
              _CameraPreviewCover(controller: controller)
            else
              _CameraPreparingView(
                initializing: _initializing,
                message: _statusMessage,
              ),
            Positioned.fill(child: _QuoteCameraOverlay(pulseCtrl: _pulseCtrl)),
            _CaptureTopBar(
              torchOn: _torchOn,
              torchEnabled: cameraReady && !_processing,
              onBack: _close,
              onTorch: _toggleTorch,
            ),
            _CaptureBottomBar(
              canCapture: canCapture,
              processing: _processing,
              message: _statusMessage,
              onCapture: _capture,
            ),
            if (_processing) const _OcrLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewCover({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CameraPreparingView extends StatelessWidget {
  final bool initializing;
  final String? message;

  const _CameraPreparingView({required this.initializing, this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050805), Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              initializing
                  ? Icons.camera_alt_rounded
                  : Icons.camera_alt_outlined,
              color: Colors.white.withValues(alpha: 0.72),
              size: 40,
            ),
            const SizedBox(height: 18),
            if (initializing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _kGreen,
                  strokeWidth: 2,
                ),
              )
            else
              Text(
                message ?? '카메라를 준비하지 못했어요',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: _kFont,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCameraOverlay extends StatelessWidget {
  final Animation<double> pulseCtrl;

  const _QuoteCameraOverlay({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final padding = MediaQuery.paddingOf(context);
            final frameW = math.min(size.width - 44, 360.0);
            final maxFrameH = math.max(
              190.0,
              size.height - padding.top - padding.bottom - 230,
            );
            final frameH = math.min(math.max(frameW * 0.64, 210.0), maxFrameH);
            final frameLeft = (size.width - frameW) / 2;
            final frameTop = (size.height - frameH) / 2 - 22;
            final frameRect = Rect.fromLTWH(
              frameLeft,
              frameTop,
              frameW,
              frameH,
            );
            final quoteAlpha = 0.54 + pulseCtrl.value * 0.28;

            return SizedBox.expand(
              child: CustomPaint(
                painter: _QuoteGuidePainter(
                  frameRect: frameRect,
                  pulse: pulseCtrl.value,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: frameLeft - 2,
                      top: frameTop - 52,
                      child: _GuideQuote(mark: '“', opacity: quoteAlpha),
                    ),
                    Positioned(
                      right: frameLeft - 2,
                      top: frameTop + frameH - 28,
                      child: _GuideQuote(mark: '”', opacity: quoteAlpha),
                    ),
                    ...List.generate(4, (index) {
                      final top = frameTop + frameH * (0.28 + index * 0.12);
                      return Positioned(
                        left: frameLeft + 42,
                        right: frameLeft + 42,
                        top: top,
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      );
                    }),
                    Positioned(
                      left: 28,
                      right: 28,
                      top: frameTop + frameH + 56,
                      child: Text(
                        '문장을 따옴표 안에 맞춰주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: _kFont,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GuideQuote extends StatelessWidget {
  final String mark;
  final double opacity;

  const _GuideQuote({required this.mark, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Text(
      mark,
      style: TextStyle(
        color: _kGreen.withValues(alpha: opacity),
        fontSize: 86,
        height: 1,
        fontWeight: FontWeight.w400,
        fontFamily: _kFont,
        shadows: [
          Shadow(color: _kGreen.withValues(alpha: 0.45), blurRadius: 22),
        ],
      ),
    );
  }
}

class _QuoteGuidePainter extends CustomPainter {
  final Rect frameRect;
  final double pulse;

  const _QuoteGuidePainter({required this.frameRect, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final cutout = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(18),
    );
    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    final borderPaint = Paint()
      ..color = _kGreen.withValues(alpha: 0.22 + pulse * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(cutout, borderPaint);

    final cornerPaint = Paint()
      ..color = _kGreen.withValues(alpha: 0.72 + pulse * 0.18)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const corner = 34.0;
    const inset = 2.0;
    final l = frameRect.left + inset;
    final t = frameRect.top + inset;
    final r = frameRect.right - inset;
    final b = frameRect.bottom - inset;

    canvas.drawLine(Offset(l, t + corner), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + corner, t), cornerPaint);
    canvas.drawLine(Offset(r - corner, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + corner), cornerPaint);
    canvas.drawLine(Offset(l, b - corner), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + corner, b), cornerPaint);
    canvas.drawLine(Offset(r - corner, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b - corner), Offset(r, b), cornerPaint);
  }

  @override
  bool shouldRepaint(_QuoteGuidePainter old) =>
      old.frameRect != frameRect || old.pulse != pulse;
}

class _CaptureTopBar extends StatelessWidget {
  final bool torchOn;
  final bool torchEnabled;
  final VoidCallback onBack;
  final VoidCallback onTorch;

  const _CaptureTopBar({
    required this.torchOn,
    required this.torchEnabled,
    required this.onBack,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _CaptureIconButton(
                icon: Icons.close_rounded,
                label: '닫기',
                onTap: onBack,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: const Text(
                  '문장 촬영',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: _kFont,
                  ),
                ),
              ),
              const Spacer(),
              _CaptureIconButton(
                icon: torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                label: torchOn ? '플래시 끄기' : '플래시 켜기',
                onTap: torchEnabled ? onTorch : null,
                active: torchOn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _CaptureIconButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? _kGreen.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.48),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? _kGreen.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? (active ? _kGreen : Colors.white)
                : Colors.white.withValues(alpha: 0.32),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CaptureBottomBar extends StatelessWidget {
  final bool canCapture;
  final bool processing;
  final String? message;
  final VoidCallback onCapture;

  const _CaptureBottomBar({
    required this.canCapture,
    required this.processing,
    required this.message,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(28, 34, 28, bottom + 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.66),
              Colors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: Text(
                message ?? (processing ? '텍스트 인식 중...' : '흔들림 없이 한 번에'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: message == null
                      ? Colors.white.withValues(alpha: 0.68)
                      : _kGreen.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: _kFont,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: canCapture ? onCapture : null,
              child: AnimatedOpacity(
                opacity: canCapture ? 1 : 0.45,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.88),
                      width: 3,
                    ),
                  ),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(alpha: 0.32),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ],
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

class _OcrLoadingOverlay extends StatelessWidget {
  const _OcrLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
              SizedBox(height: 16),
              Text(
                '텍스트 인식 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 녹음 오버레이 ────────────────────────────────────────────────────────
class _RecordingOverlay extends StatefulWidget {
  final String recognizedText;
  final VoidCallback onStop;

  const _RecordingOverlay({required this.recognizedText, required this.onStop});

  @override
  State<_RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<_RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStop,
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StopRecordingButton(pulseCtrl: _pulseCtrl, onTap: widget.onStop),
              const SizedBox(height: 20),
              const Text(
                '눌러서 중지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: _kFont,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '듣는 중...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontFamily: _kFont,
                ),
              ),
              if (widget.recognizedText.isNotEmpty) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      widget.recognizedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.6,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRecordingButton extends StatelessWidget {
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _StopRecordingButton({required this.pulseCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 96;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: buttonSize + 48,
        height: buttonSize + 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, _) {
                final t = pulseCtrl.value;
                final scale = 1.0 + t * 0.4;
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 슬라이드 종료 오버레이 ───────────────────────────────────────────────
class _SlideToStopOverlay extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _SlideToStopOverlay({required this.onConfirm, required this.onDismiss});

  @override
  State<_SlideToStopOverlay> createState() => _SlideToStopOverlayState();
}

class _SlideToStopOverlayState extends State<_SlideToStopOverlay> {
  static const double _trackHeight = 64.0;
  static const double _thumbSize = 52.0;
  static const double _trackPadding = 6.0;

  double _dragX = 0.0;
  double _maxDrag = 0.0;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX = (_dragX + d.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragX >= _maxDrag * 0.9) {
      widget.onConfirm();
    } else {
      setState(() => _dragX = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.70),
          child: SafeArea(
            child: Stack(
              children: [
                // 슬라이더 — 화면 중앙
                Center(
                  child: GestureDetector(
                    onTap: () {}, // 슬라이더 영역 탭은 dismiss 막기
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '스와이프 하여 독서를 종료',
                            style: TextStyle(
                              color: _kGreen.withValues(alpha: 0.85),
                              fontSize: 14,
                              fontFamily: _kFont,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              _maxDrag =
                                  constraints.maxWidth -
                                  _thumbSize -
                                  _trackPadding * 2;
                              final progress = _maxDrag > 0
                                  ? _dragX / _maxDrag
                                  : 0.0;
                              return Container(
                                height: _trackHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _kGreen.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // 진행 트랙
                                    Positioned(
                                      left: _trackPadding,
                                      child: Container(
                                        width: _dragX + _thumbSize * 0.5,
                                        height: _thumbSize * 0.25,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: _kGreen.withValues(
                                            alpha: progress * 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 썸 버튼
                                    Positioned(
                                      left: _trackPadding + _dragX,
                                      child: GestureDetector(
                                        onHorizontalDragUpdate: _onDragUpdate,
                                        onHorizontalDragEnd: _onDragEnd,
                                        child: Container(
                                          width: _thumbSize,
                                          height: _thumbSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: _kGreen,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.black,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 우하단 취소(잠금) 버튼
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 오늘의 화두 오버레이 ─────────────────────────────────────────────────
class _TodaysTopicOverlay extends StatefulWidget {
  final String bookTitle;
  final VoidCallback onStart;

  const _TodaysTopicOverlay({required this.bookTitle, required this.onStart});

  @override
  State<_TodaysTopicOverlay> createState() => _TodaysTopicOverlayState();
}

class _TodaysTopicOverlayState extends State<_TodaysTopicOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topic = _generateTopic(widget.bookTitle);
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Colors.black.withValues(alpha: 0.92),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '오늘의 화두',
                  style: TextStyle(
                    color: _kGreen.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.bookTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 14,
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _kGreen.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    topic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.75,
                      fontWeight: FontWeight.w300,
                      fontFamily: _kFont,
                    ),
                  ),
                ),
                const SizedBox(height: 56),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onStart();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kGreen,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(alpha: 0.40),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      '독서 시작하기',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onStart();
                  },
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text(
                        '건너뛰기',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.30),
                          fontSize: 13,
                          fontFamily: _kFont,
                        ),
                      ),
                    ),
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

// ─── 접속 중인 독자 목록 시트 ─────────────────────────────────────────────
class _ReadersSheet extends ConsumerWidget {
  const _ReadersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fireflyAsync = ref.watch(sessionFireflyProvider);
    final mutuals = fireflyAsync.valueOrNull?.mutuals ?? const [];

    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _kGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '지금 함께 읽는 사람들',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: _kFont,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '맞팔 ${mutuals.length}명',
                    style: TextStyle(
                      fontSize: 14,
                      color: _kGreen.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                      fontFamily: _kFont,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (fireflyAsync.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: _kGreen,
                  strokeWidth: 2,
                ),
              )
            else if (mutuals.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 24,
                ),
                child: Text(
                  '아직 맞팔한 친구가 없어요\n친구와 함께 읽어보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4),
                    height: 1.6,
                    fontFamily: _kFont,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: mutuals.length,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemBuilder: (context, i) {
                    final u = mutuals[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MutualReaderTile(user: u, index: i),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _MutualReaderTile extends StatelessWidget {
  final UserProfile user;
  final int index;

  const _MutualReaderTile({required this.user, required this.index});

  @override
  Widget build(BuildContext context) {
    final orbR = 14.0 + (user.username.hashCode.abs() % 8).toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreen.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        children: [
          // 발광 오브
          SizedBox(
            width: orbR * 2,
            height: orbR * 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: orbR * 2,
                  height: orbR * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _kGreen.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Container(
                  width: orbR * 0.65,
                  height: orbR * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreen,
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.75),
                        blurRadius: orbR * 0.5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 이름 + 상태
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.90),
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kGreen.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '읽는 중',
                      style: TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 북마크 아이콘
          Icon(
            index.isEven
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: _kGreen.withValues(alpha: index.isEven ? 0.85 : 0.35),
            size: 18,
          ),
        ],
      ),
    );
  }
}
