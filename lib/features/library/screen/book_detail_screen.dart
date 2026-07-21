import 'package:smooth_corner/smooth_corner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/stt_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/feed/screen/sentence_detail_screen.dart';
import '../../../features/library/controller/book_detail_social_provider.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_list_row.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../../../shared/widgets/sheet_handle.dart';
import '../../../shared/widgets/chorok_refresh.dart';

const _detailAccent = AppTheme.primaryLight;
const _detailCard = AppTheme.darkCard;
const _detailText = AppTheme.textPrimary;
const _detailMuted = AppTheme.textSecondary;
const _detailNavButtonSize = AppTheme.spaceLG + AppTheme.spaceXL;

typedef _BookSentenceQuery = ({
  String bookId,
  String title,
  String author,
  String? isbn,
});

// 책별 수집 문장 (웹은 Supabase sentences, 모바일은 SQLite choseo 테이블)
final _bookChoseoProvider =
    FutureProvider.family<List<IsarChoseo>, _BookSentenceQuery>((
      ref,
      query,
    ) async {
      if (kUseMock) return const [];
      if (kUseRemoteDb) {
        final rows = await ref
            .read(dbServiceProvider)
            .fetchMySentencesForBook(
              query.bookId,
              title: query.title,
              author: query.author,
              isbn: query.isbn,
            );
        return rows.map((r) {
          return IsarChoseo(
            choseoId: r['id'] as String,
            bookId: r['book_id'] as String? ?? query.bookId,
            bookTitle: '',
            bookAuthor: '',
            content: r['content'] as String,
            myThought: r['thought'] as String?,
            pageNumber: (r['page_number'] as num?)?.toInt(),
            createdAt:
                DateTime.tryParse(r['created_at'] as String? ?? '') ??
                DateTime.now(),
          );
        }).toList();
      }
      final repo = ref.read(bookRepositoryProvider);
      if (repo == null) return const [];
      return repo.getChoseoByBook(query.bookId);
    });

typedef _Sentence = ({
  String id,
  String content,
  String? thought,
  int? pageNumber,
});

List<_Sentence> _mockDetailSentences(Book book) {
  if (!book.title.contains('채식주의자')) {
    return book.savedSentences.asMap().entries.map((entry) {
      return (
        id: 'mock_${book.id}_${entry.key}',
        content: entry.value,
        thought: null as String?,
        pageNumber: null as int?,
      );
    }).toList();
  }

  return const [
    (
      id: 'vegetarian_9',
      content: '아내가 채식을 시작하기 전까지 나는 그녀가 특별한 사람이라고 생각한 적이 없었다.',
      thought: '영혜가 타인의 시선 안에서 얼마나 평면적으로 존재했는지 보여준다.',
      pageNumber: 9,
    ),
    (
      id: 'vegetarian_12',
      content:
          '크지도 작지도 않은 키, 길지도 짧지도 않은 단발머리, 각질이 일어난 노르스름한 피부, 외꺼풀 눈에 약간 튀어나온 광대뼈, 개성있어 보이는 것을 두려워하는 듯한 무채색의 옷차림.',
      thought: null,
      pageNumber: 12,
    ),
    (
      id: 'vegetarian_52',
      content: '빠르지도, 느리지도, 힘있지도, 가냘프지도 않은 걸음걸이로.',
      thought: null,
      pageNumber: 52,
    ),
    (
      id: 'vegetarian_122',
      content:
          '며칠내내 언제가 통했던 그런 필사적인 노력에 오히려 그녀에게 죄책감을 일으켜, 그녀의 웃음이 결국 흐려져버린다는 것을 지우가 알 리 없다.',
      thought: '끝까지 설명되지 않는 감정의 결을 붙잡게 만드는 문장.',
      pageNumber: 122,
    ),
    (
      id: 'vegetarian_202',
      content: '산다는 것은 이상한 일이라고, 그 웃음의 끝에 그녀는 생각한다.',
      thought: null,
      pageNumber: 202,
    ),
  ];
}

