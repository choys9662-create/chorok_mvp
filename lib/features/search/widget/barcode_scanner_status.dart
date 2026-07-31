import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

class BarcodeScannerStatus {
  final bool processing;
  final String? message;
  final bool allowManualEntry;

  const BarcodeScannerStatus.idle()
    : processing = false,
      message = null,
      allowManualEntry = false;

  const BarcodeScannerStatus.loading(this.message)
    : processing = true,
      allowManualEntry = false;

  const BarcodeScannerStatus.failure(this.message)
    : processing = false,
      allowManualEntry = true;
}

class BarcodeScannerStatusCard extends StatelessWidget {
  final BarcodeScannerStatus status;
  final VoidCallback onManualEntry;

  const BarcodeScannerStatusCard({
    super.key,
    required this.status,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
      child: status.processing || status.message != null
          ? Padding(
              key: const ValueKey('barcode-status-card'),
              padding: const EdgeInsets.only(
                left: AppTheme.spaceXL,
                right: AppTheme.spaceXL,
                bottom: AppTheme.sectionGap,
              ),
              child: ChorokCard(
                showBorder: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXL,
                  vertical: AppTheme.spaceLG,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppTheme.spaceSM,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status.processing)
                          SizedBox(
                            width: AppTheme.iconMD,
                            height: AppTheme.iconMD,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.appPrimaryAccent,
                            ),
                          )
                        else
                          Icon(
                            Icons.info_outline_rounded,
                            size: AppTheme.iconMD,
                            color: context.appTextSecondary,
                          ),
                        const SizedBox(width: AppTheme.spaceMD),
                        Flexible(
                          child: Text(
                            status.message ?? '잠시 기다려주세요…',
                            style: AppTheme.rowText.copyWith(
                              color: context.appTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (status.allowManualEntry) ...[
                      Text(
                        '그래도 책을 찾을 수 없나요?',
                        style: AppTheme.supportingText.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                      TextButton(
                        onPressed: onManualEntry,
                        child: Text(
                          '직접 입력',
                          style: AppTheme.supportingText.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey('barcode-status-empty')),
    );
  }
}
