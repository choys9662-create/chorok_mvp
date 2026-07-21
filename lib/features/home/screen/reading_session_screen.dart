import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/services/db_service.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/services/screen_time_detox_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/session_goal.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/models/reading_session.dart';
import '../../../core/services/stt_service.dart';
import '../../../shared/repositories/book_repository.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/repositories/reading_presence_repository.dart';
import '../../../shared/utils/sentence_normalizer.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../timer/controller/timer_controller.dart';
import '../controller/session_firefly_provider.dart';
import '../widget/chosu_sheet.dart';
import '../widget/home_helpers.dart';
import '../widget/sentence_organizer_sheet.dart';
import 'ocr_capture_crop.dart';
import 'ocr_web_camera_stub.dart'
    if (dart.library.js_interop) 'ocr_web_camera_web.dart';
import 'session_recap_screen.dart';

// 세션 화면은 항상 다크 — AppTheme 상수를 직접 alias
const _kGreen = AppTheme.primaryLight;
const _kFont = AppTheme.fontFamily;
const _captureTimeout = Duration(seconds: 8);

const _fireflyStageOneEnd = Duration(minutes: 10);
const _fireflyStageTwoEnd = Duration(minutes: 30);
const _fireflyStageThreeEnd = Duration(minutes: 60);

typedef FireflyVisual = ({double radius, int layers, double pulseAmplitude});

/// 현재 라이브 세션의 연속 독서 시간에 따른 반딧불이 성장 규칙.
@visibleForTesting
FireflyVisual fireflyVisualForElapsed(Duration elapsed) {
  if (elapsed < _fireflyStageOneEnd) {
    return (radius: 10, layers: 1, pulseAmplitude: 0);
  }
  if (elapsed < _fireflyStageTwoEnd) {
    return (radius: 14, layers: 2, pulseAmplitude: 0);
  }
  if (elapsed < _fireflyStageThreeEnd) {
    return (radius: 18, layers: 3, pulseAmplitude: 0.04);
  }
  return (radius: 22, layers: 3, pulseAmplitude: 0.06);
}

/// 동시 접속자가 많을 때 겹침을 줄이는 숲 밀도 규칙.
@visibleForTesting
double fireflyDensityScale(int activeReaderCount) {
  if (activeReaderCount <= 5) return 1;
  if (activeReaderCount <= 10) return 0.9;
  return 0.8;
}

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

typedef _SessionPromptQuery = ({String? bookId, String? isbn});

final _sessionPromptSeedsProvider = FutureProvider.autoDispose
    .family<List<SessionPromptSeed>, _SessionPromptQuery>((ref, query) async {
      try {
        final rows = await ref
            .read(dbServiceProvider)
            .fetchSessionPromptCandidates(
              bookId: query.bookId,
              isbn13: query.isbn,
            );
        final grouped = <String, _PromptSeedAccumulator>{};
        for (final row in rows) {
          final sentence = (row['content'] as String?)?.trim() ?? '';
          if (sentence.length < 8) continue;
          final key = SentenceNormalizer.normalize(sentence);
          if (key.isEmpty) continue;
          final thought = (row['thought'] as String?)?.trim() ?? '';
          final likeCount = (row['like_count'] as num?)?.toInt() ?? 0;
          grouped
              .putIfAbsent(key, () => _PromptSeedAccumulator(sentence))
              .add(thought: thought, likeCount: likeCount);
        }
        final seeds = grouped.values.map((entry) => entry.toSeed()).toList()
          ..sort((a, b) => b.weight.compareTo(a.weight));
        return seeds.take(5).toList();
      } catch (_) {
        return const <SessionPromptSeed>[];
      }
    });

class _PromptSeedAccumulator {
  final String sentence;
  String thought = '';
  int count = 0;
  int likes = 0;

  _PromptSeedAccumulator(this.sentence);

  void add({required String thought, required int likeCount}) {
    count += 1;
    likes += likeCount;
    if (this.thought.isEmpty && thought.isNotEmpty) {
      this.thought = thought;
    }
  }

  SessionPromptSeed toSeed() {
    return SessionPromptSeed(
      sentence: sentence,
      thought: thought,
      weight: count * 10 + likes + (thought.isNotEmpty ? 5 : 0),
    );
  }
}

class _SessionBookMeta {
  final String? id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? isbn;
  final int startPage;
  final int totalPages;

