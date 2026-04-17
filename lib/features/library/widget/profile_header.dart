import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

/// 서재 상단 프로필 헤더 — 프로필 사진, 자기소개, 팔로우/팔로워, 설정
class ProfileHeader extends StatefulWidget {
  final VoidCallback? onSettingsTap;
  final int streak;

  const ProfileHeader({super.key, this.onSettingsTap, this.streak = 0});

  @override
  State<ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<ProfileHeader> {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  static final _modalShape = SmoothRectangleBorder(
    borderRadius: SmoothBorderRadius.only(
      topLeft: SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.6),
      topRight: SmoothRadius(cornerRadius: 20, cornerSmoothing: 0.6),
    ),
  );
  static final _buttonBorderRadius =
      SmoothBorderRadius(cornerRadius: AppTheme.radiusMD, cornerSmoothing: 0.6);

  // 더미 프로필 데이터
  String _name = '이지현';
  String _bio = '책 속에서 길을 찾는 중 🌿';
  final int _followers = 128;
  final int _following = 64;

  @override
  Widget build(BuildContext context) {
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
        radius: 24,
        side: BorderSide(color: context.appBorder),
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
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.4),
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
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
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
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                          foregroundColor: AppTheme.accent,
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.2,
                          ),
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
                fontFamily: 'Pretendard',
                fontSize: 13,
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
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    side: BorderSide(
                      color: context.appPrimaryAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.streak}일 연속 독서 중',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    final nameController = TextEditingController(text: _name);
    final bioController = TextEditingController(text: _bio);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: _modalShape,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '프로필 편집',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _SheetField(controller: nameController, label: '이름', maxLines: 1),
              const SizedBox(height: 12),
              _SheetField(
                controller: bioController,
                label: '자기소개',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _name = nameController.text.trim().isEmpty
                          ? _name
                          : nameController.text.trim();
                      _bio = bioController.text.trim();
                    });
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: SmoothRectangleBorder(
                      borderRadius: _buttonBorderRadius,
                    ),
                  ),
                  child: const Text(
                    '저장',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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

  void _showFollowList(BuildContext context, {required bool isFollower}) {
    HapticFeedback.selectionClick();
    final list = isFollower
        ? ['김민준', '박서연', '이수아', '최현우', '정지원']
        : ['한수빈', '오태양', '윤나래'];

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: _modalShape,
      builder: (_) => _FollowListSheet(
        title: isFollower ? '팔로워 $_followers명' : '팔로잉 $_following명',
        names: list,
        showFollowButton: !isFollower,
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
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appPrimaryAccent,
                  height: 1.4,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
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

// ─── 편집 필드 ─────────────────────────────────────────────────────────
class _SheetField extends StatelessWidget {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  // OutlineInputBorder는 SmoothBorderRadius 미지원 — 그대로 유지
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
      style: TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 14,
        color: context.appTextPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: context.appTextTertiary,
          fontSize: 13,
        ),
        filled: true,
        fillColor: context.appCardElevated,
        border: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _inputRadius,
          borderSide: BorderSide(color: context.appPrimaryAccent),
        ),
      ),
    );
  }
}

// ─── 팔로워/팔로잉 목록 (토글 가능) ──────────────────────────────────
class _FollowListSheet extends StatefulWidget {
  final String title;
  final List<String> names;
  final bool showFollowButton;

  const _FollowListSheet({
    required this.title,
    required this.names,
    required this.showFollowButton,
  });

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  // ─── 시각 상수 (라운드·테두리 한곳 관리) ───────────────────────────
  static final _followButtonRadius =
      SmoothBorderRadius(cornerRadius: 20, cornerSmoothing: 0.6);

  late List<bool> _followStates;

  @override
  void initState() {
    super.initState();
    _followStates = List.filled(widget.names.length, true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.appBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
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
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: widget.names.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                    child: Text(
                      widget.names[i][0],
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.names[i],
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
                              ? context.appBorder
                              : AppTheme.primary,
                          shape: SmoothRectangleBorder(
                            borderRadius: _followButtonRadius,
                            side: BorderSide(
                              color: _followStates[i]
                                  ? context.appBorder
                                  : context.appPrimaryAccent.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        child: Text(
                          _followStates[i] ? '팔로잉' : '팔로우',
                          style: AppTheme.captionLarge.copyWith(
                            fontFamily: 'Pretendard',
                            color: _followStates[i]
                                ? context.appTextTertiary
                                : context.appPrimaryAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
