import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';

// ─── 디자인 토큰 ────────────────────────────────────────────────────────────
const _kGreen = Color(0xFF00FF66);
const _kBg = Color(0xFF060B07);
const _kSurface = Color(0xFF0D1A10);
const _kBorder = Color(0xFF1A3320);

// ─── Google Sign-In 인스턴스 ──────────────────────────────────────────────
const String _kGoogleClientId =
    '1023286897589-c98eh600dgi7tgeovc4qurv99mh9c9h0.apps.googleusercontent.com';

final _googleSignIn = GoogleSignIn(
  clientId: _kGoogleClientId,
  scopes: ['email', 'profile'],
);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _setLoading(bool v) {
    if (mounted) setState(() => _loading = v);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _localizeError(msg),
          style: const TextStyle(fontFamily: 'Pretendard'),
        ),
        backgroundColor: const Color(0xFF1A0A0A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _localizeError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (lower.contains('email not confirmed')) {
      return '이메일 인증이 필요해요. 받은 편지함을 확인해주세요.';
    }
    if (lower.contains('user already registered')) return '이미 가입된 이메일이에요.';
    if (lower.contains('password should be')) return '비밀번호는 6자 이상이어야 해요.';
    if (lower.contains('network')) return '네트워크 연결을 확인해주세요.';
    return msg;
  }

  // ── 이메일 로그인 ─────────────────────────────────────────────────
  Future<void> _signIn(String email, String password) async {
    _setLoading(true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      if (mounted) context.go(AppConstants.routeHome);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('네트워크 연결을 확인해주세요.');
    } finally {
      _setLoading(false);
    }
  }

  // ── 이메일 회원가입 ───────────────────────────────────────────────
  Future<void> _signUp(String email, String password, String username) async {
    _setLoading(true);
    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'display_name': username},
      );
      if (!mounted) return;
      // 이메일 확인 없이 즉시 세션이 생성된 경우 바로 이동
      if (res.session != null) {
        context.go(AppConstants.routeHome);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '가입 확인 이메일을 보냈어요. 메일함을 확인해주세요 ✉️',
              style: TextStyle(fontFamily: 'Pretendard'),
            ),
            backgroundColor: Color(0xFF0D2010),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        _tab.animateTo(0);
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('네트워크 연결을 확인해주세요.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Google 로그인 ─────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();

    _setLoading(true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // 사용자가 취소

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) throw Exception('Google ID 토큰을 받지 못했어요.');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) context.go(AppConstants.routeHome);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Google 로그인 중 오류가 발생했어요.');
    } finally {
      _setLoading(false);
    }
  }

  // ── Apple 로그인 ──────────────────────────────────────────────────
  Future<void> _signInWithApple() async {
    HapticFeedback.mediumImpact();

    // Apple Sign In 가능 여부 확인
    final isAvailable = await SignInWithApple.isAvailable();
    if (!isAvailable) {
      _showError('이 기기에서는 Apple 로그인을 사용할 수 없어요.');
      return;
    }

    _setLoading(true);
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Apple ID 토큰을 받지 못했어요.');

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (mounted) context.go(AppConstants.routeHome);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError('Apple 로그인에 실패했어요: ${e.message}');
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Apple 로그인 중 오류가 발생했어요.');
    } finally {
      _setLoading(false);
    }
  }

  // ── nonce 유틸 ────────────────────────────────────────────────────
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const _Logo(),
                  const SizedBox(height: 40),
                  // ── 소셜 로그인 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        _SocialButton(
                          onTap: _loading ? null : _signInWithGoogle,
                          icon: _googleIcon,
                          label: 'Google로 계속하기',
                        ),
                        const SizedBox(height: 12),
                        _SocialButton(
                          onTap: _loading ? null : _signInWithApple,
                          icon: _appleIcon,
                          label: 'Apple로 계속하기',
                          dark: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── 구분선 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(child: Container(height: 1, color: _kBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '또는 이메일로',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: _kBorder)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── 이메일 탭 ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _AuthTabBar(controller: _tab),
                  ),
                  const SizedBox(height: 24),
                  // ── 폼 ──
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _LoginForm(onSubmit: _signIn, loading: _loading),
                        _SignUpForm(onSubmit: _signUp, loading: _loading),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 로고 ────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kSurface,
            border: Border.all(color: _kBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: _kGreen.withValues(alpha: 0.15),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '초',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: _kGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '초록',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '독서 몰입 플랫폼',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── 소셜 버튼 ────────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget icon;
  final String label;
  final bool dark;

  const _SocialButton({
    required this.onTap,
    required this.icon,
    required this.label,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: AppTheme.smoothBox(
            color: dark ? Colors.white : _kSurface,
            radius: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: icon),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 탭 바 ───────────────────────────────────────────────────────────────────
class _AuthTabBar extends StatelessWidget {
  final TabController controller;
  const _AuthTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: AppTheme.smoothBox(color: _kSurface, radius: 12),
      child: TabBar(
        controller: controller,
        indicator: AppTheme.smoothBox(
          color: _kGreen.withValues(alpha: 0.15),
          radius: 10,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelColor: _kGreen,
        unselectedLabelColor: Colors.white38,
        tabs: const [
          Tab(text: '로그인'),
          Tab(text: '회원가입'),
        ],
      ),
    );
  }
}

// ─── 로그인 폼 ────────────────────────────────────────────────────────────────
class _LoginForm extends StatefulWidget {
  final Future<void> Function(String email, String password) onSubmit;
  final bool loading;
  const _LoginForm({required this.onSubmit, required this.loading});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _Field(
            controller: _emailCtrl,
            hint: '이메일',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _pwCtrl,
            hint: '비밀번호',
            obscure: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white24,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SubmitButton(
            label: '로그인',
            loading: widget.loading,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onSubmit(_emailCtrl.text.trim(), _pwCtrl.text);
            },
          ),
        ],
      ),
    );
  }
}

