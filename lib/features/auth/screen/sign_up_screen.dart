import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../util/auth_error.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  // 실시간 검증 상태
  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _pwTouched = false;
  bool _pwConfirmTouched = false;

  // 약관 동의
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_rebuild);
    _emailCtrl.addListener(_rebuild);
    _pwCtrl.addListener(_rebuild);
    _pwConfirmCtrl.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _nameCtrl
      ..removeListener(_rebuild)
      ..dispose();
    _emailCtrl
      ..removeListener(_rebuild)
      ..dispose();
    _pwCtrl
      ..removeListener(_rebuild)
      ..dispose();
    _pwConfirmCtrl
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  // ── 검증 ──
  bool get _isNameValid =>
      _nameCtrl.text.trim().length >= 2 && _nameCtrl.text.trim().length <= 10;
  String? get _nameError {
    if (!_nameTouched || _nameCtrl.text.isEmpty) return null;
    if (_nameCtrl.text.trim().length < 2) return '2자 이상 입력해주세요';
    if (_nameCtrl.text.trim().length > 10) return '10자 이하로 입력해주세요';
    return null;
  }

  bool get _isEmailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_emailCtrl.text.trim());
  String? get _emailError {
    if (!_emailTouched || _emailCtrl.text.isEmpty) return null;
    if (!_isEmailValid) return '올바른 이메일 주소를 입력해주세요';
    return null;
  }

  int get _pwStrength {
    final pw = _pwCtrl.text;
    if (pw.isEmpty) return 0;
    int s = 0;
    if (pw.length >= 6) s++;
    if (pw.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(pw)) s++;
    if (RegExp(r'[0-9]').hasMatch(pw)) s++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pw)) s++;
    return s.clamp(0, 5);
  }

  String get _pwStrengthLabel {
    if (_pwCtrl.text.isEmpty) return '';
    if (_pwStrength <= 1) return '약함';
    if (_pwStrength <= 3) return '보통';
    return '강함';
  }

  Color get _pwStrengthColor {
    if (_pwStrength <= 1) return const Color(0xFFEF4444);
    if (_pwStrength <= 3) return const Color(0xFFEAB308);
    return AppTheme.primaryLight;
  }

  bool get _isPwValid => _pwCtrl.text.length >= 6;
  String? get _pwError {
    if (!_pwTouched || _pwCtrl.text.isEmpty) return null;
    if (_pwCtrl.text.length < 6) return '6자 이상 입력해주세요';
    return null;
  }

  bool get _isPwConfirmValid =>
      _pwConfirmCtrl.text == _pwCtrl.text && _pwConfirmCtrl.text.isNotEmpty;
  String? get _pwConfirmError {
    if (!_pwConfirmTouched || _pwConfirmCtrl.text.isEmpty) return null;
    if (_pwConfirmCtrl.text != _pwCtrl.text) return '비밀번호가 일치하지 않아요';
    return null;
  }

  bool get _allAgree => _agreeTerms && _agreePrivacy && _agreeMarketing;
  bool get _requiredAgree => _agreeTerms && _agreePrivacy;
  bool get _canSubmit =>
      _isNameValid &&
      _isEmailValid &&
      _isPwValid &&
      _isPwConfirmValid &&
      _requiredAgree;

  void _toggleAllAgree(bool? v) {
    setState(() {
      _agreeTerms = v ?? false;
      _agreePrivacy = v ?? false;
      _agreeMarketing = v ?? false;
    });
  }

  // ── 회원가입 API ──
  Future<void> _signUp() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final res = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
        data: {
          'username': _nameCtrl.text.trim(),
          'display_name': _nameCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      if (res.session != null) {
        context.go(AppConstants.routeHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '가입 확인 이메일을 보냈어요. 메일함을 확인해주세요 ✉️',
              style: TextStyle(fontFamily: 'Pretendard'),
            ),
            backgroundColor: AppTheme.darkPrimaryContainer,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        if (mounted) context.go(AppConstants.routeAuth);
      }
    } on AuthException catch (e) {
      if (mounted) showAuthError(context, e.message);
    } catch (_) {
      if (mounted) showAuthError(context, 'network');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.white,
        ),
        title: const Text(
          '회원가입',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 닉네임 ──
              _buildLabel('닉네임'),
              const SizedBox(height: 8),
              _ValidatedField(
                controller: _nameCtrl,
                hint: '2~10자',
                error: _nameError,
                isValid:
                    _nameTouched && _nameCtrl.text.isNotEmpty && _isNameValid,
                onFocusLost: () => setState(() => _nameTouched = true),
              ),
              const SizedBox(height: 20),

              // ── 이메일 ──
              _buildLabel('이메일'),
              const SizedBox(height: 8),
              _ValidatedField(
                controller: _emailCtrl,
                hint: 'example@email.com',
                keyboardType: TextInputType.emailAddress,
                error: _emailError,
                isValid:
                    _emailTouched &&
                    _emailCtrl.text.isNotEmpty &&
                    _isEmailValid,
                onFocusLost: () => setState(() => _emailTouched = true),
              ),
              const SizedBox(height: 20),

              // ── 비밀번호 ──
              _buildLabel('비밀번호'),
              const SizedBox(height: 8),
              _ValidatedField(
                controller: _pwCtrl,
                hint: '6자 이상',
                obscure: _obscure,
                error: _pwError,
                isValid: _pwTouched && _pwCtrl.text.isNotEmpty && _isPwValid,
                onFocusLost: () => setState(() => _pwTouched = true),
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
              ),
              if (_pwCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PasswordStrengthBar(
                  strength: _pwStrength,
                  label: _pwStrengthLabel,
                  color: _pwStrengthColor,
                ),
              ],
              const SizedBox(height: 20),

              // ── 비밀번호 확인 ──
              _buildLabel('비밀번호 확인'),
              const SizedBox(height: 8),
              _ValidatedField(
                controller: _pwConfirmCtrl,
                hint: '비밀번호를 다시 입력해주세요',
                obscure: _obscureConfirm,
                error: _pwConfirmError,
                isValid:
                    _pwConfirmTouched &&
                    _pwConfirmCtrl.text.isNotEmpty &&
                    _isPwConfirmValid,
                onFocusLost: () => setState(() => _pwConfirmTouched = true),
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textTertiary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── 약관 동의 ──
              _TermsSection(
                allAgree: _allAgree,
                agreeTerms: _agreeTerms,
                agreePrivacy: _agreePrivacy,
                agreeMarketing: _agreeMarketing,
                onAllAgree: _toggleAllAgree,
                onTerms: (v) => setState(() => _agreeTerms = v ?? false),
                onPrivacy: (v) => setState(() => _agreePrivacy = v ?? false),
                onMarketing: (v) =>
                    setState(() => _agreeMarketing = v ?? false),
              ),
              const SizedBox(height: 28),

              // ── 가입 버튼 ──
              _SubmitButton(
                label: '가입하기',
                loading: _loading,
                enabled: _canSubmit,
                onTap: _signUp,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
      ),
    );
  }
}

