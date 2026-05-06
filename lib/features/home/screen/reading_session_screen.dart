import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // ML Kit 임시 주석 처리
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
// import '../../../core/services/db_service.dart'; // 로그인 활성화 후 주석 해제
import '../../../core/services/ocr_service.dart';
import '../../../core/services/stt_service.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/session_firefly_provider.dart';
import '../widget/chosu_sheet.dart';
import 'session_recap_screen.dart';

const _kGreen = Color(0xFF00FF00);

/// 독서 세션 화면
class ReadingSessionScreen extends ConsumerStatefulWidget {
  final SessionGoal? goal;

  /// 페이지 기록용 — 없으면 RecapData.bookId가 null이어서 DB 저장 생략
  final String? bookId;
  final String bookTitle;
  final String bookAuthor;
  final int startPage;
  final int totalPages;

  const ReadingSessionScreen({
    super.key,
    this.goal,
    this.bookId,
    this.bookTitle = '채식주의자',
    this.bookAuthor = '한강',
    this.startPage = 0,
    this.totalPages = 0,
  });

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _moveCtrl;
  bool _isUiVisible = true;
  Timer? _uiHideTimer;

  void _resetUiTimer() {
    setState(() => _isUiVisible = true);
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 4), () {
      final t = ref.read(timerProvider);
      if (mounted && t.isRunning) {
        setState(() => _isUiVisible = false);
      }
    });
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
  final List<CollectedSentence> _collectedSentences = [];
  late final DateTime _sessionStartedAt;
  int? _exitSeconds; // 이탈로 종료될 때 저장

  // STT / OCR (추후 활성화 예정)
  bool _isRecording = false;
  bool _isOcrLoading = false;
  String _recognizedText = '';

  Future<void> _openOcr() async {
    setState(() => _isOcrLoading = true);
    final text = await ref.read(ocrServiceProvider).extractTextFromCamera();
    if (!mounted) return;
    setState(() => _isOcrLoading = false);
    if (text != null && text.isNotEmpty) {
      _openChosuSheet(initialText: text);
    }
  }

  Future<void> _toggleRecording() async {
    final stt = ref.read(sttServiceProvider);
    if (_isRecording) {
      await stt.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (_recognizedText.isNotEmpty) {
        final text = _recognizedText;
        _recognizedText = '';
        _openChosuSheet(initialText: text);
      }
    } else {
      final initialized = await stt.initialize();
      if (!initialized && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마이크를 사용할 수 없습니다.', style: TextStyle(fontFamily: 'Pretendard'))),
        );
        return;
      }
      if (!mounted) return;
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
      if (timer.isIdle) {
        ref.read(timerProvider.notifier).start(goal: widget.goal);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final t = ref.read(timerProvider);
      if (t.isRunning || t.isPaused) {
        _exitSeconds = t.seconds;
        ref.read(timerProvider.notifier).stop();
      }
    } else if (state == AppLifecycleState.resumed && _exitSeconds != null) {
      _navigateToRecap(_exitSeconds!);
      _exitSeconds = null;
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
    super.dispose();
  }

  // 초서 시트 열기 (공통)
  // ignore: unused_element
  Future<void> _openChosuSheet({String initialText = ''}) async {
    final result = await showModalBottomSheet<CollectedSentence>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChosuSheet(initialText: initialText),
    );
    if (!mounted) return;
    if (result != null && result.content.isNotEmpty) {
      setState(() => _collectedSentences.add(result));
    }
    ref.read(timerProvider.notifier).resume();
  }

  Future<void> _onStop() async {
    HapticFeedback.mediumImpact();
    final seconds = ref.read(timerProvider).seconds;
    ref.read(timerProvider.notifier).stop();
    _navigateToRecap(seconds);
  }

  void _navigateToRecap(int seconds) {
    // 점수 계산 (recap 화면과 동일한 공식)
    final score =
        (45 +
                (_collectedSentences.length * 3).clamp(0, 15) +
                (seconds ~/ 90).clamp(0, 40))
            .clamp(0, 100);
    // ignore: unused_local_variable — 로그인 활성화 후 DB 저장에 사용
    final _ = score;

    if (!mounted) return;
    context.pushReplacement(
      AppConstants.routeRecap,
      extra: RecapData(
        seconds: seconds,
        bookTitle: widget.bookTitle,
        bookAuthor: widget.bookAuthor,
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

    return Theme(
      data: AppTheme.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: context.appBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ① 배경
            const _SessionBackground(),

            // ② 반딧불이 + 중심 오브 — 화면 전체
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
                  Center(
                    child: _GlowOrb(
                      scale: _pulseAnim.value,
                      isPaused: timer.isPaused,
                    ),
                  ),
                ],
              ),
            ),

            // ③ UI 레이어
            GestureDetector(
              onTap: _resetUiTimer,
              behavior: HitTestBehavior.opaque,
              child: AnimatedOpacity(
                opacity: _isUiVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 600),
                child: SafeArea(
                  minimum: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─ 상단 컨트롤 바 ──────────────────────────────
                      IgnorePointer(
                        ignoring: !_isUiVisible,
                        child: _TopBar(
                          timer: timer,
                          readersCount: readersCount,
                          onTogglePause: () {
                            HapticFeedback.mediumImpact();
                            final ctrl = ref.read(timerProvider.notifier);
                            timer.isPaused ? ctrl.resume() : ctrl.pause();
                            _resetUiTimer();
                          },
                          onStopPress: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('꾹 눌러서 세션을 종료하세요', style: TextStyle(fontFamily: 'Pretendard')),
                                duration: Duration(milliseconds: 1500),
                                backgroundColor: Color(0xFF1A3D2B),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          onStopLongPress: _onStop,
                          onReadersTap: _openReadersSheet,
                        ),
                      ),

                      // ─ 타이머 숫자 ──────────────────────────────────
                      IgnorePointer(
                        ignoring: !_isUiVisible,
                        child: Center(child: _TimerDisplay(timer: timer)),
                      ),

                      const Expanded(child: SizedBox()),

                      // ─ 하단 책 정보 + 초서 액션 바 ───────────────
                      IgnorePointer(
                        ignoring: !_isUiVisible,
                        child: _BottomArea(
                          chosuCount: _collectedSentences.length,
                          bookTitle: widget.bookTitle,
                          bookAuthor: widget.bookAuthor,
                          onOcrTap: _openOcr,
                          onRecordTap: _toggleRecording,
                          isRecording: _isRecording,
                          isOcrLoading: _isOcrLoading,
                          onTypeSentence: (text) =>
                              _openChosuSheet(initialText: text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ④ 녹음 오버레이 (STT 중일 때)
            if (_isRecording)
              _RecordingOverlay(
                recognizedText: _recognizedText,
                onStop: _toggleRecording,
              ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─── 상단 컨트롤 바 (얇은 HUD) ────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TimerData timer;
  final int readersCount;
  final VoidCallback onTogglePause;
  final VoidCallback onStopPress;
  final VoidCallback onStopLongPress;
  final VoidCallback onReadersTap;

  const _TopBar({
    required this.timer,
    required this.readersCount,
    required this.onTogglePause,
    required this.onStopPress,
    required this.onStopLongPress,
    required this.onReadersTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
      child: Row(
        children: [
          Text(
            timer.isPaused ? '일시정지' : '독서 중',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: _kGreen.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _kGreen,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.8), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onReadersTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  Text(
                    '$readersCount명 함께 읽는 중',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onTogglePause,
            child: Container(
              width: 32,
              height: 32,
              decoration: AppTheme.smoothBox(
                color: timer.isPaused ? _kGreen.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.09),
                radius: 9,
                side: BorderSide(
                  color: timer.isPaused ? _kGreen.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                timer.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: timer.isPaused ? _kGreen : Colors.white.withValues(alpha: 0.65),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onStopPress,
            onLongPress: onStopLongPress,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: AppTheme.smoothBox(
                color: Colors.red.withValues(alpha: 0.15),
                radius: 10,
                side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.red.withValues(alpha: 0.8), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '종료',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── 타이머 숫자 (상단 배치) ──────────────────────────────────────────
class _TimerDisplay extends StatelessWidget {
  final TimerData timer;
  const _TimerDisplay({required this.timer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        timer.formattedTime,
        style: TextStyle(
          fontSize: 60,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: Colors.white.withValues(alpha: 0.45),
          shadows: [
            Shadow(color: _kGreen.withValues(alpha: 0.15), blurRadius: 32),
          ],
        ),
      ),
    );
  }
}

// ─── 하단 영역 (책 정보 + 초서 액션 바) ──────────────────────────────
class _BottomArea extends StatelessWidget {
  final int chosuCount;
  final String bookTitle;
  final String bookAuthor;
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;

  const _BottomArea({
    required this.chosuCount,
    required this.bookTitle,
    required this.bookAuthor,
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF060B07).withValues(alpha: 0.97),
            Colors.transparent,
          ],
          stops: const [0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 책 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 그린 강조 바
              Container(
                width: 3,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00FF00), Color(0xFF00CC6A)],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 제목 + 저자
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bookAuthor,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.50),
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ],
                ),
              ),
              // 수집 문장 수 배지
              if (chosuCount > 0) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: AppTheme.smoothPill(
                    color: _kGreen.withValues(alpha: 0.08),
                    side: BorderSide(color: _kGreen.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        size: 12,
                        color: _kGreen.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$chosuCount문장',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kGreen.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // ─ 초서 액션 바 ─────────────────────────────────────
          _ChosuActionBar(
            onOcrTap: onOcrTap,
            onRecordTap: onRecordTap,
            isRecording: isRecording,
            isOcrLoading: isOcrLoading,
            onTypeSentence: onTypeSentence,
          ),
        ],
      ),
    );
  }
}

// ─── 초서 액션 바 (텍스트 입력 + OCR + 녹음) ───────────────────────────
class _ChosuActionBar extends StatefulWidget {
  final VoidCallback onOcrTap;
  final VoidCallback onRecordTap;
  final bool isRecording;
  final bool isOcrLoading;
  final ValueChanged<String> onTypeSentence;

  const _ChosuActionBar({
    required this.onOcrTap,
    required this.onRecordTap,
    required this.isRecording,
    required this.isOcrLoading,
    required this.onTypeSentence,
  });

  @override
  State<_ChosuActionBar> createState() => _ChosuActionBarState();
}

class _ChosuActionBarState extends State<_ChosuActionBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.onTypeSentence(text);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 텍스트 입력 필드
        Expanded(
          child: Container(
            height: 44,
            decoration: AppTheme.smoothPill(
              color: Colors.white.withValues(alpha: 0.07),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontFamily: 'Pretendard',
                    ),
                    decoration: InputDecoration(
                      hintText: '문장을 입력하세요...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.35),
                        fontFamily: 'Pretendard',
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submit(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                // 전송 버튼
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _ctrl,
                  builder: (_, val, x) {
                    final hasText = val.text.trim().isNotEmpty;
                    return GestureDetector(
                      onTap: hasText ? _submit : null,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: AnimatedOpacity(
                          opacity: hasText ? 1.0 : 0.3,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: _kGreen,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // OCR 버튼
        _QuickBtn(
          icon: widget.isOcrLoading
              ? Icons.hourglass_empty_rounded
              : Icons.photo_camera_outlined,
          label: '',
          onTap: widget.onOcrTap,
          isActive: widget.isOcrLoading,
        ),
        const SizedBox(width: 8),
        // 녹음 버튼
        _QuickBtn(
          icon: widget.isRecording
              ? Icons.stop_rounded
              : Icons.mic_none_rounded,
          label: '',
          onTap: widget.onRecordTap,
          isActive: widget.isRecording,
          activeColor: Colors.red,
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final Color activeColor;

  const _QuickBtn({
    required this.icon,
    required this.label,
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
        width: 44,
        height: 44,
        decoration: AppTheme.smoothPill(
          color: isActive
              ? activeColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.07),
          side: BorderSide(
            color: isActive
                ? activeColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.10),
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isActive ? activeColor : Colors.white.withValues(alpha: 0.65),
        ),
      ),
    );
  }
}

// ─── 반딧불이 CustomPainter (화면 전체) ──────────────────────────────
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

  // ── _count 하나만 바꾸면 크기·투명도·퍼짐이 자동 조정됨
  static const int _count = 500;
  static const double _ref = 60.0;

  static final double _sizeScale    = math.pow(_ref / _count, 0.35).toDouble();
  static final double _opacityScale = math.pow(_ref / _count, 0.28).toDouble();
  // 많을수록 화면 가장자리까지 넓게 퍼짐 (1.5 상한)
  static final double _spreadMult   = math.min(math.pow(_count / _ref, 0.22).toDouble(), 1.5);

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
        globalMinR * globalMinR + u * (globalMaxR * globalMaxR - globalMinR * globalMinR),
      );

      final type = r < 0.42 ? 0 : r < 0.84 ? 1 : 2;

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
      // 타원형 좌표계: r=1.0이 화면 가장자리 — 세로 긴 폰 화면 상하까지 고르게 채움
      final baseX = cx + f.r * cx * math.cos(f.angle);
      final baseY = cy + f.r * cy * math.sin(f.angle);
      final dx = f.driftAmp * math.sin(tp * f.driftFreq + f.driftPhX);
      final dy = f.driftAmp * math.cos(tp * f.driftFreq + f.driftPhY);
      final x = baseX + dx;
      final y = baseY + dy;

      final pulseFactor = (math.sin(tp * f.pulseFreq + f.pulsePh) + 1) / 2;
      final op = f.baseOpacity * (0.3 + 0.7 * pulseFactor);
      if (op < 0.01) continue; // 너무 흐린 반딧불이 스킵
      final sz = f.baseSize * (0.7 + 0.3 * pulseFactor);

      // 앞쪽 nearbyCount개 = 마젠타(주변), 나머지 = 초록(맞팔)
      final c = i < nearbyCount ? const Color(0xFFFF00FF) : _kGreen;
      if (f.type == 0) {
        // 내부 — 3단 글로우 (블러 반지름도 마릿수에 맞게 축소)
        canvas.drawCircle(
          Offset(x, y),
          sz * 4.5,
          Paint()
            ..color = c.withValues(alpha: op * 0.10)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(3.0, 9.0 * _sizeScale)),
        );
        canvas.drawCircle(
          Offset(x, y),
          sz * 2.4,
          Paint()
            ..color = c.withValues(alpha: op * 0.28)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 4.0 * _sizeScale)),
        );
        canvas.drawCircle(Offset(x, y), sz, Paint()..color = c.withValues(alpha: op));
      } else if (f.type == 1) {
        // 중간 — 블러 글로우 + 코어
        canvas.drawCircle(
          Offset(x, y),
          sz * 2.8,
          Paint()
            ..color = c.withValues(alpha: op * 0.22)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, 6.0 * _sizeScale)),
        );
        canvas.drawCircle(Offset(x, y), sz, Paint()..color = c.withValues(alpha: op));
      } else {
        // 외부 — 블러 없음, 소프트 링 + 코어 (드로우콜 최소화)
        canvas.drawCircle(
          Offset(x, y),
          sz * 1.8,
          Paint()..color = c.withValues(alpha: op * 0.28),
        );
        canvas.drawCircle(Offset(x, y), sz, Paint()..color = c.withValues(alpha: op));
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

// ─── 배경 ─────────────────────────────────────────────────────────────
class _SessionBackground extends StatelessWidget {
  const _SessionBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF0A1F0E), Color(0xFF060B07)],
        ),
      ),
    );
  }
}

// ─── 나 — 중심 발광 오브 ──────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double scale;
  final bool isPaused;

  const _GlowOrb({required this.scale, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final size = screenW * 0.58;
    final c = isPaused ? const Color(0xFF1A6B2D) : _kGreen;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 외곽 글로우
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [c.withValues(alpha: 0.09), Colors.transparent],
                ),
              ),
            ),
            Container(
              width: size * 0.52,
              height: size * 0.52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [c.withValues(alpha: 0.18), Colors.transparent],
                ),
              ),
            ),
            Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.withValues(alpha: 0.38),
                    c.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // 중심점
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: c.withValues(alpha: 0.9),
                    blurRadius: 18,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: c.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 8,
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

