import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/db_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/models/reading_session.dart';
import '../../../core/services/stt_service.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/reading_presence_repository.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../forest/controller/live_forest_provider.dart';
import '../../forest/widget/live_forest_widget.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/session_firefly_provider.dart';
import '../widget/chosu_sheet.dart';
import 'ocr_web_camera_stub.dart'
    if (dart.library.js_interop) 'ocr_web_camera_web.dart';
import 'session_recap_screen.dart';

// 세션 화면은 항상 다크 — AppTheme 상수를 직접 alias
const _kGreen = AppTheme.primaryLight;
const _kFont = AppTheme.fontFamily;
const _captureTimeout = Duration(seconds: 8);

/// 독서 세션 화면
class ReadingSessionScreen extends ConsumerStatefulWidget {
  final SessionGoal? goal;

  /// 페이지 기록용 — 없으면 RecapData.bookId가 null이어서 DB 저장 생략
  final String? bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final int startPage;
  final int totalPages;

  const ReadingSessionScreen({
    super.key,
    this.goal,
    this.bookId,
    this.bookTitle = '',
    this.bookAuthor = '',
    this.coverUrl,
    this.startPage = 0,
    this.totalPages = 0,
  });

  @override
  ConsumerState<ReadingSessionScreen> createState() =>
      _ReadingSessionScreenState();
}

enum UiVisibility { hidden, revealed, social, actions }

class _SessionBookMeta {
  final String? id;
  final String title;
  final String author;
  final String? coverUrl;
  final int startPage;
  final int totalPages;

  const _SessionBookMeta({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.startPage,
    required this.totalPages,
  });

  bool get hasBook => id != null && id!.isNotEmpty;
}

