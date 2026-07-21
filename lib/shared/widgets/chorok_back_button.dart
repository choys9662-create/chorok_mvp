import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// 초록 앱의 공용 뒤로가기 버튼.
class ChorokBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ChorokBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '뒤로가기',
      button: true,
      child: SizedBox.square(
        dimension: AppTheme.touchTarget,
        child: IconButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            onPressed();
          },
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: AppTheme.iconMD,
            color: context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}
