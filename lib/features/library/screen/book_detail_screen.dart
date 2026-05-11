import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';

import '../widget/manual_reading_log_sheet.dart';

/// 도서 상세 통합 화면 (바텀시트 기능 통합)
class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  late final TextEditingController _pageController;
  int _currentPage = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _adjustPage(int delta, int total) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentPage = (_currentPage + delta).clamp(0, total);
      _pageController.text = '$_currentPage';
    });
  }

  Future<void> _savePage() async {
    HapticFeedback.mediumImpact();
    ref
        .read(libraryProvider.notifier)
        .updateCurrentPage(widget.bookId, _currentPage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_currentPage쪽으로 업데이트했어요'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleCompletion(Book book) async {
    HapticFeedback.heavyImpact();
    if (book.status == ReadingStatus.completed) {
      // 다시 읽기 상태로 변경 (페이지 0으로 리셋)
      ref.read(libraryProvider.notifier).updateCurrentPage(widget.bookId, 0);
    } else {
      // 완독 처리
      setState(() {
        _currentPage = book.totalPages;
        _pageController.text = '$_currentPage';
      });
      ref.read(libraryProvider.notifier).markAsCompleted(widget.bookId);
      _showCompletionDialog(book);
    }
  }

  void _showCompletionDialog(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appSurface,
        title: const Text('완독을 축하합니다! 🎉'),
        content: Text('\'${book.title}\' 책을 끝까지 읽으셨네요.\n완독 회고를 작성하러 가볼까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              '나중에',
              style: TextStyle(color: context.appTextTertiary),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppConstants.routeReflection, extra: book);
            },
            style: FilledButton.styleFrom(
              backgroundColor: context.appPrimaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('회고 작성'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookList = ref.watch(libraryProvider);
    final bookIndex = bookList.indexWhere((b) => b.id == widget.bookId);

    if (bookIndex < 0) {
      return const Scaffold(body: Center(child: Text('책을 찾을 수 없습니다.')));
    }

    final book = bookList[bookIndex];

    if (!_isInitialized) {
      _currentPage = book.currentPage;
      _pageController.text = '$_currentPage';
      _isInitialized = true;
    }

    final isCompleted = book.status == ReadingStatus.completed;

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          // ── 히어로 섹션 (표지 + 기본 정보) ───────────────────────────
          SliverToBoxAdapter(
            child: _HeroSection(
              book: book,
              isCompleted: isCompleted,
              onToggleCompletion: () => _toggleCompletion(book),
            ),
          ),

          // ── 독서 통계 ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _StatsRow(
              sessions: 12, // TODO: 실제 세션 데이터 연동
              totalHours: book.totalReadingHours,
              avgMinutes: 45,
              sentenceCount: book.savedSentences.length,
            ),
          ),

          // ── 현재 페이지 업데이트 (바텀시트에서 이식) ──────────────────────
          if (!isCompleted)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: _PageUpdateCard(
                  currentPage: _currentPage,
                  totalPages: book.totalPages,
                  controller: _pageController,
                  onAdjust: (d) => _adjustPage(d, book.totalPages),
                  onSave: _savePage,
                  onManualLog: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ManualReadingLogSheet(book: book),
                    );
                  },
                ),
              ),
            ),

          // ── 수집한 문장 리스트 ──────────────────────────────────────
          if (book.savedSentences.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '수집한 문장',
                count: book.savedSentences.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _SentenceItem(content: book.savedSentences[index]),
                childCount: book.savedSentences.length,
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
        book: book,
        onStartSession: () {
          context.push(AppConstants.routeSession, extra: book);
        },
      ),
    );
  }
}

