import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/screen/auth_screen.dart';
import '../../../shared/providers/theme_provider.dart';

// ─── 독서 목표 상태 ────────────────────────────────────────────────────────
class _ReadingGoal {
  final int dailyMinutes;
  final int weeklyDays;
  final int yearlyBooks;

  const _ReadingGoal({
    this.dailyMinutes = 30,
    this.weeklyDays = 5,
    this.yearlyBooks = 24,
  });

  _ReadingGoal copyWith({
    int? dailyMinutes,
    int? weeklyDays,
    int? yearlyBooks,
  }) => _ReadingGoal(
    dailyMinutes: dailyMinutes ?? this.dailyMinutes,
    weeklyDays: weeklyDays ?? this.weeklyDays,
    yearlyBooks: yearlyBooks ?? this.yearlyBooks,
  );
}

class _GoalNotifier extends Notifier<_ReadingGoal> {
  @override
  _ReadingGoal build() => const _ReadingGoal();

  void setDailyMinutes(int v) => state = state.copyWith(dailyMinutes: v);
  void setWeeklyDays(int v) => state = state.copyWith(weeklyDays: v);
  void setYearlyBooks(int v) => state = state.copyWith(yearlyBooks: v);
}

final _goalProvider = NotifierProvider<_GoalNotifier, _ReadingGoal>(
  _GoalNotifier.new,
);

// ─── 알림 설정 상태 ────────────────────────────────────────────────────────
class _NotifState {
  final bool reminder;
  final bool streakAlert;
  final TimeOfDay reminderTime;

  const _NotifState({
    this.reminder = true,
    this.streakAlert = true,
    this.reminderTime = const TimeOfDay(hour: 21, minute: 0),
  });

  _NotifState copyWith({
    bool? reminder,
    bool? streakAlert,
    TimeOfDay? reminderTime,
  }) => _NotifState(
    reminder: reminder ?? this.reminder,
    streakAlert: streakAlert ?? this.streakAlert,
    reminderTime: reminderTime ?? this.reminderTime,
  );
}

class _NotifNotifier extends Notifier<_NotifState> {
  @override
  _NotifState build() => const _NotifState();

  void toggleReminder() => state = state.copyWith(reminder: !state.reminder);
  void toggleStreak() =>
      state = state.copyWith(streakAlert: !state.streakAlert);
  void setTime(TimeOfDay t) => state = state.copyWith(reminderTime: t);
}

final _notifProvider = NotifierProvider<_NotifNotifier, _NotifState>(
  _NotifNotifier.new,
);

