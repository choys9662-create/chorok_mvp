import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ─── 네비게이션 데이터 ────────────────────────────────────────────────────

class SentenceDetailExtra {
  final String sentenceContent;
  final String bookTitle;
  final String bookAuthor;
  final int? page;
  final String? collectorUsername; // 원 수집자
  final String? collectorThought; // 원 수집자의 생각

  const SentenceDetailExtra({
    required this.sentenceContent,
    required this.bookTitle,
    required this.bookAuthor,
    this.page,
    this.collectorUsername,
    this.collectorThought,
  });
}

// ─── 내부 모델 ────────────────────────────────────────────────────────────

class _ReaderThought {
  final String username;
  final String thought;
  final DateTime createdAt;
  final int empathyCount;
  bool isLiked;

  _ReaderThought({
    required this.username,
    required this.thought,
    required this.createdAt,
    this.empathyCount = 0,
    this.isLiked = false,
  });
}

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// ─── 목업 데이터 ──────────────────────────────────────────────────────────

List<_ReaderThought> _buildMockThoughts() => [
  _ReaderThought(
    username: 'reader_jin',
    thought: '거부의 시작이 꿈이라는 건, 의지가 아닌 무의식의 선택이라는 뜻. 영혜의 저항은 논리가 아니라 본능에서 왔다.',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    empathyCount: 42,
  ),
  _ReaderThought(
    username: 'bookworm_su',
    thought: '꿈이 현실을 바꾸는 순간. 우리도 설명할 수 없는 감각으로 삶을 바꾼 적이 있지 않나.',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    empathyCount: 28,
    isLiked: true,
  ),
  _ReaderThought(
    username: 'midnight_books',
    thought: '"꿈 때문에"라는 짧은 이유가 오히려 강렬해요. 이유를 길게 설명하지 않는 게 영혜의 방식이다.',
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    empathyCount: 56,
  ),
  _ReaderThought(
    username: 'seoulreader',
    thought: '채식이 곧 저항이고, 꿈이 곧 각성이다. 한강은 이 한 문장에 소설 전체를 압축했다.',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    empathyCount: 91,
  ),
  _ReaderThought(
    username: 'hesse_lover',
    thought: '데미안에서 "새는 알에서 나오려고 투쟁한다"와 같은 결의 문장. 각성은 항상 고통을 수반한다.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    empathyCount: 34,
  ),
  _ReaderThought(
    username: 'leafy_reader',
    thought: '이 문장을 처음 읽었을 때 "왜?"라고 물었다. 마지막에 다시 읽었을 때 더 이상 묻지 않았다.',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    empathyCount: 67,
  ),
];

// ─── 메인 스크린 ──────────────────────────────────────────────────────────

class SentenceDetailScreen extends StatefulWidget {
  final SentenceDetailExtra data;

  const SentenceDetailScreen({super.key, required this.data});

  @override
  State<SentenceDetailScreen> createState() => _SentenceDetailScreenState();
}