class _ReadingSessionScreenState extends ConsumerState<ReadingSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  late final AnimationController _moveCtrl;

  UiVisibility _uiState = UiVisibility.hidden;
  Timer? _uiHideTimer;
  bool _goalReachedNotified = false;

  // 실시간 '읽고 있는 친구' presence — 세션 화면이 살아있는 동안만 행 유지.
  // dispose에서 안전하게 쓰도록 repository 참조를 캡처해 둔다.
  ReadingPresenceRepository? _presence;
  Timer? _presenceHeartbeat;

  void _setUi(UiVisibility next, {Duration? autoHideAfter}) {
    setState(() => _uiState = next);
    _uiHideTimer?.cancel();
    if (autoHideAfter == null) return;
    _uiHideTimer = Timer(autoHideAfter, () {
      if (!mounted) return;
      final t = ref.read(timerProvider);
      if (!t.isRunning) return;
      switch (_uiState) {
        case UiVisibility.actions:
          _setUi(
            UiVisibility.revealed,
            autoHideAfter: const Duration(seconds: 6),
          );
        case UiVisibility.revealed:
          _setUi(UiVisibility.hidden);
        case UiVisibility.social:
          _setUi(UiVisibility.hidden);
        case UiVisibility.hidden:
          break;
      }
    });
  }

  void _onScreenTap() {
    switch (_uiState) {
      case UiVisibility.hidden:
        _setUi(
          UiVisibility.revealed,
          autoHideAfter: const Duration(seconds: 6),
        );
      case UiVisibility.revealed:
        _setUi(UiVisibility.social, autoHideAfter: const Duration(seconds: 8));
      case UiVisibility.social:
        _setUi(UiVisibility.hidden);
      case UiVisibility.actions:
        _setUi(
          UiVisibility.revealed,
          autoHideAfter: const Duration(seconds: 6),
        );
    }
  }

  void _onPlusTap() {
    HapticFeedback.selectionClick();
    _setUi(UiVisibility.actions, autoHideAfter: const Duration(seconds: 8));
  }

  void _openSentencesSheet() {
    final book = _readSessionBook();
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SentencesReviewSheet(
        sentences: [..._preExistingSentences, ..._collectedSentences],
        onDelete: (index) {
          final offset = _preExistingSentences.length;
          if (index >= offset) {
            setState(() => _collectedSentences.removeAt(index - offset));
          } else {
            final removed = _preExistingSentences[index];
            setState(() => _preExistingSentences.removeAt(index));
            final sentenceId = removed.id;
            if (sentenceId != null && sentenceId.isNotEmpty) {
              ref.read(dbServiceProvider).deleteSentence(sentenceId);
            }
          }
        },
        onUpdateThought: _updateSentenceThought,
        bookTitle: book.title,
        bookAuthor: book.author,
      ),
    ).then(
      (_) => _setUi(
        UiVisibility.revealed,
        autoHideAfter: const Duration(seconds: 6),
      ),
    );
  }

  void _openReadersSheet() {
    _uiHideTimer?.cancel();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ReadersSheet(),
    ).then((_) => _setUi(UiVisibility.hidden));
  }

  void _dismissTopicAndStart() {
    if (!_showTopic) return;
    final book = _readSessionBook();
    setState(() => _showTopic = false);
    final timer = ref.read(timerProvider);
    if (timer.isIdle) {
      ref
          .read(timerProvider.notifier)
          .start(goal: widget.goal, session: _sessionExtraForTimer(book));
    }
    _setUi(UiVisibility.hidden);
  }

  final List<CollectedSentence> _collectedSentences = [];
  late final DateTime _sessionStartedAt;
  List<CollectedSentence> _preExistingSentences = [];

  // 집중도 산출용 — 타이머가 running일 때만 앱을 벗어난 경우를 '이탈'로 카운트.
  // OCR/녹음 등 앱 내 기능은 타이머를 pause하므로 자연히 제외된다.
  int _exitCount = 0;
  int _exitDurationSeconds = 0;
  DateTime? _exitStartedAt;

  bool _isRecording = false;
  bool _showSlideToStop = false;
  bool _showTopic = true;
  bool _showPageInput = false;
  int _stoppedSeconds = 0;
  _SessionBookMeta? _sessionBook;
  _SessionBookMeta? _stoppedBook;
  String _recognizedText = '';

  _SessionBookMeta _resolveSessionBook({
    required TimerData timer,
    required List<Book> books,
  }) {
    Book? findBook(String? id) {
      if (id == null || id.isEmpty) return null;
      for (final book in books) {
        if (book.id == id) return book;
      }
      return null;
    }

    final explicitId = widget.bookId;
    if (explicitId != null && explicitId.isNotEmpty) {
      final libraryBook = findBook(explicitId);
      return _SessionBookMeta(
        id: explicitId,
        title: widget.bookTitle.isNotEmpty
            ? widget.bookTitle
            : libraryBook?.title ?? '',
        author: widget.bookAuthor.isNotEmpty
            ? widget.bookAuthor
            : libraryBook?.author ?? '',
        coverUrl: widget.coverUrl ?? libraryBook?.coverUrl,
        startPage: widget.startPage > 0
            ? widget.startPage
            : libraryBook?.currentPage ?? widget.startPage,
        totalPages: widget.totalPages > 0
            ? widget.totalPages
            : libraryBook?.totalPages ?? widget.totalPages,
      );
    }

    final activeSession = timer.session;
    if (activeSession != null &&
        ((activeSession.bookId?.isNotEmpty ?? false) ||
            activeSession.bookTitle.isNotEmpty)) {
      final libraryBook = findBook(activeSession.bookId);
      return _SessionBookMeta(
        id: activeSession.bookId,
        title: activeSession.bookTitle.isNotEmpty
            ? activeSession.bookTitle
            : libraryBook?.title ?? '',
        author: activeSession.bookAuthor.isNotEmpty
            ? activeSession.bookAuthor
            : libraryBook?.author ?? '',
        coverUrl: activeSession.coverUrl ?? libraryBook?.coverUrl,
        startPage: activeSession.startPage > 0
            ? activeSession.startPage
            : libraryBook?.currentPage ?? activeSession.startPage,
        totalPages: activeSession.totalPages > 0
            ? activeSession.totalPages
            : libraryBook?.totalPages ?? activeSession.totalPages,
      );
    }

    if (widget.bookTitle.isNotEmpty || widget.bookAuthor.isNotEmpty) {
      return _SessionBookMeta(
        id: widget.bookId,
        title: widget.bookTitle,
        author: widget.bookAuthor,
        coverUrl: widget.coverUrl,
        startPage: widget.startPage,
        totalPages: widget.totalPages,
      );
    }

    return const _SessionBookMeta(
      id: null,
      title: '',
      author: '',
      coverUrl: null,
      startPage: 0,
      totalPages: 0,
    );
  }

  _SessionBookMeta _readSessionBook() {
    if (_sessionBook != null) return _sessionBook!;
    return _lockResolvedSessionBook(
      timer: ref.read(timerProvider),
      books: ref.read(libraryProvider),
    );
  }

  _SessionBookMeta _lockResolvedSessionBook({
    required TimerData timer,
    required List<Book> books,
  }) {
    if (_sessionBook != null) return _sessionBook!;
    final book = _resolveSessionBook(timer: timer, books: books);
    if (book.hasBook || book.title.isNotEmpty || book.author.isNotEmpty) {
      _sessionBook = book;
    }
    return book;
  }

  SessionExtra _sessionExtraForTimer(_SessionBookMeta book) {
    return SessionExtra(
      goal: widget.goal,
      bookId: book.id,
      bookTitle: book.title,
      bookAuthor: book.author,
      coverUrl: book.coverUrl,
      startPage: book.startPage,
      totalPages: book.totalPages,
    );
  }

  Future<void> _openOcr() async {
    ref.read(timerProvider.notifier).pause();
    _uiHideTimer?.cancel();

    final result = await Navigator.of(context).push<OcrResult>(
      PageRouteBuilder(
        pageBuilder: (_, animation, _) => const _OcrCaptureScreen(),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    _setUi(UiVisibility.revealed, autoHideAfter: const Duration(seconds: 6));
    _handleOcrResult(
      result ?? const OcrCancelled(),
      noTextMessage: '텍스트를 인식하지 못했어요. 더 또렷한 사진으로 다시 시도해 보세요.',
    );
  }

  void _handleOcrResult(OcrResult result, {required String noTextMessage}) {
    switch (result) {
      case OcrSuccess(text: final text):
        _openChosuSheet(initialText: text);
      case OcrNoText():
        ref.read(timerProvider.notifier).resume();
        _showOcrSnack(noTextMessage);
      case OcrError(message: final message):
        ref.read(timerProvider.notifier).resume();
        _showOcrSnack(message);
      case OcrCancelled():
        ref.read(timerProvider.notifier).resume();
    }
  }

  Future<void> _openGalleryOcr() async {
    final picker = ImagePicker();
    ref.read(timerProvider.notifier).pause();
    _uiHideTimer?.cancel();
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (picked == null) {
        ref.read(timerProvider.notifier).resume();
        _setUi(
          UiVisibility.revealed,
          autoHideAfter: const Duration(seconds: 6),
        );
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final result = await ref
          .read(ocrServiceProvider)
          .extractTextFromBytes(bytes);
      if (!mounted) return;
      _setUi(UiVisibility.revealed, autoHideAfter: const Duration(seconds: 6));
      _handleOcrResult(
        result,
        noTextMessage: '텍스트를 인식하지 못했어요. 더 또렷한 이미지로 다시 시도해 보세요.',
      );
    } catch (_) {
      if (!mounted) return;
      ref.read(timerProvider.notifier).resume();
      _showOcrSnack('이미지를 불러올 수 없어요.');
    }
  }

  void _showOcrSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: _kFont)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _toggleRecording() async {
    final stt = ref.read(sttServiceProvider);
    if (_isRecording) {
      await stt.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (_recognizedText.isEmpty) {
        ref.read(timerProvider.notifier).resume();
        return;
      }
      final text = _recognizedText;
      _recognizedText = '';
      _openChosuSheet(initialText: text);
    } else {
      final initialized = await stt.initialize();
      if (!initialized && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '마이크를 사용할 수 없습니다.',
              style: TextStyle(fontFamily: _kFont),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      ref.read(timerProvider.notifier).pause();
      setState(() {
        _isRecording = true;
        _recognizedText = '';
      });
      await stt.listen(
        listenFor: const Duration(seconds: 30),
        onResult: (text) {
          if (mounted) setState(() => _recognizedText = text);
        },
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _moveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = ref.read(timerProvider);
      if (!timer.isIdle) {
        // 타이머 이미 실행 중 — 화두 오버레이 건너뜀
        setState(() => _showTopic = false);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();

      // 세션 시작 — 실시간 presence 등록 + 주기적 heartbeat (TTL 90s의 절반 주기).
      if (!const bool.fromEnvironment('USE_MOCK')) {
        final presence = ref.read(readingPresenceRepositoryProvider);
        _presence = presence;
        presence.start();
        _presenceHeartbeat = Timer.periodic(
          const Duration(seconds: 45),
          (_) => presence.heartbeat(),
        );
      }

      final sessionBookId = _readSessionBook().id;
      if (sessionBookId != null && !const bool.fromEnvironment('USE_MOCK')) {
        ref.read(dbServiceProvider).fetchMySentencesForBook(sessionBookId).then(
          (rows) {
            if (mounted) {
              setState(() {
                _preExistingSentences = rows
                    .map(
                      (r) => CollectedSentence(
                        content: r['content'] as String? ?? '',
                        id: r['id'] as String?,
                        thought: r['thought'] as String? ?? '',
                        pageNumber: r['page_number'] as int?,
                      ),
                    )
                    .toList();
              });
            }
          },
        );
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_exitStartedAt != null) {
        _exitCount++;
        _exitDurationSeconds += DateTime.now()
            .difference(_exitStartedAt!)
            .inSeconds;
        _exitStartedAt = null;
      }
      ref.read(timerProvider.notifier).syncFromWallClock();
      WakelockPlus.enable();
    } else {
      // 타이머가 실제로 돌고 있을 때 앱을 벗어난 경우만 이탈로 기록.
      // 앱 내 기능(OCR/녹음/문장작성)은 타이머를 pause하므로 제외된다.
      if (_exitStartedAt == null && ref.read(timerProvider).isRunning) {
        _exitStartedAt = DateTime.now();
      }
    }
  }

  @override
  void dispose() {
    _uiHideTimer?.cancel();
    // 세션 종료 — presence 행 삭제 (fire-and-forget). 누락돼도 TTL로 stale 처리됨.
    _presenceHeartbeat?.cancel();
    _presence?.end();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _pulseCtrl.dispose();
    _moveCtrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  Future<void> _openChosuSheet({String initialText = ''}) async {
    final hasInitialText = initialText.trim().isNotEmpty;
    final book = _readSessionBook();
    ref.read(timerProvider.notifier).pause();
    final result = await showGeneralDialog<CollectedSentence>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '문장 수집 닫기',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => ChosuSheet(
        initialText: initialText,
        bookTitle: book.title,
        autofocusSentence: !hasInitialText,
      ),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
    if (!mounted) return;
    if (result != null && result.content.isNotEmpty) {
      setState(() => _collectedSentences.add(result));
    }
    ref.read(timerProvider.notifier).resume();
  }

  Future<void> _updateSentenceThought(int index, String? thought) async {
    final normalized = thought?.trim() ?? '';
    final offset = _preExistingSentences.length;

    if (index < offset) {
      final current = _preExistingSentences[index];
      final sentenceId = current.id;
      if (sentenceId != null && sentenceId.isNotEmpty) {
        await ref
            .read(dbServiceProvider)
            .updateSentenceThought(sentenceId, normalized);
      }
      if (!mounted) return;
      setState(() {
        _preExistingSentences[index] = current.copyWith(thought: normalized);
      });
      return;
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= _collectedSentences.length) return;
    setState(() {
      _collectedSentences[localIndex] = _collectedSentences[localIndex]
          .copyWith(thought: normalized);
    });
  }

  void _onStop() {
    HapticFeedback.mediumImpact();
    final book = _readSessionBook();
    final seconds = ref.read(timerProvider).seconds;
    _stoppedBook = book;
    ref.read(timerProvider.notifier).stop();
    if (book.hasBook) {
      setState(() {
        _stoppedSeconds = seconds;
        _showPageInput = true;
      });
    } else {
      _navigateToRecap(seconds, book: book);
    }
  }

  void _showSlideToUnlock() {
    HapticFeedback.mediumImpact();
    ref.read(timerProvider.notifier).pause();
    setState(() => _showSlideToStop = true);
  }

  void _dismissSlideToUnlock() {
    setState(() => _showSlideToStop = false);
    ref.read(timerProvider.notifier).resume();
  }

  void _navigateToRecap(
    int seconds, {
    int? confirmedPage,
    _SessionBookMeta? book,
  }) {
    if (!mounted) return;
    final sessionBook = book ?? _stoppedBook ?? _readSessionBook();
    context.pushReplacement(
      AppConstants.routeRecap,
      extra: RecapData(
        seconds: seconds,
        bookTitle: sessionBook.title,
        bookAuthor: sessionBook.author,
        coverUrl: sessionBook.coverUrl,
        sentences: List.from(_collectedSentences),
        bookId: sessionBook.id,
        startPage: sessionBook.startPage,
        endPage: confirmedPage,
        totalPages: sessionBook.totalPages,
        sessionStartedAt: _sessionStartedAt,
        exitCount: _exitCount,
        exitDurationSeconds: _exitDurationSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final books = ref.watch(libraryProvider);
    final book =
        _stoppedBook ?? _lockResolvedSessionBook(timer: timer, books: books);
    final firefly = ref.watch(sessionFireflyProvider).valueOrNull;
    final mutuals = firefly?.mutuals ?? const [];
    final readersCount =
        (firefly?.mutualCount ?? 0) + (firefly?.nearbyCount ?? 0);

    if (timer.goalReached && !_goalReachedNotified) {
      _goalReachedNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '목표를 달성했어요! 🎉',
              style: TextStyle(
                fontFamily: _kFont,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF0D1A0D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }

    return Theme(
      data: AppTheme.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ① 배경
              const _SessionBackground(),

              // ② 라이브 포레스트 반딧불 배경 — 실시간 독자 수 반영
              Builder(
                builder: (context) {
                  final counts =
                      ref.watch(liveReaderCountsProvider).valueOrNull ??
                      LiveReaderCounts.fallback;
                  return LiveForestWidget(
                    activeCount: counts.active,
                    todayCount: counts.today,
                    weekCount: counts.week,
                  );
                },
              ),

              // ③ 반딧불이 + 독자 오브 + 중심 오브
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _moveCtrl]),
                builder: (_, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _NamedReaderOrbs(
                      mutuals: mutuals,
                      time: _moveCtrl.value,
                      showNames: _uiState == UiVisibility.social,
                    ),
                    Center(
                      child: _GlowOrb(
                        scale: _pulseAnim.value,
                        isPaused: timer.isPaused,
                      ),
                    ),
                  ],
                ),
              ),

              // ③ 화면 터치 감지 (상태 전환)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onScreenTap,
                ),
              ),

              // ④ Revealed (Frame 52) — 자물쇠 + 큰 타이머 + + 버튼 + 책정보
              _SessionLayer(
                visible: _uiState == UiVisibility.revealed,
                child: _RevealedView(
                  timer: timer,
                  bookTitle: book.title,
                  bookAuthor: book.author,
                  sessionStartedAt: _sessionStartedAt,
                  streakDays: ref.watch(readingStreakProvider).valueOrNull ?? 0,
                  sentenceCount:
                      _preExistingSentences.length + _collectedSentences.length,
                  onLockLongPress: _showSlideToUnlock,
                  onPlusTap: _onPlusTap,
                  onSentencesTap: _openSentencesSheet,
                ),
              ),

              // ⑤ Social — 이름 표시 + 함께 읽는 독자 CTA
              _SessionLayer(
                visible: _uiState == UiVisibility.social,
                child: _SocialView(
                  timer: timer,
                  readersCount: readersCount,
                  onReadersTap: _openReadersSheet,
                ),
              ),

              // ⑥ Actions (Frame 54) — pill 타이머 + 2x2 액션 그리드
              _SessionLayer(
                visible: _uiState == UiVisibility.actions,
                child: _ActionsView(
                  timer: timer,
                  bookTitle: book.title,
                  bookAuthor: book.author,
                  isRecording: _isRecording,
                  onWrite: () => _openChosuSheet(),
                  onCamera: _openOcr,
                  onGallery: _openGalleryOcr,
                  onMic: _toggleRecording,
                ),
              ),

              // ⑤ 녹음 오버레이
              if (_isRecording)
                _RecordingOverlay(
                  recognizedText: _recognizedText,
                  onStop: _toggleRecording,
                ),

              // ⑥ 슬라이드 종료 오버레이
              if (_showSlideToStop)
                _SlideToStopOverlay(
                  onConfirm: () {
                    setState(() => _showSlideToStop = false);
                    _onStop();
                  },
                  onDismiss: _dismissSlideToUnlock,
                ),

              // ⑦ 화두 오버레이
              if (_showTopic)
                _TodaysTopicOverlay(
                  bookTitle: book.title,
                  bookAuthor: book.author,
                  coverUrl: book.coverUrl,
                  onStart: _dismissTopicAndStart,
                ),

              // ⑧ 페이지 입력 오버레이
              if (_showPageInput)
                _PageInputOverlay(
                  initialPage: book.startPage,
                  totalPages: book.totalPages,
                  onConfirm: (page) {
                    setState(() => _showPageInput = false);
                    _navigateToRecap(_stoppedSeconds, confirmedPage: page);
                  },
                  onSkip: () {
                    setState(() => _showPageInput = false);
                    _navigateToRecap(_stoppedSeconds);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 중앙 pill 타이머 (단독 표시용) ────────────────────────────────────────────
class _PillTimerOnly extends StatelessWidget {
  final TimerData timer;

  const _PillTimerOnly({required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.25 : 0.45),
          width: 1,
        ),
        color: Colors.black, // Fireflies 가림
      ),
      child: Text(
        timer.formattedTime,
        style: TextStyle(
          fontSize: 16,
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
          fontWeight: FontWeight.w400,
          letterSpacing: 2,
          fontFamily: _kFont,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── 함께 읽는 독자 CTA ────────────────────────────────────────────────────

// ─── 이름 있는 독자 오브 레이어 ──────────────────────────────────────────
class _NamedReaderOrbs extends StatelessWidget {
  final List<UserProfile> mutuals;
  final double time;
  final bool showNames;

  const _NamedReaderOrbs({
    required this.mutuals,
    required this.time,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final tp = time * 2 * math.pi;

    final widgets = <Widget>[];
    for (int i = 0; i < mutuals.length; i++) {
      final user = mutuals[i];
      final seed = user.username.hashCode.abs();
      final rng = math.Random(seed);

      double nx = 0.5, ny = 0.5;
      for (int attempt = 0; attempt < 12; attempt++) {
        nx = 0.05 + rng.nextDouble() * 0.90;
        ny = 0.12 + rng.nextDouble() * 0.76; // 최소 12% — drift + orbR 여유 확보
        final ddx = (nx - 0.5) / 0.22;
        final ddy = (ny - 0.5) / 0.12;
        if (ddx * ddx + ddy * ddy > 1.0) break;
      }

      final driftAmp = 5.0 + rng.nextDouble() * 8.0;
      final phX = rng.nextDouble() * 2 * math.pi;
      final phY = rng.nextDouble() * 2 * math.pi;
      final orbR = 4.0 + rng.nextDouble() * 26.0;

      final cx = nx * size.width;
      final cy = ny * size.height;
      final dx = driftAmp * math.sin(tp + phX);
      final dy = driftAmp * math.cos(tp + phY);

      final top = (cy + dy - orbR).clamp(0.0, size.height - orbR * 2);
      final left = cx + dx - orbR;

      widgets.add(
        Positioned(
          left: left,
          top: top,
          child: _SingleNamedOrb(radius: orbR),
        ),
      );

      // 이름 레이블 — social 상태일 때만 페이드인
      widgets.add(
        Positioned(
          left: cx + dx - 36,
          top: top + orbR * 2 + 5,
          width: 72,
          child: AnimatedOpacity(
            opacity: showNames ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: Text(
              user.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _kGreen.withValues(alpha: 0.90),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.2,
                fontFamily: _kFont,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: widgets);
  }
}

class _SingleNamedOrb extends StatelessWidget {
  final double radius;

  const _SingleNamedOrb({required this.radius});

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(painter: _OrbRingPainter(radius: radius)),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  final double radius;
  const _OrbRingPainter({required this.radius});

  static const _darkGreen = Color(0xFF1A3B1A);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    if (radius < 5) {
      canvas.drawCircle(c, radius, Paint()..color = _kGreen);
      return;
    }

    // 어두운 녹색 채움 (외곽)
    canvas.drawCircle(c, radius, Paint()..color = _darkGreen);

    // 밝은 녹색 중심
    final centerR = radius >= 18 ? radius * 0.40 : radius * 0.45;
    canvas.drawCircle(c, centerR, Paint()..color = _kGreen);
  }

  @override
  bool shouldRepaint(_OrbRingPainter old) => old.radius != radius;
}

// ─── 배경 (순수 블랙) ──────────────────────────────────────────────────────
class _SessionBackground extends StatelessWidget {
  const _SessionBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [Color(0xFF050805), Color(0xFF000000)],
        ),
      ),
    );
  }
}

// ─── 나 — 중심 3단 링 오브 ────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final double scale;
  final bool isPaused;

  const _GlowOrb({required this.scale, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final radius = screenW * 0.14;
    final d = radius * 2;
    final bright = isPaused ? const Color(0xFF2A7A3D) : _kGreen;

    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: d,
        height: d,
        child: CustomPaint(
          painter: _CenterOrbPainter(radius: radius, bright: bright),
        ),
      ),
    );
  }
}

class _CenterOrbPainter extends CustomPainter {
  final double radius;
  final Color bright;

  const _CenterOrbPainter({required this.radius, required this.bright});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // Layer 1 (외곽): 아주 어두운 녹색
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF0D2010));
    // Layer 2 (중간): 중간 어두운 녹색
    canvas.drawCircle(
      c,
      radius * 0.65,
      Paint()..color = const Color(0xFF1A3B1A),
    );
    // Layer 3 (중심): 밝은 녹색
    canvas.drawCircle(c, radius * 0.32, Paint()..color = bright);
  }

  @override
  bool shouldRepaint(_CenterOrbPainter old) =>
      old.bright != bright || old.radius != radius;
}

// ─── OCR 촬영 화면 ───────────────────────────────────────────────────────
class _OcrCaptureScreen extends ConsumerStatefulWidget {
  const _OcrCaptureScreen();

  @override
  ConsumerState<_OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends ConsumerState<_OcrCaptureScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraCtrl;
  OcrWebCameraController? _webCameraCtrl;
  CameraImage? _latestFrame;
  late final AnimationController _pulseCtrl;
  bool _initializing = true;
  bool _processing = false;
  bool _streamReady = kIsWeb;
  bool _torchOn = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    _webCameraCtrl?.dispose();
    _cameraCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (kIsWeb) {
      await _initializeWebCamera();
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _statusMessage = '사용할 수 있는 카메라가 없어요';
        });
        return;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: _ocrCaptureImageFormatGroup,
      );
      _cameraCtrl = controller;

      await controller.initialize();
      if (!kIsWeb) {
        await controller.startImageStream((frame) {
          _latestFrame = frame;
          if (!_streamReady && mounted) {
            setState(() => _streamReady = true);
          }
        });
      }
      try {
        await controller.setFlashMode(FlashMode.off);
      } on CameraException {
        // Some web browsers expose a camera but not torch/flash controls.
      }
      if (!mounted) return;
      setState(() => _initializing = false);
    } on CameraException catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _statusMessage = '카메라를 열 수 없어요';
      });
    }
  }

  Future<void> _initializeWebCamera() async {
    final controller = OcrWebCameraController();
    _webCameraCtrl = controller;
    if (mounted) setState(() {});

    try {
      await WidgetsBinding.instance.endOfFrame;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _initializing = false);
    } catch (_) {
      controller.dispose();
      if (!mounted) return;
      setState(() {
        _webCameraCtrl = null;
        _initializing = false;
        _statusMessage = '카메라를 열 수 없어요';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _cameraCtrl;
    final webController = _webCameraCtrl;
    if (kIsWeb) {
      if (webController == null || !webController.isReady || _processing) {
        return;
      }
    } else if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _processing) {
      return;
    }
    if (!kIsWeb && _latestFrame == null) {
      setState(() => _statusMessage = '카메라를 준비하는 중이에요');
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = null;
    });
    if (!kIsWeb) HapticFeedback.mediumImpact();

    try {
      final bytes = await _captureOcrBytes();
      final result = await ref
          .read(ocrServiceProvider)
          .extractTextFromBytes(bytes);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _statusMessage = '촬영 중 문제가 생겼어요. 다시 시도해 주세요';
      });
    }
  }

  Future<Uint8List> _captureOcrBytes() async {
    final viewportSize = MediaQuery.sizeOf(context);
    final guideFrame = _quoteGuideFrameRect(
      viewportSize,
      MediaQuery.paddingOf(context),
    );

    if (kIsWeb) {
      final controller = _webCameraCtrl;
      if (controller == null) {
        throw StateError('Web camera is not ready.');
      }
      return controller
          .captureJpeg(cropRect: guideFrame, viewportSize: viewportSize)
          .timeout(_captureTimeout);
    }

    final controller = _cameraCtrl;
    if (controller == null) {
      throw StateError('Camera is not ready.');
    }
    final frame = _latestFrame;
    if (frame == null) {
      throw StateError('Camera stream frame is not ready.');
    }
    return _encodeCameraFrameToJpeg(
      frame,
      rotationDegrees: _ocrFrameRotationDegrees(controller),
      cropRect: guideFrame,
      viewportSize: viewportSize,
    );
  }

  Future<void> _toggleTorch() async {
    if (kIsWeb) return;

    final controller = _cameraCtrl;
    if (controller == null || !controller.value.isInitialized || _processing) {
      return;
    }

    try {
      final next = !_torchOn;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!mounted) return;
      setState(() => _torchOn = next);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = '플래시를 사용할 수 없어요');
    }
  }

  void _close() {
    Navigator.of(context).pop(const OcrCancelled());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraCtrl;
    final webController = _webCameraCtrl;
    final webCameraReady = kIsWeb && webController?.isReady == true;
    final nativeCameraReady =
        !kIsWeb && controller?.value.isInitialized == true;
    final cameraReady = webCameraReady || nativeCameraReady;
    final canCapture =
        cameraReady && _streamReady && !_processing && _statusMessage == null;

    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb && webController != null)
              OcrWebCameraPreview(controller: webController)
            else if (nativeCameraReady && controller != null)
              _CameraPreviewCover(controller: controller)
            else
              _CameraPreparingView(
                initializing: _initializing,
                message: _statusMessage,
              ),
            if (kIsWeb && webController != null && !webCameraReady)
              const Positioned.fill(child: _CameraWarmupOverlay()),
            Positioned.fill(child: _QuoteCameraOverlay(pulseCtrl: _pulseCtrl)),
            _CaptureTopBar(
              torchOn: _torchOn,
              torchEnabled: !kIsWeb && cameraReady && !_processing,
              onBack: _close,
              onTorch: _toggleTorch,
            ),
            _CaptureBottomBar(
              canCapture: canCapture,
              processing: _processing,
              message: _statusMessage,
              onCapture: _capture,
            ),
            if (_processing) const _OcrLoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