// 책별 세션 통계 (세션 수, 누적 시간, 평균 분)
final _bookSessionStatsProvider =
    FutureProvider.family<
      ({int sessions, double totalHours, int avgMinutes}),
      String
    >((ref, bookId) async {
      if (kUseMock && bookId == '1') {
        return (sessions: 5, totalHours: 2.5, avgMinutes: 30);
      }
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
  final Map<String, String?> _mockThoughts = {};

  _BookSentenceQuery _sentenceQuery(Book book) => (
    bookId: book.id,
    title: book.title,
    author: book.author,
    isbn: book.isbn,
  );

  @override
  void initState() {
    super.initState();
    final books = ref.read(libraryProvider);
    final idx = books.indexWhere((b) => b.id == widget.bookId);
    if (idx >= 0) _currentPage = books[idx].currentPage;
  }

  void _savePage(int page) {
    final books = ref.read(libraryProvider);
    final idx = books.indexWhere((b) => b.id == widget.bookId);
    final totalPages = idx >= 0 ? books[idx].totalPages : 0;
    final clamped = (totalPages > 0 ? page.clamp(0, totalPages) : page).toInt();
    setState(() => _currentPage = clamped);
    ref
        .read(libraryProvider.notifier)
        .updateCurrentPage(widget.bookId, clamped);
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
            child: Text(
              '취소',
              style: AppTheme.supportingText.copyWith(
                color: ctx.appTextTertiary,
              ),
            ),
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
              foregroundColor: AppTheme.primary,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showAddSentenceSheet(Book book, {String initialText = ''}) {
    final query = _sentenceQuery(book);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSentenceSheet(
        bookId: book.id,
        initialText: initialText,
        onSaved: () {
          if (!kUseMock) {
            ref.invalidate(_bookChoseoProvider(query));
          }
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(chorokSnackBar(context, '문장을 저장했어요'));
          }
        },
      ),
    );
  }

  void _showSentenceMethodSheet(Book book) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SentenceMethodSheet(
        onWrite: () {
          Navigator.pop(sheetContext);
          _showAddSentenceSheet(book);
        },
        onCamera: () {
          Navigator.pop(sheetContext);
          _openOcrSentenceSheet(book, ImageSource.camera);
        },
        onGallery: () {
          Navigator.pop(sheetContext);
          _openOcrSentenceSheet(book, ImageSource.gallery);
        },
        onMic: () {
          Navigator.pop(sheetContext);
          _openVoiceSentenceSheet(book);
        },
      ),
    );
  }

  Future<void> _openOcrSentenceSheet(Book book, ImageSource source) async {
    OcrResult result;
    try {
      if (source == ImageSource.camera) {
        result = await ref.read(ocrServiceProvider).extractTextFromCamera();
      } else {
        final picked = await ImagePicker().pickImage(source: source);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        result = await ref.read(ocrServiceProvider).extractTextFromBytes(bytes);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '이미지를 읽지 못했어요'));
      return;
    }

    if (!mounted) return;
    switch (result) {
      case OcrSuccess(text: final text):
        _showAddSentenceSheet(book, initialText: text);
      case OcrNoText():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(chorokSnackBar(context, '텍스트를 인식하지 못했어요'));
      case OcrError(message: final message):
        ScaffoldMessenger.of(context).showSnackBar(
          chorokSnackBar(context, message.isEmpty ? 'OCR 처리에 실패했어요' : message),
        );
      case OcrCancelled():
        break;
    }
  }

  Future<void> _openVoiceSentenceSheet(Book book) async {
    final stt = ref.read(sttServiceProvider);
    final initialized = await stt.initialize();
    if (!mounted) return;
    if (!initialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '마이크를 사용할 수 없습니다'));
      return;
    }

    var recognizedText = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _VoiceCaptureSheet(
        onStart: (onText) => stt.listen(
          listenFor: const Duration(seconds: 30),
          onResult: (text) {
            recognizedText = text;
            onText(text);
          },
        ),
        onStop: () async {
          await stt.stop();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );

    await stt.stop();
    if (!mounted) return;
    final text = recognizedText.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '인식된 문장이 없어요'));
      return;
    }
    _showAddSentenceSheet(book, initialText: text);
  }

  void _showEditThoughtSheet(_Sentence sentence, Book book) {
    final query = _sentenceQuery(book);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditThoughtSheet(
        sentence: sentence,
        onSave: (thought) => _saveSentenceThought(sentence, thought, query),
      ),
    );
  }

  Future<void> _saveSentenceThought(
    _Sentence sentence,
    String? thought,
    _BookSentenceQuery query,
  ) async {
    final trimmed = thought?.trim();
    final normalized = trimmed?.isNotEmpty == true ? trimmed : null;

    if (kUseMock) {
      setState(() => _mockThoughts[sentence.id] = normalized);
      return;
    }

    await ref
        .read(libraryProvider.notifier)
        .updateSentenceThought(sentenceId: sentence.id, thought: normalized);
    ref.invalidate(_bookChoseoProvider(query));
  }

  void _startSession(Book book) {
    HapticFeedback.mediumImpact();
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

    final sentenceQuery = _sentenceQuery(book);
    final choseoAsync = ref.watch(_bookChoseoProvider(sentenceQuery));
    final List<_Sentence> sentences = kUseMock
        ? _mockDetailSentences(book).map((sentence) {
            return (
              id: sentence.id,
              content: sentence.content,
              thought: _mockThoughts[sentence.id] ?? sentence.thought,
              pageNumber: sentence.pageNumber,
            );
          }).toList()
        : (choseoAsync.valueOrNull ?? const [])
              .map(
                (c) => (
                  id: c.choseoId,
                  content: c.content,
                  thought: c.myThought,
                  pageNumber: c.pageNumber,
                ),
              )
              .toList();
    final isLoadingSentences = !kUseMock && choseoAsync.isLoading;
    final hasSentenceError = !kUseMock && choseoAsync.hasError;
    final detailSentenceCount = kUseMock && book.id == '1'
        ? 10
        : sentences.length;
    final heroSentenceCount = kUseMock && book.id == '1'
        ? 15
        : sentences.length;

    return Scaffold(
      backgroundColor: context.appBg,
      bottomNavigationBar: _ContinueReadingBar(
        onContinue: () => _startSession(book),
        onAddSentence: () => _showSentenceMethodSheet(book),
      ),
      body: Column(
        children: [
          _BookDetailTopBar(onBack: () => context.pop()),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                ChorokSliverRefreshControl(
                  onRefresh: () async {
                    final socialQuery = _socialQueryFor(book);
                    ref.invalidate(_bookChoseoProvider(sentenceQuery));
                    ref.invalidate(bookDetailSocialProvider(socialQuery));
                    await Future.wait([
                      ref.read(_bookChoseoProvider(sentenceQuery).future),
                      ref.read(bookDetailSocialProvider(socialQuery).future),
                      ref.read(libraryProvider.notifier).reload(),
                    ]);
                  },
                ),
                // ── 히어로 섹션 ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      final sessions =
                          ref
                              .watch(_bookSessionStatsProvider(widget.bookId))
                              .valueOrNull
                              ?.sessions ??
                          0;
                      return _HeroSection(
                        book: book,
                        sessionCount: sessions,
                        sentenceCount: heroSentenceCount,
                      );
                    },
                  ),
                ),

                // ── 현재 페이지 조절 ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: _CurrentPageControl(
                    key: ValueKey('${book.id}_${book.totalPages}'),
                    currentPage: _currentPage,
                    totalPages: book.totalPages,
                    onPreviewPage: (page) =>
                        setState(() => _currentPage = page),
                    onCommitPage: _savePage,
                    onEditTotalPages: () => _showSetTotalPages(book.totalPages),
                  ),
                ),

                // ── 독서 통계 ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      final stats = ref
                          .watch(_bookSessionStatsProvider(widget.bookId))
                          .valueOrNull;
                      return _StatsRow(
                        sessions: stats?.sessions ?? 0,
                        totalHours: stats?.totalHours ?? 0.0,
                        progress: kUseMock && book.id == '1'
                            ? 0.70
                            : book.readingProgress,
                        sentenceCount: detailSentenceCount,
                      );
                    },
                  ),
                ),

                // ── 내 수집 문장 리스트 ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: '내가 수집한 문장',
                    onTap: sentences.isEmpty
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            context.push(
                              AppConstants.routeBookSentences,
                              extra: book,
                            );
                          },
                  ),
                ),
                if (sentences.isEmpty)
                  SliverToBoxAdapter(
                    child: isLoadingSentences
                        ? const _SentenceLoadingState()
                        : _SentenceEmptyState(
                            onAdd: () => _showSentenceMethodSheet(book),
                            hasError: hasSentenceError,
                          ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _SentenceItem(
                        sentence: sentences[index],
                        onEditThought: () =>
                            _showEditThoughtSheet(sentences[index], book),
                      ),
                      childCount: sentences.length,
                    ),
                  ),

                _DiscussedPassagesSection(book: book),

                _FollowingHighlightsSection(book: book),

                _PopularThoughtsSection(book: book),

                _ThoughtExplorerSection(book: book),

                _ReviewsSummarySection(book: book),

                SliverToBoxAdapter(child: _BookInfoSection(book: book)),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 110,
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

