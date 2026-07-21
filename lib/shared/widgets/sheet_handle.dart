import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ChorokSheetHandle extends StatelessWidget {
  const ChorokSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppTheme.space2XL + AppTheme.spaceMD,
        height: AppTheme.spaceXS,
        decoration: AppTheme.smoothBox(
          color: context.appDivider,
          radius: AppTheme.radiusInner,
        ),
      ),
    );
  }
}

/// 바텀시트에서 반복되는 handle + 제목 + 보조값/닫기 제어의 공통 헤더다.
///
/// 시트의 높이, 배경, 스크롤과 keyboard inset은 화면마다 달라 여기서 결정하지 않는다.
class ChorokSheetHeader extends StatelessWidget {
  final String title;
  final String? secondary;
  final Widget? trailing;
  final VoidCallback? onClose;
  final bool includeHandle;

  const ChorokSheetHeader({
    super.key,
    required this.title,
    this.secondary,
    this.trailing,
    this.onClose,
    this.includeHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final action =
        trailing ??
        (onClose == null
            ? null
            : IconButton(
                onPressed: onClose,
                color: context.appTextSecondary,
                tooltip: '닫기',
                icon: const Icon(Icons.close_rounded),
              ));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (includeHandle) ...[
          const SizedBox(height: AppTheme.spaceMD),
          const ChorokSheetHandle(),
          const SizedBox(height: AppTheme.spaceLG),
        ],
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.screenPadding,
            right: AppTheme.screenPadding,
            bottom: AppTheme.spaceSM,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sectionTitle.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    if (secondary != null) ...[
                      const SizedBox(width: AppTheme.spaceSM),
                      Text(
                        secondary!,
                        style: AppTheme.supportingText.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?action,
            ],
          ),
        ),
      ],
    );
  }
}