// ─── 실시간 검증 필드 ──────────────────────────────────────────────────────────
class _ValidatedField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? error;
  final bool isValid;
  final VoidCallback? onFocusLost;

  const _ValidatedField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.error,
    this.isValid = false,
    this.onFocusLost,
  });

  @override
  State<_ValidatedField> createState() => _ValidatedFieldState();
}

class _ValidatedFieldState extends State<_ValidatedField> {
  @override
  Widget build(BuildContext context) {
    Widget? suffixWidget = widget.suffix;
    final hasText = widget.controller.text.isNotEmpty;

    if (widget.suffix == null && hasText) {
      if (widget.error != null) {
        suffixWidget = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 20),
        );
      } else if (widget.isValid) {
        suffixWidget = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 20,
          ),
        );
      }
    }

    if (widget.suffix != null && hasText) {
      Widget? statusIcon;
      if (widget.error != null) {
        statusIcon = const Icon(
          Icons.close_rounded,
          color: Color(0xFFEF4444),
          size: 18,
        );
      } else if (widget.isValid) {
        statusIcon = const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF10B981),
          size: 18,
        );
      }
      if (statusIcon != null) {
        suffixWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [statusIcon, widget.suffix!],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Focus(
          onFocusChange: (f) {
            if (!f) widget.onFocusLost?.call();
          },
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 15, color: AppTheme.textTertiary),
              suffixIcon: suffixWidget,
              suffixIconConstraints: const BoxConstraints(minHeight: 20),
              filled: true,
              fillColor: AppTheme.darkSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.error!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
          ),
        ],
      ],
    );
  }
}

// ─── 비밀번호 강도 바 ──────────────────────────────────────────────────────────
class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  final String label;
  final Color color;

  const _PasswordStrengthBar({
    required this.strength,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: strength / 5,
                backgroundColor: AppTheme.darkBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── 약관 동의 섹션 ────────────────────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final bool allAgree, agreeTerms, agreePrivacy, agreeMarketing;
  final ValueChanged<bool?> onAllAgree, onTerms, onPrivacy, onMarketing;

  const _TermsSection({
    required this.allAgree,
    required this.agreeTerms,
    required this.agreePrivacy,
    required this.agreeMarketing,
    required this.onAllAgree,
    required this.onTerms,
    required this.onPrivacy,
    required this.onMarketing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkSurface,
        radius: 12,
        side: BorderSide.none,
      ),
      child: Column(
        children: [
          _TermRow(
            label: '전체 동의',
            checked: allAgree,
            onChanged: onAllAgree,
            bold: true,
          ),
          const SizedBox(height: 12),
          _TermRow(
            label: '[필수] 서비스 이용약관 동의',
            checked: agreeTerms,
            onChanged: onTerms,
          ),
          const SizedBox(height: 8),
          _TermRow(
            label: '[필수] 개인정보 처리방침 동의',
            checked: agreePrivacy,
            onChanged: onPrivacy,
          ),
          const SizedBox(height: 8),
          _TermRow(
            label: '[선택] 마케팅 정보 수신 동의',
            checked: agreeMarketing,
            onChanged: onMarketing,
          ),
        ],
      ),
    );
  }
}

class _TermRow extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool?> onChanged;
  final bool bold;

  const _TermRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checked
                  ? AppTheme.primaryLight
                  : AppTheme.darkSurface,
            ),
            child: checked
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 14 : 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: bold ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 가입 버튼 ─────────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  final bool enabled;

  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled || loading;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: AppTheme.smoothBox(
            gradient: isDisabled
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryLight.withValues(alpha: 0.2),
                      AppTheme.accent.withValues(alpha: 0.2),
                    ],
                  )
                : context.appReadingGradient,
            radius: 12,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDisabled
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
