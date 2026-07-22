import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 초록 표준 카드 컨테이너 — Apple-style smooth corner
class ChorokCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color? borderColor;
  final Clip clipBehavior;
  final bool showBorder;

  /// 중첩 박스용 surface(#222422)와 radius 6을 사용한다.
  final bool inner;

  /// [inner]의 이전 이름. 호출부 호환을 위해 유지한다.
  final bool elevated;
  final bool hasShadow;

  const ChorokCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.gradient,
    this.borderColor,
    this.clipBehavior = Clip.none,
    this.showBorder = true,
    this.inner = false,
    this.elevated = false,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final useInnerSurface = inner || elevated;
    final bg =
        backgroundColor ??
        (useInnerSurface ? context.appCardElevated : context.appCard);

    return Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.cardPaddingMD),
      clipBehavior: clipBehavior,
      decoration: AppTheme.smoothBox(
        color: gradient == null ? bg : null,
        gradient: gradient,
        radius: useInnerSurface ? AppTheme.radiusInner : AppTheme.radiusOuter,
        side: showBorder
            ? BorderSide(color: borderColor ?? context.appBorder)
            : BorderSide.none,
        shadows: hasShadow
            ? [
                BoxShadow(
                  color: context.appPrimaryAccent.withValues(alpha: 0.18),
                  blurRadius: AppTheme.spaceXL,
                  offset: const Offset(0, AppTheme.spaceSM),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// 토큰 기반 진행 바 — 다크 중첩 트랙과 브랜드 그린 fill을 공유한다.
class ChorokProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? trackColor;
  final Color? valueColor;
  final Gradient? gradient;

  const ChorokProgressBar({
    super.key,
    required this.value,
    this.height = AppTheme.spaceXS,
    this.trackColor,
    this.valueColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (_, constraints) => ClipPath(
          clipper: ShapeBorderClipper(
            shape: AppTheme.smoothBorder(AppTheme.radiusInner),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ChorokCard(
                inner: true,
                showBorder: false,
                padding: EdgeInsets.zero,
                backgroundColor: trackColor ?? context.appProgressTrack,
                child: const SizedBox.expand(),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: constraints.maxWidth * value.clamp(0.0, 1.0),
                  child: ChorokCard(
                    inner: true,
                    showBorder: false,
                    padding: EdgeInsets.zero,
                    backgroundColor: valueColor,
                    gradient: valueColor == null
                        ? gradient ?? context.appReadingGradient
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
