import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 반딧불 데이터
class _Firefly {
  final Offset position;
  final double size;
  final double brightness;
  final double phaseOffset; // 깜빡임 위상 차이

  const _Firefly({
    required this.position,
    required this.size,
    required this.brightness,
    required this.phaseOffset,
  });
}

/// 라이브 포레스트 CustomPainter
///
/// 글로우는 매 프레임 `MaskFilter.blur`로 그리면 GPU 부하·발열이 커서,
/// 부드러운 글로우 스프라이트(흰색 알파 그라데이션)를 한 번만 구워두고
/// 반딧불마다 `drawImageRect`로 색·투명도만 modulate 한다. 블러 0회.
class _LiveForestPainter extends CustomPainter {
  final List<_Firefly> fireflies;
  final ui.Image sprite;
  final ValueListenable<double> t;

  _LiveForestPainter({
    required this.fireflies,
    required this.sprite,
    required this.t,
  }) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final animationValue = t.value;
    final spriteSize = sprite.width.toDouble();
    final src = Rect.fromLTWH(0, 0, spriteSize, spriteSize);

    for (final f in fireflies) {
      final pos = Offset(
        f.position.dx * size.width,
        f.position.dy * size.height,
      );

      // 개별 반짝임 계산
      final pulse =
          0.65 + 0.35 * sin((animationValue * 2 * pi) + f.phaseOffset);
      final alpha = (f.brightness * pulse).clamp(0.0, 1.0);

      // 스프라이트의 코어 반경이 f.size에 대응하도록 스케일.
      final half = f.size * 6.25;
      final dst = Rect.fromCenter(
        center: pos,
        width: half * 2,
        height: half * 2,
      );

      final paint = Paint()
        ..filterQuality = FilterQuality.low
        ..colorFilter = ColorFilter.mode(
          AppTheme.fireflyColor.withValues(alpha: alpha),
          BlendMode.modulate,
        );
      canvas.drawImageRect(sprite, src, dst, paint);
    }
  }

  // 리페인트는 [t] 리스너가 구동한다.
  @override
  bool shouldRepaint(_LiveForestPainter oldDelegate) => false;
}

/// 라이브 포레스트 위젯
/// 현재 읽는 중인 사용자들을 반딧불로 시각화
class LiveForestWidget extends StatefulWidget {
  /// 현재 읽는 중 (밝음)
  final int activeCount;

  /// 오늘 읽음 (중간)
  final int todayCount;

  /// 이번 주 읽음 (희미)
  final int weekCount;

  const LiveForestWidget({
    super.key,
    this.activeCount = 15,
    this.todayCount = 33,
    this.weekCount = 32,
  });

  @override
  State<LiveForestWidget> createState() => _LiveForestWidgetState();
}

class _LiveForestWidgetState extends State<LiveForestWidget> {
  // 깜빡임 위상(0~1). 60fps vsync마다 다시 그리면 발열이 커서 ~15fps로 갱신.
  static const _periodSeconds = 5.0;
  static const _frame = Duration(milliseconds: 66);

  final ValueNotifier<double> _t = ValueNotifier(0);
  Timer? _timer;
  late List<_Firefly> _fireflies;
  ui.Image? _sprite;

  @override
  void initState() {
    super.initState();
    _generateFireflies();
    _sprite = _bakeGlowSprite();
    _timer = Timer.periodic(_frame, (_) {
      _t.value =
          (_t.value + _frame.inMilliseconds / 1000 / _periodSeconds) % 1.0;
    });
  }

  /// 코어 + 부드러운 헤일로를 한 장의 알파 그라데이션 스프라이트로 굽는다.
  ui.Image _bakeGlowSprite() {
    const dim = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(dim / 2, dim / 2);
    const radius = dim / 2;
    final shader = ui.Gradient.radial(
      center,
      radius,
      [
        Colors.white.withValues(alpha: 1.0), // 코어 중심
        Colors.white.withValues(alpha: 0.40), // 첫 번째 글로우
        Colors.white.withValues(alpha: 0.20), // 두 번째 글로우
        Colors.white.withValues(alpha: 0.0), // 헤일로 가장자리
      ],
      [0.0, 0.10, 0.16, 1.0],
    );
    canvas.drawCircle(center, radius, Paint()..shader = shader);
    return recorder.endRecording().toImageSync(dim, dim);
  }

  void _generateFireflies() {
    final rng = Random(); // 매번 다른 패턴의 반딧불을 생성하도록 고정 시드 제거
    _fireflies = [];

    void addGroup(
      int count,
      double brightness,
      double minSize,
      double maxSize,
    ) {
      for (int i = 0; i < count; i++) {
        _fireflies.add(
          _Firefly(
            position: Offset(rng.nextDouble(), rng.nextDouble()),
            size: minSize + rng.nextDouble() * (maxSize - minSize),
            brightness: brightness,
            phaseOffset: rng.nextDouble() * 2 * pi,
          ),
        );
      }
    }

    addGroup(widget.activeCount, 1.0, 2.0, 3.5); // 현재 읽는 중
    addGroup(widget.todayCount, 0.45, 1.5, 2.5); // 오늘 읽음
    addGroup(widget.weekCount, 0.18, 1.0, 2.0); // 이번 주 읽음
  }

  @override
  void dispose() {
    _timer?.cancel();
    _t.dispose();
    _sprite?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sprite = _sprite;
    if (sprite == null) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _LiveForestPainter(
          fireflies: _fireflies,
          sprite: sprite,
          t: _t,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