// ─── 녹음 오버레이 (STT 활성화 후 구현) ─────────────────────────────────
class _RecordingOverlay extends StatelessWidget {
  final String recognizedText;
  final VoidCallback onStop;

  const _RecordingOverlay({required this.recognizedText, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onStop,
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                '탭하여 중지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Pretendard',
                ),
              ),
              if (recognizedText.isNotEmpty) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    recognizedText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                      height: 1.6,
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

// ─── 접속 중인 독자 목록 ──────────────────────────────────────────────
class _ReadersSheet extends StatelessWidget {
  const _ReadersSheet();

  @override
  Widget build(BuildContext context) {
    // 목업 데이터
    final readers = [
      (name: '책벌레수진', book: '채식주의자', time: '1h 20m'),
      (name: '밤의여행자', book: '이방인', time: '45m'),
      (name: '초록잎', book: '데미안', time: '2h 10m'),
      (name: '달빛독서', book: '채식주의자', time: '15m'),
      (name: 'seoulreader', book: '모순', time: '55m'),
      (name: '북크리에이터', book: '도둑맞은 집중력', time: '3h 5m'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                      color: const Color(0xFF00FF00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00FF00).withValues(alpha: 0.5), blurRadius: 8),
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
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '총 42명',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF00FF00).withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: readers.length,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, i) {
                  final r = readers[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.smoothBox(
                        color: Colors.white.withValues(alpha: 0.05),
                        radius: 16,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            child: const Icon(Icons.person_rounded, color: Colors.white54, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  r.book,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            r.time,
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF00FF00).withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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
