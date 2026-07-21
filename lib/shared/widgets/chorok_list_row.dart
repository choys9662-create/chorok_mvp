import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// leading · 제목/보조정보 · trailing 정렬만 맡기는 공통 리스트 행 셸.
///
/// 텍스트 스타일과 실제 상호작용의 의미는 각 화면이 소유한다.
class ChorokListRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? supporting;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  const ChorokListRow({
    super.key,
    required this.title,
    this.leading,
    this.supporting,
    this.trailing,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppTheme.spaceMD),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (supporting != null) ...[
                  const SizedBox(height: AppTheme.spaceXS),
                  supporting!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.spaceMD),
            trailing!,
          ],
        ],
      ),
    );

    return row;
  }
}
