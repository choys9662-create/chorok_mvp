import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/utils/book_genre.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_refresh.dart';

enum _TasteMode { time, completed }

const _tasteHorizontalPadding = AppTheme.screenPadding;

final _tasteSessionGroupsProvider = FutureProvider.autoDispose
    .family<List<_TasteGroup>, String?>((ref, userId) async {
      if (kUseMock) {
        return _buildGroups(ref.watch(libraryProvider), _TasteMode.time);
      }
      return _loadTasteGroupsFromSessions(userId);
    });

class TasteAnalysisScreen extends ConsumerStatefulWidget {
  final String? userId;

  const TasteAnalysisScreen({super.key, this.userId});

  @override
  ConsumerState<TasteAnalysisScreen> createState() =>
      _TasteAnalysisScreenState();
}

class _TasteAnalysisScreenState extends ConsumerState<TasteAnalysisScreen> {
  _TasteMode _mode = _TasteMode.time;
  final _expandedGenres = <String>{};

  @override
  Widget build(BuildContext context) {
    final booksAsync = widget.userId == null
        ? AsyncValue.data(ref.watch(libraryProvider))
        : ref.watch(userBooksProvider(widget.userId!));
    final sessionGroupsAsync = _mode == _TasteMode.time
        ? ref.watch(_tasteSessionGroupsProvider(widget.userId))
        : null;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        bottom: false,
        child: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _TasteEmpty(message: '독서 취향을 불러오지 못했어요'),
          data: (books) => ChorokRefresh(
            onRefresh: () => _refresh(ref),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      _tasteHorizontalPadding,
                      AppTheme.sectionGap,
                      _tasteHorizontalPadding,
                      AppTheme.spaceXL,
                    ),
                    child: _TasteHeader(
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                ..._buildContent(context, books, sessionGroupsAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(_tasteSessionGroupsProvider(widget.userId));
    if (widget.userId == null) {
      await ref.read(libraryProvider.notifier).reload();
    } else {
      ref.invalidate(userBooksProvider(widget.userId!));
      await ref.read(userBooksProvider(widget.userId!).future);
    }
  }

  List<Widget> _buildContent(
    BuildContext context,
    List<Book> books,
    AsyncValue<List<_TasteGroup>>? sessionGroupsAsync,
  ) {
    final bookGroups = _buildGroups(books, _mode);
    final sessionGroups = sessionGroupsAsync?.valueOrNull ?? const [];
    final groups = sessionGroups.isNotEmpty ? sessionGroups : bookGroups;
    if (groups.isEmpty &&
        sessionGroupsAsync != null &&
        sessionGroupsAsync.isLoading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (groups.isEmpty && (sessionGroupsAsync?.hasError ?? false)) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _TasteEmpty(message: '독서 취향을 불러오지 못했어요'),
        ),
      ];
    }
    if (groups.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: _TasteEmpty(message: '아직 독서 취향 데이터가 없어요'),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _tasteHorizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TasteModeRow(
                mode: _mode,
                onToggle: () => setState(() {
                  _mode = _mode == _TasteMode.time
                      ? _TasteMode.completed
                      : _TasteMode.time;
                }),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              _TasteHeroCard(group: groups.first, mode: _mode),
              const SizedBox(height: AppTheme.sectionGap),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.only(
          left: _tasteHorizontalPadding,
          right: _tasteHorizontalPadding,
          bottom:
              MediaQuery.paddingOf(context).bottom +
              AppTheme.sectionGap +
              AppTheme.spaceXL * 3 +
              AppTheme.spaceMD,
        ),
        sliver: SliverList.separated(
          itemCount: groups.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTheme.sectionGap),
          itemBuilder: (context, index) {
            final group = groups[index];
            return _TasteGenreSection(
              rank: index + 1,
              group: group,
              mode: _mode,
              expanded: _expandedGenres.contains(group.genre),
              onToggleExpanded: () => setState(() {
                if (!_expandedGenres.add(group.genre)) {
                  _expandedGenres.remove(group.genre);
                }
              }),
            );
          },
        ),
      ),
    ];
  }
}

class _TasteHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TasteHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Semantics(
            label: '뒤로 가기',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                onBack();
              },
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context.appTextSecondary,
                  size: 20,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '나의 독서 취향',
                style: AppTheme.screenTitle.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44, height: 44),
        ],
      ),
    );
  }
}

class _TasteModeRow extends StatelessWidget {
  final _TasteMode mode;
  final VoidCallback onToggle;

