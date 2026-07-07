import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/utils/book_genre.dart';

enum _TasteMode { time, completed }

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: booksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _TasteEmpty(message: '독서 취향을 불러오지 못했어요'),
          data: (books) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
                  child: _TasteHeader(
                    onBack: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              ..._buildContent(context, books),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, List<Book> books) {
    final groups = _buildGroups(books, _mode);
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
          padding: const EdgeInsets.symmetric(horizontal: 30),
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
              const SizedBox(height: 20),
              _TasteHeroCard(group: groups.first, mode: _mode),
              const SizedBox(height: 46),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          30,
          0,
          30,
          MediaQuery.paddingOf(context).bottom + 112,
        ),
        sliver: SliverList.separated(
          itemCount: groups.length,
          separatorBuilder: (_, _) => const SizedBox(height: 58),
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
                style: AppTheme.headingLarge.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0,
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
            style: AppTheme.headingLarge.copyWith(
              color: const Color(0xFF758076),
              letterSpacing: 0,
            ),
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
            child: Container(
              width: 86,
              height: 48,
              alignment: mode == _TasteMode.time
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              padding: const EdgeInsets.all(7),
              decoration: AppTheme.smoothBox(
                color: const Color(0xFF171C18),
                radius: 8,
              ),
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: AppTheme.smoothBox(
                  color: const Color(0xFF97A49A),
                  radius: 5,
                ),
                child: Icon(
                  mode == _TasteMode.time
                      ? Icons.watch_later_rounded
                      : Icons.menu_book_rounded,
                  size: 22,
                  color: AppTheme.darkCard,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: AppTheme.smoothBox(
        color: AppTheme.darkCard,
        radius: 8,
        side: const BorderSide(color: Color(0xFF273027)),
      ),
      child: Column(
        children: [
          Text(
            '${group.genre} $suffix',
            textAlign: TextAlign.center,
            style: AppTheme.displayMedium.copyWith(
              color: AppTheme.primaryLight,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '전체 이용자 중에서 ${group.genre}을 $action',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: AppTheme.headingSmall.copyWith(
                color: AppTheme.primaryLight,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
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
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$rank | ${group.genre}',
                style: AppTheme.displayMedium.copyWith(
                  color: const Color(0xFFDDE5DC),
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              mode == _TasteMode.time
                  ? _formatMinutes(group.totalMinutes)
                  : '${group.completedCount}권',
              style: AppTheme.headingLarge.copyWith(
                color: const Color(0xFFDDE5DC),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(30, 22, 30, 0),
          decoration: AppTheme.smoothBox(color: AppTheme.darkCard, radius: 10),
          child: Column(
            children: [
              for (final entry in visibleBooks.indexed) ...[
                _TasteBookRow(book: entry.$2),
                if (entry.$1 != visibleBooks.length - 1)
                  const Divider(height: 36, color: Color(0xFF242B24)),
              ],
              if (group.books.length > visibleBooks.length) ...[
                const Divider(height: 36, color: Color(0xFF242B24)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleExpanded();
                  },
                  child: SizedBox(
                    height: 64,
                    child: Center(
                      child: Text(
                        '전체보기',
                        style: AppTheme.headingSmall.copyWith(
                          color: const Color(0xFF7F8B81),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else if (expanded && group.books.length > 6) ...[
                const Divider(height: 36, color: Color(0xFF242B24)),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleExpanded();
                  },
                  child: SizedBox(
                    height: 64,
                    child: Center(
                      child: Text(
                        '접기',
                        style: AppTheme.headingSmall.copyWith(
                          color: const Color(0xFF7F8B81),
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 22),
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
      height: 42,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.headingSmall.copyWith(
                color: const Color(0xFF879187),
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyLarge.copyWith(
                color: const Color(0xFF879187),
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              _formatMinutes(book.minutes),
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyLarge.copyWith(
                color: const Color(0xFF879187),
                letterSpacing: 0,
              ),
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
    return Center(
      child: Text(
        message,
        style: AppTheme.bodyLarge.copyWith(color: context.appTextTertiary),
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
          genre: _genreLabel(book.genre),
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

String _genreLabel(String? raw) {
  final label = classifyBookGenre(raw);
  return label == unclassifiedGenre ? '기타' : label;
}

String _formatMinutes(int totalMinutes) {
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes분';
  if (minutes == 0) return '$hours시간';
  return '$hours시간 $minutes분';
}
