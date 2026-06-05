import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../util/auth_error.dart';

// ─── 디자인 토큰 (AppTheme 기반) ─────────────────────────────────────────────
const _kBg = Color(0xFF121212); // AppTheme.darkBg
const _kBorder = Color(0xFF2C2C2C); // AppTheme.darkBorder
const _kAuthControlFill = Color(0xFF111811);
const _kAuthControlBorder = Color(0x3D8DFF54);

// ─── Google Sign-In 인스턴스 ──────────────────────────────────────────────
// serverClientId: Supabase/웹에서 검증에 사용하는 Web OAuth client ID
// clientId: iOS 네이티브 sign-in에 사용하는 iOS OAuth client ID
//   → Info.plist REVERSED_CLIENT_ID의 역순이 clientId
//     예) com.googleusercontent.apps.XXXX-YYY → XXXX-YYY.apps.googleusercontent.com
final _googleSignIn = GoogleSignIn(
  serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
  clientId: dotenv.env['GOOGLE_IOS_CLIENT_ID'],
  scopes: ['email', 'profile'],
);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱이 백그라운드 → 포어그라운드로 복귀할 때 _loading 리셋
  // (Google 브라우저 인증 후 돌아올 때 버튼이 비활성화되는 문제 방지)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loading) {
      // 처리 완료를 위해 잠시 대기 후 초기화
      Future.delayed(const Duration(seconds: 2), () => _setLoading(false));
    }
  }

  void _setLoading(bool v) {
    if (mounted) setState(() => _loading = v);
  }

  void _showError(String msg) {
    if (!mounted) return;
    showAuthError(context, msg);
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

  // ── Google 로그인 ─────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();

    _setLoading(true);
    try {
      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        return;
      }

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
      debugPrint('[Google로그인 오류] $e');
      _showError('Google 로그인 실패\n${e.toString()}');
    } finally {
      if (!kIsWeb) _setLoading(false);
    }
  }

  // ── Apple 로그인 ──────────────────────────────────────────────────
  Future<void> _signInWithApple() async {
    HapticFeedback.mediumImpact();

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
              // ── 로그인 폼 ──
              _LoginForm(onSubmit: _signIn, loading: _loading),
              const SizedBox(height: 24),
              // ── 회원가입 링크 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '계정이 없으신가요?',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppConstants.routeSignUp),
                    child: Text(
                      '회원가입',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
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
            gradient: AppTheme.greenGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryLight.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '초',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '초록',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '독서 몰입 플랫폼',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: AppTheme.smoothBox(
            color: dark ? Colors.white : _kAuthControlFill,
            radius: 12,
            side: BorderSide(color: dark ? Colors.white : _kAuthControlBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: icon),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
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
                color: AppTheme.textTertiary,
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
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 16, color: AppTheme.textTertiary),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kAuthControlFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAuthControlBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kAuthControlBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryLight, width: 1.4),
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
    final isDisabled = loading;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: GestureDetector(
          onTap: isDisabled ? null : onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
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
                        fontWeight: FontWeight.w400,
                        color: isDisabled
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.white,
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
