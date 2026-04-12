import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';

/// 독서 세션 목표 설정 바텀 시트
///
/// 반환값: [SessionGoal] — 사용자가 설정한 세션 목표
///         null — 시트가 닫혔을 때 (취소)
class SessionGoalSheet extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final String bookTitle;

  const SessionGoalSheet({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.bookTitle,
  });

  @override
  State<SessionGoalSheet> createState() => _SessionGoalSheetState();
}

class _SessionGoalSheetState extends State<SessionGoalSheet> {
  bool _isTimeGoal = true; // true: 시간 목표, false: 페이지 목표
  int? _selectedMinutes;
  final _pageController = TextEditingController();
  bool _customTimeMode = false;
  final _customMinutesController = TextEditingController();

  static const List<int> _presetMinutes = [15, 30, 45, 60, 90];

  @override
  void dispose() {
    _pageController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  SessionGoal? _buildGoal() {
    if (_isTimeGoal) {
      if (_customTimeMode) {
        final min = int.tryParse(_customMinutesController.text);
        if (min == null || min <= 0) return null;
        return SessionGoal.time(min);
      }
      if (_selectedMinutes == null) return null;
      return SessionGoal.time(_selectedMinutes!);
    } else {
      final page = int.tryParse(_pageController.text);
      if (page == null || page <= widget.currentPage) return null;
      return SessionGoal.pages(
        target: page,
        startPage: widget.currentPage,
      );
    }
  }

  void _submit() {
    final goal = _buildGoal();
    if (goal == null) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, goal);
  }

  void _submitFree() {
    HapticFeedback.selectionClick();
    Navigator.pop(context, const SessionGoal.free());
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 핸들 ───────────────────────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.darkBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── 헤더 ───────────────────────────────────────────
              Text(
                '이번 독서 목표',
                style: AppTheme.headingMedium.copyWith(
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.bookTitle,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 20),

              // ── 탭 선택 (시간 / 페이지) ────────────────────────
              _GoalTypeSelector(
                isTimeGoal: _isTimeGoal,
                onChanged: (v) => setState(() {
                  _isTimeGoal = v;
                  _customTimeMode = false;
                }),
              ),
              const SizedBox(height: 20),

              // ── 목표 입력 영역 ─────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: _isTimeGoal
                    ? _TimeGoalSection(
                        presets: _presetMinutes,
                        selectedMinutes: _selectedMinutes,
                        customMode: _customTimeMode,
                        customController: _customMinutesController,
                        onPresetTap: (min) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMinutes = min;
                            _customTimeMode = false;
                          });
                        },
                        onCustomTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMinutes = null;
                            _customTimeMode = true;
                          });
                        },
                      )
                    : _PageGoalSection(
                        currentPage: widget.currentPage,
                        totalPages: widget.totalPages,
                        controller: _pageController,
                        onChanged: () => setState(() {}),
                      ),
              ),
              const SizedBox(height: 24),

              // ── 시작 버튼 ──────────────────────────────────────
              Semantics(
                label: '독서 시작',
                button: true,
                child: GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: AppTheme.smoothBox(
                      gradient: AppTheme.greenGradient,
                      radius: AppTheme.radiusMD,
                    ),
                    child: Text(
                      '독서 시작하기',
                      style: AppTheme.bodyLarge.copyWith(
                        color: AppTheme.darkBg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── 자유 독서 버튼 ─────────────────────────────────
              Center(
                child: Semantics(
                  label: '목표 없이 자유롭게 읽기',
                  button: true,
                  child: GestureDetector(
                    onTap: _submitFree,
                    child: SizedBox(
                      height: 48,
                      child: Center(
                        child: Text(
                          '목표 없이 자유롭게 읽기',
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    ),
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

// ─── 목표 유형 선택기 ────────────────────────────────────────────────────

class _GoalTypeSelector extends StatelessWidget {
  final bool isTimeGoal;
  final ValueChanged<bool> onChanged;

  const _GoalTypeSelector({
    required this.isTimeGoal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCardElevated,
        radius: AppTheme.radiusMD,
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: '시간 목표',
              isSelected: isTimeGoal,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: '페이지 목표',
              isSelected: !isTimeGoal,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: AppTheme.smoothPill(
          color: isSelected ? AppTheme.primary : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: isSelected ? AppTheme.primaryLight : AppTheme.textTertiary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─── 시간 목표 영역 ──────────────────────────────────────────────────────

class _TimeGoalSection extends StatelessWidget {
  final List<int> presets;
  final int? selectedMinutes;
  final bool customMode;
  final TextEditingController customController;
  final ValueChanged<int> onPresetTap;
  final VoidCallback onCustomTap;

  const _TimeGoalSection({
    required this.presets,
    required this.selectedMinutes,
    required this.customMode,
    required this.customController,
    required this.onPresetTap,
    required this.onCustomTap,
  });

  String _formatPreset(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '$h시간 $m분' : '$h시간';
    }
    return '$minutes분';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((min) => _PresetChip(
                  label: _formatPreset(min),
                  isSelected: selectedMinutes == min && !customMode,
                  onTap: () => onPresetTap(min),
                )),
            _PresetChip(
              label: '직접 입력',
              isSelected: customMode,
              onTap: onCustomTap,
            ),
          ],
        ),
        if (customMode) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: AppTheme.smoothBox(
                    color: AppTheme.darkCardElevated,
                    radius: AppTheme.radiusMD,
                    side: const BorderSide(color: AppTheme.darkBorder),
                  ),
                  child: TextField(
                    controller: customController,
                    keyboardType: TextInputType.number,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '분 단위로 입력',
                      hintStyle: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '분',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label 선택',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: AppTheme.smoothPill(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.15)
                : AppTheme.darkCardElevated,
            side: BorderSide(
              color: isSelected ? AppTheme.accent : AppTheme.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 페이지 목표 영역 ────────────────────────────────────────────────────

class _PageGoalSection extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _PageGoalSection({
    required this.currentPage,
    required this.totalPages,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final targetPage = int.tryParse(controller.text);
    final remaining =
        targetPage != null && targetPage > currentPage
            ? targetPage - currentPage
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 현재 위치
        Text(
          '현재 $currentPage쪽 / $totalPages쪽',
          style: AppTheme.captionLarge.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // 입력 필드
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: AppTheme.smoothBox(
                  color: AppTheme.darkCardElevated,
                  radius: AppTheme.radiusMD,
                  side: const BorderSide(color: AppTheme.darkBorder),
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '목표 페이지 (예: ${(currentPage + 30).clamp(0, totalPages)})',
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '쪽',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),

        // 남은 쪽수
        if (remaining != null) ...[
          const SizedBox(height: 8),
          Text(
            '$remaining쪽 남았어요',
            style: AppTheme.captionLarge.copyWith(
              color: AppTheme.primaryLight,
            ),
          ),
        ],
      ],
    );
  }
}
