import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 표준 플로팅 스낵바 — 테마/디자인 일관성을 위해 호출처에서 직접 SnackBar 생성 대신 사용
SnackBar chorokSnackBar(
  BuildContext context,
  String message, {
  bool success = true,
}) {
  return SnackBar(
    content: Row(
      children: [
        Icon(
          success ? Icons.check_circle_rounded : Icons.info_rounded,
          color: success ? context.appPrimaryAccent : context.appTextSecondary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
    backgroundColor: context.appCardElevated,
    behavior: SnackBarBehavior.floating,
    shape: SmoothRectangleBorder(
      smoothness: 0.6,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      side: BorderSide.none,
    ),
    margin: const EdgeInsets.fromLTRB(
      AppTheme.screenPadding,
      0,
      AppTheme.screenPadding,
      16,
    ),
    duration: const Duration(seconds: 2),
  );
}
