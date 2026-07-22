import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/reading_presence_repository.dart';

// 세션 화면은 항상 다크 — AppTheme 상수를 직접 alias
const _green = AppTheme.primaryLight;

const _fireflyStageOneEnd = Duration(minutes: 10);
const _fireflyStageTwoEnd = Duration(minutes: 30);
const _fireflyStageThreeEnd = Duration(minutes: 60);

/// 떠도는 움직임(wander)만의 속도 배율. pulse와 독립.
/// 반드시 정수 — 마스터 클록(_moveCtrl 120초) 루프 이음새(1→0)에서
/// 위치가 안 튀려면 주파수가 정수여야 한다. 2면 2배 빠름, 1이 기본.
const _wanderSpeed = 1;

typedef FireflyVisual = ({double growthScale, int layers, double pulseAmplitude});

/// 연속 독서 시간에 따른 성장 배율. 절대 크기는 orb마다 자기 base에
/// 이 배율을 곱해 정한다(나=orbSelfBaseRadius, 친구=그×0.75 …).
/// 배율은 stage1 = 1.0 기준.
FireflyVisual fireflyVisualForElapsed(Duration elapsed) {
  if (elapsed < _fireflyStageOneEnd) {
    return (growthScale: 1.0, layers: 2, pulseAmplitude: 0);
  }
  if (elapsed < _fireflyStageTwoEnd) {
    return (growthScale: 1.2, layers: 2, pulseAmplitude: 0);
  }
  if (elapsed < _fireflyStageThreeEnd) {
    return (growthScale: 1.4, layers: 3, pulseAmplitude: 0.04);
  }
  return (growthScale: 1.6, layers: 3, pulseAmplitude: 0.06);
}

/// 동시 접속자가 많을 때 겹침을 줄이는 숲 밀도 규칙.
@visibleForTesting
double fireflyDensityScale(int activeReaderCount) {
  if (activeReaderCount <= 5) return 1;
  if (activeReaderCount <= 10) return 0.9;
  return 0.8;
}

// ─── 이름 있는 독자 오브 레이어 ──────────────────────────────────────────
// 캔버스 기반 오브/반딧불 렌더링은 세션의 몰입 레이어이므로 카드 규칙 적용 예외다.
class NamedReaderOrbs extends StatelessWidget {
  final List<UserProfile> mutuals;
  final Map<String, ReadingPresenceInfo> presences;
  final int neighborCount;
  final double time;
  final bool showNames;

  const NamedReaderOrbs({
    super.key,
    required this.mutuals,
    required this.presences,
    required this.neighborCount,
    required this.time,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty && neighborCount == 0) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final tp = time * 2 * math.pi;

    final widgets = <Widget>[];
    final densityScale = fireflyDensityScale(mutuals.length);
    final neighborLimit = math.min(neighborCount, 12);
    for (int i = 0; i < neighborLimit; i++) {
      _addOrb(
        widgets: widgets,
        size: size,
        tp: tp,
        seed: Object.hash('neighbor', i).abs(),
        // 이웃 = 나 base의 60%, 성장 없음.
        radiusBase: AppTheme.orbSelfBaseRadius * AppTheme.orbNeighborRatio,
        radiusRange: 0,
        layers: 1,
        label: '이웃',
        labelColor: context.appTextSecondary.withValues(alpha: 0.62),
        orbColor: context.appTextSecondary,
        orbAlpha: 0.35,
      );
    }

    for (int i = 0; i < math.min(mutuals.length, 12); i++) {
      final user = mutuals[i];
      final startedAt = presences[user.id]?.startedAt;
      final elapsed = startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt);
      final visual = fireflyVisualForElapsed(
        elapsed.isNegative ? Duration.zero : elapsed,
      );
      _addOrb(
        widgets: widgets,
        size: size,
        tp: tp,
        seed: user.username.hashCode.abs(),
        // 친구 = 나 base의 75% × 그 친구의 독서시간 성장배율.
        radiusBase:
            AppTheme.orbSelfBaseRadius *
            AppTheme.orbFriendRatio *
            visual.growthScale,
        radiusRange: 0,
        layers: visual.layers,
        pulseAmplitude: visual.pulseAmplitude,
        sizeScale: densityScale,
        label: user.displayName,
        labelColor: _green.withValues(alpha: 0.90),
        orbColor: _green,
        orbAlpha: 1.0,
      );
    }