class _CameraWarmupOverlay extends StatelessWidget {
  const _CameraWarmupOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_alt_rounded,
              color: Colors.white.withValues(alpha: 0.72),
              size: 40,
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

ImageFormatGroup get _ocrCaptureImageFormatGroup {
  if (kIsWeb) return ImageFormatGroup.unknown;
  return defaultTargetPlatform == TargetPlatform.iOS
      ? ImageFormatGroup.bgra8888
      : ImageFormatGroup.yuv420;
}

Uint8List _encodeCameraFrameToJpeg(
  CameraImage frame, {
  int rotationDegrees = 0,
  Rect? cropRect,
  Size? viewportSize,
}) {
  final image = switch (frame.format.group) {
    ImageFormatGroup.jpeg => img.decodeImage(frame.planes.first.bytes),
    ImageFormatGroup.bgra8888 => _bgra8888ToImage(frame),
    ImageFormatGroup.yuv420 => _yuv420ToImage(frame),
    ImageFormatGroup.nv21 || ImageFormatGroup.unknown => null,
  };
  if (image == null) {
    throw UnsupportedError('Unsupported camera image format.');
  }

  final rotated = _rotateImageForOcr(image, rotationDegrees);
  final cropped = _cropImageToViewportRect(
    rotated,
    cropRect: cropRect,
    viewportSize: viewportSize,
  );
  return img.encodeJpg(cropped, quality: 85);
}

img.Image _cropImageToViewportRect(
  img.Image image, {
  required Rect? cropRect,
  required Size? viewportSize,
}) {
  if (cropRect == null ||
      viewportSize == null ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0) {
    return image;
  }

  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final scale = math.max(
    viewportSize.width / imageSize.width,
    viewportSize.height / imageSize.height,
  );
  final displayedWidth = imageSize.width * scale;
  final displayedHeight = imageSize.height * scale;
  final overflowX = (displayedWidth - viewportSize.width) / 2;
  final overflowY = (displayedHeight - viewportSize.height) / 2;
  final left = ((cropRect.left + overflowX) / scale).clamp(
    0.0,
    imageSize.width - 1,
  );
  final top = ((cropRect.top + overflowY) / scale).clamp(
    0.0,
    imageSize.height - 1,
  );
  final right = ((cropRect.right + overflowX) / scale).clamp(
    left + 1,
    imageSize.width,
  );
  final bottom = ((cropRect.bottom + overflowY) / scale).clamp(
    top + 1,
    imageSize.height,
  );

  return img.copyCrop(
    image,
    x: left.round(),
    y: top.round(),
    width: math.max(1, (right - left).round()),
    height: math.max(1, (bottom - top).round()),
  );
}

int _ocrFrameRotationDegrees(CameraController controller) {
  final sensorDegrees = controller.description.sensorOrientation;
  final deviceDegrees = switch (controller.value.lockedCaptureOrientation ??
      controller.value.deviceOrientation) {
    DeviceOrientation.portraitUp => 0,
    DeviceOrientation.landscapeLeft => 90,
    DeviceOrientation.portraitDown => 180,
    DeviceOrientation.landscapeRight => 270,
  };

  if (controller.description.lensDirection == CameraLensDirection.front) {
    return (sensorDegrees + deviceDegrees) % 360;
  }
  return (sensorDegrees - deviceDegrees + 360) % 360;
}

img.Image _rotateImageForOcr(img.Image image, int degrees) {
  final normalized = degrees % 360;
  if (normalized == 0) return image;
  return img.copyRotate(image, angle: normalized);
}

img.Image _bgra8888ToImage(CameraImage frame) {
  final image = img.Image(width: frame.width, height: frame.height);
  final plane = frame.planes.first;
  final bytes = plane.bytes;

  for (var y = 0; y < frame.height; y++) {
    final rowOffset = y * plane.bytesPerRow;
    for (var x = 0; x < frame.width; x++) {
      final index = rowOffset + x * 4;
      image.setPixelRgba(
        x,
        y,
        bytes[index + 2],
        bytes[index + 1],
        bytes[index],
        bytes[index + 3],
      );
    }
  }

  return image;
}

img.Image _yuv420ToImage(CameraImage frame) {
  if (frame.planes.length < 3) {
    throw UnsupportedError('YUV camera image does not include 3 planes.');
  }

  final image = img.Image(width: frame.width, height: frame.height);
  final yPlane = frame.planes[0];
  final uPlane = frame.planes[1];
  final vPlane = frame.planes[2];
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  for (var y = 0; y < frame.height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y ~/ 2) * uPlane.bytesPerRow;
    for (var x = 0; x < frame.width; x++) {
      final yValue = yPlane.bytes[yRow + x];
      final uvIndex = uvRow + (x ~/ 2) * uvPixelStride;
      final uValue = uPlane.bytes[uvIndex];
      final vValue = vPlane.bytes[uvIndex];

      final c = yValue - 16;
      final d = uValue - 128;
      final e = vValue - 128;
      final r = _clipColor((298 * c + 409 * e + 128) >> 8);
      final g = _clipColor((298 * c - 100 * d - 208 * e + 128) >> 8);
      final b = _clipColor((298 * c + 516 * d + 128) >> 8);
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  return image;
}

int _clipColor(int value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value;
}

class _CameraPreviewCover extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewCover({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _CameraPreparingView extends StatelessWidget {
  final bool initializing;
  final String? message;

  const _CameraPreparingView({required this.initializing, this.message});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050805), Colors.black],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              initializing
                  ? Icons.camera_alt_rounded
                  : Icons.camera_alt_outlined,
              color: Colors.white.withValues(alpha: 0.72),
              size: 40,
            ),
            const SizedBox(height: 18),
            if (initializing)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: _kGreen,
                  strokeWidth: 2,
                ),
              )
            else
              Text(
                message ?? '카메라를 준비하지 못했어요',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: _kFont,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Rect _quoteGuideFrameRect(Size size, EdgeInsets padding) {
  final frameW = math.min(size.width - 44, 360.0);
  final maxFrameH = math.max(
    190.0,
    size.height - padding.top - padding.bottom - 230,
  );
  final frameH = math.min(math.max(frameW * 0.64, 210.0), maxFrameH);
  final frameLeft = (size.width - frameW) / 2;
  final frameTop = (size.height - frameH) / 2 - 22;
  return Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);
}

