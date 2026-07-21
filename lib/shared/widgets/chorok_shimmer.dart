import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 단순 pulse shimmer 박스 — 외부 패키지 없이 구현
class ChorokShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const ChorokShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = AppTheme.radiusOuter,
  });

  @override
  State<ChorokShimmer> createState() => _ChorokShimmerState();
}

class _ChorokShimmerState extends State<ChorokShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: AppTheme.smoothBox(
          color: Color.lerp(
            context.appCardElevated,
            context.appCard,
            _anim.value,
          ),
          radius: widget.radius,
        ),
      ),
    );
  }
}
