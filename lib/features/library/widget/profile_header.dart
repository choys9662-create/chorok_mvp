import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/profile_repository.dart';
import '../../../shared/widgets/sheet_handle.dart';

/// 서재 상단 프로필 헤더 — 프로필 사진, 자기소개, 팔로우/팔로워, 설정
class ProfileHeader extends ConsumerStatefulWidget {
  final VoidCallback? onSettingsTap;
  final int streak;

  const ProfileHeader({super.key, this.onSettingsTap, this.streak = 0});

  @override
  ConsumerState<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends ConsumerState<ProfileHeader> {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  static final _modalShape = SmoothRectangleBorder(
    smoothness: 0.6,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(10),
      topRight: Radius.circular(10),
    ),
  );
  static final _buttonBorderRadius = BorderRadius.circular(AppTheme.radiusMD);

  String _name = '';
  String _bio = kUseMock ? '책 속에서 길을 찾는 중' : '';
  int _followers = kUseMock ? 128 : 0;
  int _following = kUseMock ? 64 : 0;
  List<UserProfile> _followerProfiles = kUseMock
      ? [
          UserProfile(id: '', username: 'kim', displayName: '김민준'),
          UserProfile(id: '', username: 'park', displayName: '박서연'),
          UserProfile(id: '', username: 'lee', displayName: '이수아'),
          UserProfile(id: '', username: 'choi', displayName: '최현우'),
          UserProfile(id: '', username: 'jung', displayName: '정지원'),
        ]
      : const [];
  List<UserProfile> _followingProfiles = kUseMock
      ? [
          UserProfile(id: '', username: 'han', displayName: '한수빈'),
          UserProfile(id: '', username: 'oh', displayName: '오태양'),
          UserProfile(id: '', username: 'yun', displayName: '윤나래'),
        ]
      : const [];

