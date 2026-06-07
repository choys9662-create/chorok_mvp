import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class TabSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const TabSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const double _trackHeight = 48;

  @override
  Widget build(BuildContext context) {
    const tabs = ['이번 주', '이번 달', '올해'];
    return SizedBox(
      height: _trackHeight,
      child: Container(
        decoration: AppTheme.smoothPill(
          color: context.appCard,
          side: BorderSide.none,
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: tabs.asMap().entries.map((e) {
            final isSelected = e.key == selected;
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(e.key);
                  },
                  customBorder: AppTheme.smoothShape(radius: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: AppTheme.smoothPill(
                      color: isSelected ? AppTheme.primary : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w400
                            : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : context.appTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