  const _TasteModeRow({required this.mode, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            mode == _TasteMode.time ? '읽은 시간 기준' : '완독 기준',
            style: AppTheme.body.copyWith(color: context.appTextSecondary),
          ),
        ),
        Semantics(
          label: mode == _TasteMode.time ? '완독 기준 보기' : '읽은 시간 기준 보기',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              onToggle();
            },
            child: SizedBox(
              width: 46,
              height: 24,
              child: ChorokCard(
                inner: true,
                showBorder: false,
                padding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: mode == _TasteMode.time
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: ChorokCard(
                      inner: true,
                      backgroundColor: context.appTextSecondary,
                      showBorder: false,
                      padding: EdgeInsets.zero,
                      child: Icon(
                        mode == _TasteMode.time
                            ? Icons.watch_later_rounded
                            : Icons.menu_book_rounded,
                        size: 13,
                        color: context.appCard,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TasteHeroCard extends StatelessWidget {
  final _TasteGroup group;
  final _TasteMode mode;

  const _TasteHeroCard({required this.group, required this.mode});

  @override
  Widget build(BuildContext context) {
    final suffix = mode == _TasteMode.time ? '책벌레' : '도서관';
    final action = mode == _TasteMode.time ? '가장 오래 읽었어요!' : '가장 많이 읽었어요!';

    return SizedBox(
      width: double.infinity,
      child: ChorokCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: AppTheme.spaceMD,
        ),
        child: Column(
          spacing: AppTheme.spaceSM,
          children: [
            Text(
              '${group.genre} $suffix',
              textAlign: TextAlign.center,
              style: AppTheme.sectionTitle.copyWith(
                color: context.appPrimaryAccent,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '전체 이용자 중에서 ${group.genre}을 $action',
                textAlign: TextAlign.center,
                maxLines: 1,
                style: AppTheme.supportingText.copyWith(
                  color: context.appPrimaryAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasteGenreSection extends StatelessWidget {
  final int rank;
  final _TasteGroup group;
  final _TasteMode mode;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _TasteGenreSection({
    required this.rank,
    required this.group,
    required this.mode,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final visibleBooks = expanded ? group.books : group.books.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppTheme.spaceMD,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$rank | ${group.genre}',
                style: AppTheme.sectionTitle.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Text(
              mode == _TasteMode.time
                  ? _formatMinutes(group.totalMinutes)
                  : '${group.completedCount}권',
              style: AppTheme.sectionTitle.copyWith(
                color: context.appTextPrimary,
              ),
            ),
          ],
        ),
        ChorokCard(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.cardPaddingMD,
            AppTheme.cardPaddingMD,
            AppTheme.cardPaddingMD,
            AppTheme.spaceXS,
          ),
          child: Column(
            children: [
              for (final entry in visibleBooks.indexed) ...[
                _TasteBookRow(book: entry.$2),
                if (entry.$1 != visibleBooks.length - 1)
                  const Divider(height: AppTheme.sectionGap),
              ],
              if (group.books.length > visibleBooks.length) ...[
                const Divider(height: AppTheme.sectionGap),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleExpanded();
                  },
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        '전체보기',
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (expanded && group.books.length > 6) ...[
                const Divider(height: AppTheme.sectionGap),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleExpanded();
                  },
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        '접기',
                        style: AppTheme.rowText.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: AppTheme.spaceLG),
            ],
          ),
        ),
      ],
    );
  }
}

class _TasteBookRow extends StatelessWidget {
  final _TasteBook book;

  const _TasteBookRow({required this.book});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.rowText.copyWith(color: context.appTextSecondary),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            flex: 2,
            child: Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          SizedBox(
            width: 82,
            child: Text(
              _formatMinutes(book.minutes),
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body.copyWith(color: context.appTextSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasteEmpty extends StatelessWidget {
  final String message;

  const _TasteEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.06),
      child: Text(
        message,
        style: AppTheme.sectionTitle.copyWith(color: context.appTextSecondary),
      ),
    );
  }
}

class _TasteGroup {
  final String genre;
  final List<_TasteBook> books;

  const _TasteGroup({required this.genre, required this.books});

  int get totalMinutes => books.fold(0, (sum, book) => sum + book.minutes);
  int get completedCount => books.where((book) => book.completed).length;
}

class _TasteBook {
  final String title;
  final String author;
  final String genre;
  final int minutes;
  final bool completed;

  const _TasteBook({
    required this.title,
    required this.author,
    required this.genre,
    required this.minutes,
    required this.completed,
  });
}

class _TasteBookDraft {
  final String title;
  final String author;
  final String genre;
  int seconds;

  _TasteBookDraft({
    required this.title,
    required this.author,
    required this.genre,
    required this.seconds,
  });
}

Future<List<_TasteGroup>> _loadTasteGroupsFromSessions(String? userId) async {
  final client = Supabase.instance.client;
  final effectiveUserId = userId ?? client.auth.currentUser?.id;
  if (effectiveUserId == null) return const [];

  List<dynamic> rows;
  try {
    rows = await client
        .from('reading_sessions')
        .select(
          'book_id, duration_seconds, books(title, author, genre, global_books(category))',
        )
        .eq('user_id', effectiveUserId);
  } catch (_) {
    rows = await client
        .from('reading_sessions')
        .select('book_id, duration_seconds, books(title, author, genre)')
        .eq('user_id', effectiveUserId);
  }

  return _buildGroupsFromSessionRows(rows);
}

List<_TasteGroup> _buildGroupsFromSessionRows(List<dynamic> rows) {
  final byBook = <String, _TasteBookDraft>{};
  for (final row in rows.cast<Map<String, dynamic>>()) {
    final seconds = (row['duration_seconds'] as num?)?.toInt() ?? 0;
    if (seconds <= 0) continue;

    final book = row['books'] as Map<String, dynamic>?;
    final title = (book?['title'] as String?)?.trim();
    if (title == null || title.isEmpty) continue;
    final author = (book?['author'] as String?)?.trim() ?? '';
    final globalBook = book?['global_books'] as Map<String, dynamic>?;
    final genre = _genreLabel(
      (book?['genre'] as String?) ?? globalBook?['category'] as String?,
      fallbackTitle: title,
    );
    final key = '${row['book_id'] ?? '$title|$author'}';
    final existing = byBook[key];
    if (existing == null) {
      byBook[key] = _TasteBookDraft(
        title: title,
        author: author,
        genre: genre,
        seconds: seconds,
      );
    } else {
      existing.seconds += seconds;
    }
  }

  final rowsByGenre = <String, List<_TasteBook>>{};
  for (final draft in byBook.values) {
    final minutes = (draft.seconds / 60).round();
    if (minutes <= 0) continue;
    rowsByGenre
        .putIfAbsent(draft.genre, () => [])
        .add(
          _TasteBook(
            title: draft.title,
            author: draft.author,
            genre: draft.genre,
            minutes: minutes,
            completed: false,
          ),
        );
  }

  final groups = rowsByGenre.entries.map((entry) {
    final books = entry.value..sort((a, b) => b.minutes.compareTo(a.minutes));
    return _TasteGroup(genre: entry.key, books: books);
  }).toList();
  groups.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
  return groups;
}

List<({String genre, String title, String author, int minutes})>
tasteSessionRowsForTest(List<Map<String, dynamic>> rows) {
  return [
    for (final group in _buildGroupsFromSessionRows(rows))
      for (final book in group.books)
        (
          genre: group.genre,
          title: book.title,
          author: book.author,
          minutes: book.minutes,
        ),
  ];
}

List<_TasteGroup> _buildGroups(List<Book> books, _TasteMode mode) {
  final rows = books
      .where(
        (book) => mode == _TasteMode.time
            ? book.totalReadingHours > 0
            : book.status == ReadingStatus.completed,
      )
      .map(
        (book) => _TasteBook(
          title: book.title,
          author: book.author,
          genre: _genreLabel(book.genre, fallbackTitle: book.title),
          minutes: (book.totalReadingHours * 60).round(),
          completed: book.status == ReadingStatus.completed,
        ),
      )
      .toList();

  final byGenre = <String, List<_TasteBook>>{};
  for (final row in rows) {
    byGenre.putIfAbsent(row.genre, () => []).add(row);
  }

  final groups = byGenre.entries.map((entry) {
    final books = entry.value..sort((a, b) => b.minutes.compareTo(a.minutes));
    return _TasteGroup(genre: entry.key, books: books);
  }).toList();

  groups.sort((a, b) {
    final primary = mode == _TasteMode.time
        ? b.totalMinutes.compareTo(a.totalMinutes)
        : b.completedCount.compareTo(a.completedCount);
    if (primary != 0) return primary;
    return b.totalMinutes.compareTo(a.totalMinutes);
  });
  return groups;
}

String _genreLabel(String? raw, {String? fallbackTitle}) {
  final label = classifyBookGenre(raw);
  if (label != unclassifiedGenre) return label;
  return _genreFromKnownTitle(fallbackTitle) ?? '기타';
}

String? _genreFromKnownTitle(String? title) {
  final t = title?.trim();
  if (t == null || t.isEmpty) return null;
  if (t.contains('지구 끝의 온실')) return 'SF';
  if (t.contains('파친코')) return '역사소설';
  if (t.contains('달러구트')) return '판타지';
  return null;
}

String _formatMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