  @override
  void initState() {
    super.initState();
    if (kUseMock) {
      _name = '이지현';
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    _name = _displayNameFromMeta(user?.userMetadata, user?.email);
    _loadProfile();
  }

  static String _displayNameFromMeta(Map? meta, String? email) {
    final displayName = (meta?['display_name'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final fullName = (meta?['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    final name = (meta?['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email?.split('@').first ?? '사용자';
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait<Object?>([
        ProfileRepository(client).getById(user.id),
        FollowRepository(client).getFollowers(user.id),
        FollowRepository(client).getFollowing(user.id),
      ]);
      if (!mounted) return;
      final profile = results[0] as UserProfile?;
      final followers = results[1] as List<UserProfile>;
      final following = results[2] as List<UserProfile>;
      setState(() {
        if (profile != null) {
          if (profile.displayName.isNotEmpty) _name = profile.displayName;
          _bio = profile.bio ?? '';
        }
        _followers = followers.length;
        _following = following.length;
        _followerProfiles = followers;
        _followingProfiles = following;
      });
    } catch (_) {
      // 프로필 상단은 핵심 화면이므로 소셜 수치 로딩 실패 시 기본값을 유지한다.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(followMutationVersionProvider, (_, _) {
      _loadProfile();
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        16,
        AppTheme.screenPadding,
        0,
      ),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 10,
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── 프로필 사진 ───────────────────────────────────
              GestureDetector(
                onTap: _onPickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark
                          ? AppTheme.primary.withValues(alpha: 0.4)
                          : context.primaryBg(0.14),
                      child: Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: context.appPrimaryAccent,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.primary
                              : context.appPrimaryAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // ─── 이름 + 통계 ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: context.appTextPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StatItem(
                          label: '팔로워',
                          count: _followers,
                          onTap: () =>
                              _showFollowList(context, isFollower: true),
                        ),
                        const SizedBox(width: 24),
                        _StatItem(
                          label: '팔로잉',
                          count: _following,
                          onTap: () =>
                              _showFollowList(context, isFollower: false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ─── 액션 버튼들 (편집 + 설정) ─────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: '프로필 편집',
                    button: true,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        onPressed: () => _showEditProfileSheet(context),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: context.appPrimaryAccent,
                          backgroundColor: isDark
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : context.primaryBg(0.12),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                  if (widget.onSettingsTap != null) ...[
                    const SizedBox(width: 8),
                    Semantics(
                      label: '설정',
                      button: true,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: widget.onSettingsTap,
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          style: IconButton.styleFrom(
                            foregroundColor: context.appTextSecondary,
                            backgroundColor: context.appCardElevated,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // ─── 자기소개 ──────────────────────────────────────────
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _bio.isEmpty ? '자기소개를 입력해보세요' : _bio,
              style: TextStyle(
                fontSize: 12,
                color: _bio.isEmpty
                    ? context.appTextTertiary
                    : context.appTextSecondary,
                height: 1.4,
              ),
            ),
          ),

          // ─── 스트릭 배지 ───────────────────────────────────────
          if (widget.streak > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: AppTheme.smoothPill(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : context.primaryBg(0.10),
                    side: BorderSide.none,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.streak}일 연속 독서 중',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.appPrimaryAccent,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _onPickPhoto() {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('프로필 사진 변경 기능은 출시 예정이에요'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: _modalShape,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditProfileSheet(
          initialName: _name,
          initialBio: _bio,
          buttonBorderRadius: _buttonBorderRadius,
          onSaved: (name, bio) => setState(() {
            _name = name;
            _bio = bio;
          }),
        ),
      ),
    );
  }

  void _showFollowList(BuildContext context, {required bool isFollower}) {
    HapticFeedback.selectionClick();
    final list = isFollower ? _followerProfiles : _followingProfiles;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: _modalShape,
      builder: (_) => _FollowListSheet(
        title: isFollower ? '팔로워 $_followers명' : '팔로잉 $_following명',
        profiles: list,
        showFollowButton: kUseMock && !isFollower,
        emptyMessage: isFollower
            ? '아직 팔로워가 없어요'
            : '아직 팔로우한 독자가 없어요',
      ),
    );
  }
}

// ─── 통계 항목 ─────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;

  const _StatItem({
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $count명',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.appPrimaryAccent,
                  height: 1.4,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appTextSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 프로필 편집 시트 ──────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String initialName;
  final String initialBio;
  final BorderRadius buttonBorderRadius;
  final void Function(String name, String bio) onSaved;

  const _EditProfileSheet({
    required this.initialName,
    required this.initialBio,
    required this.buttonBorderRadius,
    required this.onSaved,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2 || name.length > 20) {
      setState(() => _error = '이름은 2~20자 사이로 입력해주세요');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!kUseMock) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await ProfileRepository(
            Supabase.instance.client,
          ).updateProfile(userId, displayName: name, bio: _bioCtrl.text.trim());
        }
      }
      if (!mounted) return;
      widget.onSaved(name, _bioCtrl.text.trim());
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '저장에 실패했어요. 다시 시도해주세요';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ChorokSheetHandle(),
          const SizedBox(height: 20),
          Text(
            '프로필 편집',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _SheetField(controller: _nameCtrl, label: '이름', maxLines: 1),
          const SizedBox(height: 12),
          _SheetField(controller: _bioCtrl, label: '자기소개', maxLines: 3),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: SmoothRectangleBorder(
                  smoothness: 0.6,
                  borderRadius: widget.buttonBorderRadius,
                ),
              ),
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 편집 필드 ─────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  // OutlineInputBorder는 BorderRadius 미지원 — 그대로 유지
  static const _inputRadius = BorderRadius.all(
    Radius.circular(AppTheme.radiusMD),
  );

  final TextEditingController controller;
  final String label;
  final int maxLines;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(fontSize: 16, color: context.appTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.appTextTertiary, fontSize: 12),
        filled: true,
        fillColor: context.appCardElevated,
        border: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ─── 팔로워/팔로잉 목록 (토글 가능) ──────────────────────────────────
class _FollowListSheet extends StatefulWidget {
  final String title;
  final List<UserProfile> profiles;
  final bool showFollowButton;
  final String emptyMessage;

  const _FollowListSheet({
    required this.title,
    required this.profiles,
    required this.showFollowButton,
    required this.emptyMessage,
  });

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  static final _followButtonRadius = BorderRadius.circular(10);

  late List<bool> _followStates;

  @override
  void initState() {
    super.initState();
    _followStates = List.filled(widget.profiles.length, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        const SizedBox(height: 12),
        const ChorokSheetHandle(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            widget.title,
            style: AppTheme.headingSmall.copyWith(
              color: context.appTextPrimary,
            ),
          ),
        ),
        Expanded(
          child: widget.profiles.isEmpty
              ? _FollowEmptyState(message: widget.emptyMessage)
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.profiles.length,
            itemBuilder: (context, i) {
              final p = widget.profiles[i];
              final initial = p.displayName.isNotEmpty
                  ? p.displayName[0]
                  : '?';
              return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // 빈 id(목업)는 실제 프로필이 없으므로 이동하지 않는다.
                onTap: p.id.isEmpty
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push(
                          AppConstants.routeUserProfile,
                          extra: p,
                        );
                      },
                child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isDark
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : context.primaryBg(0.12),
                    child: Text(
                      initial,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.displayName,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  if (widget.showFollowButton)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _followStates[i] = !_followStates[i]);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: ShapeDecoration(
                          color: _followStates[i]
                              ? context.appCardElevated
                              : isDark
                              ? AppTheme.primary
                              : context.appPrimaryAccent,
                          shape: SmoothRectangleBorder(
                            smoothness: 0.6,
                            borderRadius: _followButtonRadius,
                            side: BorderSide.none,
                          ),
                        ),
                        child: Text(
                          _followStates[i] ? '팔로잉' : '팔로우',
                          style: AppTheme.captionLarge.copyWith(
                            color: _followStates[i]
                                ? context.appTextTertiary
                                : isDark
                                ? context.appPrimaryAccent
                                : Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── 팔로우 목록 빈 상태 ────────────────────────────────────────────────
class _FollowEmptyState extends StatelessWidget {
  final String message;

  const _FollowEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 40,
              color: context.appTextTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