// ─── 메인 화면 ─────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.appTextPrimary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Text(
          '설정',
          style: AppTheme.headingSmall.copyWith(color: context.appTextPrimary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: AppTheme.spaceMD,
        ),
        children: [
          // ─── 테마 ───────────────────────────────────────────────────
          _SectionLabel('화면'),
          _SettingsCard(
            children: [_ThemeTile(themeMode: themeMode, ref: ref)],
          ),
          const SizedBox(height: AppTheme.space2XL),

          // ─── 독서 목표 ─────────────────────────────────────────────
          _SectionLabel('독서 목표'),
          _GoalSection(),
          const SizedBox(height: AppTheme.space2XL),

          // ─── 알림 ──────────────────────────────────────────────────
          _SectionLabel('알림'),
          _NotifSection(),
          const SizedBox(height: AppTheme.space2XL),

          // ─── 앱 정보 ───────────────────────────────────────────────
          _SectionLabel('앱 정보'),
          _SettingsCard(
            children: [
              _InfoTile(
                icon: Icons.emoji_events_outlined,
                label: '성취 & 뱃지',
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeAchievements);
                },
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),

              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: '버전 정보',
                trailing: Text(
                  '1.0.0',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ),

              _InfoTile(
                icon: Icons.privacy_tip_outlined,
                label: '개인정보처리방침',
                onTap: () => HapticFeedback.selectionClick(),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),

              _InfoTile(
                icon: Icons.description_outlined,
                label: '서비스 이용약관',
                onTap: () => HapticFeedback.selectionClick(),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),

              _InfoTile(
                icon: Icons.mail_outline_rounded,
                label: '문의하기',
                onTap: () => HapticFeedback.selectionClick(),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          // ─── 계정 (실사용 빌드 전용) ──────────────────────────────
          if (!kUseMock) ...[
            _SectionLabel('계정'),
            _SettingsCard(
              children: [
                _InfoTile(
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  iconColor: const Color(0xFFFF4F4F),
                  labelColor: const Color(0xFFFF4F4F),
                  onTap: () => _showLogoutConfirm(context),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space2XL),
          ],

          // ─── 디자인 미리보기 (debug only) ─────────────────────────
          if (kDebugMode) ...[
            _SectionLabel('개발'),
            _SettingsCard(
              children: [
                _InfoTile(
                  icon: Icons.preview_rounded,
                  label: '로그인 화면 미리보기',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AuthScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.space3XL),
        ],
      ),
    );
  }
}

// ─── 테마 타일 ─────────────────────────────────────────────────────────────
class _ThemeTile extends StatelessWidget {
  final ThemeMode themeMode;
  final WidgetRef ref;

  const _ThemeTile({required this.themeMode, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: context.appPrimaryAccent,
              ),
              const SizedBox(width: 10),
              Text(
                '테마',
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Row(
            children: [
              _ThemeChip(
                label: '라이트',
                icon: Icons.light_mode_rounded,
                selected: themeMode == ThemeMode.light,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.light);
                },
              ),
              const SizedBox(width: 8),
              _ThemeChip(
                label: '다크',
                icon: Icons.dark_mode_rounded,
                selected: themeMode == ThemeMode.dark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.dark);
                },
              ),
              const SizedBox(width: 8),
              _ThemeChip(
                label: '시스템',
                icon: Icons.settings_suggest_outlined,
                selected: themeMode == ThemeMode.system,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(themeModeProvider.notifier).set(ThemeMode.system);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: selected
              ? AppTheme.smoothBox(
                  gradient: context.appReadingGradient,
                  radius: AppTheme.radiusMD,
                )
              : AppTheme.smoothBox(
                  color: context.appCardElevated,
                  radius: AppTheme.radiusMD,
                  side: BorderSide.none,
                ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : context.appTextSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.captionLarge.copyWith(
                  color: selected ? Colors.white : context.appTextSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 독서 목표 섹션 ─────────────────────────────────────────────────────────
class _GoalSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(_goalProvider);

    return _SettingsCard(
      children: [
        _SliderTile(
          icon: Icons.schedule_outlined,
          label: '일일 독서',
          value: '${goal.dailyMinutes}분',
          sliderValue: goal.dailyMinutes.toDouble(),
          min: 10,
          max: 120,
          divisions: 11,
          onChanged: (v) =>
              ref.read(_goalProvider.notifier).setDailyMinutes(v.round()),
        ),

        _SliderTile(
          icon: Icons.calendar_today_outlined,
          label: '주간 목표',
          value: '주 ${goal.weeklyDays}일',
          sliderValue: goal.weeklyDays.toDouble(),
          min: 1,
          max: 7,
          divisions: 6,
          onChanged: (v) =>
              ref.read(_goalProvider.notifier).setWeeklyDays(v.round()),
        ),

        _SliderTile(
          icon: Icons.menu_book_outlined,
          label: '연간 목표',
          value: '${goal.yearlyBooks}권',
          sliderValue: goal.yearlyBooks.toDouble(),
          min: 1,
          max: 100,
          divisions: 99,
          onChanged: (v) =>
              ref.read(_goalProvider.notifier).setYearlyBooks(v.round()),
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double sliderValue;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.appPrimaryAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTheme.bodyMedium.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.appPrimaryAccent,
              inactiveTrackColor: context.appBorder,
              thumbColor: context.appPrimaryAccent,
              overlayColor: context.appPrimaryAccent.withValues(alpha: 0.15),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: sliderValue,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 알림 섹션 ─────────────────────────────────────────────────────────────
class _NotifSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = ref.watch(_notifProvider);

    return _SettingsCard(
      children: [
        _ToggleTile(
          icon: Icons.notifications_outlined,
          label: '독서 리마인더',
          subtitle: notif.reminder
              ? '${notif.reminderTime.hour.toString().padLeft(2, '0')}:${notif.reminderTime.minute.toString().padLeft(2, '0')} 알림'
              : '꺼짐',
          value: notif.reminder,
          onChanged: (_) {
            HapticFeedback.selectionClick();
            ref.read(_notifProvider.notifier).toggleReminder();
          },
          onTap: notif.reminder
              ? () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: notif.reminderTime,
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: Theme.of(ctx).colorScheme.copyWith(
                          primary: context.appPrimaryAccent,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    ref.read(_notifProvider.notifier).setTime(picked);
                  }
                }
              : null,
        ),

        _ToggleTile(
          icon: Icons.local_fire_department_outlined,
          label: '스트릭 경고',
          subtitle: '오늘 읽지 않으면 알림',
          value: notif.streakAlert,
          onChanged: (_) {
            HapticFeedback.selectionClick();
            ref.read(_notifProvider.notifier).toggleStreak();
          },
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onTap;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.appPrimaryAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodyMedium.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: context.appPrimaryAccent,
              activeTrackColor: context.appPrimaryAccent.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 공용 컴포넌트 ─────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppTheme.spaceSM),
      child: Text(
        text,
        style: AppTheme.captionLarge.copyWith(
          color: context.appTextTertiary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide.none,
      ),
      child: Column(children: children),
    );
  }
}

void _showLogoutConfirm(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '로그아웃',
              style: AppTheme.headingSmall.copyWith(
                color: const Color(0xFFFF4F4F),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '로그아웃하면 다음에 다시 로그인해야 해요.',
              style: AppTheme.captionLarge.copyWith(
                color: Theme.of(ctx).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Supabase.instance.client.auth.signOut();
                      // GoRouter refreshListenable이 signOut을 감지해서 /auth로 리다이렉트
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4F4F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('로그아웃'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? context.appTextSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyMedium.copyWith(
                  color: labelColor ?? context.appTextPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              DefaultTextStyle(
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
                child: IconTheme(
                  data: IconThemeData(color: context.appTextTertiary, size: 18),
                  child: trailing!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

