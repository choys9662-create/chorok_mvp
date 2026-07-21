import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/reading_session.dart';
import '../../shared/repositories/book_repository.dart';
import '../../shared/repositories/supabase_book_repository.dart';
import '../../shared/widgets/chorok_card.dart';

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
    context.go(AppConstants.routeHome);
  }

  Future<void> _onComplete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await ref
          .read(bookRepositoryProvider)
          ?.saveReflection(
            bookId: widget.book.id,
            bookTitle: widget.book.title,
            bookAuthor: widget.book.author,
            starRating: _starRating,
            memorableLine: _lineCtrl.text,
            legacy: _legacyCtrl.text,
          );
    } catch (error, stackTrace) {
      debugPrint('[독서 회고 저장 오류] $error\n$stackTrace');
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      context.go(AppConstants.routeHome);
      return;
    }

    try {
      await ref
          .read(supabaseBookRepositoryProvider)
          .saveReview(
            book: widget.book,
            starRating: _starRating,
            memorableLine: _lineCtrl.text,
            legacy: _legacyCtrl.text,
          );
    } catch (error, stackTrace) {
      debugPrint('[공개 리뷰 저장 오류] $error\n$stackTrace');
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    context.go(AppConstants.routeHome);
  }

  // ── 빌드 ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
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
              const SizedBox(height: AppTheme.sectionGap),

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
      padding: const EdgeInsets.only(
        left: AppTheme.spaceSM,
        top: AppTheme.spaceSM,
        right: AppTheme.spaceLG,
      ),
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
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.appTextSecondary,
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
            style: AppTheme.supportingText.copyWith(
              color: context.appTextSecondary,
            ),
          ),

          const Spacer(),

          // 나중에 하기
          Semantics(
            button: true,
            label: '나중에 하기',
            child: GestureDetector(
              onTap: onSkip,
              child: SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    '나중에',
                    style: AppTheme.rowText.copyWith(
                      color: context.appTextSecondary,
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
      padding: const EdgeInsets.only(
        left: AppTheme.spaceXL,
        top: AppTheme.spaceMD,
        right: AppTheme.spaceXL,
      ),
      child: SizedBox(
        height: AppTheme.spaceXS,
        child: ChorokCard(
          inner: true,
          showBorder: false,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: LinearProgressIndicator(
            value: (current + 1) / total,
            backgroundColor: context.appProgressTrack,
            valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
            minHeight: AppTheme.spaceXS,
          ),
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
      padding: const EdgeInsets.only(
        left: AppTheme.spaceXL,
        right: AppTheme.spaceXL,
        bottom: AppTheme.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.screenTitle.copyWith(color: context.appTextPrimary),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            subtitle,
            style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppTheme.sectionGap),
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
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey('$i-$filled'),
                          size: 44,
                          color: filled
                              ? context.appPrimaryAccent
                              : context.appTextTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppTheme.spaceXL),

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
              ? ChorokCard(
                  key: ValueKey(rating),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXL,
                    vertical: AppTheme.spaceSM,
                  ),
                  backgroundColor: context.primaryBg(0.08),
                  showBorder: false,
                  child: Text(
                    _labels[rating],
                    style: AppTheme.rowText.copyWith(
                      color: context.appPrimaryAccent,
                    ),
                  ),
                )
              : const SizedBox(key: ValueKey(0), height: 40),
        ),

        const SizedBox(height: AppTheme.sectionGap),

        // 서브 안내
        SizedBox(
          width: double.infinity,
          child: ChorokCard(
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Text(
                    '별점과 감상은 책 정보 화면의 사용자 평가에 함께 보여요.',
                    style: AppTheme.supportingText.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
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
      spacing: AppTheme.spaceLG,
      children: [
        // 입력 필드
        SizedBox(
          width: double.infinity,
          child: ChorokCard(
            padding: const EdgeInsets.all(AppTheme.spaceXL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppTheme.spaceMD,
              children: [
                Icon(icon, size: 20, color: context.appPrimaryAccent),
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: AppTheme.rowText.copyWith(
                    height: 1.6,
                    color: context.appTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTheme.rowText.copyWith(
                      height: 1.6,
                      color: context.appTextTertiary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: context.appPrimaryAccent,
                  cursorWidth: 1.5,
                ),
              ],
            ),
          ),
        ),

        // 선택 입력 안내
        Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 14,
              color: context.appTextTertiary,
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Text(
              '선택 입력이에요 — 비워도 괜찮아요',
              style: AppTheme.supportingText.copyWith(
                color: context.appTextTertiary,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceXL,
        AppTheme.spaceMD,
        AppTheme.spaceXL,
        AppTheme.sectionGap,
      ),
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
                margin: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceXS,
                ),
                width: active
                    ? AppTheme.spaceMD + AppTheme.spaceSM
                    : AppTheme.radiusInner,
                height: AppTheme.radiusInner,
                child: ChorokCard(
                  inner: true,
                  backgroundColor: active
                      ? context.appPrimaryAccent
                      : context.appBorder,
                  showBorder: false,
                  padding: EdgeInsets.zero,
                  child: const SizedBox.expand(),
                ),
              );
            }),
          ),
          const SizedBox(height: AppTheme.spaceXL),

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
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ChorokCard(
                    backgroundColor: active
                        ? context.appPrimaryAccent
                        : context.appCardElevated,
                    showBorder: false,
                    padding: EdgeInsets.zero,
                    child: Center(
                      child: widget.isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.appBg,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _label,
                                  style: AppTheme.rowText.copyWith(
                                    color: active
                                        ? context.appBg
                                        : context.appTextTertiary,
                                  ),
                                ),
                                if (!_isLastStep) ...[
                                  const SizedBox(width: AppTheme.spaceSM),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                    color: active
                                        ? context.appBg
                                        : context.appTextTertiary,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 별점 미선택 안내 (1단계에서만)
          if (widget.currentStep == 0 && !widget.canProceed) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              '별점을 선택해야 다음으로 넘어갈 수 있어요',
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
