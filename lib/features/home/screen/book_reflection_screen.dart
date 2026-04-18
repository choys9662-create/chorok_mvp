import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ─── 감상 데이터 (라우터 extra) ──────────────────────────────────────────────

class ReflectionExtra {
  final String bookId;
  final String bookTitle;
  final String bookAuthor;

  const ReflectionExtra({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
  });
}

// ─── 화면 ────────────────────────────────────────────────────────────────────

class BookReflectionScreen extends StatefulWidget {
  final ReflectionExtra book;

  const BookReflectionScreen({super.key, required this.book});

  @override
  State<BookReflectionScreen> createState() => _BookReflectionScreenState();
}

class _BookReflectionScreenState extends State<BookReflectionScreen>
    with SingleTickerProviderStateMixin {
  int _starRating = 0;
  final _textCtrl = TextEditingController();
  bool _isSaving = false;
  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterCtrl.forward());
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    // TODO: 실제 서버 저장 연동 시 여기서 repository 호출
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Column(
              children: [
                _Header(bookTitle: widget.book.bookTitle),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 완독 축하 배너
                        _CompletionBanner(
                          bookTitle: widget.book.bookTitle,
                          author: widget.book.bookAuthor,
                        ),
                        const SizedBox(height: 24),

                        // 별점
                        _StarRatingSection(
                          rating: _starRating,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            setState(() => _starRating = v);
                          },
                        ),
                        const SizedBox(height: 24),

                        // 감상 입력
                        _ReflectionInput(controller: _textCtrl),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // 하단 액션
                _BottomActions(
                  isSaving: _isSaving,
                  canSave: _starRating > 0 || _textCtrl.text.trim().isNotEmpty,
                  onSave: _onSave,
                  onSkip: () {
                    HapticFeedback.selectionClick();
                    context.go('/home');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 헤더 ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String bookTitle;

  const _Header({required this.bookTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '완독 감상',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
              Text(
                '이 책 어떠셨나요?',
                style: AppTheme.headingLarge.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: '닫기',
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                context.go('/home');
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.appCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.appBorder),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: context.appTextTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 완독 축하 배너 ───────────────────────────────────────────────────────────

class _CompletionBanner extends StatelessWidget {
  final String bookTitle;
  final String author;

  const _CompletionBanner({required this.bookTitle, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        gradient: AppTheme.greenCardGradient,
        radius: AppTheme.radiusXL,
        side: BorderSide(color: context.appPrimaryAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: AppTheme.smoothBox(
              gradient: AppTheme.greenGradient,
              radius: AppTheme.radiusMD,
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: context.appBg,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: AppTheme.smoothBox(
                    color: context.appPrimaryAccent.withValues(alpha: 0.12),
                    radius: AppTheme.radiusSM,
                  ),
                  child: Text(
                    '🎉  완독 달성',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appPrimaryAccent,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bookTitle,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  author,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: context.appTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 별점 섹션 ────────────────────────────────────────────────────────────────

class _StarRatingSection extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarRatingSection({required this.rating, required this.onChanged});

  static const _labels = ['', '별로예요', '그저 그래요', '괜찮아요', '좋아요', '최고예요!'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 책에 별점을 주세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < rating;
              return Semantics(
                button: true,
                label: '별 ${i + 1}개',
                child: GestureDetector(
                  onTap: () => onChanged(i + 1),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: AnimatedScale(
                      scale: filled ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: filled
                            ? context.appPrimaryAccent
                            : context.appTextTertiary,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 12),
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _labels[rating],
                  key: ValueKey(rating),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appPrimaryAccent,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 감상 텍스트 입력 ─────────────────────────────────────────────────────────

class _ReflectionInput extends StatelessWidget {
  final TextEditingController controller;

  const _ReflectionInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '감상을 남겨보세요',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusLG,
            side: BorderSide(color: context.appBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: controller,
            maxLines: 6,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.appTextPrimary,
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText: '이 책을 읽고 어떤 생각이 들었나요?\n기억에 남는 순간, 느낀 점을 자유롭게 적어보세요.',
              hintStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.appTextTertiary,
                height: 1.6,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            cursorColor: context.appPrimaryAccent,
          ),
        ),
      ],
    );
  }
}

// ─── 하단 액션 ────────────────────────────────────────────────────────────────

class _BottomActions extends StatelessWidget {
  final bool isSaving;
  final bool canSave;
  final VoidCallback onSave;
  final VoidCallback onSkip;

  const _BottomActions({
    required this.isSaving,
    required this.canSave,
    required this.onSave,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.appBg,
        border: Border(top: BorderSide(color: context.appBorder)),
      ),
      child: Row(
        children: [
          // 나중에
          Semantics(
            button: true,
            label: '나중에',
            child: SizedBox(
              height: 48,
              child: TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: context.appTextTertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  '나중에',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 저장하기
          Expanded(
            child: Semantics(
              button: true,
              label: '감상 저장',
              child: GestureDetector(
                onTap: canSave && !isSaving ? onSave : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: AppTheme.smoothBox(
                    gradient: canSave ? AppTheme.greenGradient : null,
                    color: canSave ? null : context.appCard,
                    radius: AppTheme.radiusMD,
                    side: canSave
                        ? BorderSide.none
                        : BorderSide(color: context.appBorder),
                  ),
                  alignment: Alignment.center,
                  child: isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.appBg,
                          ),
                        )
                      : Text(
                          '감상 저장하기',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: canSave
                                ? context.appBg
                                : context.appTextTertiary,
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