// ─── 하단 액션 바 ──────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final Book book;
  final VoidCallback onStartSession;

  const _BottomActionBar({required this.book, required this.onStartSession});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: context.appBg.withValues(alpha: 0.8),
        // border: Border(top: BorderSide(color: context.appBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onStartSession,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                '이어 읽기',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: AppTheme.smoothShape(radius: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {}, // TODO: 삭제/메뉴
            icon: const Icon(Icons.more_vert_rounded),
            style: IconButton.styleFrom(
              backgroundColor: context.appCardElevated,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 페이지 업데이트 카드 ───────────────────────────────────────────────────

class _PageUpdateCard extends StatelessWidget {
  final int currentPage, totalPages;
  final TextEditingController controller;
  final Function(int) onAdjust;
  final VoidCallback onSave;
  final VoidCallback onManualLog;

  const _PageUpdateCard({
    required this.currentPage,
    required this.totalPages,
    required this.controller,
    required this.onAdjust,
    required this.onSave,
    required this.onManualLog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        color: context.appCardElevated,
        radius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '현재 페이지 업데이트',
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton.icon(
                onPressed: onManualLog,
                icon: const Icon(Icons.history_edu_rounded, size: 16),
                label: const Text('수동 기록', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: context.appPrimaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _QuickAdjust(label: '-10', onTap: () => onAdjust(-10)),
              const SizedBox(width: 8),
              _QuickAdjust(label: '+10', onTap: () => onAdjust(10)),
              const SizedBox(width: 8),
              _QuickAdjust(label: '+50', onTap: () => onAdjust(50)),
              const Spacer(),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.all(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('/ $totalPages쪽', style: AppTheme.captionSmall),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSave,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.1,
                ),
                foregroundColor: context.appPrimaryAccent,
                shape: AppTheme.smoothShape(radius: 8),
              ),
              child: const Text(
                '페이지 저장',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAdjust extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAdjust({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.appPrimaryAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: context.appPrimaryAccent,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── 서브 위젯들 (Hero, Stats, Header 등) ──────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Book book;
  final bool isCompleted;
  final VoidCallback onToggleCompletion;

  const _HeroSection({
    required this.book,
    required this.isCompleted,
    required this.onToggleCompletion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 12,
        24,
        24,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          BookCover(
            coverUrl: book.coverUrl,
            gradientIndex:
                book.title.hashCode.abs() % AppTheme.coverGradients.length,
            width: 140,
            height: 200,
            radius: 16,
          ),
          const SizedBox(height: 24),
          Text(
            book.title,
            style: AppTheme.headingLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            book.author,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${(book.readingProgress * 100).toInt()}%',
                style: AppTheme.headingSmall.copyWith(
                  color: context.appPrimaryAccent,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${book.currentPage} / ${book.totalPages}쪽',
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: book.readingProgress,
              minHeight: 6,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              onToggleCompletion();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isCompleted ? '다시 읽는 중으로 변경되었습니다.' : '완독 처리가 완료되었습니다! 🎉',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ), // 터치 영역 확장
              decoration: AppTheme.smoothBox(
                color: isCompleted
                    ? context.appPrimaryAccent.withValues(alpha: 0.1)
                    : context.appCardElevated,
                radius: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isCompleted
                        ? context.appPrimaryAccent
                        : context.appTextTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '완독하기',
                    style: TextStyle(
                      color: isCompleted
                          ? context.appPrimaryAccent
                          : context.appTextSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int sessions, sentenceCount;
  final double totalHours;
  final int avgMinutes;

  const _StatsRow({
    required this.sessions,
    required this.totalHours,
    required this.avgMinutes,
    required this.sentenceCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(label: '세션', value: '$sessions'),
          _StatItem(label: '누적 시간', value: '${totalHours.toStringAsFixed(1)}h'),
          _StatItem(label: '평균', value: '$avgMinutes분'),
          _StatItem(label: '문장', value: '$sentenceCount'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.headingSmall.copyWith(
            color: context.appPrimaryAccent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTheme.captionSmall.copyWith(color: context.appTextTertiary),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        children: [
          Text(title, style: AppTheme.headingSmall),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceItem extends StatelessWidget {
  final String content;
  const _SentenceItem({required this.content});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.smoothBox(
          color: context.appCardElevated,
          radius: 12,
        ),
        child: Text(
          content,
          style: AppTheme.bodySmall.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
