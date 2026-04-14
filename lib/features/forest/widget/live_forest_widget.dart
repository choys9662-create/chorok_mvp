import 'dart:math';
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
class _LiveForestPainter extends CustomPainter {
  final List<_Firefly> fireflies;
  final double animationValue;

  const _LiveForestPainter({
    required this.fireflies,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in fireflies) {
      final pos = Offset(
        f.position.dx * size.width,
        f.position.dy * size.height,
      );

      // 개별 반짝임 계산
      final pulse =
          0.65 + 0.35 * sin((animationValue * 2 * pi) + f.phaseOffset);
      final alpha = (255 * f.brightness * pulse).clamp(0.0, 255.0).toInt();

      // 글로우 효과
      final glowPaint = Paint()
        ..color = AppTheme.fireflyColor.withValues(alpha: alpha / 255 * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, f.size * 4);
      canvas.drawCircle(pos, f.size * 3.5, glowPaint);

      // 반딧불 본체
      final bodyPaint = Paint()
        ..color = AppTheme.fireflyColor.withValues(alpha: alpha / 255);
      canvas.drawCircle(pos, f.size, bodyPaint);
    }
  }

  @override
  bool shouldRepaint(_LiveForestPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
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

class _LiveForestWidgetState extends State<LiveForestWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Firefly> _fireflies;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _generateFireflies();
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LiveForestPainter(
            fireflies: _fireflies,
            animationValue: _controller.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}