class _ContinueReadingBar extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onAddSentence;

  const _ContinueReadingBar({
    required this.onContinue,
    required this.onAddSentence,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 84 + bottom,
      padding: EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceLG,
        AppTheme.screenPadding,
        AppTheme.spaceMD + bottom,
      ),
      color: context.appBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            button: true,
            label: '이어 읽기',
            child: GestureDetector(
              onTap: onContinue,
              child: SizedBox(
                width: 170,
                height: 32,
                child: ChorokCard(
                  padding: EdgeInsets.zero,
                  backgroundColor: context.appPrimaryAccent,
                  borderColor: context.appPrimaryAccent,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: AppTheme.spaceLG,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        Text(
                          '이어 읽기',
                          style: AppTheme.supportingText.copyWith(
                            color: AppTheme.primary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Semantics(
            button: true,
            label: '문장 추가',
            child: GestureDetector(
              onTap: onAddSentence,
              child: SizedBox(
                width: 32,
                height: 32,
                child: ChorokCard(
                  inner: true,
                  padding: EdgeInsets.zero,
                  backgroundColor: context.appBg,
                  borderColor: context.appPrimaryAccent,
                  child: Icon(
                    Icons.add_rounded,
                    size: AppTheme.sectionTitle.fontSize,
                    color: AppTheme.primaryLight,
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

class _SentenceMethodSheet extends StatelessWidget {
  final VoidCallback onWrite;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onMic;

  const _SentenceMethodSheet({
    required this.onWrite,
    required this.onCamera,
    required this.onGallery,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: ShapeDecoration(
        color: context.appSurface,
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusOuter),
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottom + AppTheme.spaceXL),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppTheme.spaceSM,
          children: [
            const ChorokSheetHeader(title: '문장 기록'),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.screenPadding,
              ),
              child: Column(
                spacing: AppTheme.spaceSM,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SentenceMethodTile(
                          icon: Icons.text_fields_rounded,
                          label: '직접적기',
                          onTap: onWrite,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: _SentenceMethodTile(
                          icon: Icons.camera_alt_outlined,
                          label: '사진찍기',
                          onTap: onCamera,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _SentenceMethodTile(
                          icon: Icons.image_outlined,
                          label: '불러오기',
                          onTap: onGallery,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: _SentenceMethodTile(
                          icon: Icons.graphic_eq_rounded,
                          label: '음성인식',
                          onTap: onMic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentenceMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SentenceMethodTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 88,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppTheme.spaceSM,
              children: [
                Icon(
                  icon,
                  color: context.appPrimaryAccent,
                  size: AppTheme.spaceXL,
                ),
                Text(
                  label,
                  style: AppTheme.supportingText.copyWith(
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceCaptureSheet extends StatefulWidget {
  final Future<void> Function(ValueChanged<String> onText) onStart;
  final Future<void> Function() onStop;

  const _VoiceCaptureSheet({required this.onStart, required this.onStop});

  @override
  State<_VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends State<_VoiceCaptureSheet> {
  String _recognizedText = '';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_started) return;
      _started = true;
      await widget.onStart((text) {
        if (mounted) setState(() => _recognizedText = text);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final displayText = _recognizedText.trim().isEmpty
        ? '말하면 여기에 문장이 나타나요'
        : _recognizedText;

    return Container(
      decoration: ShapeDecoration(
        color: context.appSurface,
        shape: SmoothRectangleBorder(
          smoothness: 0.6,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusOuter),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppTheme.spaceXL,
        AppTheme.spaceLG,
        AppTheme.spaceXL,
        bottom + AppTheme.spaceXL,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ChorokSheetHandle(),
            const SizedBox(height: AppTheme.spaceXL),
            const Icon(
              Icons.graphic_eq_rounded,
              color: AppTheme.primaryLight,
              size: AppTheme.space3XL,
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              displayText,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: _recognizedText.trim().isEmpty
                    ? _detailMuted
                    : _detailText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: widget.onStop,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryLight,
                  foregroundColor: AppTheme.primary,
                  shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
                ),
                child: const Text('중지'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookDetailTopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _BookDetailTopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          AppTheme.spaceLG,
          AppTheme.screenPadding,
          0,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: '뒤로 가기',
            button: true,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              color: _detailAccent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: _detailNavButtonSize,
                height: _detailNavButtonSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 히어로 섹션 ──────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Book book;
  final int sessionCount;
  final int sentenceCount;

  const _HeroSection({
    required this.book,
    required this.sessionCount,
    required this.sentenceCount,
  });

  @override
  Widget build(BuildContext context) {
    final gradientIndex =
        book.title.hashCode.abs() % AppTheme.coverGradients.length;
    final meta = book.title.contains('채식주의자')
        ? '${book.author} | 창비 | 2022'
        : book.author;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceMD,
        AppTheme.screenPadding,
        AppTheme.spaceXL,
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              ChorokCard(
                padding: EdgeInsets.zero,
                showBorder: false,
                hasShadow: true,
                clipBehavior: Clip.antiAlias,
                child: BookCover(
                  coverUrl: book.coverUrl,
                  gradientIndex: gradientIndex,
                  width: 150,
                  height: 230,
                  radius: AppTheme.radiusOuter,
                ),
              ),
              Positioned(
                right: -48,
                top: 0,
                child: Column(
                  spacing: AppTheme.spaceSM,
                  children: [
                    _StatBadge(
                      icon: Icons.circle,
                      value: '$sessionCount',
                      color: context.appPrimaryAccent,
                      sideColor: context.appPrimaryAccent,
                    ),
                    _StatBadge(
                      icon: Icons.circle,
                      value: '$sentenceCount',
                      color: _detailMuted,
                      sideColor: _detailMuted.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.sectionGap),
          Text(
            book.title,
            style: AppTheme.sectionTitle.copyWith(
              color: _detailAccent,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            meta,
            style: AppTheme.rowText.copyWith(
              color: _detailAccent.withValues(alpha: 0.92),
              height: 1.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── 현재 페이지 조절 ─────────────────────────────────────────────────────

class _CurrentPageControl extends StatefulWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPreviewPage;
  final ValueChanged<int> onCommitPage;
  final VoidCallback onEditTotalPages;

  const _CurrentPageControl({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPreviewPage,
    required this.onCommitPage,
    required this.onEditTotalPages,
  });

  @override
  State<_CurrentPageControl> createState() => _CurrentPageControlState();
}

class _CurrentPageControlState extends State<_CurrentPageControl> {
  late int _page;
  late final TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();

  int get _max => widget.totalPages > 0 ? widget.totalPages : 9999;

  @override
  void initState() {
    super.initState();
    _page = widget.currentPage.clamp(0, _max).toInt();
    _ctrl = TextEditingController(text: '$_page');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commitText();
    });
  }

  @override
  void didUpdateWidget(covariant _CurrentPageControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage ||
        widget.totalPages != oldWidget.totalPages) {
      _setPage(
        widget.currentPage,
        previewOnly: true,
        haptic: false,
        notifyPreview: false,
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setPage(
    int value, {
    bool previewOnly = false,
    bool haptic = true,
    bool notifyPreview = true,
  }) {
    final next = value.clamp(0, _max).toInt();
    if (next == _page && _ctrl.text == '$next') return;
    setState(() {
      _page = next;
      _ctrl.text = '$next';
      _ctrl.selection = TextSelection.collapsed(offset: '$next'.length);
    });
    if (notifyPreview) widget.onPreviewPage(next);
    if (!previewOnly) widget.onCommitPage(next);
    if (haptic) HapticFeedback.selectionClick();
  }

  void _commitText() {
    final parsed = int.tryParse(_ctrl.text.trim());
    if (parsed == null) {
      _ctrl.text = '$_page';
      return;
    }
    _setPage(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final sliderMax = widget.totalPages > 0
        ? widget.totalPages.toDouble()
        : 100.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding * 3,
        0,
        AppTheme.screenPadding * 3,
        AppTheme.sectionGap,
      ),
      child: Column(
        children: [
          Text(
            '현재 페이지',
            style: AppTheme.supportingText.copyWith(color: _detailMuted),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageStepButton(
                icon: Icons.remove_rounded,
                onTap: () => _setPage(_page - 1),
              ),
              const SizedBox(width: AppTheme.sectionGap),
              SizedBox(
                width: 112,
                height: 60,
                child: ChorokCard(
                  inner: true,
                  padding: EdgeInsets.zero,
                  backgroundColor: context.appControlBg,
                  borderColor: context.appPrimaryAccent,
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ctrl,
                            focusNode: _focusNode,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            onSubmitted: (_) {
                              _commitText();
                              _focusNode.unfocus();
                            },
                            style: AppTheme.displayMedium.copyWith(
                              color: _detailAccent,
                              height: 1.05,
                            ),
                            cursorColor: _detailAccent,
                            decoration: const InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.fromLTRB(
                                AppTheme.spaceSM,
                                AppTheme.spaceMD,
                                0,
                                AppTheme.spaceMD,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        GestureDetector(
                          onTap: () {
                            _focusNode.requestFocus();
                            _ctrl.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _ctrl.text.length,
                            );
                          },
                          child: const Icon(
                            Icons.edit_rounded,
                            size: 16,
                            color: _detailAccent,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceLG),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.sectionGap),
              _PageStepButton(
                icon: Icons.add_rounded,
                onTap: () => _setPage(_page + 1),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLG),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: _detailAccent,
              inactiveTrackColor: _detailMuted.withValues(alpha: 0.35),
              thumbColor: _detailAccent,
              overlayColor: _detailAccent.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: _page.toDouble().clamp(0, sliderMax).toDouble(),
              min: 0,
              max: sliderMax,
              onChanged: (value) {
                final next = value.round().clamp(0, _max).toInt();
                setState(() {
                  _page = next;
                  _ctrl.text = '$next';
                  _ctrl.selection = TextSelection.collapsed(
                    offset: '$next'.length,
                  );
                });
                widget.onPreviewPage(next);
              },
              onChangeEnd: (value) => widget.onCommitPage(value.round()),
            ),
          ),
          GestureDetector(
            onTap: widget.onEditTotalPages,
            child: Text(
              widget.totalPages > 0 ? '전체 ${widget.totalPages}' : '전체 페이지 입력',
              style: AppTheme.captionSmall.copyWith(color: _detailMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PageStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: const ShapeDecoration(
            color: _detailCard,
            shape: CircleBorder(),
          ),
          child: Icon(icon, size: 17, color: _detailMuted),
        ),
      ),
    );
  }
}

// ─── 독서 통계 ────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int sessions, sentenceCount;
  final double totalHours;
  final double progress;

  const _StatsRow({
    required this.sessions,
    required this.totalHours,
    required this.progress,
    required this.sentenceCount,
  });

  @override
  Widget build(BuildContext context) {
    final progressPct = '${(progress * 100).toInt()}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        0,
        AppTheme.screenPadding,
        AppTheme.sectionGap,
      ),
      child: Row(
        children: [
          _StatCard(label: '세션', value: '$sessions'),
          const SizedBox(width: AppTheme.spaceSM),
          _StatCard(label: '누적 시간', value: '${totalHours.toStringAsFixed(1)}h'),
          const SizedBox(width: AppTheme.spaceSM),
          _StatCard(label: '진행도', value: progressPct),
          const SizedBox(width: AppTheme.spaceSM),
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
      child: SizedBox(
        height: 118,
        child: ChorokCard(
          showBorder: false,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: AppTheme.spaceMD,
            children: [
              Text(
                value,
                style: AppTheme.rowText.copyWith(color: _detailAccent),
              ),
              Text(
                label,
                style: AppTheme.caption.copyWith(color: _detailMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  final Color sideColor;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.color,
    required this.sideColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      backgroundColor: context.appBg,
      borderColor: sideColor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppTheme.spaceSM, color: color),
          const SizedBox(width: AppTheme.spaceXS),
          Text(value, style: AppTheme.supportingText.copyWith(color: color)),
        ],
      ),
    );
  }
}

BookDetailSocialQuery _socialQueryFor(Book book) =>
    (title: book.title, author: book.author, isbn: book.isbn);

class _DiscussedPassagesSection extends ConsumerWidget {
  final Book book;

  const _DiscussedPassagesSection({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailSocialProvider(_socialQueryFor(book)));
    return async.when(
      loading: () => SliverToBoxAdapter(
        child: _SocialSectionShell(
          title: '사람들이 멈춘 문장',
          child: const _SocialSkeletonRow(),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (data) {
        final passages = data.discussedPassages;
        if (passages.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: _SocialSectionShell(
            title: '사람들이 멈춘 문장',
            trailing: '${passages.length}곳',
            child: SizedBox(
              height: 214,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                itemCount: passages.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.spaceMD),
                itemBuilder: (context, index) => _DiscussedPassageCard(
                  passage: passages[index],
                  prominent: index == 0,
                  onTap: () =>
                      _showDiscussedPassageSheet(context, passages[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiscussedPassageCard extends StatelessWidget {
  final BookDiscussedPassage passage;
  final bool prominent;
  final VoidCallback onTap;

  const _DiscussedPassageCard({
    required this.passage,
    required this.prominent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final preview = passage.previewThoughts.isEmpty
        ? null
        : passage.previewThoughts.first;
    return Semantics(
      button: true,
      label: '${passage.readerCount}명이 생각을 남긴 문장 자세히 보기',
      child: GestureDetector(
        key: ValueKey('discussed-passage-card-${passage.id}'),
        onTap: onTap,
        child: SizedBox(
          width: prominent ? 286 : 258,
          child: ChorokCard(
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            backgroundColor: prominent
                ? context.primaryBg(0.08)
                : context.appCard,
            borderColor: prominent
                ? context.appPrimaryAccent.withValues(alpha: 0.45)
                : context.appBorder.withValues(alpha: 0.20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _PassageClusterMark(),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: Text(
                        '${passage.readerCount}명이 이 부분에 생각을 남겼어요',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption.copyWith(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.88,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  '“${passage.representativeText}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body.copyWith(
                    color: context.appTextPrimary.withValues(alpha: 0.92),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                if (preview != null)
                  ChorokCard(
                    inner: true,
                    showBorder: false,
                    backgroundColor: context.appBg.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                      vertical: AppTheme.spaceSM,
                    ),
                    child: Text(
                      preview.thought,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body.copyWith(
                        color: context.appTextPrimary.withValues(alpha: 0.70),
                        height: 1.4,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  children: [
                    if (passage.pageNumber != null)
                      Text(
                        'p. ${passage.pageNumber}',
                        style: AppTheme.caption.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppTheme.spaceMD,
                      color: context.appTextSecondary.withValues(alpha: 0.72),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PassageClusterMark extends StatelessWidget {
  const _PassageClusterMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 9,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 2,
            child: _PassageDot(color: _detailMuted.withValues(alpha: 0.52)),
          ),
          Positioned(
            left: 6,
            top: 0,
            child: _PassageDot(
              color: AppTheme.primaryLight.withValues(alpha: 0.48),
            ),
          ),
          Positioned(
            left: 12,
            top: 2,
            child: _PassageDot(color: _detailAccent.withValues(alpha: 0.88)),
          ),
        ],
      ),
    );
  }
}

class _PassageDot extends StatelessWidget {
  final Color color;

  const _PassageDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

void _showDiscussedPassageSheet(
  BuildContext context,
  BookDiscussedPassage passage,
) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DiscussedPassageSheet(passage: passage),
  );
}

class _DiscussedPassageSheet extends StatelessWidget {
  final BookDiscussedPassage passage;

  const _DiscussedPassageSheet({required this.passage});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Container(
        decoration: ShapeDecoration(
          color: context.appSurface,
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusOuter),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ChorokSheetHeader(title: '이 대목에 남겨진 생각'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ChorokCard(
                        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                        backgroundColor: context.primaryBg(0.08),
                        borderColor: context.appPrimaryAccent.withValues(
                          alpha: 0.30,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '“${passage.representativeText}”',
                                style: AppTheme.body.copyWith(
                                  color: context.appTextPrimary.withValues(
                                    alpha: 0.90,
                                  ),
                                  height: 1.65,
                                ),
                              ),
                            ),
                            if (passage.pageNumber != null) ...[
                              const SizedBox(width: AppTheme.spaceMD),
                              Text(
                                'p. ${passage.pageNumber}',
                                style: AppTheme.caption.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    Text(
                      '${passage.readerCount}명의 독자가 이 부분에 머물렀어요',
                      style: AppTheme.caption.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.screenPadding,
                    0,
                    AppTheme.screenPadding,
                    bottom + AppTheme.spaceXL,
                  ),
                  itemCount: passage.members.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spaceMD),
                  itemBuilder: (context, index) =>
                      _PassageThoughtCard(thought: passage.members[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassageThoughtCard extends StatelessWidget {
  final BookSocialThought thought;

  const _PassageThoughtCard({required this.thought});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      borderColor: context.appBorderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceMD,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thought.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                    if (thought.username?.trim().isNotEmpty == true &&
                        thought.username != thought.displayName)
                      Text(
                        '@${thought.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (thought.pageNumber != null)
                Text(
                  'p. ${thought.pageNumber}',
                  style: AppTheme.captionSmall.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
            ],
          ),
          Text(
            thought.sentence,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextSecondary,
              height: 1.55,
            ),
          ),
          Text(
            thought.thought,
            style: AppTheme.bodyMedium.copyWith(
              color: context.appTextPrimary.withValues(alpha: 0.88),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularThoughtsSection extends ConsumerWidget {
  final Book book;

  const _PopularThoughtsSection({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailSocialProvider(_socialQueryFor(book)));
    return async.when(
      loading: () => SliverToBoxAdapter(
        child: _SocialSectionShell(
          title: '지금 많이 멈춘 생각',
          child: const _SocialSkeletonRow(),
        ),
      ),
      error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (data) {
        final thoughts = data.popularThoughts;
        if (thoughts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: _SocialSectionShell(
            title: '지금 많이 멈춘 생각',
            trailing: data.meta.readerCount > 0
                ? '${data.meta.readerCount}명'
                : null,
            child: SizedBox(
              height: 218,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                itemCount: thoughts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.spaceMD),
                itemBuilder: (context, index) {
                  return _BookThoughtCard(
                    book: book,
                    thought: thoughts[index],
                    prominent: index == 0,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BookInfoSection extends StatefulWidget {
  final Book book;

  const _BookInfoSection({required this.book});

  @override
  State<_BookInfoSection> createState() => _BookInfoSectionState();
}

class _BookInfoSectionState extends State<_BookInfoSection> {
  bool _authorExpanded = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final description = _bookDescription(book);
    final authorIntro = _authorIntro(book.author);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceXS,
        AppTheme.screenPadding,
        AppTheme.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: '책 소개'),
          ChorokCard(
            showBorder: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: AppTheme.bodyMedium.copyWith(
                    color: _detailText.withValues(alpha: 0.78),
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                Wrap(
                  spacing: AppTheme.spaceSM,
                  runSpacing: AppTheme.spaceSM,
                  children: [
                    _BookInfoChip(label: book.author),
                    if (book.genre != null) _BookInfoChip(label: book.genre!),
                    if (book.totalPages > 0)
                      _BookInfoChip(label: '${book.totalPages}쪽'),
                    if (book.isbn?.isNotEmpty == true)
                      const _BookInfoChip(label: 'ISBN'),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLG),
                Text(
                  '작가',
                  style: AppTheme.captionSmall.copyWith(color: _detailAccent),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  authorIntro,
                  maxLines: _authorExpanded ? null : 2,
                  overflow: _authorExpanded ? null : TextOverflow.ellipsis,
                  style: AppTheme.captionLarge.copyWith(
                    color: _detailText.withValues(alpha: 0.68),
                    height: 1.55,
                  ),
                ),
                if (authorIntro.length > 70)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _authorExpanded = !_authorExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppTheme.spaceSM),
                      child: Text(
                        _authorExpanded ? '접기' : '작가 더보기',
                        style: AppTheme.captionSmall.copyWith(
                          color: _detailAccent,
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

  String _bookDescription(Book book) {
    final description = book.description?.trim();
    if (description != null && description.isNotEmpty) return description;

    if (book.title.contains('채식주의자')) {
      return '일상의 질서 안에서 설명되지 않는 감각이 어떻게 한 사람의 삶을 바꾸는지 따라가는 소설. 초록에서는 이 책을 문장에 멈추는 경험과 다른 독자의 해석을 함께 보는 방식으로 읽는다.';
    }
    return '이 책의 소개와 독자들이 멈춘 문장을 함께 볼 수 있어요. 책 자체의 정보와 문장에 남긴 생각을 한 흐름에서 확인합니다.';
  }

  String _authorIntro(String author) {
    if (author.contains('한강')) {
      return '한강은 인간의 고통, 침묵, 회복의 가능성을 섬세한 문장으로 탐구해 온 작가입니다. 독자들은 작품의 사건보다 문장 안에 남은 감각에 오래 머무는 경우가 많습니다.';
    }
    return '$author 작가의 책을 읽은 독자들이 어떤 문장에 멈췄는지 함께 확인해보세요.';
  }
}

class _FollowingHighlightsSection extends ConsumerWidget {
  final Book book;

  const _FollowingHighlightsSection({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailSocialProvider(_socialQueryFor(book)));
    return async.maybeWhen(
      data: (data) {
        final thoughts = data.followingThoughts;
        if (thoughts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: _SocialSectionShell(
            title: '이웃의 문장',
            trailing: '${thoughts.length}명',
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.screenPadding,
                ),
                itemCount: thoughts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppTheme.spaceMD),
                itemBuilder: (context, index) =>
                    _BookThoughtCard(book: book, thought: thoughts[index]),
              ),
            ),
          ),
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

enum _ThoughtSortMode { popular, recent, following }

class _ThoughtExplorerSection extends ConsumerStatefulWidget {
  final Book book;

  const _ThoughtExplorerSection({required this.book});

  @override
  ConsumerState<_ThoughtExplorerSection> createState() =>
      _ThoughtExplorerSectionState();
}

class _ThoughtExplorerSectionState
    extends ConsumerState<_ThoughtExplorerSection> {
  _ThoughtSortMode _mode = _ThoughtSortMode.popular;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      bookDetailSocialProvider(_socialQueryFor(widget.book)),
    );
    return async.maybeWhen(
      data: (data) {
        final thoughts = switch (_mode) {
          _ThoughtSortMode.popular => data.popularThoughts,
          _ThoughtSortMode.recent => data.recentSentenceThoughts,
          _ThoughtSortMode.following => data.followingThoughts,
        };
        if (data.recentSentenceThoughts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spaceLG,
              AppTheme.screenPadding,
              AppTheme.spaceSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: '문장과 생각'),
                _ThoughtSegmentedControl(
                  value: _mode,
                  onChanged: (value) => setState(() => _mode = value),
                ),
                const SizedBox(height: AppTheme.spaceMD),
                if (thoughts.isEmpty)
                  _SocialEmptyState(
                    text: _mode == _ThoughtSortMode.following
                        ? '팔로잉한 독자의 문장이 아직 없어요'
                        : '아직 공개된 생각이 없어요',
                  )
                else
                  ...thoughts
                      .take(8)
                      .map(
                        (thought) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.spaceMD,
                          ),
                          child: _BookThoughtListCard(
                            book: widget.book,
                            thought: thought,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _ReviewsSummarySection extends ConsumerWidget {
  final Book book;

  const _ReviewsSummarySection({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailSocialProvider(_socialQueryFor(book)));
    return async.maybeWhen(
      data: (data) {
        if (data.reviews.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.spaceMD,
              AppTheme.screenPadding,
              AppTheme.spaceXL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeader(title: '이 책에 남긴 말'),
                ...data.reviews
                    .take(3)
                    .map(
                      (review) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spaceMD,
                        ),
                        child: _ReviewSummaryCard(review: review),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }
}

class _SocialSectionShell extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;

  const _SocialSectionShell({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        AppTheme.spaceMD,
        0,
        AppTheme.spaceLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceMD,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            child: ChorokSectionHeader(
              title: title,
              trailing: trailing == null
                  ? null
                  : Text(
                      trailing!,
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SocialSkeletonRow extends StatelessWidget {
  const _SocialSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.spaceMD),
        itemBuilder: (_, _) => SizedBox(
          width: 260,
          child: ChorokCard(
            showBorder: false,
            padding: EdgeInsets.zero,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _BookThoughtCard extends ConsumerStatefulWidget {
  final Book book;
  final BookSocialThought thought;
  final bool prominent;

  const _BookThoughtCard({
    required this.book,
    required this.thought,
    this.prominent = false,
  });

  @override
  ConsumerState<_BookThoughtCard> createState() => _BookThoughtCardState();
}

class _BookThoughtCardState extends ConsumerState<_BookThoughtCard> {
  bool? _followingOverride;
  bool _isMutating = false;

  bool get _isFollowing => _followingOverride ?? widget.thought.isFollowing;

  Future<void> _toggleFollow() async {
    final userId = widget.thought.userId;
    if (userId == null || userId.isEmpty || _isMutating) return;
    HapticFeedback.selectionClick();
    final next = !_isFollowing;
    setState(() {
      _followingOverride = next;
      _isMutating = true;
    });
    try {
      final repo = ref.read(followRepositoryProvider);
      if (next) {
        await repo.follow(userId);
      } else {
        await repo.unfollow(userId);
      }
    } catch (_) {
      if (mounted) _followingOverride = !next;
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  void _openProfile() {
    final userId = widget.thought.userId;
    if (userId == null || userId.isEmpty) return;
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeUserProfile,
      extra: UserProfile(
        id: userId,
        username: widget.thought.username ?? widget.thought.displayName,
        displayName: widget.thought.displayName,
        avatarUrl: widget.thought.avatarUrl,
      ),
    );
  }

  void _openSentence() {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: widget.thought.sentence,
        bookTitle: widget.book.title,
        bookAuthor: widget.book.author,
        page: widget.thought.pageNumber,
        collectorUsername: widget.thought.displayName,
        collectorUserHandle: widget.thought.username,
        collectorThought: widget.thought.thought,
        sentenceId: widget.thought.sentenceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thought = widget.thought;
    return SizedBox(
      width: widget.prominent ? 286 : 258,
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        backgroundColor: widget.prominent
            ? context.primaryBg(0.10)
            : context.appCard,
        borderColor: widget.prominent
            ? context.appPrimaryAccent.withValues(alpha: 0.70)
            : context.appBorder.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _openProfile,
                  child: _ThoughtAvatar(thought: thought),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: GestureDetector(
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          thought.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.captionLarge.copyWith(
                            color: _detailText,
                            height: 1.2,
                          ),
                        ),
                        if (thought.username != null &&
                            thought.username!.isNotEmpty &&
                            thought.username != thought.displayName)
                          Text(
                            '@${thought.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.captionSmall.copyWith(
                              color: _detailMuted,
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSM),
                _FollowMiniButton(
                  isFollowing: _isFollowing,
                  isBusy: _isMutating,
                  onTap: _toggleFollow,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Expanded(
              child: GestureDetector(
                onTap: _openSentence,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppTheme.spaceMD,
                  children: [
                    Text(
                      thought.thought,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.captionLarge.copyWith(
                        color: _detailText.withValues(alpha: 0.88),
                        height: 1.55,
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ChorokCard(
                        inner: true,
                        showBorder: false,
                        backgroundColor: context.appBg.withValues(alpha: 0.22),
                        padding: const EdgeInsets.all(AppTheme.spaceSM),
                        child: Text(
                          '“${thought.sentence}”',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption.copyWith(
                            color: context.appTextSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _ThoughtMetaRow(thought: thought),
          ],
        ),
      ),
    );
  }
}

class _BookThoughtListCard extends StatelessWidget {
  final Book book;
  final BookSocialThought thought;

  const _BookThoughtListCard({required this.book, required this.thought});

  void _openSentence(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: thought.sentence,
        bookTitle: book.title,
        bookAuthor: book.author,
        page: thought.pageNumber,
        collectorUsername: thought.displayName,
        collectorUserHandle: thought.username,
        collectorThought: thought.thought,
        sentenceId: thought.sentenceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSentence(context),
      child: ChorokCard(
        padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
        borderColor: thought.isFollowing
            ? context.appPrimaryAccent.withValues(alpha: 0.42)
            : context.appBorder.withValues(alpha: 0.20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ThoughtAvatar(thought: thought),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        thought.displayName,
                        style: AppTheme.captionLarge.copyWith(
                          color: _detailText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (thought.username != null &&
                          thought.username!.isNotEmpty &&
                          thought.username != thought.displayName)
                        Text(
                          '@${thought.username}',
                          style: AppTheme.captionSmall.copyWith(
                            color: _detailMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (thought.isFollowing) const _FollowingPill(),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              thought.thought,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionLarge.copyWith(
                color: _detailText.withValues(alpha: 0.82),
                height: 1.55,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              '“${thought.sentence}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionSmall.copyWith(
                color: _detailMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _ThoughtMetaRow(thought: thought),
          ],
        ),
      ),
    );
  }
}

class _ThoughtAvatar extends StatelessWidget {
  final BookSocialThought thought;

  const _ThoughtAvatar({required this.thought});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: ChorokCard(
        inner: true,
        showBorder: false,
        padding: EdgeInsets.zero,
        backgroundColor: thought.isFollowing
            ? context.primaryBg(0.18)
            : context.appTextPrimary.withValues(alpha: 0.06),
        child: Center(
          child: Text(
            thought.displayName.characters.first,
            style: AppTheme.supportingText.copyWith(
              color: thought.isFollowing
                  ? context.appPrimaryAccent
                  : context.appTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowMiniButton extends StatelessWidget {
  final bool isFollowing;
  final bool isBusy;
  final VoidCallback onTap;

  const _FollowMiniButton({
    required this.isFollowing,
    required this.isBusy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: SizedBox(
        height: 28,
        child: ChorokCard(
          inner: true,
          showBorder: isFollowing,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
          backgroundColor: isFollowing
              ? context.primaryBg(0.14)
              : context.appPrimaryAccent,
          borderColor: context.appPrimaryAccent.withValues(alpha: 0.48),
          child: Center(
            child: Text(
              isFollowing ? '팔로잉' : '팔로우',
              style: AppTheme.caption.copyWith(
                color: isFollowing
                    ? context.appPrimaryAccent
                    : AppTheme.primary,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowingPill extends StatelessWidget {
  const _FollowingPill();

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      showBorder: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      backgroundColor: context.primaryBg(0.14),
      child: Text(
        '팔로잉',
        style: AppTheme.caption.copyWith(
          color: context.appPrimaryAccent,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ThoughtMetaRow extends StatelessWidget {
  final BookSocialThought thought;

  const _ThoughtMetaRow({required this.thought});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.favorite_rounded,
          size: 13,
          color: _detailAccent.withValues(alpha: 0.86),
        ),
        const SizedBox(width: AppTheme.spaceXS),
        Text(
          '${thought.likeCount}',
          style: AppTheme.captionSmall.copyWith(color: _detailMuted),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Icon(
          Icons.chat_bubble_rounded,
          size: 12,
          color: _detailMuted.withValues(alpha: 0.72),
        ),
        const SizedBox(width: AppTheme.spaceXS),
        Text(
          '${thought.commentCount}',
          style: AppTheme.captionSmall.copyWith(color: _detailMuted),
        ),
        const Spacer(),
        Text(
          _relativeDate(thought.createdAt),
          style: AppTheme.captionSmall.copyWith(color: _detailMuted),
        ),
      ],
    );
  }
}

class _BookInfoChip extends StatelessWidget {
  final String label;

  const _BookInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      backgroundColor: context.appTextPrimary.withValues(alpha: 0.05),
      borderColor: context.appTextSecondary.withValues(alpha: 0.18),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: context.appTextSecondary,
          height: 1.1,
        ),
      ),
    );
  }
}

class _ThoughtSegmentedControl extends StatelessWidget {
  final _ThoughtSortMode value;
  final ValueChanged<_ThoughtSortMode> onChanged;

  const _ThoughtSegmentedControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ChorokCard(
        inner: true,
        showBorder: false,
        padding: const EdgeInsets.all(AppTheme.spaceXS),
        child: Row(
          children: [
            _SegmentButton(
              label: '인기',
              selected: value == _ThoughtSortMode.popular,
              onTap: () => onChanged(_ThoughtSortMode.popular),
            ),
            _SegmentButton(
              label: '최신',
              selected: value == _ThoughtSortMode.recent,
              onTap: () => onChanged(_ThoughtSortMode.recent),
            ),
            _SegmentButton(
              label: '팔로잉',
              selected: value == _ThoughtSortMode.following,
              onTap: () => onChanged(_ThoughtSortMode.following),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: selected
            ? ChorokCard(
                inner: true,
                showBorder: false,
                padding: EdgeInsets.zero,
                backgroundColor: context.primaryBg(0.18),
                child: Center(
                  child: Text(
                    label,
                    style: AppTheme.caption.copyWith(
                      color: context.appPrimaryAccent,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  label,
                  style: AppTheme.caption.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ),
      ),
    );
  }
}

class _SocialEmptyState extends StatelessWidget {
  final String text;

  const _SocialEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ChorokCard(
        showBorder: false,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXL),
        child: Center(
          child: Text(
            text,
            style: AppTheme.supportingText.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewSummaryCard extends StatelessWidget {
  final BookReviewSummary review;

  const _ReviewSummaryCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      showBorder: false,
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.displayName,
                      style: AppTheme.captionLarge.copyWith(color: _detailText),
                    ),
                    if (review.username != null &&
                        review.username!.isNotEmpty &&
                        review.username != review.displayName)
                      Text(
                        '@${review.username}',
                        style: AppTheme.captionSmall.copyWith(
                          color: _detailMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (review.isFollowing) const _FollowingPill(),
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                '★ ${review.starRating}',
                style: AppTheme.captionSmall.copyWith(color: _detailAccent),
              ),
            ],
          ),
          if (review.memorableLine?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              '“${review.memorableLine!.trim()}”',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionLarge.copyWith(
                color: _detailText.withValues(alpha: 0.80),
                height: 1.5,
              ),
            ),
          ],
          if (review.legacy?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              review.legacy!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.captionSmall.copyWith(
                color: _detailMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _relativeDate(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inDays >= 365) return '${diff.inDays ~/ 365}년 전';
  if (diff.inDays >= 30) return '${diff.inDays ~/ 30}달 전';
  if (diff.inDays >= 1) return '${diff.inDays}일 전';
  if (diff.inHours >= 1) return '${diff.inHours}시간 전';
  return '방금';
}

// ─── 공통 서브 위젯 ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.spaceSM,
        AppTheme.screenPadding,
        AppTheme.spaceLG,
      ),
      child: ChorokSectionHeader(
        title: title,
        trailing: onTap == null
            ? null
            : Semantics(
                button: true,
                label: '$title 전체보기',
                child: GestureDetector(
                  onTap: onTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '전체보기',
                        style: AppTheme.supportingText.copyWith(
                          color: context.appPrimaryAccent,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceXS),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: AppTheme.spaceLG,
                        color: context.appPrimaryAccent,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _SentenceEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  final bool hasError;

  const _SentenceEmptyState({required this.onAdd, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spaceSM,
      ),
      child: GestureDetector(
        onTap: onAdd,
        child: ChorokCard(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXL),
          borderColor: hasError
              ? AppTheme.warningColor
              : context.appTextSecondary,
          child: Column(
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: AppTheme.spaceXL,
                color: context.appPrimaryAccent.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                hasError ? '문장을 불러오지 못했어요' : '마음에 남는 문장을 기록해보세요',
                style: AppTheme.supportingText.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              ChorokCard(
                inner: true,
                showBorder: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                  vertical: AppTheme.spaceSM,
                ),
                backgroundColor: context.primaryBg(0.12),
                child: Text(
                  '첫 문장 추가하기',
                  style: AppTheme.supportingText.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SentenceItem extends StatelessWidget {
  final _Sentence sentence;
  final VoidCallback onEditThought;

  const _SentenceItem({required this.sentence, required this.onEditThought});

  @override
  Widget build(BuildContext context) {
    final hasThought = sentence.thought != null && sentence.thought!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spaceXS,
      ),
      child: Semantics(
        button: true,
        label: hasThought ? '생각이 기록된 문장' : '문장에 생각 추가',
        child: GestureDetector(
          onTap: onEditThought,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 70),
            child: ChorokCard(
              showBorder: hasThought,
              borderColor: context.appPrimaryAccent,
              padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: ChorokListRow(
                  leading: SizedBox(
                    width: 40,
                    child: Text(
                      sentence.pageNumber != null
                          ? '${sentence.pageNumber}p'
                          : '',
                      style: AppTheme.caption.copyWith(
                        color: context.appTextSecondary,
                        height: 1.55,
                      ),
                    ),
                  ),
                  title: Text(
                    sentence.content,
                    style: AppTheme.body.copyWith(
                      height: 1.55,
                      color: context.appTextPrimary.withValues(alpha: 0.72),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentenceLoadingState extends StatelessWidget {
  const _SentenceLoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
        vertical: AppTheme.spaceMD,
      ),
      child: SizedBox(
        height: 96,
        child: ChorokCard(
          borderColor: context.appTextSecondary,
          child: const Center(
            child: SizedBox(
              width: AppTheme.spaceLG,
              height: AppTheme.spaceLG,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _detailAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditThoughtSheet extends ConsumerStatefulWidget {
  final _Sentence sentence;
  final Future<void> Function(String? thought) onSave;

  const _EditThoughtSheet({required this.sentence, required this.onSave});

  @override
  ConsumerState<_EditThoughtSheet> createState() => _EditThoughtSheetState();
}

class _EditThoughtSheetState extends ConsumerState<_EditThoughtSheet> {
  late final TextEditingController _thoughtCtrl;
  final _focusNode = FocusNode();
  bool _isSaving = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _thoughtCtrl = TextEditingController(text: widget.sentence.thought ?? '');
    Future.delayed(const Duration(milliseconds: 100), _focusNode.requestFocus);
  }

  @override
  void dispose() {
    _thoughtCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _hasError = false;
    });
    HapticFeedback.mediumImpact();

    try {
      await widget.onSave(_thoughtCtrl.text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasError = true;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final bottomPadding = keyboardInset > 0
        ? AppTheme.spaceXL
        : media.padding.bottom + AppTheme.spaceXL;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: ShapeDecoration(
          color: context.appSurface,
          shape: SmoothRectangleBorder(
            smoothness: 0.6,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusOuter),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AppTheme.spaceXL,
              AppTheme.spaceLG,
              AppTheme.spaceXL,
              bottomPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ChorokSheetHandle(),
                const SizedBox(height: AppTheme.spaceLG),
                Row(
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: AppTheme.spaceLG,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '내 생각 수정',
                      style: AppTheme.sectionTitle.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLG),
                SizedBox(
                  width: double.infinity,
                  child: ChorokCard(
                    inner: true,
                    showBorder: false,
                    padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                    child: Text(
                      widget.sentence.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextSecondary,
                        height: 1.65,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
                _SheetTextField(
                  controller: _thoughtCtrl,
                  focusNode: _focusNode,
                  hintText: '이 문장에서 무엇을 느꼈나요?',
                  minLines: 6,
                  maxLines: 8,
                ),
                if (_hasError) ...[
                  const SizedBox(height: AppTheme.spaceSM),
                  Text(
                    '저장에 실패했어요. 다시 시도해보세요.',
                    style: AppTheme.supportingText.copyWith(
                      color: AppTheme.warningColor,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLG),
                _SheetActionButton(
                  label: '저장하기',
                  enabled: !_isSaving,
                  loading: _isSaving,
                  onTap: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 문장 추가 바텀시트 ───────────────────────────────────────────────────────

class _AddSentenceSheet extends ConsumerStatefulWidget {
  final String bookId;
  final String initialText;
  final VoidCallback onSaved;

  const _AddSentenceSheet({
    required this.bookId,
    this.initialText = '',
    required this.onSaved,
  });

  @override
  ConsumerState<_AddSentenceSheet> createState() => _AddSentenceSheetState();
}

class _AddSentenceSheetState extends ConsumerState<_AddSentenceSheet> {
  final _contentCtrl = TextEditingController();
  final _thoughtCtrl = TextEditingController();
  final _pageCtrl = TextEditingController();
  final _contentFocus = FocusNode();
  final _thoughtFocus = FocusNode();
  bool _isWritingThought = false;
  bool _isSaving = false;
  bool _hasError = false;

  bool get _hasInput => _contentCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _contentCtrl.text = widget.initialText;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _contentFocus.requestFocus();
      if (_contentCtrl.text.isNotEmpty) {
        _contentCtrl.selection = TextSelection.collapsed(
          offset: _contentCtrl.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _thoughtCtrl.dispose();
    _pageCtrl.dispose();
    _contentFocus.dispose();
    _thoughtFocus.dispose();
    super.dispose();
  }

  void _openThoughtStep() {
    if (!_hasInput) return;
    setState(() => _isWritingThought = true);
    _contentFocus.unfocus();
    Future.delayed(
      const Duration(milliseconds: 80),
      _thoughtFocus.requestFocus,
    );
  }

  Future<void> _save() async {
    if (!_hasInput) return;
    setState(() {
      _isSaving = true;
      _hasError = false;
    });
    HapticFeedback.mediumImpact();

    final thought = _thoughtCtrl.text.trim();
    final pageNumber = int.tryParse(_pageCtrl.text.trim());
    try {
      await ref
          .read(libraryProvider.notifier)
          .addSentence(
            widget.bookId,
            _contentCtrl.text,
            thought: thought.isNotEmpty ? thought : null,
            pageNumber: pageNumber,
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
            child: Text(
              '계속 작성',
              style: AppTheme.supportingText.copyWith(
                color: ctx.appTextTertiary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '나가기',
              style: AppTheme.supportingText.copyWith(
                color: AppTheme.warningColor,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight =
        media.size.height - keyboardInset - media.padding.top - 12;
    final maxSheetHeight = availableHeight
        .clamp(320.0, media.size.height * 0.92)
        .toDouble();
    final bottomPadding = keyboardInset > 0
        ? AppTheme.spaceXL
        : media.padding.bottom + AppTheme.spaceXL;

    return PopScope(
      canPop: !_hasInput,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _onPop();
        if (shouldPop && mounted) nav.pop();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          decoration: ShapeDecoration(
            color: context.appSurface,
            shape: SmoothRectangleBorder(
              smoothness: 0.6,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusOuter),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppTheme.spaceXL,
                AppTheme.spaceLG,
                AppTheme.spaceXL,
                bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ChorokSheetHandle(),
                  const SizedBox(height: AppTheme.spaceLG),

                  // 헤더
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: ChorokCard(
                          inner: true,
                          showBorder: false,
                          padding: EdgeInsets.zero,
                          backgroundColor: context.primaryBg(0.12),
                          child: Icon(
                            Icons.format_quote_rounded,
                            color: context.appPrimaryAccent,
                            size: AppTheme.spaceLG,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Text(
                        '문장 추가',
                        style: AppTheme.sectionTitle.copyWith(
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMD),
                  _SentenceStepHeader(isWritingThought: _isWritingThought),
                  const SizedBox(height: AppTheme.spaceLG),

                  if (_isWritingThought)
                    _BookThoughtStep(
                      sentence: _contentCtrl.text.trim(),
                      thoughtCtrl: _thoughtCtrl,
                      thoughtFocus: _thoughtFocus,
                      hasError: _hasError,
                      isSaving: _isSaving,
                      canSave: _hasInput && !_isSaving,
                      onBack: () => setState(() => _isWritingThought = false),
                      onSave: _save,
                    )
                  else
                    _BookSentenceStep(
                      contentCtrl: _contentCtrl,
                      pageCtrl: _pageCtrl,
                      contentFocus: _contentFocus,
                      hasInput: _hasInput,
                      isSaving: _isSaving,
                      onChanged: (_) => setState(() {}),
                      onContinue: _openThoughtStep,
                      onSave: _save,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentenceStepHeader extends StatelessWidget {
  final bool isWritingThought;

  const _SentenceStepHeader({required this.isWritingThought});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SentenceStepBadge(number: '1', label: '문장', active: !isWritingThought),
        Expanded(
          child: Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
            color: context.appDivider,
          ),
        ),
        _SentenceStepBadge(number: '2', label: '생각', active: isWritingThought),
      ],
    );
  }
}

class _SentenceStepBadge extends StatelessWidget {
  final String number;
  final String label;
  final bool active;

  const _SentenceStepBadge({
    required this.number,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? context.appPrimaryAccent : context.appTextTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            padding: EdgeInsets.zero,
            backgroundColor: active
                ? context.appPrimaryAccent
                : context.appCard,
            child: Center(
              child: Text(
                number,
                style: AppTheme.supportingText.copyWith(
                  color: active ? AppTheme.primary : context.appTextTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        Text(label, style: AppTheme.supportingText.copyWith(color: color)),
      ],
    );
  }
}

class _BookSentenceStep extends StatelessWidget {
  final TextEditingController contentCtrl;
  final TextEditingController pageCtrl;
  final FocusNode contentFocus;
  final bool hasInput;
  final bool isSaving;
  final ValueChanged<String> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onSave;

  const _BookSentenceStep({
    required this.contentCtrl,
    required this.pageCtrl,
    required this.contentFocus,
    required this.hasInput,
    required this.isSaving,
    required this.onChanged,
    required this.onContinue,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AccentTextField(
          controller: contentCtrl,
          focusNode: contentFocus,
          hintText: '기록하고 싶은 문장을 입력하세요',
          minLines: 7,
          maxLines: 9,
          accentColor: context.appPrimaryAccent,
          onChanged: onChanged,
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Row(
          children: [
            SizedBox(
              width: 88,
              height: 36,
              child: ChorokCard(
                inner: true,
                showBorder: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                ),
                child: Row(
                  children: [
                    Text(
                      'p.',
                      style: AppTheme.supportingText.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceXS),
                    Expanded(
                      child: TextField(
                        controller: pageCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        style: AppTheme.supportingText.copyWith(
                          color: context.appTextPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '페이지',
                          hintStyle: AppTheme.supportingText.copyWith(
                            color: context.appTextTertiary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        cursorColor: context.appPrimaryAccent,
                        cursorWidth: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${contentCtrl.text.length}자',
              style: AppTheme.supportingText.copyWith(
                color: context.appTextTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceLG),
        _SheetActionButton(
          label: '생각 쓰기',
          enabled: hasInput && !isSaving,
          loading: false,
          onTap: onContinue,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: TextButton(
            onPressed: (hasInput && !isSaving) ? onSave : null,
            child: Text(
              '문장만 저장',
              style: AppTheme.rowText.copyWith(
                color: hasInput ? context.appTextTertiary : context.appBorder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BookThoughtStep extends StatelessWidget {
  final String sentence;
  final TextEditingController thoughtCtrl;
  final FocusNode thoughtFocus;
  final bool hasError;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onSave;

  const _BookThoughtStep({
    required this.sentence,
    required this.thoughtCtrl,
    required this.thoughtFocus,
    required this.hasError,
    required this.isSaving,
    required this.canSave,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ChorokCard(
            inner: true,
            showBorder: false,
            padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
            child: Text(
              sentence,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.supportingText.copyWith(
                color: context.appTextSecondary,
                height: 1.65,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.edit_rounded, size: 15),
            label: const Text('문장 수정'),
            style: TextButton.styleFrom(
              foregroundColor: context.appTextTertiary,
              textStyle: AppTheme.supportingText,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Row(
          children: [
            Icon(
              Icons.edit_note_rounded,
              size: AppTheme.spaceMD,
              color: context.appTextTertiary,
            ),
            const SizedBox(width: AppTheme.spaceXS),
            Text(
              '내 생각',
              style: AppTheme.supportingText.copyWith(
                color: context.appTextTertiary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceXS),
            ChorokCard(
              inner: true,
              showBorder: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceXS,
                vertical: AppTheme.spaceXS,
              ),
              backgroundColor: context.appTextTertiary.withValues(alpha: 0.15),
              child: Text(
                '선택',
                style: AppTheme.caption.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _SheetTextField(
          controller: thoughtCtrl,
          focusNode: thoughtFocus,
          hintText: '이 문장에서 무엇을 느꼈나요?',
          minLines: 6,
          maxLines: 8,
        ),
        if (hasError) ...[
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            '저장에 실패했어요. 다시 시도해보세요.',
            style: AppTheme.supportingText.copyWith(
              color: AppTheme.warningColor,
            ),
          ),
        ],
        const SizedBox(height: AppTheme.spaceLG),
        _SheetActionButton(
          label: '저장하기',
          enabled: canSave,
          loading: isSaving,
          onTap: onSave,
        ),
      ],
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _SheetActionButton({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          gradient: enabled ? AppTheme.greenGradient : null,
          color: enabled
              ? null
              : context.appPrimaryAccent.withValues(alpha: 0.2),
          shape: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: AppTheme.smoothShape(radius: AppTheme.radiusOuter),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: AppTheme.spaceLG,
                      height: AppTheme.spaceLG,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : Text(
                      label,
                      style: AppTheme.rowText.copyWith(
                        color: enabled
                            ? AppTheme.primary
                            : context.appTextTertiary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int minLines;
  final int maxLines;
  final Color accentColor;
  final ValueChanged<String>? onChanged;

  const _AccentTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
    required this.accentColor,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      showBorder: false,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
              color: accentColor,
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: minLines,
                maxLines: maxLines,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onChanged: onChanged,
                style: AppTheme.rowText.copyWith(
                  color: context.appTextPrimary,
                  height: 1.7,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: AppTheme.rowText.copyWith(
                    color: context.appTextTertiary,
                    height: 1.7,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceLG,
                  ),
                ),
                cursorColor: accentColor,
                cursorWidth: 1.5,
              ),
            ),
            const SizedBox(width: AppTheme.spaceLG),
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
  final int minLines;
  final int maxLines;

  const _SheetTextField({
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.minLines,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      showBorder: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceMD,
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: minLines,
        maxLines: maxLines,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: AppTheme.rowText.copyWith(
          color: context.appTextPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTheme.rowText.copyWith(
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
