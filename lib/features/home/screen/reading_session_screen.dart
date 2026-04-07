import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
// import '../../../core/services/db_service.dart'; // 로그인 활성화 후 주석 해제
import '../../timer/controller/timer_controller.dart';
import '../widget/chosu_sheet.dart';
import 'session_recap_screen.dart';

const _kGreen = Color(0xFF00FF00);

/// 독서 세션 화면
class ReadingSessionScreen extends ConsumerStatefulWidget {
  final SessionGoal? goal;

  const ReadingSessionScreen({super.key, this.goal});

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _moveCtrl;
  bool _showControls = false;
  final List<String> _collectedSentences = [];

  @override
  void initState() {
    super.initState();
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
      duration: const Duration(seconds: 30),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = ref.read(timerProvider);
      if (timer.isIdle) {
        ref.read(timerProvider.notifier).start(goal: widget.goal);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _moveCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // 초서 시트 열기 — 타이머 일시정지 후 재개
  Future<void> _openChosu() async {
    setState(() => _showControls = false);
    final timer = ref.read(timerProvider);
    if (timer.isRunning) ref.read(timerProvider.notifier).pause();

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChosuSheet(),
    );

    if (!mounted) return;
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _collectedSentences.add(result.trim()));
    }
    ref.read(timerProvider.notifier).resume();
  }

  Future<void> _onStop() async {
    HapticFeedback.mediumImpact();
    final seconds = ref.read(timerProvider).seconds;
    ref.read(timerProvider.notifier).stop();

    // 점수 계산 (recap 화면과 동일한 공식)
    final score = (45 +
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
        bookTitle: '채식주의자',
        bookAuthor: '한강',
        sentences: List.from(_collectedSentences),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final ctrl = ref.read(timerProvider.notifier);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF060B07),
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
            SafeArea(
              minimum: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─ 상단 정보 바 ──────────────────────────────
                  _TopBar(
                    timer: timer,
                    chosuCount: _collectedSentences.length,
                    onMenuTap: () => setState(() => _showControls = true),
                  ),

                  // ─ 가운데 투명 영역 (반딧불이 가림 없이) ──────
                  const Spacer(),

                  // ─ 하단 책 정보 + 초서 액션 바 ───────────────
                  _BottomArea(chosuCount: _collectedSentences.length, onChosuTap: _openChosu),
                ],
              ),
            ),

            // ④ 컨트롤 오버레이
            if (_showControls)
              _ControlsOverlay(
                timer: timer,
                ctrl: ctrl,
                onDismiss: () => setState(() => _showControls = false),
                onStop: _onStop,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 상단 정보 바 ──────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TimerData timer;
  final int chosuCount;
  final VoidCallback onMenuTap;

  const _TopBar({
    required this.timer,
    required this.chosuCount,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      // 위에서 아래로 투명해지는 그라디언트 — 반딧불이 가리지 않음
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF060B07).withValues(alpha: 0.85),
            Colors.transparent,
          ],
          stops: const [0.55, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 + 숲벗 + 메뉴
          Row(
            children: [
              Text(
                timer.isPaused ? '일시정지' : '독서 중',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.2,
                  color: _kGreen.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 10),
              // 숲벗 카운트 (인라인)
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kGreen.withValues(alpha: 0.8),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '42명 함께 읽는 중',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              const Spacer(),
              // 일시정지/메뉴 버튼 — 존재를 알리되 눈에 안 띄게
              GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: AppTheme.smoothBox(
                    color: Colors.white.withValues(alpha: 0.07),
                    radius: 10,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        timer.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timer.isPaused ? '재개' : '일시정지',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SizedBox(height: 10),

          // 타이머
          Text(
            timer.formattedTime,
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Colors.white.withValues(alpha: 0.95),
              shadows: [
                Shadow(color: _kGreen.withValues(alpha: 0.18), blurRadius: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 진행 바 — 목표가 있으면 목표 대비, 없으면 45분 기본
          _GradientProgressBar(
            value: timer.goal?.type == SessionGoalType.time
                ? (timer.seconds / timer.goal!.targetSeconds).clamp(0.0, 1.0)
                : (timer.seconds % (45 * 60)) / (45 * 60),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timer.seconds < 60
                    ? '${timer.seconds}초 경과'
                    : '${timer.seconds ~/ 60}분 경과',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              Text(
                timer.goal != null && timer.goal!.type != SessionGoalType.free
                    ? '목표 ${timer.goal!.label}'
                    : '자유 독서',
                style: TextStyle(
                  fontSize: 10,
                  color: timer.goalReached
                      ? _kGreen.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── 하단 영역 (책 정보 + 초서 액션 바) ──────────────────────────────
class _BottomArea extends StatelessWidget {
  final int chosuCount;
  final VoidCallback onChosuTap;

  const _BottomArea({required this.chosuCount, required this.onChosuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
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
            children: [
              Container(
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF00FF00), Color(0xFF00CC6A)],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '채식주의자',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '한강 · 창비 · 2007',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (chosuCount > 0)
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
                        size: 11,
                        color: _kGreen.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$chosuCount문장',
                        style: TextStyle(
                          fontSize: 11,
                          color: _kGreen.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ─ 초서 액션 바 ─────────────────────────────────────
          // 카메라(OCR) + 마이크(STT) + 텍스트 입력 세 가지 경로를 항상 노출
          _ChosuActionBar(onTap: onChosuTap),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── 초서 액션 바 ─────────────────────────────────────────────────────
class _ChosuActionBar extends StatelessWidget {
  final VoidCallback onTap;
  const _ChosuActionBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // OCR 버튼
        _QuickBtn(
          icon: Icons.photo_camera_outlined,
          label: 'OCR',
          onTap: onTap,
        ),
        const SizedBox(width: 8),
        // STT 버튼
        _QuickBtn(icon: Icons.mic_none_rounded, label: '녹음', onTap: onTap),
        const SizedBox(width: 8),
        // 텍스트 입력 필드 (가장 직관적 — 넓게)
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: AppTheme.smoothBox(
                color: Colors.white.withValues(alpha: 0.07),
                radius: 12,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '문장 기록하기...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: AppTheme.smoothBox(
          color: Colors.white.withValues(alpha: 0.07),
          radius: 12,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.45)),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 반딧불이 CustomPainter (화면 전체) ──────────────────────────────
class _FireflyPainter extends CustomPainter {
  final double pulse;
  final double time;

  const _FireflyPainter({required this.pulse, required this.time});

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
    return List.generate(42, (i) {
      final type = i < 14
          ? 0
          : i < 28
          ? 1
          : 2;
      // 화면 전체로 분산 — 코너까지 도달하도록 r 범위 확장
      final minR = type == 0
          ? 0.08
          : type == 1
          ? 0.35
          : 0.60;
      final maxR = type == 0
          ? 0.60
          : type == 1
          ? 0.88
          : 1.05;
      return (
        angle: rng.nextDouble() * 2 * math.pi,
        r: minR + rng.nextDouble() * (maxR - minR),
        baseSize: type == 0
            ? 2.5 + rng.nextDouble() * 2.5
            : type == 1
            ? 1.5 + rng.nextDouble() * 2.0
            : 1.0 + rng.nextDouble() * 1.5,
        baseOpacity: type == 0
            ? 0.55 + rng.nextDouble() * 0.45
            : type == 1
            ? 0.18 + rng.nextDouble() * 0.22
            : 0.05 + rng.nextDouble() * 0.10,
        type: type,
        driftAmp: type == 0
            ? 7.0 + rng.nextDouble() * 7.0
            : type == 1
            ? 4.0 + rng.nextDouble() * 5.0
            : 2.0 + rng.nextDouble() * 3.0,
        driftPhX: rng.nextDouble() * 2 * math.pi,
        driftPhY: rng.nextDouble() * 2 * math.pi,
        driftFreq: 0.4 + rng.nextDouble() * 0.8,
        pulsePh: rng.nextDouble() * 2 * math.pi,
        pulseFreq: 1.0 + rng.nextDouble() * 2.0,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    // 화면 전체 커버: 코너까지 도달하는 반지름 사용
    final maxR = math.sqrt(cx * cx + cy * cy);
    final tp = time * 2 * math.pi;

    for (final f in _flies) {
      final baseX = cx + f.r * maxR * math.cos(f.angle);
      final baseY = cy + f.r * maxR * math.sin(f.angle);
      final dx = f.driftAmp * math.sin(tp * f.driftFreq + f.driftPhX);
      final dy = f.driftAmp * math.cos(tp * f.driftFreq + f.driftPhY);

      final x = baseX + dx;
      final y = baseY + dy;

      final pulseFactor = (math.sin(tp * f.pulseFreq + f.pulsePh) + 1) / 2;
      final op = f.baseOpacity * (0.35 + 0.65 * pulseFactor);
      final sz = f.baseSize * (0.65 + 0.35 * pulseFactor);

      // 글로우
      canvas.drawCircle(
        Offset(x, y),
        sz * 2.8,
        Paint()
          ..color = _kGreen.withValues(alpha: op * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      // 코어
      canvas.drawCircle(
        Offset(x, y),
        sz,
        Paint()..color = _kGreen.withValues(alpha: op),
      );
    }
  }

  @override
  bool shouldRepaint(_FireflyPainter old) =>
      old.pulse != pulse || old.time != time;
}

// ─── 그라디언트 진행 바 ────────────────────────────────────────────────
class _GradientProgressBar extends StatelessWidget {
  final double value;
  const _GradientProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => Container(
        height: 3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [Color(0xFF00FF00), Color(0xFF00CC6A)],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

// ─── 컨트롤 오버레이 (일시정지/종료) ─────────────────────────────────
class _ControlsOverlay extends StatelessWidget {
  final TimerData timer;
  final TimerNotifier ctrl;
  final VoidCallback onDismiss;
  final Future<void> Function() onStop;

  const _ControlsOverlay({
    required this.timer,
    required this.ctrl,
    required this.onDismiss,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Column(
            children: [
              // 닫기 버튼
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // 일시정지/재개
              GestureDetector(
                onTap: () {
                  if (timer.isRunning) {
                    ctrl.pause();
                  } else {
                    ctrl.resume();
                  }
                  onDismiss();
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A3D2B).withValues(alpha: 0.9),
                    border: Border.all(color: _kGreen.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.2),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Icon(
                    timer.isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _kGreen,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                timer.isRunning ? '일시정지' : '재개',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 32),
              // 밀어서 종료
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: GestureDetector(
                  onTap: () {}, // 이벤트 전파 차단
                  child: _SlideToExit(onExit: onStop),
                ),
              ),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 밀어서 종료 슬라이더 ─────────────────────────────────────────────
class _SlideToExit extends StatefulWidget {
  final Future<void> Function() onExit;
  const _SlideToExit({required this.onExit});

  @override
  State<_SlideToExit> createState() => _SlideToExitState();
}

class _SlideToExitState extends State<_SlideToExit>
    with SingleTickerProviderStateMixin {
  double _drag = 0;
  late final AnimationController _snapCtrl;
  bool _triggered = false;

  static const _handle = 50.0;
  static const _threshold = 0.75;

  @override
  void initState() {
    super.initState();
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _snapCtrl.dispose();
    super.dispose();
  }

  double _maxDrag(double w) => w - _handle;
  double _prog(double w) => (_drag / _maxDrag(w)).clamp(0.0, 1.0);

  void _onUpdate(DragUpdateDetails d, double w) {
    if (_triggered) return;
    _snapCtrl.stop();
    setState(() => _drag = (_drag + d.delta.dx).clamp(0.0, _maxDrag(w)));
  }

  void _onEnd(DragEndDetails d, double w) {
    if (_triggered) return;
    if (_prog(w) >= _threshold) {
      _triggered = true;
      HapticFeedback.mediumImpact();
      widget.onExit();
    } else {
      final anim = Tween<double>(
        begin: _drag,
        end: 0,
      ).animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.elasticOut));
      anim.addListener(() => setState(() => _drag = anim.value));
      _snapCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final p = _prog(w);

        return SizedBox(
          height: _handle,
          child: Stack(
            children: [
              Container(
                height: _handle,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(_handle / 2),
                  border: Border.all(
                    color: Color.lerp(
                      Colors.white.withValues(alpha: 0.12),
                      Colors.red.withValues(alpha: 0.5),
                      p,
                    )!,
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: p,
                child: Container(
                  height: _handle,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_handle / 2),
                    color: Colors.red.withValues(alpha: 0.10 + p * 0.15),
                  ),
                ),
              ),
              Center(
                child: Text(
                  '밀어서 종료',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.22 + 0.2 * p),
                  ),
                ),
              ),
              Positioned(
                left: _drag,
                top: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) => _onUpdate(d, w),
                  onHorizontalDragEnd: (d) => _onEnd(d, w),
                  child: Container(
                    width: _handle,
                    height: _handle,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        Colors.white.withValues(alpha: 0.14),
                        Colors.red.withValues(alpha: 0.75),
                        p,
                      ),
                      boxShadow: p > 0.15
                          ? [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3 * p),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.stop_rounded,
                      color: Colors.white.withValues(alpha: 0.5 + 0.5 * p),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
