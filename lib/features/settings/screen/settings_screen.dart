import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/screen/auth_screen.dart';
import '../../../shared/repositories/profile_repository.dart';

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

// ─── 계정 정보 상태 (이메일 · 로그인 방식 · 비공개 계정) ───────────────────
class _AccountInfo {
  final String? email;
  final String? providerLabel;
  final bool isPrivate;

  const _AccountInfo({this.email, this.providerLabel, this.isPrivate = false});

  _AccountInfo copyWith({bool? isPrivate}) => _AccountInfo(
    email: email,
    providerLabel: providerLabel,
    isPrivate: isPrivate ?? this.isPrivate,
  );
}

String? _providerLabelOf(String? provider) {
  if (provider == null) return null;
  if (provider.contains('google')) return 'Google';
  if (provider.contains('apple')) return 'Apple';
  if (provider.contains('naver')) return '네이버';
  return null;
}

class _AccountNotifier extends AsyncNotifier<_AccountInfo> {
  @override
  Future<_AccountInfo> build() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const _AccountInfo();
    final profile = await ref.read(profileRepositoryProvider).getById(user.id);
    return _AccountInfo(
      email: user.email,
      providerLabel: _providerLabelOf(user.appMetadata['provider'] as String?),
      isPrivate: profile?.isPrivate ?? false,
    );
  }

  Future<void> setPrivate(bool value) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    state = AsyncData(previous.copyWith(isPrivate: value));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(user.id, isPrivate: value);
    } catch (_) {
      state = AsyncData(previous); // 실패 시 롤백
    }
  }
}

final _accountProvider = AsyncNotifierProvider<_AccountNotifier, _AccountInfo>(
  _AccountNotifier.new,
);

// ─── 메인 화면 ─────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _SettingsCard(children: const [_ThemeTile()]),
          const SizedBox(height: AppTheme.space2XL),

          // ─── 독서 목표 ─────────────────────────────────────────────
          _SectionLabel('독서 목표'),
          _GoalSection(),
          const SizedBox(height: AppTheme.space2XL),

          // 로컬 알림 스케줄링이 붙기 전까지 실사용 앱에서는 가짜 토글을 숨긴다.
          if (kUseMock) ...[
            _SectionLabel('알림'),
            _NotifSection(),
            const SizedBox(height: AppTheme.space2XL),
          ],

          // ─── 앱 정보 ───────────────────────────────────────────────
          _SectionLabel('앱 정보'),
          _SettingsCard(
            children: [
              if (kUseMock)
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

              // ponytail: 개인정보처리방침·이용약관 문서가 아직 없어 타일 제거.
              // 문서 URL 확정 시 url_launcher로 여는 _InfoTile을 여기 복원한다.
              _InfoTile(
                icon: Icons.mail_outline_rounded,
                label: '문의하기',
                onTap: () {
                  HapticFeedback.selectionClick();
                  launchUrl(
                    Uri(
                      scheme: 'mailto',
                      path: 'choys9662@gmail.com',
                      query: 'subject=초록 문의',
                    ),
                  );
                },
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          // ─── 계정 (실사용 빌드 전용) ──────────────────────────────
          if (!kUseMock) ...[
            _SectionLabel('계정'),
            _AccountSection(),
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
  const _ThemeTile();

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
                  fontWeight: FontWeight.w400,
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
                label: 'OLED 다크',
                icon: Icons.dark_mode_rounded,
                selected: true,
                onTap: () {
                  HapticFeedback.selectionClick();
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
          decoration: AppTheme.smoothBox(
            color: selected ? context.appActiveFill : context.appControlBg,
            radius: AppTheme.radiusMD,
            side: BorderSide(
              color: selected
                  ? context.appPillBorderActive
                  : context.appBorderSubtle,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? context.appPrimaryAccent
                    : context.appTextSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.captionLarge.copyWith(
                  color: selected
                      ? context.appPrimaryAccent
                      : context.appTextSecondary,
                  fontWeight: selected ? FontWeight.w400 : FontWeight.w400,
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
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: context.appPrimaryAccent,
              inactiveTrackColor: context.appProgressTrack,
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
                      fontWeight: FontWeight.w400,
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

// ─── 계정 섹션 ─────────────────────────────────────────────────────────────
class _AccountSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(_accountProvider).valueOrNull;

    return _SettingsCard(
      children: [
        if (account?.email != null)
          _InfoTile(
            icon: Icons.mail_outline_rounded,
            label: account!.providerLabel != null
                ? '이메일 (${account.providerLabel} 로그인)'
                : '이메일',
            trailing: Text(
              account.email!,
              style: AppTheme.captionLarge.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ),

        _ToggleTile(
          icon: Icons.lock_outline_rounded,
          label: '비공개 계정',
          subtitle: '켜면 팔로우를 승인해야 내 초서를 볼 수 있어요',
          value: account?.isPrivate ?? false,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            ref.read(_accountProvider.notifier).setPrivate(v);
          },
        ),

        _InfoTile(
          icon: Icons.block_rounded,
          label: '차단 유저 목록',
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(AppConstants.routeBlockedUsers);
          },
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
        ),

        _InfoTile(
          icon: Icons.logout_rounded,
          label: '로그아웃',
          iconColor: const Color(0xFFFF4F4F),
          labelColor: const Color(0xFFFF4F4F),
          onTap: () => _showLogoutConfirm(context),
        ),

        _InfoTile(
          icon: Icons.no_accounts_rounded,
          label: '탈퇴하기',
          iconColor: const Color(0xFFFF4F4F),
          labelColor: const Color(0xFFFF4F4F),
          onTap: () => _showDeleteAccountConfirm(context),
        ),
      ],
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
          fontWeight: FontWeight.w400,
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
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '로그아웃',
              style: AppTheme.headingSmall.copyWith(
                color: const Color(0xFFFF4F4F),
                fontWeight: FontWeight.w400,
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
                      shape: AppTheme.smoothShape(radius: 10),
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
                      shape: AppTheme.smoothShape(radius: 10),
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

void _showDeleteAccountConfirm(BuildContext context) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      var isDeleting = false;
      String? errorMessage;
      return StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '탈퇴하기',
                  style: AppTheme.headingSmall.copyWith(
                    color: const Color(0xFFFF4F4F),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '계정과 모든 독서 기록·초서·소셜 활동이 영구적으로 삭제돼요.\n이 작업은 되돌릴 수 없어요.',
                  style: AppTheme.captionLarge.copyWith(
                    color: Theme.of(ctx).textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: AppTheme.captionLarge.copyWith(
                      color: const Color(0xFFFF4F4F),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: AppTheme.smoothShape(radius: 10),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                setModalState(() => isDeleting = true);
                                try {
                                  await ProfileRepository(
                                    Supabase.instance.client,
                                  ).deleteAccount();
                                } catch (error, stackTrace) {
                                  debugPrint('[계정 삭제 오류] $error\n$stackTrace');
                                  if (ctx.mounted) {
                                    setModalState(() {
                                      isDeleting = false;
                                      errorMessage =
                                          '계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.';
                                    });
                                  }
                                  return;
                                }

                                try {
                                  await Supabase.instance.client.auth.signOut();
                                } catch (error, stackTrace) {
                                  debugPrint(
                                    '[계정 삭제 후 로그아웃 오류] $error\n$stackTrace',
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4F4F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: AppTheme.smoothShape(radius: 10),
                        ),
                        child: isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('영구 삭제'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
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
                  fontWeight: FontWeight.w400,
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
