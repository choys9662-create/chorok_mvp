import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/widgets/page_slider_card.dart';
import '../widget/manual_reading_log_sheet.dart';

// 책별 수집 문장 (모바일 SQLite choseo 테이블 — 웹/목업은 book.savedSentences 사용)
final _bookChoseoProvider = FutureProvider.family<List<String>, String>(
  (ref, bookId) async {
    if (kIsWeb || kUseMock) return const [];
    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return const [];
    final rows = await repo.getChoseoByBook(bookId);
    return rows.map((c) => c.content).toList();
  },
);

// 책별 세션 통계 (세션 수, 누적 시간, 평균 분)
final _bookSessionStatsProvider = FutureProvider.family<
  ({int sessions, double totalHours, int avgMinutes}),
  String
>((ref, bookId) async {
  final repo = ref.read(bookRepositoryProvider);
  if (repo == null) return (sessions: 0, totalHours: 0.0, avgMinutes: 0);
  final sessions = await repo.getSessionsForBook(bookId);
  final count = sessions.length;
  if (count == 0) return (sessions: 0, totalHours: 0.0, avgMinutes: 0);
  final totalSecs = sessions.fold(0, (s, r) => s + r.durationSeconds);
  return (
    sessions: count,
    totalHours: totalSecs / 3600.0,
    avgMinutes: totalSecs ~/ count ~/ 60,
  );
});

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

  void _showMenu(Book book) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: ctx.appTextTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.format_quote_rounded,
                color: ctx.appPrimaryAccent,
              ),
              title: Text(
                '문장 추가',
                style: TextStyle(color: ctx.appTextPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showAddSentenceSheet(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('책 삭제', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSentenceSheet(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSentenceSheet(
        bookId: book.id,
        onSaved: () {
          if (!kIsWeb) {
            ref.invalidate(_bookChoseoProvider(widget.bookId));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              chorokSnackBar(context, '문장을 저장했어요'),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(Book book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: const Text('책 삭제'),
        content: Text(
          '${book.title}을(를) 서재에서 삭제할까요?\n독서 기록도 함께 사라져요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('취소', style: TextStyle(color: ctx.appTextTertiary)),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              ref.read(libraryProvider.notifier).deleteBook(widget.bookId);
              context.pop();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCompletion(Book book) async {
    HapticFeedback.heavyImpact();
    if (book.status == ReadingStatus.completed) {
      await ref.read(libraryProvider.notifier).cancelCompletion(widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '읽음이 취소되었어요',
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
      await ref.read(libraryProvider.notifier).markAsCompleted(widget.bookId);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<List<Book>>(libraryProvider, (prev, next) {
      final nextIdx = next.indexWhere((b) => b.id == widget.bookId);
      if (nextIdx < 0) return;
      final prevIdx = prev?.indexWhere((b) => b.id == widget.bookId) ?? -1;
      if (prevIdx >= 0) {
        final prevBook = prev![prevIdx];
        final nextBook = next[nextIdx];
        if (prevBook.status != nextBook.status ||
            prevBook.currentPage != nextBook.currentPage) {
          setState(() => _currentPage = nextBook.currentPage);
        }
      }
    });

    final bookList = ref.watch(libraryProvider);
    final bookIndex = bookList.indexWhere((b) => b.id == widget.bookId);

    if (bookIndex < 0) {
      if (bookList.isEmpty) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const Scaffold(body: Center(child: Text('책을 찾을 수 없습니다.')));
    }

    final book = bookList[bookIndex];
    final isCompleted = book.status == ReadingStatus.completed;

    final dbChoseo = ref
        .watch(_bookChoseoProvider(widget.bookId))
        .valueOrNull ?? const [];
    final sentences = (kUseMock || kIsWeb) ? book.savedSentences : dbChoseo;

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
            child: Builder(builder: (context) {
              final stats = ref
                  .watch(_bookSessionStatsProvider(widget.bookId))
                  .valueOrNull;
              return _StatsRow(
                sessions: stats?.sessions ?? 0,
                totalHours: stats?.totalHours ?? 0.0,
                avgMinutes: stats?.avgMinutes ?? 0,
                sentenceCount: sentences.length,
              );
            }),
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
                  onSave: (page) async {
                    setState(() => _currentPage = page);
                    await _savePage();
                  },
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
          if (sentences.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: '수집한 문장',
                count: sentences.length,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SentenceItem(content: sentences[index]),
                childCount: sentences.length,
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
        onMenu: () => _showMenu(book),
      ),
    );
  }
}

// ─── 하단 액션 바 ──────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final Book book;
  final VoidCallback onStartSession;
  final VoidCallback onMenu;

  const _BottomActionBar({
    required this.book,
    required this.onStartSession,
    required this.onMenu,
  });

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
            onPressed: onMenu,
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
              // ── 헤더: 뒤로가기 ──────────────────────────────────
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
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
                style: AppTheme.headingMedium,
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
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
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
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onToggleCompletion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
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
                              size: 16,
                              color: isCompleted
                                  ? context.appPrimaryAccent
                                  : context.appTextTertiary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '읽었어요',
                              style: TextStyle(
                                fontSize: 13,
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
              ] else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onSetTotalPages,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onToggleCompletion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
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
                              size: 16,
                              color: isCompleted
                                  ? context.appPrimaryAccent
                                  : context.appTextTertiary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '읽었어요',
                              style: TextStyle(
                                fontSize: 13,
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

// ─── 문장 추가 바텀시트 ───────────────────────────────────────────────────────

class _AddSentenceSheet extends ConsumerStatefulWidget {
  final String bookId;
  final VoidCallback onSaved;

  const _AddSentenceSheet({required this.bookId, required this.onSaved});

  @override
  ConsumerState<_AddSentenceSheet> createState() => _AddSentenceSheetState();
}

class _AddSentenceSheetState extends ConsumerState<_AddSentenceSheet> {
  final _contentCtrl = TextEditingController();
  final _thoughtCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  bool _isSaving = false;
  bool _hasError = false;

  bool get _hasInput => _contentCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), _contentFocus.requestFocus);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _thoughtCtrl.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSaving = true;
      _hasError = false;
    });
    HapticFeedback.mediumImpact();

    try {
      await ref.read(libraryProvider.notifier).addSentence(
        widget.bookId,
        content,
        thought: _thoughtCtrl.text.trim().isNotEmpty
            ? _thoughtCtrl.text.trim()
            : null,
      );
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasError = true;
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<bool> _onPop() async {
    if (!_hasInput) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.appSurface,
        title: const Text('작성 중인 내용이 있어요'),
        content: const Text('저장하지 않고 나가면 내용이 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('계속 작성', style: TextStyle(color: ctx.appTextTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _onPop();
        if (shouldPop && mounted) nav.pop();
      },
      child: Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: context.appTextTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            '문장 추가',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // 문장 입력
          _SheetTextField(
            controller: _contentCtrl,
            focusNode: _contentFocus,
            hintText: '기록하고 싶은 문장을 입력하세요',
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),

          // 내 생각 입력 (선택)
          _SheetTextField(
            controller: _thoughtCtrl,
            hintText: '내 생각 (선택)',
            maxLines: 2,
          ),

          // 에러 메시지
          if (_hasError) ...[
            const SizedBox(height: 10),
            Text(
              '저장에 실패했어요. 다시 시도해보세요.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade400),
            ),
          ],
          const SizedBox(height: 20),

          // 저장 버튼
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_hasInput && !_isSaving)
                  ? _save
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimaryAccent,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    context.appPrimaryAccent.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: AppTheme.smoothShape(radius: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _SheetTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.maxLines,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: 12,
        side: BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 14,
          color: context.appTextPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14,
            color: context.appTextTertiary,
            height: 1.6,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        cursorColor: context.appPrimaryAccent,
        cursorWidth: 1.5,
      ),
    );
  }
}