  const _SessionBookMeta({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.isbn,
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

  // 화면 밝기 절전 — 10초 무터치 시 어둑하게, 터치하면 사용자 밝기로 복원.
  // UI 가시성(_uiState)과 독립적으로, 모든 포인터 입력이 _brightenScreen()을 깨운다.
  static const _idleRevealDuration = Duration(seconds: 10);
  static const _brightnessIdle = _idleRevealDuration;
  static const _dimBrightness = 0.20;
  Timer? _brightnessIdleTimer;
  bool _dimmed = false;

  Future<void> _brightenScreen() async {
    _brightnessIdleTimer?.cancel();
    _brightnessIdleTimer = Timer(_brightnessIdle, _dimScreen);
    _dimmed = false;
    try {
      // 터치하면 앱 밝기 오버라이드를 풀어 휴대폰 원래(시스템) 밝기로 되돌린다.
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (e) {
      // 시뮬레이터·웹 등 밝기 제어 미지원 환경은 조용히 무시.
      debugPrint('[밝기] 복원 실패: $e');
    }
  }

  Future<void> _dimScreen() async {
    if (!mounted || _dimmed) return;
    // 반딧불이만 보이는 몰입 화면(UI 완전 숨김)일 때만 절전한다. 시계·버튼이 보이는
    // 상태(revealed/social/actions)에선 어둑하게 하지 않는다. 카메라·시트가 위에 떠
    // 있거나(최상단 아님) STT 녹음 중이면, UI가 숨김으로 돌아가 있어도 제외한다.
    // 제외 시 어둑하게 하지 않고 idle 주기로 폴링만 한다(조건이 맞으면 그때 절전).
    final isIdleReadingScreen =
        _uiState == UiVisibility.hidden &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        !_isRecording;
    if (!isIdleReadingScreen) {
      _brightnessIdleTimer = Timer(_brightnessIdle, _dimScreen);
      return;
    }
    _dimmed = true;
    try {
      await ScreenBrightness().setApplicationScreenBrightness(_dimBrightness);
      debugPrint('[밝기] 절전 진입 → $_dimBrightness');
    } catch (e) {
      _dimmed = false;
      debugPrint('[밝기] 절전 실패: $e');
    }
  }

  // 실시간 '읽고 있는 친구' presence — 세션 화면이 살아있는 동안만 행 유지.
  // dispose에서 안전하게 쓰도록 repository 참조를 캡처해 둔다.
  ReadingPresenceRepository? _presence;
  Timer? _presenceStartupRetry;
  Timer? _presenceHeartbeat;
  bool _presenceStarted = false;

  void _setUi(UiVisibility next, {Duration? autoHideAfter}) {
    setState(() => _uiState = next);
    _uiHideTimer?.cancel();
    if (autoHideAfter == null) return;
    _uiHideTimer = Timer(autoHideAfter, () {
      if (!mounted) return;
      final t = ref.read(timerProvider);
      if (!t.isRunning) {
        // 일시정지(시트·OCR·백그라운드) 중에는 숨기지 않되 포기하지도 않는다 —
        // 재개될 때까지 같은 주기로 재시도해야 복귀 후 자동 숨김이 살아난다.
        _setUi(_uiState, autoHideAfter: autoHideAfter);
        return;
      }
      switch (_uiState) {
        case UiVisibility.actions:
          _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
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
        _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
      case UiVisibility.revealed:
        _setUi(UiVisibility.social, autoHideAfter: _idleRevealDuration);
      case UiVisibility.social:
        _setUi(UiVisibility.hidden);
      case UiVisibility.actions:
        _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
    }
  }

  void _onPlusTap() {
    HapticFeedback.selectionClick();
    _setUi(UiVisibility.actions, autoHideAfter: _idleRevealDuration);
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
        onUpdatePage: _updateSentencePage,
        bookTitle: book.title,
        bookAuthor: book.author,
      ),
    ).then(
      (_) => _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration),
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

  Future<void> _dismissTopicAndStart() async {
    if (!_showTopic) return;
    final book = _readSessionBook();
    final timer = ref.read(timerProvider);
    if (timer.isIdle) {
      final detoxStatus = kUseMock
          ? DetoxStartStatus.unsupported
          : await ScreenTimeDetoxService.instance.startDetox();
      if (!mounted) return;
      if (detoxStatus
          case DetoxStartStatus.denied ||
              DetoxStartStatus.cancelled ||
              DetoxStartStatus.emptySelection ||
              DetoxStartStatus.failed) {
        _showDetoxStartFailure(detoxStatus);
        return;
      }
      ref
          .read(timerProvider.notifier)
          .start(goal: widget.goal, session: _sessionExtraForTimer(book));
      if (book.id != null && book.id!.isNotEmpty) {
        ref.read(libraryProvider.notifier).markSessionStarted(book.id!);
      }
      if (detoxStatus == DetoxStartStatus.unsupported) {
        _showSoftDetoxNotice();
      }
      _beginPresenceTracking(includeLocation: true);
    }
    setState(() => _showTopic = false);
    _setUi(UiVisibility.hidden);
  }

  void _showDetoxStartFailure(DetoxStartStatus status) {
    final message = switch (status) {
      DetoxStartStatus.denied => '스크린 타임 권한을 허용해야 디톡스 독서를 시작할 수 있어요.',
      DetoxStartStatus.cancelled => '제한할 앱을 선택하면 디톡스 독서를 시작할 수 있어요.',
      DetoxStartStatus.emptySelection => '독서 중 제한할 앱을 하나 이상 선택해 주세요.',
      _ => '앱 제한을 시작하지 못했어요. 잠시 후 다시 시도해 주세요.',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: _kFont)),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSoftDetoxNotice() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            '앱 내 집중 모드로 시작했어요. Screen Time 지원 빌드에서는 선택한 다른 앱도 제한돼요.',
            style: TextStyle(fontFamily: _kFont),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        isbn: libraryBook?.isbn,
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
        isbn: libraryBook?.isbn,
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
        isbn: null,
        startPage: widget.startPage,
        totalPages: widget.totalPages,
      );
    }

    return const _SessionBookMeta(
      id: null,
      title: '',
      author: '',
      coverUrl: null,
      isbn: null,
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

  Future<OcrResult?> _pushOcrCapture() {
    return Navigator.of(context).push<OcrResult>(
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
  }

  // 정리 시트에서 "추가 촬영"을 누르면 호출. 다음 페이지를 찍어 인식된 문장을
  // 반환하고, 실패/빈 결과면 스낵으로 알린 뒤 null(시트는 그대로 유지).
  Future<OcrCapture?> _captureSentences() async {
    final result = await _pushOcrCapture();
    if (!mounted) return null;
    switch (result ?? const OcrCancelled()) {
      case OcrSuccess(text: final text, paragraphs: final paragraphs):
        return (text: text, paragraphs: paragraphs);
      case OcrNoText():
        _showOcrSnack('텍스트를 인식하지 못했어요. 더 또렷한 사진으로 다시 시도해 보세요.');
        return null;
      case OcrError(message: final message):
        _showOcrSnack(message);
        return null;
      case OcrCancelled():
        return null;
    }
  }

  Future<void> _openOcr() async {
    ref.read(timerProvider.notifier).pause();
    _uiHideTimer?.cancel();

    final result = await _pushOcrCapture();
    if (!mounted) return;
    _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
    _handleOcrResult(
      result ?? const OcrCancelled(),
      noTextMessage: '텍스트를 인식하지 못했어요. 더 또렷한 사진으로 다시 시도해 보세요.',
    );
  }

  void _handleOcrResult(OcrResult result, {required String noTextMessage}) {
    switch (result) {
      case OcrSuccess(text: final text, paragraphs: final paragraphs):
        _openSentenceOrganizer(text, paragraphs: paragraphs);
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
        _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      final result = await ref
          .read(ocrServiceProvider)
          .extractTextFromBytes(bytes);
      if (!mounted) return;
      _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
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
    _sessionStartedAt = ref.read(timerProvider).startedAt ?? DateTime.now();
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
      duration: const Duration(seconds: 120),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = ref.read(timerProvider);
      if (!timer.isIdle) {
        // 타이머 이미 실행 중 — 화두 오버레이 건너뜀
        setState(() => _showTopic = false);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      WakelockPlus.enable();

      // 기본은 앱 밝기 오버라이드를 풀어 시스템 밝기를 따르고, 무터치 10초 후만 20%로 낮춘다.
      // 애니메이션은 끈다 — 백그라운드 전환 중 OS가 프로세스를 곧 정지시켜 페이드가 중간에
      // 끊기고, 그 어중간한 밝기가 이후 복원 기준값으로 잘못 캐싱되는 문제가 있었다.
      ScreenBrightness().setAnimate(false).catchError((Object e) {
        debugPrint('[밝기] setAnimate 실패: $e');
      });
      _brightenScreen();

      // 라이브 포레스트 진입 자체를 presence로 등록한다. 위치 권한은 실제 독서를
      // 시작할 때만 요청하므로, 둘러보기만 해도 권한 팝업이 뜨지는 않는다.
      _beginPresenceTracking();

      final sessionBookId = _readSessionBook().id;
      if (sessionBookId != null && !kUseMock) {
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

  /// 라이브 포레스트 진입을 presence로 등록한다. 실제 독서 시작 때만 위치를
  /// 보강해 이웃 집계에 반영한다.
  void _beginPresenceTracking({bool includeLocation = false}) {
    if (kUseMock) return;

    if (_presenceStarted) {
      final presence = _presence;
      if (includeLocation && presence != null) {
        _startPresence(presence, _readSessionBook(), includeLocation: true);
      }
      return;
    }

    final presence = ref.read(readingPresenceRepositoryProvider);
    _presenceStarted = true;
    _presence = presence;
    _startPresence(
      presence,
      _readSessionBook(),
      includeLocation: includeLocation,
    );
    // 진입 직후 auth 복원이 아직 끝나지 않아 start가 건너뛴 경우를 빠르게 복구한다.
    // heartbeat는 upsert라 이미 시작된 경우에도 안전하다.
    _presenceStartupRetry = Timer(
      const Duration(seconds: 2),
      () => unawaited(_heartbeatPresence()),
    );
    _presenceHeartbeat = Timer.periodic(
      const Duration(seconds: 45),
      (_) => unawaited(_heartbeatPresence()),
    );
  }

  /// heartbeat가 성공하면 즉시 숲 데이터를 다시 읽는다. 특히 iOS가 백그라운드
  /// 동안 타이머를 멈췄다가 복귀한 직후에는 다음 45초 주기를 기다리면 안 된다.
  Future<void> _heartbeatPresence() async {
    final presence = _presence;
    if (presence == null || kUseMock) return;
    try {
      await presence.heartbeat();
      if (mounted) ref.invalidate(sessionFireflyProvider);
    } catch (error) {
      debugPrint('[presence] heartbeat failed: $error');
    }
  }

  Future<void> _startPresence(
    ReadingPresenceRepository presence,
    _SessionBookMeta sessionBook, {
    bool includeLocation = false,
  }) async {
    try {
      final position = includeLocation ? await _currentPositionOrNull() : null;
      await presence.start(
        bookTitle: sessionBook.title.isNotEmpty ? sessionBook.title : null,
        bookAuthor: sessionBook.author.isNotEmpty ? sessionBook.author : null,
        bookCoverUrl: sessionBook.coverUrl,
        latitude: position == null ? null : _coarseCoord(position.latitude),
        longitude: position == null ? null : _coarseCoord(position.longitude),
      );
      if (mounted) ref.invalidate(sessionFireflyProvider);
    } catch (error) {
      debugPrint('[presence] start failed: $error');
    }
  }

  Future<Position?> _currentPositionOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  double _coarseCoord(double value) => (value * 1000).roundToDouble() / 1000;

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
      unawaited(_heartbeatPresence());
      // 백그라운드 동안 OS가 app 밝기 오버라이드를 해제하므로 복귀 시 다시 건다.
      _dimmed = false;
      _brightenScreen();
    } else {
      // 타이머가 실제로 돌고 있을 때 앱을 벗어난 경우만 이탈로 기록.
      // 앱 내 기능(OCR/녹음/문장작성)은 타이머를 pause하므로 제외된다.
      if (_exitStartedAt == null && ref.read(timerProvider).isRunning) {
        _exitStartedAt = DateTime.now();
      }
      // 홈 화면으로 나갈 때도 명시적으로 복원한다 — resume 때와 대칭으로, 플러그인 자체
      // auto-reset(백그라운드 전환 시 기본 복원 동작)에만 기대지 않는다.
      _brightnessIdleTimer?.cancel();
      _dimmed = false;
      ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    }
  }

  @override
  void dispose() {
    _uiHideTimer?.cancel();
    // 세션 종료 — presence 행 삭제 (fire-and-forget). 누락돼도 TTL로 stale 처리됨.
    _presenceStartupRetry?.cancel();
    _presenceHeartbeat?.cancel();
    _presence?.end();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _brightnessIdleTimer?.cancel();
    ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
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

  // OCR 결과를 문장 단위로 끊어 정리(합치기/문단)한 뒤, 확정된 블록마다
  // 기존 초서 수집(생각 입력) 흐름으로 넘긴다. STT(음성)는 한 발화이므로 거치지 않는다.
  Future<void> _openSentenceOrganizer(
    String text, {
    List<List<String>>? paragraphs,
  }) async {
    final blocks = await showGeneralDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '문장 정리 닫기',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => SentenceOrganizerSheet(
        rawText: text,
        paragraphs: paragraphs,
        onCapture: _captureSentences,
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
    if (blocks == null || blocks.isEmpty) {
      ref.read(timerProvider.notifier).resume();
      return;
    }
    for (final block in blocks) {
      if (!mounted) return;
      await _openChosuSheet(initialText: block);
    }
  }

  Future<void> _openChosuSheet({String initialText = ''}) async {
    final hasInitialText = initialText.trim().isNotEmpty;
    final book = _readSessionBook();
    ref.read(timerProvider.notifier).pause();
    // 뒤에 깔린 액션 그리드가 비치지 않도록 카드가 뜨기 전에 세션 UI 레이어를 숨긴다.
    _setUi(UiVisibility.hidden);
    final result = await showGeneralDialog<CollectedSentence>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '문장 수집 닫기',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => ChosuSheet(
        initialText: initialText,
        bookTitle: book.title,
        autofocusSentence: !hasInitialText,
        timerText: ref.read(timerProvider).formattedTime,
      ),
      // 카드는 고정 위치(키보드 위)에서 제자리 페이드로만 등장한다.
      // 슬라이드가 조금이라도 섞이면 키보드와 함께 솟아오르는 모션으로
      // 보이므로 위치 이동은 일절 주지 않는다.
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
          reverseCurve: Curves.easeIn,
        ),
        child: child,
      ),
    );
    if (!mounted) return;
    if (result != null && result.content.isNotEmpty) {
      setState(() => _collectedSentences.add(result));
    }
    ref.read(timerProvider.notifier).resume();
    // 닫힌 뒤에는 타이머가 보이는 상태로 복귀했다가 자동으로 어두워진다.
    _setUi(UiVisibility.revealed, autoHideAfter: _idleRevealDuration);
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

  Future<void> _updateSentencePage(int index, int? page) async {
    final offset = _preExistingSentences.length;

    // copyWith은 null로 지울 수 없어 새 객체로 교체한다.
    CollectedSentence withPage(CollectedSentence s) => CollectedSentence(
      id: s.id,
      content: s.content,
      thought: s.thought,
      pageNumber: page,
    );

    if (index < offset) {
      final current = _preExistingSentences[index];
      final sentenceId = current.id;
      if (sentenceId != null && sentenceId.isNotEmpty) {
        await ref.read(dbServiceProvider).updateSentencePage(sentenceId, page);
      }
      if (!mounted) return;
      setState(() {
        _preExistingSentences[index] = withPage(current);
      });
      return;
    }

    final localIndex = index - offset;
    if (localIndex < 0 || localIndex >= _collectedSentences.length) return;
    setState(() {
      _collectedSentences[localIndex] = withPage(
        _collectedSentences[localIndex],
      );
    });
  }

  void _beginStopFlow() {
    HapticFeedback.mediumImpact();
    final book = _readSessionBook();
    final seconds = ref.read(timerProvider).seconds;
    _stoppedBook = book;
    _stoppedSeconds = seconds;

    if (!book.hasBook) {
      ref.read(timerProvider.notifier).stop();
      _navigateToRecap(seconds, book: book);
      return;
    }

    ref.read(timerProvider.notifier).pause();
    setState(() => _showPageInput = true);
  }

  void _cancelStopFlow() {
    _stoppedBook = null;
    _stoppedSeconds = 0;
    setState(() => _showPageInput = false);
    ref.read(timerProvider.notifier).resume();
  }

  void _confirmStopFlow(int page) {
    final seconds = _stoppedSeconds;
    final book = _stoppedBook ?? _readSessionBook();
    setState(() => _showPageInput = false);
    ref.read(timerProvider.notifier).stop();
    _navigateToRecap(seconds, confirmedPage: page, book: book);
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
    // 오브로 흩뿌리는 친구 = '지금 같이 읽는 맞팔'만. 전체 맞팔(mutualFollowProvider)을
    // 뿌리면 안 읽는 친구가 반딧불로 떠서 CTA 수("함께 읽는 N명")·시트와 안 맞는다.
    final mutuals = firefly?.mutuals ?? const [];
    final readerPresences =
        firefly?.books ?? const <String, ReadingPresenceInfo>{};
    final nearbyCount = firefly?.nearbyCount ?? 0;
    final neighborCount = math.max(0, nearbyCount);
    // 함께 읽는 독자 CTA — 시트(_PeopleTab)·오브와 동일하게 '지금 읽는 맞팔' 수.
    // nearbyCount(전체 active, 본인 포함)를 더하면 시트 목록과 안 맞아서 제외.
    final readersCount = firefly?.mutualCount ?? 0;

    if (timer.goalReached && !_goalReachedNotified) {
      _goalReachedNotified = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '목표를 달성했어요! 🎉',
              style: AppTheme.body.copyWith(color: AppTheme.textPrimary),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: AppTheme.darkCard,
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
          backgroundColor: AppTheme.darkBg,
          // 모든 포인터 입력에서 시스템 밝기로 복원(소비하지 않고 통과). 무터치 10초 후 20%.
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _brightenScreen(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ① 배경
                const _SessionBackground(),

                // ② 실제 독자 오브 + 중심 오브
                AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnim, _moveCtrl]),
                  builder: (_, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      _NamedReaderOrbs(
                        mutuals: mutuals,
                        presences: readerPresences,
                        neighborCount: neighborCount,
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
                    streakDays:
                        ref.watch(readingStreakProvider).valueOrNull ?? 0,
                    sentenceCount:
                        _preExistingSentences.length +
                        _collectedSentences.length,
                    onLockLongPress: _beginStopFlow,
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

                // ⑥ 화두 오버레이
                if (_showTopic)
                  _TodaysTopicOverlay(
                    bookTitle: book.title,
                    bookAuthor: book.author,
                    coverUrl: book.coverUrl,
                    currentPage: book.startPage,
                    totalPages: book.totalPages,
                    activeReaderCount: readersCount,
                    nearbyReaderCount: neighborCount,
                    promptSeeds:
                        ref
                            .watch(
                              _sessionPromptSeedsProvider((
                                bookId: book.id,
                                isbn: book.isbn,
                              )),
                            )
                            .valueOrNull ??
                        const <SessionPromptSeed>[],
                    accentColor: _kGreen,
                    onStart: () {
                      _dismissTopicAndStart();
                    },
                  ),

                // ⑦ 페이지 입력 오버레이
                if (_showPageInput)
                  _PageInputOverlay(
                    timeText: _formatStoppedTime(_stoppedSeconds),
                    sessionStartedAt: _sessionStartedAt,
                    initialPage: book.startPage,
                    totalPages: book.totalPages,
                    onConfirm: _confirmStopFlow,
                    onCancel: _cancelStopFlow,
                  ),
              ],
            ),
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
    return ChorokCard(
      backgroundColor: AppTheme.darkBg, // Fireflies 가림
      borderColor: _kGreen.withValues(alpha: timer.isPaused ? 0.25 : 0.45),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceSM,
      ),
      child: Text(
        timer.formattedTime,
        style: AppTheme.rowText.copyWith(
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
          letterSpacing: 2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── 함께 읽는 독자 CTA ────────────────────────────────────────────────────

// ─── 이름 있는 독자 오브 레이어 ──────────────────────────────────────────
// 캔버스 기반 오브/반딧불 렌더링은 세션의 몰입 레이어이므로 카드 규칙 적용 예외다.
class _NamedReaderOrbs extends StatelessWidget {
  final List<UserProfile> mutuals;
  final Map<String, ReadingPresenceInfo> presences;
  final int neighborCount;
  final double time;
  final bool showNames;

  const _NamedReaderOrbs({
    required this.mutuals,
    required this.presences,
    required this.neighborCount,
    required this.time,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty && neighborCount == 0) return const SizedBox.shrink();
    final size = MediaQuery.of(context).size;
    final tp = time * 2 * math.pi;

    final widgets = <Widget>[];
    final densityScale = fireflyDensityScale(mutuals.length);
    final neighborLimit = math.min(neighborCount, 12);
    for (int i = 0; i < neighborLimit; i++) {
      _addOrb(
        widgets: widgets,
        size: size,
        tp: tp,
        seed: Object.hash('neighbor', i).abs(),
        radiusBase: 4.0,
        radiusRange: 8.0,
        layers: 1,
        label: '이웃',
        labelColor: context.appTextSecondary.withValues(alpha: 0.62),
        orbColor: context.appTextSecondary,
        orbAlpha: 0.35,
      );
    }

    for (int i = 0; i < math.min(mutuals.length, 12); i++) {
      final user = mutuals[i];
      final startedAt = presences[user.id]?.startedAt;
      final elapsed = startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt);
      final visual = fireflyVisualForElapsed(
        elapsed.isNegative ? Duration.zero : elapsed,
      );
      _addOrb(
        widgets: widgets,
        size: size,
        tp: tp,
        seed: user.username.hashCode.abs(),
        radiusBase: visual.radius,
        radiusRange: 0,
        layers: visual.layers,
        pulseAmplitude: visual.pulseAmplitude,
        sizeScale: densityScale,
        label: user.displayName,
        labelColor: _kGreen.withValues(alpha: 0.90),
        orbColor: _kGreen,
        orbAlpha: 1.0,
      );
    }

    return Stack(fit: StackFit.expand, children: widgets);
  }

  void _addOrb({
    required List<Widget> widgets,
    required Size size,
    required double tp,
    required int seed,
    required double radiusBase,
    required double radiusRange,
    int layers = 3,
    double pulseAmplitude = 0,
    double sizeScale = 1,
    required String label,
    required Color labelColor,
    required Color orbColor,
    required double orbAlpha,
  }) {
    final rng = math.Random(seed);

    final pulsePhase = (seed % 360) * math.pi / 180;
    final pulseScale = 1 + pulseAmplitude * math.sin(tp + pulsePhase);
    final orbR =
        (radiusBase + rng.nextDouble() * radiusRange) * sizeScale * pulseScale;

    // 서로 다른 정수 주파수 사인의 합 → 궤도처럼 안 보이고 무작위하게 떠돈다.
    // 정수 주파수라 40초 루프 이음새(1→0)에서 위치가 안 튄다.
    // span: 가장자리 여백만 남기고(위 타이머·아래 CTA 침범 방지) 전 영역을 훑는다.
    double wander(int axisSalt, double span) {
      final r = math.Random(seed ^ axisSalt);
      double sum = 0, ampTotal = 0;
      for (int h = 0; h < 3; h++) {
        final freq = 1 + r.nextInt(4); // 1~4
        final amp = 1.0 / (h + 1); // 1, 0.5, 0.33 — 저주파가 큰 흐름을 만든다
        final ph = r.nextDouble() * 2 * math.pi;
        sum += amp * math.sin(tp * freq + ph);
        ampTotal += amp;
      }
      return 0.5 + span * (sum / ampTotal);
    }

    final nx = wander(0x9e3779b9, 0.45);
    final ny = wander(0x85ebca6b, 0.40);
    final cx = nx * size.width;
    final cy = ny * size.height;

    final top = (cy - orbR).clamp(0.0, size.height - orbR * 2);
    final left = cx - orbR;

    widgets.add(
      Positioned(
        left: left,
        top: top,
        child: _SingleNamedOrb(
          radius: orbR,
          color: orbColor,
          alpha: orbAlpha,
          layers: layers,
        ),
      ),
    );

    widgets.add(
      Positioned(
        left: cx - 36,
        top: top + orbR * 2 + 5,
        width: 72,
        child: AnimatedOpacity(
          opacity: showNames ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.supportingText.copyWith(
              color: labelColor,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleNamedOrb extends StatelessWidget {
  final double radius;
  final Color color;
  final double alpha;
  final int layers;

  const _SingleNamedOrb({
    required this.radius,
    this.color = _kGreen,
    this.alpha = 1.0,
    this.layers = 3,
  });

  @override
  Widget build(BuildContext context) {
    final d = radius * 2;
    return SizedBox(
      width: d,
      height: d,
      child: CustomPaint(
        painter: _OrbRingPainter(
          radius: radius,
          color: color,
          alpha: alpha,
          layers: layers,
        ),
      ),
    );
  }
}

class _OrbRingPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double alpha;
  final int layers;

  const _OrbRingPainter({
    required this.radius,
    this.color = _kGreen,
    this.alpha = 1.0,
    this.layers = 3,
  }) : assert(layers >= 1 && layers <= 3);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // 시간이 지날수록 중심에서 바깥쪽으로 최대 3단까지 성장한다.
    if (layers >= 3) {
      canvas.drawCircle(
        c,
        radius,
        Paint()..color = color.withValues(alpha: 0.08 * alpha),
      );
    }
    if (layers >= 2) {
      canvas.drawCircle(
        c,
        radius * 0.65,
        Paint()..color = color.withValues(alpha: 0.20 * alpha),
      );
    }
    canvas.drawCircle(
      c,
      radius * 0.32,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_OrbRingPainter old) =>
      old.radius != radius ||
      old.color != color ||
      old.alpha != alpha ||
      old.layers != layers;
}

// ─── 배경 (순수 블랙) ──────────────────────────────────────────────────────
// 오브와 함께 한 장의 캔버스처럼 동작하는 배경이라 일반 카드가 아닌 렌더링 예외다.
class _SessionBackground extends StatelessWidget {
  const _SessionBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [AppTheme.darkBg, AppTheme.darkBg],
        ),
      ),
    );
  }
}

// ─── 나 — 중심 3단 링 오브 ────────────────────────────────────────────────
// true circle CustomPainter 예외: Live Forest의 pulse와 3단 링을 유지한다.
class _GlowOrb extends StatelessWidget {
  final double scale;
  final bool isPaused;

  const _GlowOrb({required this.scale, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final radius = screenW * 0.14;
    final d = radius * 2;
    final bright = isPaused ? _kGreen.withValues(alpha: 0.25) : _kGreen;

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
    // Layer 1 (외곽): 초록 토큰의 낮은 opacity
    canvas.drawCircle(
      c,
      radius,
      Paint()..color = AppTheme.primaryLight.withValues(alpha: 0.08),
    );
    // Layer 2 (중간): 초록 토큰의 중간 opacity
    canvas.drawCircle(
      c,
      radius * 0.65,
      Paint()..color = AppTheme.primaryLight.withValues(alpha: 0.20),
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
    final guideFrame = quoteGuideFrameRect(
      viewportSize,
      MediaQuery.paddingOf(context),
    );
    final cropFrame = ocrCaptureCropRect(guideFrame);

    if (kIsWeb) {
      final controller = _webCameraCtrl;
      if (controller == null) {
        throw StateError('Web camera is not ready.');
      }
      return controller
          .captureJpeg(cropRect: cropFrame, viewportSize: viewportSize)
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
    final rotationDegrees = _ocrFrameRotationDegrees(controller);
    debugPrint(
      'OCR capture: frame=${frame.width}x${frame.height} '
      'rot=$rotationDegrees viewport=$viewportSize crop=$cropFrame',
    );
    return _encodeCameraFrameToJpeg(
      frame,
      rotationDegrees: rotationDegrees,
      cropRect: cropFrame,
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
        backgroundColor: AppTheme.darkBg,
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
            const SizedBox(height: AppTheme.spaceLG),
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

  final sourceRect = sourceRectForViewportCrop(
    sourceSize: Size(image.width.toDouble(), image.height.toDouble()),
    cropRect: cropRect,
    viewportSize: viewportSize,
  );
  debugPrint(
    'OCR crop: rotated=${image.width}x${image.height} source=$sourceRect',
  );
  final left = sourceRect.left.ceil().clamp(0, image.width - 1);
  final top = sourceRect.top.ceil().clamp(0, image.height - 1);
  final right = sourceRect.right.floor().clamp(left + 1, image.width);
  final bottom = sourceRect.bottom.floor().clamp(top + 1, image.height);

  return img.copyCrop(
    image,
    x: left,
    y: top,
    width: math.max(1, right - left),
    height: math.max(1, bottom - top),
  );
}

int _ocrFrameRotationDegrees(CameraController controller) {
  // iOS는 camera_avfoundation이 스트림 connection의 videoOrientation을 기기
  // 방향으로 설정해 프레임이 이미 화면 방향으로 회전되어 도착한다.
  // sensorOrientation(90 고정)으로 또 회전하면 이중 회전 → 크롭 좌표가 틀어진다.
  if (defaultTargetPlatform == TargetPlatform.iOS) return 0;
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
      // 카메라 준비 전체화면 vignette — 카드가 아닌 몰입 배경(§5 예외).
      decoration: const BoxDecoration(
        color: Colors.black,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.darkCard, Colors.black],
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
            const SizedBox(height: AppTheme.spaceLG),
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
                  fontSize: AppTheme.fsRowText,
                  fontFamily: _kFont,
                ),
              ),
          ],
        ),
      ),
    );
  }
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
            final frameRect = quoteGuideFrameRect(size, padding);

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
                      left: 24,
                      right: 24,
                      top: frameRect.bottom + 18,
                      child: Text(
                        '페이지를 평평하게 펴고, 그림자가 지지 않게 촬영하세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: AppTheme.fsBody, // 15→14 스냅(§3)
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

class _QuoteGuidePainter extends CustomPainter {
  final Rect frameRect;
  final double pulse;

  const _QuoteGuidePainter({required this.frameRect, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    // 카메라 crop 가이드 프레임 cutout — 촬영 정렬용 물리 프레임으로 카드가 아니다(§5 예외).
    final cutout = RRect.fromRectAndRadius(frameRect, const Radius.circular(8));
    final overlayPath = Path()
      ..addRect(fullRect)
      ..addRRect(cutout)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );

    canvas.drawRRect(
      cutout,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7 + pulse * 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
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
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 0),
          child: Row(
            children: [
              _CaptureIconButton(
                icon: torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                label: torchOn ? '플래시 끄기' : '플래시 켜기',
                onTap: torchEnabled ? onTorch : null,
                active: torchOn,
              ),
              const Spacer(),
              _CaptureIconButton(
                icon: Icons.close_rounded,
                label: '닫기',
                onTap: onBack,
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
        padding: EdgeInsets.fromLTRB(28, 28, 28, bottom + 40),
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
            if (message != null || processing) ...[
              SizedBox(
                height: 22,
                child: Text(
                  message ?? '텍스트 인식 중...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message == null
                        ? Colors.white.withValues(alpha: 0.68)
                        : _kGreen.withValues(alpha: 0.9),
                    fontSize: AppTheme.fsSupporting,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLG),
            ],
            GestureDetector(
              onTap: canCapture ? onCapture : null,
              child: AnimatedOpacity(
                opacity: canCapture ? 1 : 0.45,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.black.withValues(alpha: 0.9),
                    size: 28,
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
            spacing: AppTheme.spaceLG,
            children: [
              Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 48,
              ),
              CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
              Text(
                '텍스트 인식 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppTheme.fsRowText,
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
                  fontSize: AppTheme.fsRowText,
                  fontWeight: FontWeight.w400,
                  fontFamily: _kFont,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '듣는 중...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: AppTheme.fsSupporting,
                  fontFamily: _kFont,
                ),
              ),
              if (widget.recognizedText.isNotEmpty) ...[
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLG,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      widget.recognizedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: AppTheme.fsRowText,
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
                        spacing: AppTheme.spaceLG,
                        children: [
                          Text(
                            '스와이프 하여 독서를 종료',
                            style: TextStyle(
                              color: _kGreen.withValues(alpha: 0.85),
                              fontSize: AppTheme.fsRowText,
                              fontFamily: _kFont,
                              letterSpacing: 0.5,
                            ),
                          ),
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
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusOuter,
                                  ),
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
                                            AppTheme.radiusInner,
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
                                              AppTheme.radiusOuter,
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
  final int currentPage;
  final int totalPages;
  final int activeReaderCount;
  final int nearbyReaderCount;
  final List<SessionPromptSeed> promptSeeds;
  final Color accentColor;
  final VoidCallback onStart;

  const _TodaysTopicOverlay({
    required this.bookTitle,
    required this.bookAuthor,
    this.coverUrl,
    required this.currentPage,
    required this.totalPages,
    required this.activeReaderCount,
    required this.nearbyReaderCount,
    required this.promptSeeds,
    required this.accentColor,
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
          color: AppTheme.darkBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = math.min(constraints.maxWidth, 430.0);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sectionGap,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, constraints.maxHeight),
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: constraints.maxHeight * 0.165,
                              bottom: AppTheme.sectionGap,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxWidth),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SessionEntryQuestionButton(
                                    label: sessionEntryPrompt(
                                      bookTitle: widget.bookTitle,
                                      currentPage: widget.currentPage,
                                      totalPages: widget.totalPages,
                                      now: DateTime.now(),
                                      seeds: widget.promptSeeds,
                                    ),
                                    accentColor: widget.accentColor,
                                  ),
                                  const SizedBox(height: AppTheme.sectionGap),
                                  BookCover(
                                    coverUrl: widget.coverUrl,
                                    gradientIndex: widget.bookTitle.hashCode
                                        .abs(),
                                    width: 160,
                                    height: 244,
                                    radius: AppTheme.radiusInner,
                                  ),
                                  const SizedBox(height: AppTheme.spaceXL),
                                  const _SessionEntryBadge(label: '6번째 세션'),
                                  const SizedBox(height: AppTheme.spaceMD),
                                  Text(
                                    widget.bookTitle,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTheme.rowText.copyWith(
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spaceSM),
                                  Text(
                                    _sessionEntryBookMeta(widget.bookAuthor),
                                    textAlign: TextAlign.center,
                                    style: AppTheme.supportingText.copyWith(
                                      color: AppTheme.textSecondary.withValues(
                                        alpha: 0.34,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.sectionGap),
                                  _SessionEntryStats(
                                    activeReaderCount: widget.activeReaderCount,
                                    nearbyReaderCount: widget.nearbyReaderCount,
                                    accentColor: widget.accentColor,
                                  ),
                                ],
                              ),
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

class _SessionEntryBadge extends StatelessWidget {
  final String label;

  const _SessionEntryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      inner: true,
      showBorder: false,
      backgroundColor: context.appPrimaryAccent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      child: Text(
        label,
        style: AppTheme.supportingText.copyWith(color: AppTheme.darkBg),
      ),
    );
  }
}

class _SessionEntryQuestionButton extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _SessionEntryQuestionButton({
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      key: const ValueKey('session-entry-question-button'),
      showBorder: false,
      backgroundColor: context.appCard,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceMD,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTheme.rowText.copyWith(color: accentColor),
      ),
    );
  }
}

class _SessionEntryStats extends StatelessWidget {
  final int activeReaderCount;
  final int nearbyReaderCount;
  final Color accentColor;

  const _SessionEntryStats({
    required this.activeReaderCount,
    required this.nearbyReaderCount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SessionEntryStatChip(
          value: activeReaderCount,
          dotColor: accentColor,
          textColor: accentColor,
        ),
        const SizedBox(width: AppTheme.spaceSM),
        _SessionEntryStatChip(
          value: nearbyReaderCount,
          dotColor: context.appTextTertiary,
          textColor: context.appTextSecondary,
        ),
      ],
    );
  }
}

class _SessionEntryStatChip extends StatelessWidget {
  final int value;
  final Color dotColor;
  final Color textColor;

  const _SessionEntryStatChip({
    required this.value,
    required this.dotColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 56,
      child: ChorokCard(
        inner: true,
        showBorder: false,
        backgroundColor: context.appCard,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상태 dot은 true circle이라 radius 규칙 예외다.
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text('$value', style: AppTheme.rowText.copyWith(color: textColor)),
          ],
        ),
      ),
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
            // 전체 화면 scrim은 카드가 아닌 몰입 레이어 렌더링 예외다.
            child: ColoredBox(color: AppTheme.darkBg.withValues(alpha: 0.55)),
          ),
        ),

        // 상단: 자물쇠 + 큰 타이머 + 날짜
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceXL,
                AppTheme.spaceLG,
                AppTheme.spaceXL,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LockBadge(
                    isPaused: timer.isPaused,
                    onLongPress: onLockLongPress,
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  Text(
                    timer.formattedTime,
                    // 세션 타이머는 design.md의 display 예외(60px대)다.
                    style: AppTheme.displayMedium.copyWith(
                      color: _kGreen.withValues(
                        alpha: timer.isPaused ? 0.55 : 1.0,
                      ),
                      fontSize: 64, // display 예외: 세션 타이머 대형 수치(§3)
                      height: 1.0,
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: [
                        Shadow(
                          color: _kGreen.withValues(alpha: 0.35),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),
                  Text(
                    streakDays > 0 ? '$_dateLabel +$streakDays일' : _dateLabel,
                    style: AppTheme.supportingText.copyWith(
                      color: AppTheme.textPrimary.withValues(alpha: 0.55),
                      letterSpacing: 0.4,
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
            padding: EdgeInsets.fromLTRB(
              AppTheme.spaceXL,
              0,
              AppTheme.spaceXL,
              bottom + AppTheme.sectionGap,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PlusButton(onTap: onPlusTap),
                const SizedBox(height: AppTheme.spaceMD),
                if (sentenceCount > 0) ...[
                  _SentenceBadge(count: sentenceCount, onTap: onSentencesTap),
                  const SizedBox(height: AppTheme.spaceMD),
                ] else
                  const SizedBox(height: AppTheme.spaceXS),
                Text(
                  bookTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.sectionTitle.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  bookAuthor,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.supportingText.copyWith(
                    color: _kGreen.withValues(alpha: 0.80),
                    letterSpacing: 0.3,
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
      key: const ValueKey('reading-session-lock-button'),
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: ChorokCard(
          backgroundColor: AppTheme.darkBg.withValues(alpha: 0.18),
          borderColor: _kGreen.withValues(alpha: alpha),
          padding: EdgeInsets.zero,
          child: Center(
            child: Icon(
              Icons.lock_outline_rounded,
              color: _kGreen.withValues(alpha: alpha),
              size: 20,
            ),
          ),
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
      child: SizedBox(
        width: 40,
        height: 40,
        child: ChorokCard(
          backgroundColor: AppTheme.darkBg.withValues(alpha: 0.18),
          borderColor: _kGreen.withValues(alpha: 0.85),
          padding: EdgeInsets.zero,
          child: Center(
            child: Icon(
              Icons.add_rounded,
              color: _kGreen.withValues(alpha: 0.95),
              size: 22,
            ),
          ),
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
      child: ChorokCard(
        showBorder: false,
        backgroundColor: _kGreen,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceLG,
          vertical: AppTheme.spaceMD,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_rounded, color: AppTheme.darkBg, size: 15),
            const SizedBox(width: AppTheme.spaceSM),
            Text(
              '+$count',
              style: AppTheme.rowText.copyWith(color: AppTheme.darkBg),
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
  final Future<void> Function(int index, int? page) onUpdatePage;
  final String bookTitle;
  final String bookAuthor;

  const _SentencesReviewSheet({
    required this.sentences,
    required this.onDelete,
    required this.onUpdateThought,
    required this.onUpdatePage,
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
    // 페이지 내림차순 정렬. 페이지가 없는 문장은 맨 뒤로.
    // 같은 페이지(또는 둘 다 페이지 없음)는 기록 순서를 유지한다.
    final indexed = widget.sentences.indexed.toList()
      ..sort((a, b) {
        final pa = a.$2.pageNumber;
        final pb = b.$2.pageNumber;
        final byPage = (pa == null && pb == null)
            ? 0
            : pa == null
            ? 1
            : pb == null
            ? -1
            : pb.compareTo(pa);
        return byPage != 0 ? byPage : a.$1.compareTo(b.$1);
      });
    _items = indexed.map((e) => e.$2).toList();
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

  Future<void> _editPage(int index) async {
    final item = _items[index];
    final result = await showDialog<({int? page})>(
      context: context,
      builder: (_) => _PageEditDialog(initialPage: item.pageNumber),
    );
    if (result == null) return;

    try {
      await widget.onUpdatePage(index, result.page);
      if (!mounted) return;
      setState(() {
        _items[index] = CollectedSentence(
          id: item.id,
          content: item.content,
          thought: item.thought,
          pageNumber: result.page,
        );
        _expandedIndex = index;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('페이지를 저장하지 못했어요. 다시 시도해주세요.')),
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
    final topInset = math.max(media.viewPadding.top, media.padding.top);
    final islandClearance = math.max(topInset, 66.0);
    final dismissTop = islandClearance + 8;
    final topGap = dismissTop + 58;

    return Container(
      height: size.height,
      color: Colors.black,
      child: Stack(
        children: [
          const Positioned.fill(child: _SentenceReviewBackground()),
          Positioned(
            top: dismissTop,
            left: 0,
            right: 0,
            child: _SentenceSheetDismissControl(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Column(
            children: [
              SizedBox(height: topGap),
              _PillTimerOnly(timer: timer),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLG,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _kGreen,
                  borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_outlined,
                      color: Colors.black,
                      size: 19,
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '이 책에서 모은 문장 ${_items.length}개',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: AppTheme.fsRowText,
                        fontWeight: FontWeight.w400,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space2XL),
              Expanded(
                child: Stack(
                  children: [
                    if (_items.isEmpty)
                      Center(
                        child: Text(
                          '아직 모은 문장이 없어요',
                          style: TextStyle(
                            color: _kGreen.withValues(alpha: 0.45),
                            fontSize: AppTheme.fsRowText,
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
                            onEditPage: () => _editPage(i),
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
                        fontSize: AppTheme.fsSectionTitle, // 24→18 스냅(§3)
                        fontWeight: FontWeight.w400,
                        fontFamily: _kFont,
                      ),
                    ),
                    if (widget.bookAuthor.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceSM),
                      Text(
                        widget.bookAuthor,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _kGreen.withValues(alpha: 0.86),
                          fontSize: AppTheme.fsRowText,
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

class _SentenceSheetDismissControl extends StatelessWidget {
  final VoidCallback onTap;

  const _SentenceSheetDismissControl({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: '문장 모아보기 닫기',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 88,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 34,
                  color: _kGreen.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeableSentenceReviewCard extends StatefulWidget {
  final CollectedSentence sentence;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onEditThought;
  final VoidCallback onEditPage;
  final VoidCallback onDelete;

  const _SwipeableSentenceReviewCard({
    super.key,
    required this.sentence,
    required this.expanded,
    required this.onTap,
    required this.onEditThought,
    required this.onEditPage,
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
                  color: AppTheme.warningColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
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
                widget.expanded ? AppTheme.space2XL : AppTheme.spaceLG,
                20,
                widget.expanded ? AppTheme.space2XL : AppTheme.spaceLG,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(
                  alpha: _deleting ? 0.78 : 0.94,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                border: Border.all(
                  color: _deleting
                      ? AppTheme.warningColor
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
                onEditPage: widget.onEditPage,
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
  final VoidCallback onEditPage;

  const _SentenceReviewRow({
    required this.sentence,
    required this.expanded,
    required this.deleting,
    required this.onEditThought,
    required this.onEditPage,
  });

  @override
  Widget build(BuildContext context) {
    final color = deleting ? AppTheme.warningColor : _kGreen;
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
              fontSize: AppTheme.fsRowText,
              height: 1.55,
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              fontFamily: _kFont,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spaceMD),
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
                          fontSize: AppTheme.fsRowText,
                          height: 1.72,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          fontFamily: _kFont,
                        ),
                      ),
                      if (sentence.thought.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceMD),
                        Text(
                          sentence.thought,
                          style: TextStyle(
                            color: color.withValues(alpha: 0.78),
                            fontSize: AppTheme.fsRowText,
                            height: 1.6,
                            letterSpacing: 0,
                            fontFamily: _kFont,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: AppTheme.spaceMD),
                        Text(
                          '아직 이 문장에 대한 생각이 없어요',
                          style: TextStyle(
                            color: color.withValues(alpha: 0.48),
                            fontSize: AppTheme.fsRowText,
                            height: 1.6,
                            letterSpacing: 0,
                            fontFamily: _kFont,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TextButton.icon(
                                  onPressed: deleting ? null : onEditPage,
                                  icon: Icon(
                                    Icons.bookmark_outline_rounded,
                                    size: 18,
                                    color: color,
                                  ),
                                  label: Text(
                                    sentence.pageNumber == null
                                        ? '쪽 추가'
                                        : '쪽 수정',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: AppTheme.fsRowText,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      fontFamily: _kFont,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceSM),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TextButton.icon(
                                  onPressed: deleting ? null : onEditThought,
                                  icon: Icon(
                                    Icons.edit_note_rounded,
                                    size: 18,
                                    color: color,
                                  ),
                                  label: Text(
                                    sentence.thought.isEmpty
                                        ? '생각 추가'
                                        : '생각 수정',
                                    style: TextStyle(
                                      color: color,
                                      fontSize: AppTheme.fsRowText,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                      fontFamily: _kFont,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Text(
                    sentence.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: AppTheme.fsRowText,
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
    final lift = !kIsWeb;
    final liftInset = lift ? keyboardInset : 0.0;
    // 키보드가 올라오면 시트를 키보드 위 공간에 맞춰, 입력란이 항상 키보드 바로
    // 위에 보이게 한다. 원문은 위에서 줄어들고 스크롤되며 입력란이 우선이다.
    final maxHeight =
        (media.size.height - media.viewPadding.top - liftInset - 12)
            .clamp(280.0, media.size.height * 0.92)
            .toDouble();
    final bottomPadding =
        media.padding.bottom + 22 + (lift ? 0 : keyboardInset);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: liftInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusOuter),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.space2XL,
              14,
              AppTheme.space2XL,
              bottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space2XL),
                Row(
                  children: [
                    const Icon(
                      Icons.edit_note_rounded,
                      color: _kGreen,
                      size: 22,
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '문장에 대한 생각',
                      style: TextStyle(
                        color: _kGreen,
                        fontSize: AppTheme.fsSectionTitle, // 24→18 스냅(§3)
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        fontFamily: _kFont,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceLG),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight * 0.32),
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spaceLG),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        widget.sentence.content,
                        style: const TextStyle(
                          color: _kGreen,
                          fontSize: AppTheme.fsRowText,
                          height: 1.72,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                          fontFamily: _kFont,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TextField(
                    controller: _thoughtCtrl,
                    autofocus: true,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    cursorColor: _kGreen,
                    style: const TextStyle(
                      color: _kGreen,
                      fontSize: AppTheme.fsRowText,
                      height: 1.62,
                      letterSpacing: 0,
                      fontFamily: _kFont,
                    ),
                    decoration: InputDecoration(
                      hintText: '이 문장을 보며 든 생각을 적어보세요',
                      hintStyle: TextStyle(
                        color: _kGreen.withValues(alpha: 0.42),
                        fontSize: AppTheme.fsRowText,
                        letterSpacing: 0,
                        fontFamily: _kFont,
                      ),
                      filled: true,
                      fillColor: AppTheme.darkCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
                        borderSide: BorderSide(
                          color: _kGreen.withValues(alpha: 0.45),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
                        borderSide: BorderSide(
                          color: _kGreen.withValues(alpha: 0.45),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
                        borderSide: const BorderSide(
                          color: _kGreen,
                          width: 1.4,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLG,
                        vertical: AppTheme.spaceLG,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),
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
                        fontSize: AppTheme.fsRowText,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        fontFamily: _kFont,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusOuter,
                        ),
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

class _PageEditDialog extends StatefulWidget {
  final int? initialPage;

  const _PageEditDialog({required this.initialPage});

  @override
  State<_PageEditDialog> createState() => _PageEditDialogState();
}

class _PageEditDialogState extends State<_PageEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialPage?.toString() ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() =>
      Navigator.pop(context, (page: int.tryParse(_ctrl.text.trim())));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
      ),
      title: const Text(
        '몇 쪽에서 모은 문장인가요?',
        style: TextStyle(
          color: _kGreen,
          fontSize: AppTheme.fsSectionTitle,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
          fontFamily: _kFont,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        cursorColor: _kGreen,
        onSubmitted: (_) => _save(),
        style: const TextStyle(
          color: _kGreen,
          fontSize: AppTheme.fsRowText,
          letterSpacing: 0,
          fontFamily: _kFont,
        ),
        decoration: InputDecoration(
          hintText: '쪽 번호',
          hintStyle: TextStyle(
            color: _kGreen.withValues(alpha: 0.42),
            fontFamily: _kFont,
          ),
          filled: true,
          fillColor: AppTheme.darkCard,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
            borderSide: BorderSide(color: _kGreen.withValues(alpha: 0.45)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
            borderSide: const BorderSide(color: _kGreen, width: 1.4),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (page: null)),
          child: Text(
            '비우기',
            style: TextStyle(
              color: _kGreen.withValues(alpha: 0.6),
              fontFamily: _kFont,
            ),
          ),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
            ),
          ),
          child: const Text(
            '저장',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              letterSpacing: 0,
              fontFamily: _kFont,
            ),
          ),
        ),
      ],
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
      // 전체화면 scrim vignette — CustomPainter 몰입 페이드로 카드가 아니다(§5 예외).
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
            // 비네트는 전체 화면 몰입 오버레이 예외다.
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.darkBg.withValues(alpha: 0.72),
                    AppTheme.darkBg.withValues(alpha: 0),
                    AppTheme.darkBg.withValues(alpha: 0.80),
                  ],
                  stops: [0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              top: AppTheme.spaceMD,
              bottom: bottom + AppTheme.spaceXL,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridWidth = math.min(constraints.maxWidth - 112, 288.0);
                final cardWidth = (gridWidth - 10) / 2;

                return Column(
                  children: [
                    _PillTimer(timer: timer),
                    const Spacer(flex: 52),
                    Text(
                      '문장을 가져올게요',
                      style: AppTheme.rowText.copyWith(
                        color: AppTheme.textPrimary.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXL),
                    SizedBox(
                      width: gridWidth,
                      child: Wrap(
                        spacing: AppTheme.spaceSM,
                        runSpacing: AppTheme.spaceSM,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.text_fields_rounded,
                              label: '직접적기',
                              onTap: onWrite,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.camera_alt_rounded,
                              label: '사진찍기',
                              onTap: onCamera,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
                            child: _ActionCard(
                              icon: Icons.image_rounded,
                              label: '불러오기',
                              onTap: onGallery,
                            ),
                          ),
                          SizedBox(
                            width: cardWidth,
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
                    ),
                    const Spacer(flex: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sectionGap,
                      ),
                      child: Text(
                        bookTitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sectionTitle.copyWith(color: _kGreen),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.sectionGap,
                      ),
                      child: Text(
                        bookAuthor,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.supportingText.copyWith(
                          color: AppTheme.textPrimary.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
    return ChorokCard(
      inner: true,
      backgroundColor: AppTheme.darkBg.withValues(alpha: 0.32),
      borderColor: _kGreen.withValues(alpha: timer.isPaused ? 0.30 : 0.95),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLG,
        vertical: AppTheme.spaceSM,
      ),
      child: Text(
        timer.formattedTime,
        style: AppTheme.rowText.copyWith(
          color: _kGreen.withValues(alpha: timer.isPaused ? 0.55 : 0.95),
          letterSpacing: 0,
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
    final iconColor = isActive
        ? AppTheme.warningColor
        : _kGreen.withValues(alpha: 0.95);
    final labelColor = isActive
        ? AppTheme.warningColor.withValues(alpha: 0.95)
        : _kGreen.withValues(alpha: 0.95);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        height: 132,
        child: ChorokCard(
          showBorder: false,
          backgroundColor: AppTheme.darkCard,
          padding: EdgeInsets.zero,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  label,
                  style: AppTheme.rowText.copyWith(
                    color: labelColor,
                    letterSpacing: 0,
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
            // 비네트는 전체 화면 몰입 오버레이 예외다.
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.darkBg.withValues(alpha: 0.72),
                    AppTheme.darkBg.withValues(alpha: 0),
                    AppTheme.darkBg.withValues(alpha: 0.96),
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
                  padding: const EdgeInsets.only(top: AppTheme.spaceMD),
                  child: _PillTimer(timer: timer),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: bottom + AppTheme.sectionGap,
                  ),
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
                        const SizedBox(height: AppTheme.spaceXS),
                        Text(
                          readersCount > 0
                              ? '함께 읽는 $readersCount명의 초록 확인'
                              : '함께 읽는 초록 확인',
                          style: AppTheme.rowText.copyWith(
                            color: _kGreen.withValues(alpha: 0.85),
                            letterSpacing: 0.3,
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
// 시드 기반 시간·책과 이웃 목록은 디자인 앱 전용이다.
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

const _kMockNeighbors = [
  (name: '익명의 나뭇잎', bookTitle: '전쟁과 평화 4', author: '레프 톨스토이', time: '00:30:25'),
  (
    name: '용기리기리',
    bookTitle: '사체와 죽어가는 이의 대화',
    author: 'D.A.F.사드',
    time: '00:20:15',
  ),
  (
    name: '익명의 초록나무',
    bookTitle: '다섯 개의 오렌지 나무',
    author: '아서 코난 도일',
    time: '00:05:45',
  ),
  (name: '남냥콩떡', bookTitle: '디자인 미학', author: '제인 포지', time: '00:05:45'),
];

String _seededTimer(String username) {
  final hash = username.codeUnits.fold(0, (a, b) => a + b);
  final mins = 3 + (hash % 57);
  final secs = username.hashCode.abs() % 60;
  return '00:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

({String title, String author}) _seededBook(String username) {
  final idx = username.hashCode.abs() % _kMockBooks.length;
  return _kMockBooks[idx];
}

({String title, String author}) _presenceBookFor(
  ReadingPresenceInfo? presence,
  String username,
) {
  if (presence?.hasTitle ?? false) {
    return (title: presence!.title!, author: presence.author ?? '');
  }
  return kUseMock ? _seededBook(username) : (title: '책 정보 없음', author: '');
}

String _readerTime(UserProfile user, Map<String, ReadingPresenceInfo> readers) {
  final startedAt = readers[user.id]?.startedAt;
  if (startedAt == null) {
    return kUseMock ? _seededTimer(user.username) : '--:--:--';
  }
  return _formatStoppedTime(
    DateTime.now().difference(startedAt).inSeconds.clamp(0, 359999),
  );
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
    final books =
        fireflyAsync.valueOrNull?.books ??
        const <String, ReadingPresenceInfo>{};
    final size = MediaQuery.sizeOf(context);
    final panelHeight = size.height * 0.80;

    void changeTab(int i) {
      setState(() => _tab = i);
      _pageCtrl.animateToPage(
        i,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }

    return SizedBox(
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: panelHeight,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.98),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusOuter),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLG,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text(
                          '함께 읽는 친구',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppTheme.fsSectionTitle, // 20→18 스냅(§3)
                            height: 1,
                            fontWeight: FontWeight.w400,
                            fontFamily: _kFont,
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _ReadersFilter(
                            current: _tab,
                            onChanged: changeTab,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLG),
                  Expanded(
                    child: fireflyAsync.isLoading && !fireflyAsync.hasValue
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: _kGreen,
                              strokeWidth: 2,
                            ),
                          )
                        : PageView(
                            controller: _pageCtrl,
                            onPageChanged: (i) => setState(() => _tab = i),
                            children: [
                              _PeopleTab(mutuals: mutuals, readers: books),
                              _BooksTab(mutuals: mutuals, books: books),
                            ],
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

// 사람 / 책을 좌우로 넘기는 필터. 본문 PageView와 같은 상태를 공유한다.
class _ReadersFilter extends StatelessWidget {
  final int current;
  final ValueChanged<int> onChanged;

  const _ReadersFilter({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: current == 0 ? '친구 필터, 책으로 전환' : '책 필터, 친구로 전환',
      button: true,
      child: GestureDetector(
        key: const ValueKey('readers-sheet-filter'),
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) {
          onChanged(details.localPosition.dx < AppTheme.spaceXL * 2 ? 0 : 1);
        },
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 100) return;
          onChanged(velocity < 0 ? 1 : 0);
        },
        child: SizedBox(
          width: AppTheme.spaceXL * 4,
          height: kMinInteractiveDimension,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.darkNested,
              borderRadius: BorderRadius.circular(AppTheme.radiusInner),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  key: const ValueKey('readers-sheet-filter-thumb'),
                  alignment: current == 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceXS),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInner,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.people_rounded,
                          color: current == 0
                              ? _kGreen
                              : Colors.white.withValues(alpha: 0.48),
                          size: AppTheme.fsSectionTitle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: current == 1
                              ? _kGreen
                              : Colors.white.withValues(alpha: 0.48),
                          size: AppTheme.fsSectionTitle,
                        ),
                      ),
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

// ─── 사람들 탭 ─────────────────────────────────────────────────────────────
class _PeopleTab extends StatelessWidget {
  final List<UserProfile> mutuals;
  final Map<String, ReadingPresenceInfo> readers;

  const _PeopleTab({required this.mutuals, required this.readers});

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty && !kUseMock) {
      return const _ReadersEmptyState();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        for (final user in mutuals.take(3))
          _PersonReaderRow(
            name: user.displayName,
            bookTitle: _presenceBookFor(readers[user.id], user.username).title,
            time: _readerTime(user, readers),
            seed: user.username,
            active: true,
          ),
        if (kUseMock) ...[
          const SizedBox(height: AppTheme.spaceLG),
          const _ReaderSectionTitle('함께 읽는 이웃'),
          const SizedBox(height: AppTheme.spaceLG),
          for (final neighbor in _kMockNeighbors)
            _PersonReaderRow(
              name: neighbor.name,
              bookTitle: neighbor.bookTitle,
              time: neighbor.time,
              seed: neighbor.name,
              active: false,
            ),
        ],
      ],
    );
  }
}

class _PersonReaderRow extends StatelessWidget {
  final String name;
  final String bookTitle;
  final String time;
  final String seed;
  final bool active;

  const _PersonReaderRow({
    required this.name,
    required this.bookTitle,
    required this.time,
    required this.seed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = active ? _kGreen : Colors.white.withValues(alpha: 0.86);
    return _ReaderRowFrame(
      child: Row(
        children: [
          _SheetOrb(seed: seed, active: active),
          const SizedBox(width: AppTheme.spaceMD),
          SizedBox(
            width: 104,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: AppTheme.fsBody, // 15→14 스냅(§3)
                fontWeight: FontWeight.w400,
                fontFamily: _kFont,
              ),
            ),
          ),
          Expanded(
            child: Text(
              bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: active ? 0.34 : 0.30),
                fontSize: AppTheme.fsCaption, // 11→10 스냅(§3)
                fontWeight: FontWeight.w400,
                fontFamily: _kFont,
              ),
            ),
          ),
          Icon(
            Icons.favorite_border_rounded,
            color: active ? _kGreen : Colors.white.withValues(alpha: 0.86),
            size: 18,
          ),
          const SizedBox(width: 14),
          Text(
            time,
            style: TextStyle(
              color: active ? _kGreen : Colors.white.withValues(alpha: 0.86),
              fontSize: AppTheme.fsBody,
              fontWeight: FontWeight.w400,
              fontFamily: _kFont,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 책 탭 ────────────────────────────────────────────────────────────────
class _BooksTab extends StatelessWidget {
  final List<UserProfile> mutuals;
  final Map<String, ReadingPresenceInfo> books;

  const _BooksTab({required this.mutuals, required this.books});

  @override
  Widget build(BuildContext context) {
    if (mutuals.isEmpty && !kUseMock) {
      return const _ReadersEmptyState();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        for (final user in mutuals.take(3))
          _BookReaderRow(
            book: _presenceBookFor(books[user.id], user.username),
            seed: user.username,
            coverUrl: books[user.id]?.coverUrl,
            active: true,
          ),
        if (kUseMock) ...[
          const SizedBox(height: AppTheme.spaceLG),
          const _ReaderSectionTitle('함께 읽는 이웃'),
          const SizedBox(height: AppTheme.spaceLG),
          for (var i = 0; i < _kMockNeighbors.length; i++)
            _BookReaderRow(
              book: (
                title: _kMockNeighbors[i].bookTitle,
                author: _kMockNeighbors[i].author,
              ),
              seed: _kMockNeighbors[i].name,
              coverUrl: null,
              active: false,
            ),
        ],
      ],
    );
  }
}

class _ReadersEmptyState extends StatelessWidget {
  const _ReadersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '지금 함께 읽는 친구가 없어요',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: AppTheme.fsBody,
          fontFamily: _kFont,
        ),
      ),
    );
  }
}

class _BookReaderRow extends StatelessWidget {
  final ({String title, String author}) book;
  final String seed;
  final String? coverUrl;
  final bool active;

  const _BookReaderRow({
    required this.book,
    required this.seed,
    required this.coverUrl,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = active ? _kGreen : Colors.white.withValues(alpha: 0.86);
    return _ReaderRowFrame(
      child: Row(
        children: [
          _SheetOrb(seed: seed, active: active),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: AppTheme.fsBody, // 15→14 스냅(§3)
                    height: 1.05,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: active ? 0.36 : 0.34),
                    fontSize: AppTheme.fsSupporting,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    fontFamily: _kFont,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            active ? Icons.bookmark_border_rounded : Icons.bookmark_outline,
            color: active ? _kGreen : Colors.white.withValues(alpha: 0.86),
            size: 18,
          ),
          const SizedBox(width: AppTheme.space2XL),
          BookCover(
            coverUrl: coverUrl,
            gradientIndex: book.title.hashCode.abs(),
            width: 36,
            height: 56,
            radius: AppTheme.radiusInner,
          ),
        ],
      ),
    );
  }
}

class _ReaderRowFrame extends StatelessWidget {
  final Widget child;

  const _ReaderRowFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
      ),
      child: child,
    );
  }
}

class _ReaderSectionTitle extends StatelessWidget {
  final String text;

  const _ReaderSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: AppTheme.fsSectionTitle, // 19→18 스냅(§3)
        fontWeight: FontWeight.w400,
        fontFamily: _kFont,
      ),
    );
  }
}

// ─── 공통 — 시트용 오브 ────────────────────────────────────────────────────
class _SheetOrb extends StatelessWidget {
  final String seed;
  final bool active;

  const _SheetOrb({required this.seed, required this.active});

  @override
  Widget build(BuildContext context) {
    final r = active ? 11.0 : 9.0;
    return SizedBox(
      width: r * 2,
      height: r * 2,
      child: CustomPaint(
        painter: _OrbRingPainter(
          radius: r,
          color: active ? _kGreen : Colors.white,
          alpha: active ? 1 : 0.72,
        ),
      ),
    );
  }
}

String _formatStoppedTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

String _sessionDateLabel(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final weekday = weekdays[(date.weekday - 1).clamp(0, 6)];
  return '$y.$m.$d($weekday)';
}

// ─── 페이지 입력 오버레이 ─────────────────────────────────────────────────────
class _PageInputOverlay extends StatefulWidget {
  final String timeText;
  final DateTime sessionStartedAt;
  final int initialPage;
  final int totalPages;
  final ValueChanged<int> onConfirm;
  final VoidCallback onCancel;

  const _PageInputOverlay({
    required this.timeText,
    required this.sessionStartedAt,
    required this.initialPage,
    required this.totalPages,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_PageInputOverlay> createState() => _PageInputOverlayState();
}

class _PageInputOverlayState extends State<_PageInputOverlay> {
  late int _page;
  bool _hasRecordedPage = false;

  @override
  void initState() {
    super.initState();
    _page = widget.initialPage.clamp(0, _maxPage);
  }

  int get _maxPage => widget.totalPages > 0 ? widget.totalPages : 9999;

  void _increment() => setState(() {
    _page = (_page + 1).clamp(0, _maxPage);
    _hasRecordedPage = true;
  });

  void _decrement() => setState(() {
    _page = (_page - 1).clamp(0, _maxPage);
    _hasRecordedPage = true;
  });

  void _handleBackgroundTap() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
      return;
    }
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final ratio = _maxPage > 0 ? _page / _maxPage : 0.0;
    final isActive = _hasRecordedPage;
    final promptColor = isActive
        ? _kGreen.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.46);
    final pageColor = isActive ? _kGreen : Colors.white.withValues(alpha: 0.28);
    final editColor = isActive
        ? _kGreen.withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.18);
    final trackColor = isActive ? _kGreen : AppTheme.darkNested;
    final buttonBg = isActive ? _kGreen : AppTheme.darkNested;
    final buttonFg = isActive
        ? Colors.black
        : Colors.white.withValues(alpha: 0.35);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _handleBackgroundTap,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.80)),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  children: [
                    _PageInputLockBadge(isActive: isActive),
                    const SizedBox(height: 20),
                    Text(
                      widget.timeText,
                      style: TextStyle(
                        color: _kGreen.withValues(alpha: 0.22),
                        fontSize: 64, // display 예외: 세션 타이머 대형 수치(§3)
                        height: 1.0,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1,
                        fontFamily: _kFont,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _sessionDateLabel(widget.sessionStartedAt),
                      style: TextStyle(
                        color: _kGreen.withValues(alpha: 0.20),
                        fontSize: AppTheme.fsSupporting,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w400,
                        fontFamily: _kFont,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '오늘 몇 페이지까지 읽었나요?',
                      style: TextStyle(
                        fontFamily: _kFont,
                        fontSize: AppTheme.fsBody, // 15→14 스냅(§3)
                        color: promptColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2XL),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StepButton(icon: Icons.remove, onTap: _decrement),
                        const SizedBox(width: AppTheme.space2XL),
                        _PageBox(
                          page: _page,
                          totalPages: widget.totalPages,
                          pageColor: pageColor,
                          editColor: editColor,
                          borderColor: Colors.white.withValues(alpha: 0.04),
                          onChanged: (v) => setState(() {
                            _page = v.clamp(0, _maxPage);
                            _hasRecordedPage = true;
                          }),
                        ),
                        const SizedBox(width: AppTheme.space2XL),
                        _StepButton(icon: Icons.add, onTap: _increment),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceLG),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 346),
                      child: SizedBox(
                        width: double.infinity,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: trackColor,
                            inactiveTrackColor: AppTheme.darkNested,
                            thumbColor: trackColor,
                            overlayColor: trackColor.withValues(alpha: 0.14),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16,
                            ),
                          ),
                          child: Slider(
                            value: ratio,
                            onChanged: (v) => setState(() {
                              _page = (v * _maxPage).round().clamp(0, _maxPage);
                              _hasRecordedPage = true;
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space2XL),
                    GestureDetector(
                      onTap: isActive
                          ? () {
                              HapticFeedback.mediumImpact();
                              widget.onConfirm(_page);
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceLG,
                          vertical: AppTheme.spaceMD,
                        ),
                        decoration: BoxDecoration(
                          color: buttonBg,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusOuter,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: buttonFg,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '기록 및 독서종료',
                              style: TextStyle(
                                fontFamily: _kFont,
                                fontSize: AppTheme.fsBody, // 15→14 스냅(§3)
                                color: buttonFg,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onCancel();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceXS),
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusOuter,
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.82),
                              width: 1.2,
                            ),
                            color: const Color(
                              0xFF181818,
                            ).withValues(alpha: 0.94),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.48),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageInputLockBadge extends StatelessWidget {
  final bool isActive;

  const _PageInputLockBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? _kGreen : _kGreen.withValues(alpha: 0.10);
    final fg = isActive ? Colors.black : _kGreen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
        color: bg,
        border: Border.all(color: _kGreen.withValues(alpha: 0.24)),
      ),
      child: Icon(Icons.lock_rounded, color: fg, size: 18),
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
          color: AppTheme.darkNested,
        ),
        child: Icon(icon, size: 16, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _PageBox extends StatefulWidget {
  final int page;
  final int totalPages;
  final Color pageColor;
  final Color editColor;
  final Color borderColor;
  final ValueChanged<int> onChanged;

  const _PageBox({
    required this.page,
    required this.totalPages,
    required this.pageColor,
    required this.editColor,
    required this.borderColor,
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
        width: 148,
        height: 60,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _kFont,
            fontSize: 40, // display 예외: 페이지 대형 수치(§3)
            color: widget.pageColor,
            fontWeight: FontWeight.w300,
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
              borderSide: BorderSide(
                color: widget.pageColor.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
              borderSide: BorderSide(color: widget.pageColor),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (text) {
            final v = int.tryParse(text.trim());
            if (v != null) widget.onChanged(v);
          },
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
        width: 148,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
          border: Border.all(color: widget.borderColor),
          color: AppTheme.darkCard,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.edit, size: 13, color: widget.editColor),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${widget.page}',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: _kFont,
                    fontSize: 40, // display 예외: 페이지 대형 수치(§3)
                    color: widget.pageColor,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            if (widget.totalPages > 0) ...[
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                '/ ${widget.totalPages}',
                style: TextStyle(
                  fontFamily: _kFont,
                  fontSize: AppTheme.fsRowText,
                  color: Colors.white.withValues(alpha: 0.12),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