class _QuoteCameraOverlay extends StatelessWidget {
  final Animation<double> pulseCtrl;

  const _QuoteCameraOverlay({required this.pulseCtrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseCtrl,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final padding = MediaQuery.paddingOf(context);
            final frameRect = _quoteGuideFrameRect(size, padding);
            final quoteAlpha = 0.54 + pulseCtrl.value * 0.28;

            return SizedBox.expand(
              child: CustomPaint(
                painter: _QuoteGuidePainter(
                  frameRect: frameRect,
                  pulse: pulseCtrl.value,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: frameRect.left - 2,
                      top: frameRect.top - 52,
                      child: _GuideQuote(mark: '“', opacity: quoteAlpha),
                    ),
                    Positioned(
                      right: frameRect.left - 2,
                      top: frameRect.bottom - 28,
                      child: _GuideQuote(mark: '”', opacity: quoteAlpha),
                    ),
                    ...List.generate(4, (index) {
                      final top =
                          frameRect.top +
                          frameRect.height * (0.28 + index * 0.12);
                      return Positioned(
                        left: frameRect.left + 42,
                        right: frameRect.left + 42,
                        top: top,
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      );
                    }),
                    Positioned(
                      left: 28,
                      right: 28,
                      top: frameRect.bottom + 56,
                      child: Text(
                        '문장을 따옴표 안에 맞춰주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontFamily: _kFont,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GuideQuote extends StatelessWidget {
  final String mark;
  final double opacity;

  const _GuideQuote({required this.mark, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Text(
      mark,
      style: TextStyle(
        color: _kGreen.withValues(alpha: opacity),
        fontSize: 86,
        height: 1,
        fontWeight: FontWeight.w400,
        fontFamily: _kFont,
        shadows: [
          Shadow(color: _kGreen.withValues(alpha: 0.45), blurRadius: 22),
        ],
      ),
    );
  }
}

class _QuoteGuidePainter extends CustomPainter {
  final Rect frameRect;
  final double pulse;

  const _QuoteGuidePainter({required this.frameRect, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final cutout = RRect.fromRectAndRadius(
      frameRect,
      const Radius.circular(18),
    );
    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );

    final borderPaint = Paint()
      ..color = _kGreen.withValues(alpha: 0.22 + pulse * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(cutout, borderPaint);

    final cornerPaint = Paint()
      ..color = _kGreen.withValues(alpha: 0.72 + pulse * 0.18)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    const corner = 34.0;
    const inset = 2.0;
    final l = frameRect.left + inset;
    final t = frameRect.top + inset;
    final r = frameRect.right - inset;
    final b = frameRect.bottom - inset;

    canvas.drawLine(Offset(l, t + corner), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + corner, t), cornerPaint);
    canvas.drawLine(Offset(r - corner, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + corner), cornerPaint);
    canvas.drawLine(Offset(l, b - corner), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + corner, b), cornerPaint);
    canvas.drawLine(Offset(r - corner, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b - corner), Offset(r, b), cornerPaint);
  }

  @override
  bool shouldRepaint(_QuoteGuidePainter old) =>
      old.frameRect != frameRect || old.pulse != pulse;
}

class _CaptureTopBar extends StatelessWidget {
  final bool torchOn;
  final bool torchEnabled;
  final VoidCallback onBack;
  final VoidCallback onTorch;

  const _CaptureTopBar({
    required this.torchOn,
    required this.torchEnabled,
    required this.onBack,
    required this.onTorch,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              _CaptureIconButton(
                icon: Icons.close_rounded,
                label: '닫기',
                onTap: onBack,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: ShapeDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  shape: AppTheme.smoothShape(
                    radius: 10,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
                child: const Text(
                  '문장 촬영',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
              ),
              const Spacer(),
              _CaptureIconButton(
                icon: torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                label: torchOn ? '플래시 끄기' : '플래시 켜기',
                onTap: torchEnabled ? onTorch : null,
                active: torchOn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  const _CaptureIconButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? _kGreen.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.48),
            shape: BoxShape.circle,
            border: Border.all(
              color: active
                  ? _kGreen.withValues(alpha: 0.34)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? (active ? _kGreen : Colors.white)
                : Colors.white.withValues(alpha: 0.32),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _CaptureBottomBar extends StatelessWidget {
  final bool canCapture;
  final bool processing;
  final String? message;
  final VoidCallback onCapture;

  const _CaptureBottomBar({
    required this.canCapture,
    required this.processing,
    required this.message,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(28, 34, 28, bottom + 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.9),
              Colors.black.withValues(alpha: 0.66),
              Colors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 22,
              child: Text(
                message ?? (processing ? '텍스트 인식 중...' : '흔들림 없이 한 번에'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: message == null
                      ? Colors.white.withValues(alpha: 0.68)
                      : _kGreen.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  fontFamily: _kFont,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: canCapture ? onCapture : null,
              child: AnimatedOpacity(
                opacity: canCapture ? 1 : 0.45,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.88),
                      width: 3,
                    ),
                  ),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _kGreen.withValues(alpha: 0.32),
                          blurRadius: 24,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
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

class _OcrLoadingOverlay extends StatelessWidget {
  const _OcrLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 48,
              ),
              SizedBox(height: 16),
              CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
              SizedBox(height: 16),
              Text(
                '텍스트 인식 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 녹음 오버레이 ────────────────────────────────────────────────────────
class _RecordingOverlay extends StatefulWidget {
  final String recognizedText;
  final VoidCallback onStop;

  const _RecordingOverlay({required this.recognizedText, required this.onStop});

  @override
  State<_RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<_RecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onStop,
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StopRecordingButton(pulseCtrl: _pulseCtrl, onTap: widget.onStop),
              const SizedBox(height: 20),
              const Text(
                '눌러서 중지',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: _kFont,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '듣는 중...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontFamily: _kFont,
                ),
              ),
              if (widget.recognizedText.isNotEmpty) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      widget.recognizedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                        fontFamily: _kFont,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StopRecordingButton extends StatelessWidget {
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _StopRecordingButton({required this.pulseCtrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 96;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: buttonSize + 48,
        height: buttonSize + 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, _) {
                final t = pulseCtrl.value;
                final scale = 1.0 + t * 0.4;
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 슬라이드 종료 오버레이 ───────────────────────────────────────────────
class _SlideToStopOverlay extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _SlideToStopOverlay({required this.onConfirm, required this.onDismiss});

  @override
  State<_SlideToStopOverlay> createState() => _SlideToStopOverlayState();
}

class _SlideToStopOverlayState extends State<_SlideToStopOverlay> {
  static const double _trackHeight = 64.0;
  static const double _thumbSize = 52.0;
  static const double _trackPadding = 6.0;

  double _dragX = 0.0;
  double _maxDrag = 0.0;

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _dragX = (_dragX + d.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (_dragX >= _maxDrag * 0.9) {
      widget.onConfirm();
    } else {
      setState(() => _dragX = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.70),
          child: SafeArea(
            child: Stack(
              children: [
                // 슬라이더 — 화면 중앙
                Center(
                  child: GestureDetector(
                    onTap: () {}, // 슬라이더 영역 탭은 dismiss 막기
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '스와이프 하여 독서를 종료',
                            style: TextStyle(
                              color: _kGreen.withValues(alpha: 0.85),
                              fontSize: 16,
                              fontFamily: _kFont,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              _maxDrag =
                                  constraints.maxWidth -
                                  _thumbSize -
                                  _trackPadding * 2;
                              final progress = _maxDrag > 0
                                  ? _dragX / _maxDrag
                                  : 0.0;
                              return Container(
                                height: _trackHeight,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _kGreen.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  color: Colors.black.withValues(alpha: 0.6),
                                ),
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    // 진행 트랙
                                    Positioned(
                                      left: _trackPadding,
                                      child: Container(
                                        width: _dragX + _thumbSize * 0.5,
                                        height: _thumbSize * 0.25,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          color: _kGreen.withValues(
                                            alpha: progress * 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // 썸 버튼
                                    Positioned(
                                      left: _trackPadding + _dragX,
                                      child: GestureDetector(
                                        onHorizontalDragUpdate: _onDragUpdate,
                                        onHorizontalDragEnd: _onDragEnd,
                                        child: Container(
                                          width: _thumbSize,
                                          height: _thumbSize,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: _kGreen,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.black,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 우하단 취소(잠금) 버튼
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 세션 진입 오버레이 ─────────────────────────────────────────────────
class _TodaysTopicOverlay extends StatefulWidget {
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final VoidCallback onStart;

  const _TodaysTopicOverlay({
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    required this.onStart,
  });

  @override
  State<_TodaysTopicOverlay> createState() => _TodaysTopicOverlayState();
}

class _TodaysTopicOverlayState extends State<_TodaysTopicOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onStart();
        },
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.94),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _SessionEntryFireflies(),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = math.min(constraints.maxWidth, 430.0);
                    final verticalOffset = constraints.maxHeight * 0.05;
                    return Center(
                      child: Transform.translate(
                        offset: Offset(0, verticalOffset),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(40, 42, 40, 54),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _SessionEntryBadge(label: '6번째 세션'),
                                const SizedBox(height: 17),
                                Text(
                                  widget.bookTitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8DBBFF),
                                    fontSize: 20,
                                    height: 1.18,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: _kFont,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _sessionEntryBookMeta(widget.bookAuthor),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(
                                      0xFF8DBBFF,
                                    ).withValues(alpha: 0.78),
                                    fontSize: 13,
                                    height: 1.2,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: _kFont,
                                  ),
                                ),
                                const SizedBox(height: 23),
                                BookCover(
                                  coverUrl: widget.coverUrl,
                                  gradientIndex: widget.bookTitle.hashCode
                                      .abs(),
                                  width: 200,
                                  height: 305,
                                  radius: 8,
                                  shadows: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF65A7FF,
                                      ).withValues(alpha: 0.12),
                                      blurRadius: 18,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 34),
                                _SessionEntryQuestionButton(
                                  label: _sessionEntryQuestion(
                                    widget.bookTitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _sessionEntryBookMeta(String author) {
  final trimmed = author.trim();
  if (trimmed.isEmpty) return '2022';
  return '$trimmed | 2022';
}

String _sessionEntryQuestion(String bookTitle) {
  if (bookTitle.contains('채식주의자')) {
    return '영혜는 왜 채식을 결심했을까요?';
  }
  return '이 책은 어떤 질문을 남길까요?';
}

class _SessionEntryBadge extends StatelessWidget {
  final String label;

  const _SessionEntryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF8DBBFF).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF07101C),
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w500,
          fontFamily: _kFont,
        ),
      ),
    );
  }
}

class _SessionEntryQuestionButton extends StatelessWidget {
  final String label;

  const _SessionEntryQuestionButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF8DBBFF), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8DBBFF).withValues(alpha: 0.14),
            blurRadius: 14,
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF8DBBFF),
          fontSize: 16,
          height: 1.15,
          fontWeight: FontWeight.w400,
          fontFamily: _kFont,
        ),
      ),
    );
  }
}

class _SessionEntryFireflies extends StatelessWidget {
  const _SessionEntryFireflies();

  static const _orbs = <({double x, double y, double size, double alpha})>[
    (x: 0.145, y: 0.129, size: 22, alpha: 0.30),
    (x: 0.846, y: 0.075, size: 9, alpha: 0.14),
    (x: 0.246, y: 0.339, size: 45, alpha: 0.11),
    (x: 0.225, y: 0.525, size: 43, alpha: 0.25),
    (x: 0.805, y: 0.707, size: 36, alpha: 0.18),
    (x: 0.467, y: 0.763, size: 22, alpha: 0.30),
    (x: 0.136, y: 0.794, size: 9, alpha: 0.16),
    (x: 0.846, y: 0.875, size: 22, alpha: 0.26),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            for (final orb in _orbs)
              Positioned(
                left: constraints.maxWidth * orb.x - orb.size / 2,
                top: constraints.maxHeight * orb.y - orb.size / 2,
                child: Container(
                  width: orb.size,
                  height: orb.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFF8DBBFF,
                    ).withValues(alpha: orb.alpha * 0.18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFF8DBBFF,
                        ).withValues(alpha: orb.alpha),
                        blurRadius: orb.size * 0.45,
                        spreadRadius: orb.size * 0.08,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: orb.size * 0.34,
                      height: orb.size * 0.34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF8DBBFF,
                        ).withValues(alpha: math.min(0.72, orb.alpha + 0.18)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── 세션 UI 레이어 — 부드러운 페이드인/아웃 ─────────────────────────────────
class _SessionLayer extends StatelessWidget {
  final bool visible;
  final Widget child;

  const _SessionLayer({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(visible),
          tween: Tween<double>(begin: visible ? 12 : 0, end: 0),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (_, dy, c) =>
              Transform.translate(offset: Offset(0, dy), child: c),
          child: child,
        ),
      ),
    );
  }
}

// ─── Revealed (Frame 52) — 자물쇠 + 타이머 + 책정보 + + ─────────────────
class _RevealedView extends StatelessWidget {
  final TimerData timer;
  final String bookTitle;
  final String bookAuthor;
  final DateTime sessionStartedAt;
  final int streakDays;
  final int sentenceCount;
  final VoidCallback onLockLongPress;
  final VoidCallback onPlusTap;
  final VoidCallback onSentencesTap;

  const _RevealedView({
    required this.timer,
    required this.bookTitle,
    required this.bookAuthor,
    required this.sessionStartedAt,
    required this.streakDays,
    required this.sentenceCount,
    required this.onLockLongPress,
    required this.onPlusTap,
    required this.onSentencesTap,
  });

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  String get _dateLabel {
    final d = sessionStartedAt;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final w = _weekdays[(d.weekday - 1).clamp(0, 6)];
    return '$y.$m.$dd($w)';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 배경 디밍 — 반딧불은 살리면서 살짝만 어둡게
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withValues(alpha: 0.55)),
          ),
        ),

        // 상단: 자물쇠 + 큰 타이머 + 날짜
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LockBadge(
                    isPaused: timer.isPaused,
                    onLongPress: onLockLongPress,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    timer.formattedTime,
                    style: TextStyle(
                      color: _kGreen.withValues(
                        alpha: timer.isPaused ? 0.55 : 1.0,
                      ),
                      fontSize: 64,
                      height: 1.0,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -1,
                      fontFamily: _kFont,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(
                          color: _kGreen.withValues(alpha: 0.35),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    streakDays > 0 ? '$_dateLabel +$streakDays일' : _dateLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w400,
                      fontFamily: _kFont,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 하단: + 버튼 + 책 정보
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottom + 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlusButton(onTap: onPlusTap),
                const SizedBox(height: 14),
                if (sentenceCount > 0) ...[
                  _SentenceBadge(count: sentenceCount, onTap: onSentencesTap),
                  const SizedBox(height: 14),
                ] else
                  const SizedBox(height: 4),
                Text(
                  bookTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  bookAuthor,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kGreen.withValues(alpha: 0.80),
                    fontSize: 12,
                    letterSpacing: 0.3,
                    fontFamily: _kFont,
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

class _LockBadge extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onLongPress;

  const _LockBadge({required this.isPaused, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final alpha = isPaused ? 0.5 : 0.85;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kGreen.withValues(alpha: alpha),
            width: 1.4,
          ),
          color: Colors.black.withValues(alpha: 0.18),
        ),
        child: Icon(
          Icons.lock_outline_rounded,
          color: _kGreen.withValues(alpha: alpha),
          size: 20,
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _kGreen.withValues(alpha: 0.85),
            width: 1.4,
          ),
          color: Colors.black.withValues(alpha: 0.18),
        ),
        child: Icon(
          Icons.add_rounded,
          color: _kGreen.withValues(alpha: 0.95),
          size: 22,
        ),
      ),
    );
  }
}

class _SentenceBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _SentenceBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_rounded, color: Colors.black, size: 15),
            const SizedBox(width: 6),
            Text(
              '+$count',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                fontFamily: _kFont,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentencesReviewSheet extends ConsumerStatefulWidget {
  final List<CollectedSentence> sentences;
  final void Function(int index) onDelete;
  final Future<void> Function(int index, String? thought) onUpdateThought;
  final String bookTitle;
  final String bookAuthor;

  const _SentencesReviewSheet({
    required this.sentences,
    required this.onDelete,
    required this.onUpdateThought,
    required this.bookTitle,
    required this.bookAuthor,
  });

  @override
  ConsumerState<_SentencesReviewSheet> createState() =>
      _SentencesReviewSheetState();
}

class _SentencesReviewSheetState extends ConsumerState<_SentencesReviewSheet> {
  int? _expandedIndex;
  late final List<CollectedSentence> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.sentences);
  }

  Future<void> _editThought(int index) async {
    final item = _items[index];
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SentenceThoughtSheet(sentence: item),
    );
    if (updated == null) return;

    try {
      await widget.onUpdateThought(index, updated);
      if (!mounted) return;
      setState(() {
        _items[index] = item.copyWith(thought: updated.trim());
        _expandedIndex = index;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생각을 저장하지 못했어요. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final media = MediaQuery.of(context);
    final bottom = media.padding.bottom;
    final size = media.size;
    final horizontal = math.min(math.max(size.width * 0.085, 24.0), 42.0);
    final topGap = math.min(media.padding.top + 52, 92.0);

    return Container(
      height: size.height,
      color: Colors.black,
      child: Stack(
        children: [
          const Positioned.fill(child: _SentenceReviewBackground()),
          Positioned(
            top: media.padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: topGap),
              _PillTimerOnly(timer: timer),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Colors.black,
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '이 책에서 모은 문장 ${_items.length}개',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: Stack(
                  children: [
                    if (_items.isEmpty)
                      Center(
                        child: Text(
                          '아직 모은 문장이 없어요',
                          style: TextStyle(
                            color: _kGreen.withValues(alpha: 0.45),
                            fontSize: 16,
                            fontFamily: _kFont,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          0,
                          horizontal,
                          72,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final s = _items[i];
                          final expanded = _expandedIndex == i;
                          return _SwipeableSentenceReviewCard(
                            key: ValueKey('${s.content.hashCode}_$i'),
                            sentence: s,
                            expanded: expanded,
                            onTap: () => setState(
                              () => _expandedIndex = expanded ? null : i,
                            ),
                            onEditThought: () => _editThought(i),
                            onDelete: () {
                              setState(() {
                                _items.removeAt(i);
                                if (_expandedIndex == i) {
                                  _expandedIndex = null;
                                } else if (_expandedIndex != null &&
                                    _expandedIndex! > i) {
                                  _expandedIndex = _expandedIndex! - 1;
                                }
                              });
                              widget.onDelete(i);
                            },
                          );
                        },
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 92,
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, bottom + 28),
                child: Column(
                  children: [
                    Text(
                      widget.bookTitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        fontFamily: _kFont,
                      ),
                    ),
                    if (widget.bookAuthor.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(
                        widget.bookAuthor,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kGreen.withValues(alpha: 0.86),
                          fontSize: 16,
                          letterSpacing: 0,
                          fontFamily: _kFont,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwipeableSentenceReviewCard extends StatefulWidget {
  final CollectedSentence sentence;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onEditThought;
  final VoidCallback onDelete;

  const _SwipeableSentenceReviewCard({
    super.key,
    required this.sentence,
    required this.expanded,
    required this.onTap,
    required this.onEditThought,
    required this.onDelete,
  });

  @override
  State<_SwipeableSentenceReviewCard> createState() =>
      _SwipeableSentenceReviewCardState();
}

class _SwipeableSentenceReviewCardState
    extends State<_SwipeableSentenceReviewCard> {
  static const _maxReveal = 104.0;
  double _dragOffset = 0;
  bool _dragging = false;

  bool get _deleting => _dragOffset < -1;

  void _close() => setState(() => _dragOffset = 0);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          bottom: 12,
          child: AnimatedOpacity(
            opacity: _deleting ? 1 : 0,
            duration: const Duration(milliseconds: 120),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onDelete();
              },
              child: Container(
                width: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B4F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        AnimatedContainer(
          duration: _dragging
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_dragOffset, 0, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_deleting) {
                _close();
              } else {
                widget.onTap();
              }
            },
            onHorizontalDragStart: (_) => setState(() => _dragging = true),
            onHorizontalDragUpdate: (details) {
              final delta = details.primaryDelta ?? 0;
              setState(() {
                _dragOffset = (_dragOffset + delta).clamp(-_maxReveal, 0);
              });
            },
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final reveal =
                  velocity < -500 ||
                  (velocity <= 500 && _dragOffset.abs() > _maxReveal * 0.35);
              setState(() {
                _dragging = false;
                _dragOffset = reveal ? -_maxReveal : 0;
              });
            },
            onHorizontalDragCancel: () {
              setState(() {
                _dragging = false;
                _dragOffset = _dragOffset.abs() > _maxReveal * 0.35
                    ? -_maxReveal
                    : 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.fromLTRB(
                20,
                widget.expanded ? 22 : 18,
                20,
                widget.expanded ? 22 : 18,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF111211,
                ).withValues(alpha: _deleting ? 0.78 : 0.94),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _deleting
                      ? const Color(0xFFFF4B4F)
                      : widget.expanded
                      ? _kGreen.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.14),
                  width: widget.expanded || _deleting ? 1.4 : 1.0,
                ),
              ),
              child: _SentenceReviewRow(
                sentence: widget.sentence,
                expanded: widget.expanded,
                deleting: _deleting,
                onEditThought: widget.onEditThought,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SentenceReviewRow extends StatelessWidget {
  final CollectedSentence sentence;
  final bool expanded;
  final bool deleting;
  final VoidCallback onEditThought;

  const _SentenceReviewRow({
    required this.sentence,
    required this.expanded,
    required this.deleting,
    required this.onEditThought,
  });

  @override
  Widget build(BuildContext context) {
    final color = deleting ? const Color(0xFFFF4B4F) : _kGreen;
    final pageLabel = sentence.pageNumber == null
        ? ''
        : 'p. ${sentence.pageNumber}';

    return Row(
      crossAxisAlignment: expanded
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            pageLabel,
            style: TextStyle(
              color: color.withValues(alpha: deleting ? 1.0 : 0.95),
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              fontFamily: _kFont,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sentence.content,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          height: 1.72,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          fontFamily: _kFont,
                        ),
                      ),
                      if (sentence.thought.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          sentence.thought,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.78),
                            fontSize: 16,
                            height: 1.6,
                            letterSpacing: 0,
                            fontFamily: _kFont,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          '아직 이 문장에 대한 생각이 없어요',
                          style: TextStyle(
                            color: color.withValues(alpha: 0.48),
                            fontSize: 16,
                            height: 1.6,
                            letterSpacing: 0,
                            fontFamily: _kFont,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: deleting ? null : onEditThought,
                          icon: Icon(
                            Icons.edit_note_rounded,
                            size: 18,
                            color: color,
                          ),
                          label: Text(
                            sentence.thought.isEmpty ? '생각 추가' : '생각 수정',
                            style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              fontFamily: _kFont,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(
                    sentence.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      fontFamily: _kFont,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SentenceThoughtSheet extends StatefulWidget {
  final CollectedSentence sentence;

  const _SentenceThoughtSheet({required this.sentence});

  @override
  State<_SentenceThoughtSheet> createState() => _SentenceThoughtSheetState();
}

class _SentenceThoughtSheetState extends State<_SentenceThoughtSheet> {
  late final TextEditingController _thoughtCtrl;

  @override
  void initState() {
    super.initState();
    _thoughtCtrl = TextEditingController(text: widget.sentence.thought);
  }

  @override
  void dispose() {
    _thoughtCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, _thoughtCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final shouldLiftSheet = !kIsWeb;
    final maxHeight = (media.size.height - media.padding.top - 12)
        .clamp(360.0, media.size.height * 0.9)
        .toDouble();
    final bottomPadding =
        media.padding.bottom + 22 + (shouldLiftSheet ? 0 : keyboardInset);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: shouldLiftSheet ? keyboardInset : 0),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(22, 14, 22, bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      color: _kGreen,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '문장에 대한 생각',
                      style: TextStyle(
                        color: _kGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111211),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Text(
                    widget.sentence.content,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: 16,
                      height: 1.72,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      fontFamily: _kFont,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _thoughtCtrl,
                  autofocus: true,
                  minLines: 5,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  cursorColor: _kGreen,
                  style: const TextStyle(
                    color: _kGreen,
                    fontSize: 16,
                    height: 1.62,
                    letterSpacing: 0,
                    fontFamily: _kFont,
                  ),
                  decoration: InputDecoration(
                    hintText: '이 문장을 보며 든 생각을 적어보세요',
                    hintStyle: TextStyle(
                      color: _kGreen.withValues(alpha: 0.42),
                      fontSize: 16,
                      letterSpacing: 0,
                      fontFamily: _kFont,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF111211),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _kGreen.withValues(alpha: 0.45),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: _kGreen.withValues(alpha: 0.45),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _kGreen, width: 1.4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('저장'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        fontFamily: _kFont,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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

class _SentenceReviewBackground extends StatelessWidget {
  const _SentenceReviewBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SentenceReviewBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _SentenceReviewBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);
    _drawReaderLight(canvas, size.width * 0.14, size.height * 0.13, 18);
    _drawReaderLight(canvas, size.width * 0.64, size.height * 0.26, 34);
    _drawReaderLight(canvas, size.width * 0.84, size.height * 0.88, 20);

    final fade = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0x66000000), Color(0xF2000000)],
        stops: [0.0, 0.58, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, fade);
  }

  void _drawReaderLight(Canvas canvas, double x, double y, double radius) {
    final center = Offset(x, y);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = _kGreen.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    canvas.drawCircle(
      center,
      radius * 0.34,
      Paint()..color = _kGreen.withValues(alpha: 0.23),
    );
  }

  @override
  bool shouldRepaint(_SentenceReviewBackgroundPainter oldDelegate) => false;
}

// ─── Actions (Frame 54) — pill 타이머 + 2x2 액션 그리드 ─────────────────
class _ActionsView extends StatelessWidget {
  final TimerData timer;
  final String bookTitle;
  final String bookAuthor;
  final bool isRecording;
  final VoidCallback onWrite;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onMic;

  const _ActionsView({
    required this.timer,
    required this.bookTitle,
    required this.bookAuthor,
    required this.isRecording,
    required this.onWrite,
    required this.onCamera,
    required this.onGallery,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 비네트 디밍
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB8000000),
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, bottom + 24),
            child: Column(
              children: [
                // 상단 pill 타이머
                _PillTimer(timer: timer),
                const Spacer(flex: 3),
                // 2x2 그리드
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.text_fields_rounded,
                        label: '직접적기',
                        onTap: onWrite,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.camera_alt_outlined,
                        label: '사진찍기',
                        onTap: onCamera,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.image_outlined,
                        label: '불러오기',
                        onTap: onGallery,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ActionCard(
                        icon: isRecording
                            ? Icons.stop_rounded
                            : Icons.graphic_eq_rounded,
                        label: isRecording ? '중지' : '음성인식',
                        onTap: onMic,
                        isActive: isRecording,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 4),
                // 하단 책 정보
                Text(
                  bookTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  bookAuthor,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _kGreen.withValues(alpha: 0.75),
                    fontSize: 12,
                    letterSpacing: 0.3,
                    fontFamily: _kFont,
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

class _PillTimer extends StatelessWidget {
  final TimerData timer;

  const _PillTimer({required this.timer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.30 : 0.55),
          width: 1,
        ),
        color: Colors.black.withValues(alpha: 0.32),
      ),
      child: Text(
        timer.formattedTime,
        style: TextStyle(
          fontSize: 16,
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
          fontWeight: FontWeight.w400,
          letterSpacing: 1.4,
          fontFamily: _kFont,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive
        ? Colors.red.withValues(alpha: 0.7)
        : _kGreen.withValues(alpha: 0.55);
    final iconColor = isActive ? Colors.red : _kGreen.withValues(alpha: 0.95);
    final labelColor = isActive
        ? Colors.red.withValues(alpha: 0.95)
        : _kGreen.withValues(alpha: 0.95);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.2),
            color: Colors.black.withValues(alpha: 0.55),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                  fontFamily: _kFont,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Social 뷰 — pill 타이머 + 하단 독자 CTA ────────────────────────────────
class _SocialView extends StatelessWidget {
  final TimerData timer;
  final int readersCount;
  final VoidCallback onReadersTap;

  const _SocialView({
    required this.timer,
    required this.readersCount,
    required this.onReadersTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 비네트 디밍: 상단·하단 어둡고 중앙 투명
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB8000000), // alpha ~0.72 top
                    Colors.transparent,
                    Color(0xF5000000), // alpha ~0.96 bottom
                  ],
                  stops: [0.0, 0.30, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _PillTimer(timer: timer),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottom + 32),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onReadersTap();
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_double_arrow_up_rounded,
                          color: _kGreen.withValues(alpha: 0.85),
                          size: 28,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          readersCount > 0
                              ? '함께 읽는 $readersCount명의 초록 확인'
                              : '함께 읽는 초록 확인',
                          style: TextStyle(
                            color: _kGreen.withValues(alpha: 0.85),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                            fontFamily: _kFont,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ), // SafeArea
      ],
    ); // outer Stack
  }
}

// ─── 독자 목록 시트 — 두 탭(사람들 / 책) ─────────────────────────────────
// 세션 시간 및 책 정보는 username 해시 시드 기반 표시 (실데이터 연동 전)
const _kMockBooks = [
  (title: '데미안', author: '헤르만 헤세'),
  (title: '종의 기원', author: '정유정'),
  (title: '이반 일리치의 죽음', author: '레프 톨스토이'),
  (title: '전쟁과 평화 4', author: '레프 톨스토이'),
  (title: '사막', author: 'J.M.G. 르 클레지오'),
  (title: '다섯 개의 오렌지씨', author: '아서 코난 도일'),
  (title: '디자인 미학', author: '제인 포지'),
  (title: '글짜씨 21', author: '한국타이포그라피학회'),
  (title: '채식주의자', author: '한강'),
  (title: '82년생 김지영', author: '조남주'),
];

String _seededTimer(String username) {
  final hash = username.codeUnits.fold(0, (a, b) => a + b);
  final mins = 3 + (hash % 57);
  final secs = username.hashCode.abs() % 60;
  return '00:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

bool _seededLiked(String username) => username.hashCode.abs() % 3 != 0;

({String title, String author}) _seededBook(String username) {
  final idx = username.hashCode.abs() % _kMockBooks.length;
  return _kMockBooks[idx];
}

class _ReadersSheet extends ConsumerStatefulWidget {
  const _ReadersSheet();

  @override
  ConsumerState<_ReadersSheet> createState() => _ReadersSheetState();
}

class _ReadersSheetState extends ConsumerState<_ReadersSheet> {
  final _pageCtrl = PageController();
  int _tab = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fireflyAsync = ref.watch(sessionFireflyProvider);
    final mutuals = fireflyAsync.valueOrNull?.mutuals ?? const [];
    final timer = ref.watch(timerProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F0A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: _kGreen.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Column(
        children: [
          // 드래그 핸들
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // 탭 + pill 타이머
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _PillTimer(timer: timer),
                const Spacer(),
                _TabToggle(
                  current: _tab,
                  onChanged: (i) {
                    setState(() => _tab = i);
                    _pageCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 콘텐츠
          Expanded(
            child: fireflyAsync.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: _kGreen,
                      strokeWidth: 2,
                    ),
                  )
                : mutuals.isEmpty
                ? Center(
                    child: Text(
                      '아직 맞팔한 친구가 없어요',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 16,
                        fontFamily: _kFont,
                      ),
                    ),
                  )
                : PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) => setState(() => _tab = i),
                    children: [
                      _PeopleTab(mutuals: mutuals),
                      _BooksTab(mutuals: mutuals),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// 탭 토글 (사람 / 책)
class _TabToggle extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _TabToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen.withValues(alpha: 0.30), width: 1),
        color: Colors.black.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabBtn(
            icon: Icons.people_alt_rounded,
            selected: current == 0,
            onTap: () => onChanged(0),
          ),
          _TabBtn(
            icon: Icons.menu_book_rounded,
            selected: current == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabBtn({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? _kGreen.withValues(alpha: 0.15)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? _kGreen : Colors.white.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

// ─── 사람들 탭 ─────────────────────────────────────────────────────────────
class _PeopleTab extends StatelessWidget {
  final List<UserProfile> mutuals;

  const _PeopleTab({required this.mutuals});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: mutuals.length,
      itemBuilder: (context, i) {
        final user = mutuals[i];
        final isFirst = i == 0;
        final liked = _seededLiked(user.username);
        final time = _seededTimer(user.username);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isFirst
                  ? _kGreen.withValues(alpha: 0.06)
                  : const Color(0xFF111611),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFirst
                    ? _kGreen.withValues(alpha: 0.55)
                    : _kGreen.withValues(alpha: 0.10),
                width: isFirst ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                _SheetOrb(seed: user.username, large: isFirst),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    user.displayName,
                    style: TextStyle(
                      fontSize: isFirst ? 16 : 14,
                      fontWeight: FontWeight.w400,
                      color: isFirst
                          ? _kGreen
                          : Colors.white.withValues(alpha: 0.90),
                      fontFamily: _kFont,
                    ),
                  ),
                ),
                if (!isFirst)
                  Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 15,
                    color: liked
                        ? _kGreen.withValues(alpha: 0.85)
                        : Colors.white.withValues(alpha: 0.30),
                  ),
                if (!isFirst) const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: _kGreen.withValues(alpha: isFirst ? 1.0 : 0.85),
                    letterSpacing: 0.5,
                    fontFamily: _kFont,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── 책 탭 ────────────────────────────────────────────────────────────────
class _BooksTab extends StatelessWidget {
  final List<UserProfile> mutuals;

  const _BooksTab({required this.mutuals});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: mutuals.length,
      itemBuilder: (context, i) {
        final user = mutuals[i];
        final isFirst = i == 0;
        final book = _seededBook(user.username);
        final bookmarked = _seededLiked(user.username);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isFirst
                  ? _kGreen.withValues(alpha: 0.06)
                  : const Color(0xFF111611),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFirst
                    ? _kGreen.withValues(alpha: 0.55)
                    : _kGreen.withValues(alpha: 0.10),
                width: isFirst ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                _SheetOrb(seed: user.username, large: isFirst),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isFirst ? 15 : 14,
                          fontWeight: FontWeight.w400,
                          color: isFirst
                              ? _kGreen
                              : Colors.white.withValues(alpha: 0.92),
                          fontFamily: _kFont,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                          fontFamily: _kFont,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 18,
                  color: bookmarked
                      ? _kGreen.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 10),
                // 표지 자리 — 실데이터 연동 전 placeholder
                Container(
                  width: 44,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _kGreen.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _kGreen.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 20,
                    color: _kGreen.withValues(alpha: 0.30),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── 공통 — 시트용 오브 ────────────────────────────────────────────────────
class _SheetOrb extends StatelessWidget {
  final String seed;
  final bool large;

  const _SheetOrb({required this.seed, this.large = false});

  @override
  Widget build(BuildContext context) {
    final r = large ? 22.0 : 16.0;
    return SizedBox(
      width: r * 2,
      height: r * 2,
      child: CustomPaint(painter: _OrbRingPainter(radius: r)),
    );
  }
}

// ─── 페이지 입력 오버레이 ─────────────────────────────────────────────────────
class _PageInputOverlay extends StatefulWidget {
  final int initialPage;
  final int totalPages;
  final ValueChanged<int> onConfirm;
  final VoidCallback onSkip;

  const _PageInputOverlay({
    required this.initialPage,
    required this.totalPages,
    required this.onConfirm,
    required this.onSkip,
  });

  @override
  State<_PageInputOverlay> createState() => _PageInputOverlayState();
}

class _PageInputOverlayState extends State<_PageInputOverlay> {
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _maxPage);
  }

  int get _maxPage => widget.totalPages > 0 ? widget.totalPages : 9999;

  void _increment() => setState(() => _page = (_page + 1).clamp(0, _maxPage));
  void _decrement() => setState(() => _page = (_page - 1).clamp(0, _maxPage));

  @override
  Widget build(BuildContext context) {
    final ratio = _maxPage > 0 ? _page / _maxPage : 0.0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 어두운 스크림 — 배경 반딧불이는 은은하게 비침
          GestureDetector(
            onTap: widget.onSkip,
            child: Container(color: Colors.black.withValues(alpha: 0.72)),
          ),
          // 콘텐츠 — 카드 배경 없이 요소만 배경 위에 배치
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '오늘 몇 페이지까지 읽었나요?',
                    style: TextStyle(
                      fontFamily: _kFont,
                      fontSize: 15,
                      color: _kGreen.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 숫자 조작 행
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StepButton(icon: Icons.remove, onTap: _decrement),
                      const SizedBox(width: 28),
                      _PageBox(
                        page: _page,
                        totalPages: widget.totalPages,
                        onChanged: (v) =>
                            setState(() => _page = v.clamp(0, _maxPage)),
                      ),
                      const SizedBox(width: 28),
                      _StepButton(icon: Icons.add, onTap: _increment),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // 슬라이더 — 화면 좌우로 넓게
                  SizedBox(
                    width: 308,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _kGreen,
                        inactiveTrackColor: const Color(0xFF474747),
                        thumbColor: _kGreen,
                        overlayColor: _kGreen.withValues(alpha: 0.15),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                      ),
                      child: Slider(
                        value: ratio,
                        onChanged: (v) => setState(
                          () =>
                              _page = (v * _maxPage).round().clamp(0, _maxPage),
                        ),
                      ),
                    ),
                  ),
                  if (widget.totalPages > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '전체 ${widget.totalPages}',
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: 13,
                        color: _kGreen.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 확인 버튼 — 콘텐츠 크기만큼만, 솔리드 채움 사각형
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onConfirm(_page);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _kGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '독서종료',
                            style: TextStyle(
                              fontFamily: _kFont,
                              fontSize: 15,
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
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

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF202020),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF9B9B9B)),
      ),
    );
  }
}

class _PageBox extends StatefulWidget {
  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  const _PageBox({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  State<_PageBox> createState() => _PageBoxState();
}

class _PageBoxState extends State<_PageBox> {
  bool _editing = false;
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.page}');
    _focus = FocusNode()
      ..addListener(() {
        if (!_focus.hasFocus) _commit();
      });
  }

  @override
  void didUpdateWidget(_PageBox old) {
    super.didUpdateWidget(old);
    if (!_editing && old.page != widget.page) {
      _ctrl.text = '${widget.page}';
    }
  }

  void _commit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v != null) widget.onChanged(v);
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 106,
        height: 60,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 40,
            color: _kGreen,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _kGreen.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _kGreen),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: (_) => _commit(),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        _editing = true;
        _ctrl.text = '${widget.page}';
        _ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _ctrl.text.length),
        );
      }),
      child: Container(
        width: 106,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreen.withValues(alpha: 0.55)),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.page}',
              style: TextStyle(
                fontFamily: _kFont,
                fontSize: 40,
                color: _kGreen,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 13, color: _kGreen.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
