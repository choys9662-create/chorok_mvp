import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart';
import '../util/auth_error.dart';

// ─── 디자인 토큰 (AppTheme 기반) ─────────────────────────────────────────────
const _kBg = AppTheme.darkBg;
const _kAuthControlFill = Color(0xFF111811);
const _kAuthControlBorder = Color(0x3D8DFF54);
const _authRedirectUri = 'com.chorok.chorokapp://login-callback/';
const _naverProvider = OAuthProvider('custom:naver');

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  bool _loading = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = supabase.auth.onAuthStateChange.listen((state) {
      if (!mounted || state.session == null) return;
      context.go(AppConstants.routeHome);
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
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

  // ── Google 로그인 ─────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();

    _setLoading(true);
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : _authRedirectUri,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      debugPrint('[Google 로그인 오류] ${e.message}');
      _showError('Google 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } catch (e) {
      debugPrint('[Google로그인 오류] $e');
      _showError('Google 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (!kIsWeb) _setLoading(false);
    }
  }

  // ── Naver 로그인 ─────────────────────────────────────────────────
  Future<void> _signInWithNaver() async {
    HapticFeedback.mediumImpact();

    _setLoading(true);
    try {
      await supabase.auth.signInWithOAuth(
        _naverProvider,
        redirectTo: kIsWeb ? Uri.base.origin : _authRedirectUri,
      );
    } on AuthException catch (e) {
      debugPrint('[네이버 로그인 오류] ${e.message}');
      _showError('네이버 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } catch (e) {
      debugPrint('[네이버로그인 오류] $e');
      _showError('네이버 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (!kIsWeb) _setLoading(false);
    }
  }

  // ── Apple 로그인 ──────────────────────────────────────────────────
  Future<void> _signInWithApple() async {
    HapticFeedback.mediumImpact();

    _setLoading(true);
    try {
      if (kIsWeb) {
        await supabase.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: Uri.base.origin,
        );
        return;
      }

      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _showError('이 기기에서는 Apple 로그인을 사용할 수 없어요.');
        return;
      }

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
        debugPrint('[Apple 로그인 오류] ${e.code}: ${e.message}');
        _showError('Apple 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
      }
    } on AuthException catch (e) {
      debugPrint('[Apple 로그인 오류] ${e.message}');
      _showError('Apple 로그인을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } catch (e) {
      debugPrint('[Apple 로그인 오류] $e');
      _showError('Apple 로그인 중 오류가 발생했어요.');
    } finally {
      if (!kIsWeb) _setLoading(false);
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
                      onTap: _loading ? null : _signInWithNaver,
                      icon: _naverIcon,
                      label: '네이버로 계속하기',
                    ),
                    // iOS 네이티브는 Runner.entitlements에 Sign in with Apple이
                    // 아직 프로비저닝되지 않아 항상 실패한다(유료 Apple Developer
                    // Program 가입 전까지). 웹 OAuth 경로는 entitlement가 필요
                    // 없으므로 그대로 노출한다.
                    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) ...[
                      const SizedBox(height: 12),
                      _SocialButton(
                        onTap: _loading ? null : _signInWithApple,
                        icon: _appleIcon,
                        label: 'Apple로 계속하기',
                        dark: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // ── 약관 동의 안내 (소셜 로그인으로 가입·로그인 시 간주) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      '계속하면 ',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://chorok-web.web.app/terms.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        '이용약관',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.5),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' 및 ',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => launchUrl(
                        Uri.parse('https://chorok-web.web.app/privacy.html'),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(
                        '개인정보처리방침',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Colors.white.withValues(alpha: 0.5),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      '에\n동의하는 것으로 간주됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
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
            radius: 10,
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

// ─── 소셜 로그인 아이콘 ──────────────────────────────────────────────────────
const Widget _googleIcon = _GoogleIconPainter();
const Widget _naverIcon = _NaverIcon();
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

class _NaverIcon extends StatelessWidget {
  const _NaverIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF03C75A),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: const Text(
        'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