// ─── 회원가입 폼 ──────────────────────────────────────────────────────────────
class _SignUpForm extends StatefulWidget {
  final Future<void> Function(String email, String password, String username)
  onSubmit;
  final bool loading;
  const _SignUpForm({required this.onSubmit, required this.loading});

  @override
  State<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<_SignUpForm> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _Field(controller: _nameCtrl, hint: '닉네임'),
          const SizedBox(height: 12),
          _Field(
            controller: _emailCtrl,
            hint: '이메일',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _pwCtrl,
            hint: '비밀번호 (6자 이상)',
            obscure: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.white24,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SubmitButton(
            label: '가입하기',
            loading: widget.loading,
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onSubmit(
                _emailCtrl.text.trim(),
                _pwCtrl.text,
                _nameCtrl.text.trim(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 공용 위젯 ────────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const _Field({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 15,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kSurface,
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
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: GestureDetector(
          onTap: loading ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: AppTheme.smoothBox(
              color: loading
                  ? _kGreen.withValues(alpha: 0.15)
                  : _kGreen.withValues(alpha: 0.22),
              radius: 12,
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kGreen.withValues(alpha: 0.8),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kGreen,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 소셜 로그인 아이콘 ──────────────────────────────────────────────────────
const Widget _googleIcon = _GoogleIconPainter();
const Widget _appleIcon = _AppleIconPainter();

class _GoogleIconPainter extends StatelessWidget {
  const _GoogleIconPainter();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // G 모양 간략 표현 — 색상 호
    const colors = [
      Color(0xFF4285F4),
      Color(0xFF34A853),
      Color(0xFFFBBC05),
      Color(0xFFEA4335),
    ];
    final sweeps = [pi / 2, pi / 2, pi / 2, pi / 2];
    double start = -pi / 4;
    for (int i = 0; i < 4; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = size.width * 0.18
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.75),
        start,
        sweeps[i],
        false,
        paint,
      );
      start += sweeps[i];
    }
    // 가로 막대
    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(center.dx + radius * 0.75, center.dy),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AppleIconPainter extends StatelessWidget {
  const _AppleIconPainter();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.apple_rounded, color: Colors.black, size: 22);
  }
}
