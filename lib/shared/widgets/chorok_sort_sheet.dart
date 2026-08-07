import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'chorok_card.dart';
import 'sheet_handle.dart';

/// 정렬 시트의 한 항목. [value]는 선택 시 반환된다.
class ChorokSortOption<T> {
  final T value;
  final String label;
  const ChorokSortOption(this.value, this.label);
}

/// 정립된 정렬 바텀시트. 화면마다 흩어져 있던 정렬 시트를 하나로 통일한다.
///
/// 선택값을 반환한다. 취소(바깥 탭·드래그)하면 null.
/// 시트 크롬(배경·radius·핸들)은 여기서 확정하고 호출부는 옵션만 넘긴다.
Future<T?> showChorokSortSheet<T>({
  required BuildContext context,
  required String title,
  required List<ChorokSortOption<T>> options,
  required T selected,
}) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.appCard,
    shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
    builder: (_) => _ChorokSortSheet<T>(
      title: title,
      options: options,
      selected: selected,
    ),
  );
}

class _ChorokSortSheet<T> extends StatelessWidget {
  final String title;
  final List<ChorokSortOption<T>> options;
  final T selected;

  const _ChorokSortSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: AppTheme.spaceXL + AppTheme.spaceLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChorokSheetHeader(title: title),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Column(
                children: [
                  for (final opt in options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                      child: _SortTile<T>(
                        option: opt,
                        selected: opt.value == selected,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortTile<T> extends StatelessWidget {
  final ChorokSortOption<T> option;
  final bool selected;

  const _SortTile({required this.option, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.label,
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop(option.value);
        },
        child: ChorokCard(
          inner: true,
          showBorder: false,
          backgroundColor: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : context.appCardElevated,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLG,
            vertical: AppTheme.spaceMD,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: AppTheme.body.copyWith(
                    color: selected
                        ? context.appPrimaryAccent
                        : context.appTextPrimary,
                  ),
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppTheme.primaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
