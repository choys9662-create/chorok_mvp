import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chorok_card.dart';

/// 얇은 버튼의 채움 색. 두 톤 모두 글자는 검정이다(design.md §2).
enum ChorokButtonTone {
  /// 브랜드 그린 — 주요 행동 하나에만 쓴다.
  green,

  /// 흰색 — 초록과 나란히 놓이는 보조 행동.
  white,
}

/// 초록 얇은 버튼 — 높이 30, 모서리는 바깥 박스 규칙(10)을 따른다.
///
/// 화면마다 Semantics·GestureDetector·ChorokCard를 손으로 쌓던 것을 대신한다.
///
/// 버튼을 두 개 이상 세로로 쌓을 때는 글자 길이 때문에 폭이 달라 보이므로,
/// 가장 긴 버튼에 폭을 맞춘다:
///
/// ```dart
/// IntrinsicWidth(
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.stretch,
///     spacing: AppTheme.spaceSM,
///     children: [
///       ChorokButton(label: '이어 읽기', icon: Icons.play_arrow_rounded),
///       ChorokButton(label: '서재에 있는 책', tone: ChorokButtonTone.white),
///     ],
///   ),
/// )
/// ```
class ChorokButton extends StatelessWidget {
  /// 확정 높이. 세로 여백이 아니라 이 값이 버튼 크기를 정한다.
  static const double height = 30;

  /// 글자 좌우로 두는 여백. 스페이싱 래더가 아니라 이 버튼의 고유 치수다.
  static const double horizontalPadding = 84;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ChorokButtonTone tone;

  /// 좁은 자리에 놓을 때만 줄인다. 기본은 [horizontalPadding].
  final double padding;

  /// true면 가로를 꽉 채운다. false면 내용 + 좌우 여백만큼 차지한다.
  final bool expand;

  const ChorokButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.tone = ChorokButtonTone.green,
    this.padding = horizontalPadding,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = tone == ChorokButtonTone.green
        ? context.appPrimaryAccent
        : context.appTextPrimary;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: height,
          width: expand ? double.infinity : null,
          child: ChorokCard(
            // 높이가 30이라 세로 padding은 두지 않는다.
            padding: EdgeInsets.symmetric(horizontal: padding),
            backgroundColor: fill,
            borderColor: fill,
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppTheme.spaceLG, color: AppTheme.primary),
                  const SizedBox(width: AppTheme.spaceXS),
                ],
                Text(
                  label,
                  style: AppTheme.body.copyWith(
                    color: AppTheme.primary,
                    height: 1,
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
