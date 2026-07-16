import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';
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
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _isUploadingAvatar = false;
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
          _avatarUrl = profile.avatarUrl;
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
    final ImageProvider<Object>? avatarImage = _avatarBytes != null
        ? MemoryImage(_avatarBytes!)
        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
              ? NetworkImage(_avatarUrl!)
              : null);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        28,
        AppTheme.screenPadding,
        4,
      ),
      child: Row(
        children: [
          Semantics(
            label: '프로필 사진 변경',
            button: true,
            child: GestureDetector(
              onTap: _onPickPhoto,
              child: CircleAvatar(
                radius: 29,
                backgroundColor: isDark
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : context.primaryBg(0.14),
                backgroundImage: avatarImage,
                child: _isUploadingAvatar
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : avatarImage == null
                    ? Icon(
                        Icons.person_rounded,
                        size: 30,
                        color: context.appPrimaryAccent,
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: '프로필 편집',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showEditProfileSheet(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: context.appTextPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (widget.onSettingsTap != null) ...[
                      const SizedBox(width: 5),
                      Semantics(
                        label: '설정',
                        button: true,
                        child: GestureDetector(
                          onTap: widget.onSettingsTap,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.settings_outlined,
                              size: 17,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _StatItem(
            label: '팔로잉',
            count: _following,
            onTap: () => _showFollowList(context, isFollower: false),
          ),
          const SizedBox(width: 22),
          _StatItem(
            label: '팔로워',
            count: _followers,
            onTap: () => _showFollowList(context, isFollower: true),
          ),
        ],
      ),
    );
  }

  Future<void> _onPickPhoto() async {
    if (_isUploadingAvatar) return;
    HapticFeedback.selectionClick();
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;

      final sourceBytes = await picked.readAsBytes();
      final decoded = image_lib.decodeImage(sourceBytes);
      if (decoded == null) throw const FormatException('invalid image');
      final avatar = image_lib.copyResizeCropSquare(
        image_lib.bakeOrientation(decoded),
        size: 512,
        interpolation: image_lib.Interpolation.cubic,
      );
      final bytes = image_lib.encodeJpg(avatar, quality: 88);
      if (!mounted) return;

      setState(() {
        _avatarBytes = bytes;
        _isUploadingAvatar = true;
      });

      if (!kUseMock) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) throw StateError('unauthenticated');
        final avatarUrl = await ProfileRepository(
          Supabase.instance.client,
        ).uploadAvatar(userId, bytes);
        if (!mounted) return;
        setState(() => _avatarUrl = avatarUrl);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _avatarBytes = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필 사진을 변경하지 못했어요. 다시 시도해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
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

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FollowListScreen(
          title: isFollower ? '팔로워' : '팔로잉',
          profiles: list,
          emptyMessage: isFollower ? '아직 팔로워가 없어요' : '아직 팔로우한 독자가 없어요',
        ),
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
          height: 46,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: context.appTextTertiary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.appTextPrimary,
                  height: 1.2,
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

// ─── 팔로워/팔로잉 목록 ────────────────────────────────────────────────
class _FollowListScreen extends ConsumerStatefulWidget {
  final String title;
  final List<UserProfile> profiles;
  final String emptyMessage;

  const _FollowListScreen({
    required this.title,
    required this.profiles,
    required this.emptyMessage,
  });

  @override
  ConsumerState<_FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<_FollowListScreen> {
  late final Future<List<UserRecommendation>> _recommendations;
  final Set<String> _followedRecommendationIds = {};

  static final _cardRadius = BorderRadius.circular(8);

  @override
  void initState() {
    super.initState();
    _recommendations = kUseMock
        ? Future.value(_mockRecommendations)
        : FollowRepository(Supabase.instance.client).getUserRecommendations();
  }

  Future<void> _follow(UserProfile profile) async {
    if (profile.id.isEmpty || _followedRecommendationIds.contains(profile.id)) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _followedRecommendationIds.add(profile.id));
    try {
      await FollowRepository(Supabase.instance.client).follow(profile.id);
      ref.read(followMutationVersionProvider.notifier).state++;
    } catch (_) {
      if (!mounted) return;
      setState(() => _followedRecommendationIds.remove(profile.id));
    }
  }

  void _openProfile(UserProfile profile) {
    if (profile.id.isEmpty) return;
    HapticFeedback.selectionClick();
    GoRouter.of(context).push(AppConstants.routeUserProfile, extra: profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 64,
              // width 를 주지 않으면 Column(crossAxisAlignment: center)의 느슨한
              // 제약 탓에 Stack 이 제목 글자 폭만큼만 차지해, Positioned(left: 8)
              // 이 화면 왼쪽이 아니라 제목 왼쪽 기준이 되어 화살표가 제목과 겹친다.
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 8,
                    top: 0,
                    child: IconButton(
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        size: 28,
                        color: context.appTextPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Text(
                    widget.title,
                    style: AppTheme.headingSmall.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  if (widget.profiles.isEmpty)
                    SizedBox(
                      height: 220,
                      child: _FollowEmptyState(message: widget.emptyMessage),
                    )
                  else
                    for (final profile in widget.profiles)
                      _FollowUserTile(
                        profile: profile,
                        subtitle: profile.username.isEmpty
                            ? '함께 읽는 독자'
                            : '@${profile.username}',
                        buttonLabel: '팔로잉',
                        cardRadius: _cardRadius,
                        onTap: () => _openProfile(profile),
                      ),
                  const SizedBox(height: 18),
                  FutureBuilder<List<UserRecommendation>>(
                    future: _recommendations,
                    builder: (context, snapshot) {
                      final recommendations = snapshot.data ?? const [];
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (recommendations.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                            child: Text(
                              '추천 독자',
                              style: AppTheme.bodyMedium.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          for (final recommendation in recommendations)
                            _FollowUserTile(
                              profile: recommendation.profile,
                              subtitle: recommendation.reason,
                              buttonLabel:
                                  _followedRecommendationIds.contains(
                                    recommendation.profile.id,
                                  )
                                  ? '팔로잉'
                                  : '팔로우',
                              cardRadius: _cardRadius,
                              onTap: () => _openProfile(recommendation.profile),
                              onButtonTap: () =>
                                  _follow(recommendation.profile),
                            ),
                        ],
                      );
                    },
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

class _FollowUserTile extends StatelessWidget {
  final UserProfile profile;
  final String subtitle;
  final String buttonLabel;
  final BorderRadius cardRadius;
  final VoidCallback? onTap;
  final VoidCallback? onButtonTap;

  const _FollowUserTile({
    required this.profile,
    required this.subtitle,
    required this.buttonLabel,
    required this.cardRadius,
    this.onTap,
    this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl == null || profile.avatarUrl!.isEmpty
        ? null
        : NetworkImage(profile.avatarUrl!);
    final initial = profile.displayName.isNotEmpty
        ? profile.displayName[0]
        : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 65,
          padding: const EdgeInsets.fromLTRB(12, 10, 18, 10),
          decoration: ShapeDecoration(
            color: AppTheme.darkCard,
            shape: SmoothRectangleBorder(
              smoothness: 0.6,
              borderRadius: cardRadius,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: context.appCardElevated,
                backgroundImage: avatar,
                child: avatar == null
                    ? Text(
                        initial,
                        style: AppTheme.bodyMedium.copyWith(
                          color: context.appTextSecondary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: ShapeDecoration(
                    color: context.appCardElevated,
                    shape: SmoothRectangleBorder(
                      smoothness: 0.6,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                      fontWeight: FontWeight.w400,
                      height: 1,
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

final _mockRecommendations = [
  UserRecommendation(
    profile: UserProfile(id: '', username: 'hae', displayName: '해골맨'),
    reason: '맞팔 독자들이 많이 팔로우해요',
  ),
  UserRecommendation(
    profile: UserProfile(id: '', username: 'book', displayName: '용가리맨'),
    reason: '나와 비슷한 책을 읽어요',
  ),
];

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