    return Stack(fit: StackFit.expand, children: widgets);
  }

  void _addOrb({
    required List<Widget> widgets,
    required Size size,
    required double tp,
    required int seed,
    required double radiusBase,
    required double radiusRange,
    int layers = 3,
    double pulseAmplitude = 0,
    double sizeScale = 1,
    required String label,
    required Color labelColor,
    required Color orbColor,
    required double orbAlpha,
  }) {
    final rng = math.Random(seed);

    final pulsePhase = (seed % 360) * math.pi / 180;
    final pulseScale = 1 + pulseAmplitude * math.sin(tp + pulsePhase);
    final orbR =
        (radiusBase + rng.nextDouble() * radiusRange) * sizeScale * pulseScale;

    // 서로 다른 정수 주파수 사인의 합 → 궤도처럼 안 보이고 무작위하게 떠돈다.
    // 정수 주파수라 40초 루프 이음새(1→0)에서 위치가 안 튄다.
    // span: 가장자리 여백만 남기고(위 타이머·아래 CTA 침범 방지) 전 영역을 훑는다.
    double wander(int axisSalt, double span) {
      final r = math.Random(seed ^ axisSalt);
      double sum = 0, ampTotal = 0;
      for (int h = 0; h < 3; h++) {
        final freq = (1 + r.nextInt(4)) * _wanderSpeed; // 1~4 × 속도 배율
        final amp = 1.0 / (h + 1); // 1, 0.5, 0.33 — 저주파가 큰 흐름을 만든다
        final ph = r.nextDouble() * 2 * math.pi;
        sum += amp * math.sin(tp * freq + ph);
        ampTotal += amp;
      }
      return 0.5 + span * (sum / ampTotal);
    }

    final nx = wander(0x9e3779b9, 0.45);
    final ny = wander(0x85ebca6b, 0.40);
    final cx = nx * size.width;
    final cy = ny * size.height;

    final top = (cy - orbR).clamp(0.0, size.height - orbR * 2);
    final left = cx - orbR;

    widgets.add(
      Positioned(
        left: left,
        top: top,
        child: SingleNamedOrb(
          radius: orbR,
          color: orbColor,
          alpha: orbAlpha,
          layers: layers,
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: cx - 36,
        top: top + orbR * 2 + 5,
        width: 72,
        child: AnimatedOpacity(
          opacity: showNames ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.supportingText.copyWith(
              color: labelColor,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 나 — 중심 반딧불 ────────────────────────────────────────────────────
// 주변 독자와 같은 링 위젯·성장 규칙을 사용하되, 위치만 화면 중앙에 고정한다.
class GlowOrb extends StatelessWidget {
  final FireflyVisual visual;
  final double time;
  final bool isPaused;

  const GlowOrb({
    super.key,
    required this.visual,
    required this.time,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    // 나 orb = 절대 base × 내 독서시간 성장배율. 친구·이웃은 이 base의 비례.
    final radius = AppTheme.orbSelfBaseRadius * visual.growthScale;
    final pulseScale = isPaused
        ? 1.0
        : 1 + visual.pulseAmplitude * math.sin(time * 2 * math.pi);

    return Transform.scale(
      scale: pulseScale,
      child: SingleNamedOrb(
        key: const ValueKey('self-firefly'),
        radius: radius,
        color: _green,
        alpha: isPaused ? 0.25 : 1,
        layers: visual.layers,
      ),
    );
  }
}

// ─── 오브 프리미티브 — 반딧불·시트 오브가 공유하는 링 렌더러 ────────────────
class SingleNamedOrb extends StatelessWidget {
  final double radius;
  final Color color;
  final double alpha;
  final int layers;

  const SingleNamedOrb({
    super.key,
    required this.radius,
    this.color = _green,
    this.alpha = 1.0,
    this.layers = 3,
  });

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: OrbRingPainter(
          radius: radius,
          color: color,
          alpha: alpha,
          layers: layers,
        ),
      ),
    );
  }
}

class OrbRingPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double alpha;
  final int layers;

  const OrbRingPainter({
    required this.radius,
    this.color = _green,
    this.alpha = 1.0,
    this.layers = 3,
  }) : assert(layers >= 1 && layers <= 3);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // 시간이 지날수록 중심에서 바깥쪽으로 최대 3단까지 성장한다.
    if (layers >= 3) {
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = color.withValues(alpha: 0.2 * alpha),
      );
    }
    if (layers >= 2) {
      canvas.drawCircle(
        c,
        radius * 0.7,
        Paint()..color = color.withValues(alpha: 0.4 * alpha),
      );
    }
    canvas.drawCircle(
      c,
      radius * 0.4,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(OrbRingPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.alpha != alpha ||
      old.layers != layers;
}
