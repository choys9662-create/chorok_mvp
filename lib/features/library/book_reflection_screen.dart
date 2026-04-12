import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/reading_session.dart';
import '../../shared/repositories/book_repository.dart';

// ─── 색상 상수 (요청 스펙: 배경 #000000, 포인트 #00FF00) ─────────────────────
const _kBg = Color(0xFF000000);
const _kGreen = Color(0xFF00FF00);
const _kGreenDim = Color(0xFF00CC6A);
const _kSurface = Color(0xFF0E0E0E);
const _kBorder = Color(0xFF1A1A1A);
const _kTextPrimary = Color(0xFFF0FAF4);
const _kTextSecondary = Color(0xFF6B8C74);
const _kTextTertiary = Color(0xFF2E4A36);

// ─── 단계 정의 ────────────────────────────────────────────────────────────────
const _kStepCount = 3;
const _kStepTitles = ['이 책, 어떠셨나요?', '기억에 남는 문장', '이 책이 남긴 것'];
const _kStepSubtitles = [
  '솔직한 별점을 남겨보세요',
  '가장 인상 깊었던 문장을 적어보세요',
  '이 책이 내게 준 것들을 기록해요',
];
const _kStepHints = [
  '',
  '예) "우리는 모두 서로에게 낯선 존재다."',
  '예) 용기, 다른 시선, 위로, 새로운 질문…',
];

// ─── 메인 화면 ────────────────────────────────────────────────────────────────

class BookReflectionScreen extends ConsumerStatefulWidget {
  final Book book;

  const BookReflectionScreen({super.key, required this.book});

  @override
  ConsumerState<BookReflectionScreen> createState() =>
      _BookReflectionScreenState();
}

class _BookReflectionScreenState extends ConsumerState<BookReflectionScreen>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentStep = 0;

  // 각 단계 데이터
  int _starRating = 0;
  final _lineCtrl = TextEditingController();
  final _legacyCtrl = TextEditingController();

  bool _isSaving = false;

  // 진입 애니메이션
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _lineCtrl.dispose();
    _legacyCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  // ── 네비게이션 ──────────────────────────────────────────────────────────────

  bool get _canProceed {
    if (_currentStep == 0) return _starRating > 0;
    return true; // 2, 3단계는 선택 입력
  }

  void _goNext() {
    if (!_canProceed) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();

    if (_currentStep < _kStepCount - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _onComplete();
    }
  }

  void _goPrev() {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    if (_currentStep > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSkip() {
    HapticFeedback.selectionClick();
    context.go('/home');
  }

  Future<void> _onComplete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref.read(bookRepositoryProvider)?.saveReflection(
            bookId: widget.book.id,
            bookTitle: widget.book.title,
            bookAuthor: widget.book.author,
            starRating: _starRating,
            memorableLine: _lineCtrl.text,
            legacy: _legacyCtrl.text,
          );
    } catch (_) {
      // 저장 실패해도 홈으로 이동
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.go('/home');
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                currentStep: _currentStep,
                onBack: _currentStep > 0 ? _goPrev : null,
                onSkip: _onSkip,
              ),
              _ProgressBar(current: _currentStep, total: _kStepCount),
              const SizedBox(height: 32),

              // PageView
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _currentStep = i),
                  children: [
                    _StepWrapper(
                      title: _kStepTitles[0],
                      subtitle: _kStepSubtitles[0],
                      child: _StarStep(
                        rating: _starRating,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _starRating = v);
                        },
                      ),
                    ),
                    _StepWrapper(
                      title: _kStepTitles[1],
                      subtitle: _kStepSubtitles[1],
                      child: _TextStep(
                        controller: _lineCtrl,
                        hint: _kStepHints[1],
                        maxLines: 5,
                        icon: Icons.format_quote_rounded,
                      ),
                    ),
                    _StepWrapper(
                      title: _kStepTitles[2],
                      subtitle: _kStepSubtitles[2],
                      child: _TextStep(
                        controller: _legacyCtrl,
                        hint: _kStepHints[2],
                        maxLines: 6,
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ],
                ),
              ),

              // 하단 버튼
              _BottomCta(
                currentStep: _currentStep,
                totalSteps: _kStepCount,
                canProceed: _canProceed,
                isSaving: _isSaving,
                onNext: _goNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 상단 바 ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final int currentStep;
  final VoidCallback? onBack;
  final VoidCallback onSkip;

  const _TopBar({
    required this.currentStep,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          // 뒤로 or 공백
          SizedBox(
            width: 48,
            height: 48,
            child: onBack != null
                ? Semantics(
                    button: true,
                    label: '이전 단계',
                    child: GestureDetector(
                      onTap: onBack,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _kTextSecondary,
                        size: 20,
                      ),
                    ),
                  )
                : null,
          ),

          const Spacer(),

          // 단계 표시
          Text(
            '${currentStep + 1} / $_kStepCount',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kTextSecondary,
              height: 1.4,
            ),
          ),

          const Spacer(),

          // 나중에 하기
          Semantics(
            button: true,
            label: '나중에 하기',
            child: GestureDetector(
              onTap: onSkip,
              child: const SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kTextSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 진행 바 ─────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (current + 1) / total,
          backgroundColor: _kBorder,
          valueColor: const AlwaysStoppedAnimation(_kGreen),
          minHeight: 3,
        ),
      ),
    );
  }
}

