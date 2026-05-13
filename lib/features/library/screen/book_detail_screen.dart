import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/page_slider_card.dart';
import '../widget/manual_reading_log_sheet.dart';

/// 도서 상세 통합 화면 (바텀시트 기능 통합)
class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;

  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final books = ref.read(libraryProvider);
    final idx = books.indexWhere((b) => b.id == widget.bookId);
    if (idx >= 0) _currentPage = books[idx].currentPage;
  }

  Future<void> _savePage() async {
    HapticFeedback.mediumImpact();
    ref
        .read(libraryProvider.notifier)
        .updateCurrentPage(widget.bookId, _currentPage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_currentPage쪽으로 업데이트했어요',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showSetTotalPages(int currentTotal) {
    final ctrl = TextEditingController(
      text: currentTotal > 0 ? '$currentTotal' : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: const Text('총 페이지 수'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 300'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: ctx.appTextTertiary)),
          ),
          FilledButton(
            onPressed: () {
              final pages = int.tryParse(ctrl.text.trim());
              if (pages != null && pages > 0) {
                ref
                    .read(libraryProvider.notifier)
                    .updateTotalPages(widget.bookId, pages);
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: ctx.appPrimaryAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCompletion(Book book) async {
    HapticFeedback.heavyImpact();
    if (book.status == ReadingStatus.completed) {
      ref.read(libraryProvider.notifier).cancelCompletion(widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '완독이 취소되었어요',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          ),
        );
      }
    } else {
      setState(() => _currentPage = book.totalPages);
      ref.read(libraryProvider.notifier).markAsCompleted(widget.bookId);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Book>>(libraryProvider, (prev, next) {
      final prevIdx = prev?.indexWhere((b) => b.id == widget.bookId) ?? -1;
      final nextIdx = next.indexWhere((b) => b.id == widget.bookId);
      if (prevIdx >= 0 && nextIdx >= 0 &&
          prev![prevIdx].status != next[nextIdx].status) {
        setState(() => _currentPage = next[nextIdx].currentPage);
      }
    });

    final bookList = ref.watch(libraryProvider);
    final bookIndex = bookList.indexWhere((b) => b.id == widget.bookId);

    if (bookIndex < 0) {
      return const Scaffold(body: Center(child: Text('책을 찾을 수 없습니다.')));
    }

    final book = bookList[bookIndex];
    final isCompleted = book.status == ReadingStatus.completed;

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          // ── 히어로 섹션 ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroSection(
              book: book,
              isCompleted: isCompleted,
              onToggleCompletion: () => _toggleCompletion(book),
              onSetTotalPages: () => _showSetTotalPages(book.totalPages),
            ),
          ),

          // ── 독서 통계 ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _StatsRow(
              sessions: 12,
              totalHours: book.totalReadingHours,
              avgMinutes: 45,
              sentenceCount: book.savedSentences.length,
            ),
          ),

          // ── 현재 페이지 업데이트 ────────────────────────────────────
          if (!isCompleted)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: PageSliderCard(
                  key: ValueKey(book.totalPages),
                  initialPage: _currentPage,
                  totalPages: book.totalPages,
                  onPageChanged: (p) => setState(() => _currentPage = p),
                  onSave: (page) async => _savePage(),
                  trailing: TextButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ManualReadingLogSheet(book: book),
                    ),
                    icon: const Icon(Icons.history_edu_rounded, size: 16),
                    label: const Text('수동 기록',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appPrimaryAccent,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
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
          context.push(
            AppConstants.routeSession,
            extra: SessionExtra(
              bookId: book.id,
              bookTitle: book.title,
              bookAuthor: book.author,
              coverUrl: book.coverUrl,
              startPage: _currentPage,
              totalPages: book.totalPages,
            ),
          );
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
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: AppTheme.smoothShape(radius: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () {},
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

// ─── 히어로 섹션 ──────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Book book;
  final bool isCompleted;
  final VoidCallback onToggleCompletion;
  final VoidCallback onSetTotalPages;

  const _HeroSection({
    required this.book,
    required this.isCompleted,
    required this.onToggleCompletion,
    required this.onSetTotalPages,
  });

  @override
  Widget build(BuildContext context) {
    final hasTotal = book.totalPages > 0;
    final gradientIndex =
        book.title.hashCode.abs() % AppTheme.coverGradients.length;
    final coverColors = AppTheme.coverGradients[gradientIndex];
    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // 책 표지 컬러 기반 대기권 그라디언트
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topPad + 340,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  coverColors[0].withValues(alpha: 0.55),
                  coverColors[0].withValues(alpha: 0.18),
                  context.appBg.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(24, topPad + 12, 24, 32),
          child: Column(
            children: [
              // ── 헤더: 뒤로가기 + 완독하기 ──────────────────────────
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onToggleCompletion,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: AppTheme.smoothBox(
                        color: isCompleted
                            ? context.appPrimaryAccent.withValues(alpha: 0.12)
                            : context.appCardElevated,
                        radius: 20,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: isCompleted
                                ? context.appPrimaryAccent
                                : context.appTextTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '완독하기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? context.appPrimaryAccent
                                  : context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── 책 표지 (컬러 글로우 그림자) ──────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: coverColors[1].withValues(alpha: 0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: BookCover(
                  coverUrl: book.coverUrl,
                  gradientIndex: gradientIndex,
                  width: 148,
                  height: 210,
                  radius: 16,
                ),
              ),
              const SizedBox(height: 28),

              // ── 제목 + 저자 ─────────────────────────────────────────
              Text(
                book.title,
                style: AppTheme.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                book.author,
                style: AppTheme.bodyMedium.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // ── 진행률 ─────────────────────────────────────────────
              if (hasTotal) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${(book.readingProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: context.appPrimaryAccent,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${book.currentPage} / ${book.totalPages}쪽',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        GestureDetector(
                          onTap: onSetTotalPages,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_rounded,
                                size: 11,
                                color: context.appTextTertiary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '총 쪽수 수정',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: book.readingProgress,
                    minHeight: 8,
                    backgroundColor: context.appCardElevated,
                    valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                  ),
                ),
              ] else
                GestureDetector(
                  onTap: onSetTotalPages,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (book.currentPage > 0) ...[
                        Text(
                          '${book.currentPage}쪽',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: AppTheme.smoothBox(
                          color: context.appPrimaryAccent.withValues(alpha: 0.08),
                          radius: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 13,
                              color: context.appPrimaryAccent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '총 쪽수 입력',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.appPrimaryAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 독서 통계 ────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
      child: Row(
        children: [
          _StatCard(label: '세션', value: '$sessions'),
          const SizedBox(width: 8),
          _StatCard(
            label: '누적 시간',
            value: '${totalHours.toStringAsFixed(1)}h',
          ),
          const SizedBox(width: 8),
          _StatCard(label: '평균', value: '$avgMinutes분'),
          const SizedBox(width: 8),
          _StatCard(label: '문장', value: '$sentenceCount'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: AppTheme.smoothBox(
          color: context.appCardElevated,
          radius: 14,
        ),
        child: Column(
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
              style: AppTheme.captionSmall.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 공통 서브 위젯 ───────────────────────────────────────────────────────

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
