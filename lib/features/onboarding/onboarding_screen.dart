import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_flags.dart';
import '../../core/theme/app_theme.dart';

const _kOnboardingKey = 'onboarding_completed';

Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

// ─── 슬라이드 데이터 ──────────────────────────────────────────────────────────

class _SlideData {
  final String emoji;
  final String title;
  final String subtitle;
  final String body;

  const _SlideData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}

const List<_SlideData> _kSlides = [
  _SlideData(
    emoji: '📵',
    title: '스마트폰이\n독서를 방해하고 있어요',
    subtitle: '하루 평균 스마트폰 126분, 독서 19분',
    body: '알림 한 번에 흐름이 끊겨요.\n초록은 그 시간을 되찾아줘요.',
  ),
  _SlideData(
    emoji: '🔥',
    title: '초록으로\n읽는 시간을 지켜요',
    subtitle: '독서 중 이탈하면 기록에 남아요',
    body: '타이머와 반딧불이가 함께해요.\n집중의 흔적이 쌓일수록 숲이 자라요.',
  ),
  _SlideData(
    emoji: '✍️',
    title: '문장을 붙잡아요',
    subtitle: '읽고 잊는 대신, 찍고 기록해요',
    body: '마음에 드는 문장을 한 줄씩 초서하면\n나만의 문장 컬렉션이 만들어져요.',
  ),
  _SlideData(
    emoji: '🌱',
    title: '지금 바로\n시작해요',
    subtitle: '오늘부터 독서 습관을 만들어가요',
    body: '첫 번째 책을 등록하거나\n지금 바로 탐색해보세요.',
  ),
];

// ─── 온보딩 스크린 ────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    HapticFeedback.selectionClick();
    if (_currentPage < _kSlides.length - 1) {
      await _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish(String destination) async {
    HapticFeedback.mediumImpact();
    await markOnboardingCompleted();
    if (!mounted) return;
    // Android에서 StatefulShellRoute redirect가 누락되는 케이스 방어:
    // 세션 없으면 /auth로 직접 이동, 있으면 목적지로 이동
    // (목업 모드는 인증을 우회하므로 항상 목적지로 이동)
    final isLoggedIn =
        kUseMock || Supabase.instance.client.auth.currentSession != null;
    context.go(isLoggedIn ? destination : AppConstants.routeAuth);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
        children: [
          // 배경 그라디언트
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [Color(0xFF0A2215), AppTheme.darkBg],
                ),
              ),
            ),
          ),

          // 페이지 콘텐츠
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                  },
                  itemCount: _kSlides.length,
                  itemBuilder: (_, i) => _SlidePage(
                    data: _kSlides[i],
                    pulseAnim: _pulseAnim,
                    isActive: i == _currentPage,
                  ),
                ),
              ),

              // 하단 UI
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  children: [
                    // 페이지 인디케이터
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _kSlides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _currentPage ? 24 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _currentPage
                                ? context.appPrimaryAccent
                                : AppTheme.darkBorder,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 마지막 슬라이드 CTA
                    if (isLast) ...[
                      _PrimaryButton(
                        label: '첫 번째 책 등록하기',
                        onTap: () => _finish(AppConstants.routeSearch),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _finish(AppConstants.routeHome),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '일단 시작해보기',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      _PrimaryButton(label: '다음', onTap: _next),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _finish(AppConstants.routeHome),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            '건너뛰기',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textTertiary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 슬라이드 페이지 ──────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _SlideData data;
  final Animation<double> pulseAnim;
  final bool isActive;

  const _SlidePage({
    required this.data,
    required this.pulseAnim,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 이모지 일러스트
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, _) => Transform.scale(
              scale: isActive ? pulseAnim.value : 1.0,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.appPrimaryAccent.withValues(alpha: 0.15),
                      context.appPrimaryAccent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: Center(
                  child: Text(data.emoji, style: TextStyle(fontSize: 52)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // 제목
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: AppTheme.textPrimary,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 16),

          // 서브타이틀 (강조)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: context.appPrimaryAccent.withValues(alpha: 0.08),
              shape: AppTheme.smoothShape(radius: 10),
            ),
            child: Text(
              data.subtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: context.appPrimaryAccent,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 본문
          Text(
            data.body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppTheme.textSecondary,
              height: 1.7,
            ),
          ),

          // 슬라이드 1 전용: 반딧불이 미니 애니메이션
          if (data.emoji == '🔥') ...[
            const SizedBox(height: 32),
            const _MiniFireflies(),
          ],
        ],
      ),
    );
  }
}

// ─── 미니 반딧불이 애니메이션 ─────────────────────────────────────────────────

class _MiniFireflies extends StatefulWidget {
  const _MiniFireflies();

  @override
  State<_MiniFireflies> createState() => _MiniFirefliesState();
}

class _MiniFirefliesState extends State<_MiniFireflies>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) => CustomPaint(
          painter: _MiniFireflyPainter(
            t: _ctrl.value,
            color: ctx.appPrimaryAccent,
          ),
        ),
      ),
    );
  }
}

class _MiniFireflyPainter extends CustomPainter {
  final double t;
  final Color color;
  _MiniFireflyPainter({required this.t, required this.color});

  static final _rng = math.Random(42);
  static final List<({double x, double y, double phase, double speed})> _flies =
      List.generate(8, (i) {
        return (
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          phase: _rng.nextDouble() * math.pi * 2,
          speed: 0.3 + _rng.nextDouble() * 0.7,
        );
      });

  @override
  void paint(Canvas canvas, Size size) {
    for (final f in _flies) {
      final angle = (t * f.speed * math.pi * 2) + f.phase;
      final dx = f.x * size.width + math.sin(angle) * 12;
      final dy = f.y * size.height + math.cos(angle * 1.3) * 8;
      final alpha = ((math.sin(angle + math.pi / 2) + 1) / 2 * 0.8 + 0.2).clamp(
        0.0,
        1.0,
      );
      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(dx, dy), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(_MiniFireflyPainter old) => old.t != t;
}

// ─── 주요 CTA 버튼 ───────────────────────────────────────────────────────────

class _PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: ShapeDecoration(
            gradient: AppTheme.greenGradient,
            shape: AppTheme.smoothShape(radius: 10),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