// ─── 단계 래퍼 (타이틀 + 콘텐츠) ─────────────────────────────────────────────

class _StepWrapper extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _StepWrapper({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _kTextPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: _kTextSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
          child,
        ],
      ),
    );
  }
}

// ─── 1단계: 별점 ─────────────────────────────────────────────────────────────

class _StarStep extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarStep({required this.rating, required this.onChanged});

  static const _labels = ['', '별로예요', '그저 그래요', '괜찮아요', '좋아요', '최고예요!'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 별 5개
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < rating;
            return Semantics(
              button: true,
              label: '별 ${i + 1}개',
              child: GestureDetector(
                onTap: () => onChanged(i + 1),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: AnimatedScale(
                      scale: filled ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          key: ValueKey('$i-$filled'),
                          size: 44,
                          color: filled ? _kGreen : _kTextTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // 라벨
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: rating > 0
              ? Container(
                  key: ValueKey(rating),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: ShapeDecoration(
                    color: _kGreen.withValues(alpha: 0.08),
                    shape: const StadiumBorder(
                      side: BorderSide(color: _kGreen, width: 0.5),
                    ),
                  ),
                  child: Text(
                    _labels[rating],
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _kGreen,
                      height: 1.4,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey(0), height: 40),
        ),

        const SizedBox(height: 40),

        // 서브 안내
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD * AppTheme.radiusSM / 6),
            border: Border.all(color: _kBorder),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: _kTextSecondary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '별점은 나만 볼 수 있어요. 솔직하게 남겨보세요.',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: _kTextSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 2·3단계: 텍스트 입력 ────────────────────────────────────────────────────

class _TextStep extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final IconData icon;

  const _TextStep({
    required this.controller,
    required this.hint,
    required this.maxLines,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 입력 필드
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            border: Border.all(color: _kBorder),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: _kGreen),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: maxLines,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: _kTextPrimary,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: _kTextTertiary,
                    height: 1.6,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                cursorColor: _kGreen,
                cursorWidth: 1.5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 선택 입력 안내
        const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 14, color: _kTextTertiary),
            SizedBox(width: 6),
            Text(
              '선택 입력이에요 — 비워도 괜찮아요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextTertiary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── 하단 CTA 버튼 ────────────────────────────────────────────────────────────

class _BottomCta extends StatefulWidget {
  final int currentStep;
  final int totalSteps;
  final bool canProceed;
  final bool isSaving;
  final VoidCallback onNext;

  const _BottomCta({
    required this.currentStep,
    required this.totalSteps,
    required this.canProceed,
    required this.isSaving,
    required this.onNext,
  });

  @override
  State<_BottomCta> createState() => _BottomCtaState();
}

class _BottomCtaState extends State<_BottomCta> {
  bool _pressed = false;

  bool get _isLastStep => widget.currentStep == widget.totalSteps - 1;

  String get _label {
    if (_isLastStep) return '회고 완료';
    return '다음';
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.canProceed && !widget.isSaving;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        children: [
          // 단계 인디케이터 점
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.totalSteps, (i) {
              final active = i == widget.currentStep;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? _kGreen : _kBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // 메인 버튼
          Semantics(
            button: true,
            label: _label,
            child: GestureDetector(
              onTapDown: active ? (_) => setState(() => _pressed = true) : null,
              onTapUp: active
                  ? (_) {
                      setState(() => _pressed = false);
                      widget.onNext();
                    }
                  : null,
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  decoration: ShapeDecoration(
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_kGreen, _kGreenDim],
                          )
                        : null,
                    color: active ? null : _kSurface,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppTheme.radiusMD * 1.35),
                      side: active
                          ? BorderSide.none
                          : const BorderSide(color: _kBorder),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: widget.isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kBg,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _label,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: active ? _kBg : _kTextTertiary,
                                height: 1.4,
                              ),
                            ),
                            if (!_isLastStep) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: active ? _kBg : _kTextTertiary,
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),

          // 별점 미선택 안내 (1단계에서만)
          if (widget.currentStep == 0 && !widget.canProceed) ...[
            const SizedBox(height: 12),
            const Text(
              '별점을 선택해야 다음으로 넘어갈 수 있어요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