class _SentenceDetailScreenState extends State<SentenceDetailScreen> {
  late final List<_ReaderThought> _thoughts;
  final _myThoughtController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _thoughts = _useMock ? _buildMockThoughts() : [];
  }

  @override
  void dispose() {
    _myThoughtController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitThought() {
    final text = _myThoughtController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
      _thoughts.insert(
        0,
        _ReaderThought(
          username: '나',
          thought: text,
          createdAt: DateTime.now(),
          empathyCount: 0,
        ),
      );
      _myThoughtController.clear();
    });
    _focusNode.unfocus();

    // 실제로는 Supabase에 저장
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isSubmitting = false);
    });
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.appBg,
      body: Column(
        children: [
          // ── 스크롤 영역 ──────────────────────────────────
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: topPad)),

                // ── 네비 바 ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      8,
                      AppTheme.screenPadding,
                      0,
                    ),
                    child: Row(
                      children: [
                        Semantics(
                          label: '뒤로 가기',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.pop();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: AppTheme.smoothBox(
                                color: context.appSurface.withValues(
                                  alpha: 0.5,
                                ),
                                radius: AppTheme.radiusSM,
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_rounded,
                                size: 18,
                                color: context.appTextPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.bookTitle,
                                style: AppTheme.bodySmall.copyWith(
                                  color: context.appPrimaryAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                d.bookAuthor,
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 문장 히어로 ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.space2XL,
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 페이지 번호
                        if (d.page != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: AppTheme.smoothPill(
                                color: AppTheme.primary.withValues(alpha: 0.25),
                              ),
                              child: Text(
                                'p.${d.page}',
                                style: AppTheme.captionLarge.copyWith(
                                  color: context.appPrimaryAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                        // 원문 인용
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppTheme.spaceLG),
                          decoration: BoxDecoration(
                            color: context.appCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border(
                              left: BorderSide(
                                color: context.appPrimaryAccent,
                                width: 4,
                              ),
                            ),
                          ),
                          child: Text(
                            '"${d.sentenceContent}"',
                            style: AppTheme.headingSmall.copyWith(
                              fontStyle: FontStyle.italic,
                              color: context.appTextPrimary,
                              height: 1.7,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 수집 통계 ────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      0,
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: AppTheme.smoothBox(
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                        radius: AppTheme.radiusMD,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 18,
                            color: context.appPrimaryAccent,
                          ),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              style: AppTheme.captionLarge.copyWith(
                                color: context.appTextSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: '${_thoughts.length}명',
                                  style: AppTheme.captionLarge.copyWith(
                                    color: context.appPrimaryAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: '이 이 문장에 생각을 남겼어요'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── 구분선 ───────────────────────────────────
                SliverToBoxAdapter(
                  child: Divider(
                    height: 1,
                    color: context.appBorder,
                    indent: AppTheme.screenPadding,
                    endIndent: AppTheme.screenPadding,
                  ),
                ),

                // ── 다른 독자들의 생각 헤더 ───────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.screenPadding,
                      AppTheme.spaceLG,
                      AppTheme.screenPadding,
                      AppTheme.spaceMD,
                    ),
                    child: Text(
                      '다른 독자들의 생각',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ),

                // ── 생각 목록 ────────────────────────────────
                if (_thoughts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: context.appTextTertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '아직 남겨진 생각이 없어요\n첫 번째 생각을 남겨보세요!',
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMedium.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.screenPadding,
                    ),
                    sliver: SliverList.separated(
                      itemCount: _thoughts.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppTheme.spaceMD),
                      itemBuilder: (context, index) => _ThoughtCard(
                        thought: _thoughts[index],
                        formatTime: _formatRelative,
                        onToggleLike: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _thoughts[index].isLiked =
                                !_thoughts[index].isLiked;
                          });
                        },
                      ),
                    ),
                  ),

                // ── 하단 여백 ────────────────────────────────
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),

          // ── 입력 바 (하단 고정) ──────────────────────────
          Container(
            padding: EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              10,
              AppTheme.screenPadding,
              bottomPad + 10,
            ),
            decoration: BoxDecoration(
              color: context.appBg,
              border: Border(top: BorderSide(color: context.appBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: AppTheme.smoothBox(
                      color: context.appCard,
                      radius: 22,
                      side: BorderSide(color: context.appBorder),
                    ),
                    child: TextField(
                      controller: _myThoughtController,
                      focusNode: _focusNode,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '이 문장에 대한 나의 생각...',
                        hintStyle: AppTheme.bodySmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitThought(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: '생각 남기기',
                  button: true,
                  child: GestureDetector(
                    onTap: _submitThought,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        gradient: AppTheme.greenGradient,
                        radius: 22,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                    ),
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

// ─── 생각 카드 ────────────────────────────────────────────────────────────

class _ThoughtCard extends StatelessWidget {
  final _ReaderThought thought;
  final String Function(DateTime) formatTime;
  final VoidCallback onToggleLike;

  const _ThoughtCard({
    required this.thought,
    required this.formatTime,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final t = thought;

    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 유저 정보 + 시간 ────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  t.username[0].toUpperCase(),
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appPrimaryAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.username,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                formatTime(t.createdAt),
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── 생각 내용 ──────────────────────────────────
          Text(
            t.thought,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),

          // ── 좋아요 버튼 ────────────────────────────────
          GestureDetector(
            onTap: onToggleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  t.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 16,
                  color: t.isLiked
                      ? const Color(0xFFFF6B6B)
                      : context.appTextTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${t.empathyCount + (t.isLiked ? 1 : 0)}',
                  style: AppTheme.captionLarge.copyWith(
                    color: t.isLiked
                        ? const Color(0xFFFF6B6B)
                        : context.appTextTertiary,
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
