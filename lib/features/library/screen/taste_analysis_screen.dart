import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

class TasteAnalysisScreen extends StatelessWidget {
  final String? userId;

  const TasteAnalysisScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                18,
                AppTheme.screenPadding,
                24,
              ),
              child: Row(
                children: [
                  Semantics(
                    label: '뒤로 가기',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: AppTheme.smoothBox(
                          color: context.appCard,
                          radius: 27,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: context.appTextSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '독서 분석',
                    style: AppTheme.headingLarge.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
