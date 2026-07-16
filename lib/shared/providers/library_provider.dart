import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../core/services/db_service.dart';
import '../models/reading_session.dart';
import '../repositories/supabase_book_repository.dart';

class LibraryNotifier extends Notifier<List<Book>> {
  @override
  List<Book> build() {
    if (kUseMock) return List.from(_kMockBooks);
    Future.microtask(_loadFromDb);
    return [];
  }

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> _loadFromDb() async {
    if (_isLoading) return;
    _isLoading = true;
    debugPrint('LibraryProvider: Starting _loadFromDb');
    try {
      final repo = ref.read(supabaseBookRepositoryProvider);
      final loaded = await repo.getAllBooks();

      // _loadFromDb 대기 중 addBook으로 추가된 책 보존
      final extra = state
          .where((b) => !loaded.any((lb) => lb.id == b.id))
          .toList();
      state = [...loaded, ...extra];
      debugPrint('LibraryProvider: Loaded ${loaded.length} books');
    } catch (e) {
      debugPrint('LibraryProvider: Error loading books: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// 당겨서 새로고침용. invalidate 하면 state 가 [] 로 초기화돼 목록이 깜빡이므로,
  /// 기존 state 를 유지한 채 다시 읽는 _loadFromDb 를 그대로 쓴다.
  Future<void> reload() => _loadFromDb();

  bool addBook(Book book) {
    final isDuplicate =
        book.isbn != null &&
        book.isbn!.isNotEmpty &&
        state.any((b) => b.isbn == book.isbn);
    if (isDuplicate) return false;
    state = [...state, book];
    if (kUseMock) return true;
    // fire-and-forget — UX는 즉시 반영, Supabase 저장은 백그라운드
    ref.read(supabaseBookRepositoryProvider).saveFromBook(book);
    return true;
  }

  void updateCurrentPage(String bookId, int newPage) {
    debugPrint('LibraryProvider: updateCurrentPage($bookId, $newPage)');
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) {
      debugPrint('LibraryProvider: Book NOT FOUND for id: $bookId');
      return;
    }
    final old = state[idx];
    final clamped = old.totalPages > 0
        ? newPage.clamp(0, old.totalPages)
        : newPage;
    // 페이지가 실제로 바뀌었다는 건 방금 읽었다는 뜻 — 홈 '읽고 있는 책' 정렬 신호로도 쓴다.
    final justRead = clamped != old.currentPage;

    // 상태 결정 로직:
    // 1. 페이지가 끝까지 도달하면 completed
    // 2. 페이지가 0보다 크고 끝보다 작으면 reading
    // 3. 페이지가 0이면 기존 상태 유지 (혹은 독서 시작 전으로 간주할지 고민 필요)
    ReadingStatus newStatus = old.status;
    if (old.totalPages > 0) {
      if (clamped >= old.totalPages) {
        newStatus = ReadingStatus.completed;
      } else if (clamped > 0) {
        newStatus = ReadingStatus.reading;
      }
    }

    final now = DateTime.now();
    final updated = old.copyWith(
      currentPage: clamped,
      status: newStatus,
      completedAt:
          (newStatus == ReadingStatus.completed &&
              old.status != ReadingStatus.completed)
          ? now
          : (newStatus != ReadingStatus.completed ? null : old.completedAt),
      lastSessionStartedAt: justRead ? now : old.lastSessionStartedAt,
    );

    debugPrint('LibraryProvider: Updated status to ${updated.status}');
    state = [...state]..[idx] = updated;

    if (kUseMock) return;
    ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    if (justRead) {
      ref.read(supabaseBookRepositoryProvider).markSessionStarted(bookId, now);
    }
  }

  /// 완독 취소 — status를 reading으로 되돌리고 completedAt 초기화
  Future<void> cancelCompletion(String bookId) async {
    debugPrint('LibraryProvider: cancelCompletion($bookId)');
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;

    final old = state[idx];
    if (old.status != ReadingStatus.completed) return;

    final updated = Book(
      id: old.id,
      title: old.title,
      author: old.author,
      isbn: old.isbn,
      coverUrl: old.coverUrl,
      currentPage: old.currentPage,
      totalPages: old.totalPages,
      status: ReadingStatus.reading,
      totalReadingHours: old.totalReadingHours,
      savedSentences: old.savedSentences,
      completedAt: null,
      genre: old.genre,
      description: old.description,
      addedAt: old.addedAt,
      lastSessionStartedAt: old.lastSessionStartedAt,
    );

    state = [...state]..[idx] = updated;

    if (kUseMock) return;
    await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
  }

  /// 명시적으로 완독 처리
  Future<void> markAsCompleted(String bookId) async {
    debugPrint('LibraryProvider: markAsCompleted($bookId)');
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;

    final old = state[idx];

    final updated = old.copyWith(
      currentPage: old.totalPages > 0 ? old.totalPages : old.currentPage,
      status: ReadingStatus.completed,
      completedAt: DateTime.now(),
    );

    state = [...state]..[idx] = updated;

    if (kUseMock) return;
    await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
  }

  /// 책의 총 페이지 수 갱신.
  ///
  /// 알라딘 ItemSearch 응답에서 누락된 페이지 수를 ItemLookUp 보강 결과로 채우거나,
  /// 사용자가 수동 입력했을 때 사용한다.
  void updateTotalPages(String bookId, int totalPages) {
    if (totalPages <= 0) return;
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;
    final old = state[idx];
    if (old.totalPages == totalPages) return;
    final clampedCurrent = old.currentPage > totalPages
        ? totalPages
        : old.currentPage;
    final updated = old.copyWith(
      totalPages: totalPages,
      currentPage: clampedCurrent,
    );
    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
  }

  /// 라이브 포레스트(독서 세션) 시작 시각 기록 — 홈 '읽고 있는 책' 정렬 기준.
  void markSessionStarted(String bookId) {
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;
    final now = DateTime.now();
    final updated = state[idx].copyWith(lastSessionStartedAt: now);
    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    ref.read(supabaseBookRepositoryProvider).markSessionStarted(bookId, now);
  }

  void deleteBook(String bookId) {
    state = state.where((b) => b.id != bookId).toList();
    if (kUseMock) return;
    ref.read(supabaseBookRepositoryProvider).deleteByBookId(bookId);
  }

  /// 기존 독서 기록과 내부 ID는 유지하고 선택한 판본의 서지 정보만 교체한다.
  Future<void> replaceBookVersion(String bookId, Book version) async {
    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;

    final old = state[idx];
    final totalPages = version.totalPages > 0
        ? version.totalPages
        : old.totalPages;
    final currentPage = totalPages > 0
        ? old.currentPage.clamp(0, totalPages)
        : old.currentPage;
    final updated = Book(
      id: old.id,
      title: version.title,
      author: version.author,
      coverUrl: version.coverUrl,
      isbn: version.isbn,
      status: old.status,
      totalPages: totalPages,
      currentPage: currentPage,
      totalReadingHours: old.totalReadingHours,
      savedSentences: old.savedSentences,
      completedAt: old.completedAt,
      genre: version.genre ?? old.genre,
      description: version.description ?? old.description,
      addedAt: old.addedAt,
      lastSessionStartedAt: old.lastSessionStartedAt,
    );

    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
  }

  /// 서재 화면에서 직접 문장 추가
  Future<void> addSentence(
    String bookId,
    String content, {
    String? thought,
    int? pageNumber,
  }) async {
    if (kUseMock) return;

    final idx = state.indexWhere((b) => b.id == bookId);
    if (idx < 0) return;

    final old = state[idx];
    final trimmed = content.trim();

    await ref
        .read(dbServiceProvider)
        .saveSentenceStandalone(
          bookId: bookId,
          content: trimmed,
          thought: thought,
          pageNumber: pageNumber,
        );
    final updated = old.copyWith(
      savedSentences: [...old.savedSentences, trimmed],
    );
    state = [...state]..[idx] = updated;
    await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
  }

  Future<void> updateSentenceThought({
    required String sentenceId,
    String? thought,
  }) async {
    if (kUseMock) return;
    await ref
        .read(dbServiceProvider)
        .updateSentenceThought(sentenceId, thought);
  }

  bool containsIsbn(String? isbn13) {
    if (isbn13 == null || isbn13.isEmpty) return false;
    return state.any((b) => b.isbn == isbn13);
  }

  bool containsByTitleAuthor(String title, String author) {
    return state.any((b) => b.title == title && b.author == author);
  }

  /// 수동 독서 기록 추가
  Future<void> addManualReadingLog({
    required String bookId,
    required int startPage,
    required int endPage,
    required int durationSeconds,
    required DateTime sessionDate,
  }) async {
    final pagesRead = (endPage - startPage).clamp(0, 999999);
    final idx = state.indexWhere((b) => b.id == bookId);

    if (idx >= 0) {
      final old = state[idx];
      final newCurrentPage = endPage > old.currentPage
          ? endPage
          : old.currentPage;
      var newStatus = old.status;
      var completedAt = old.completedAt;

      if (old.status != ReadingStatus.completed &&
          old.totalPages > 0 &&
          newCurrentPage >= old.totalPages) {
        newStatus = ReadingStatus.completed;
        completedAt = DateTime.now();
      } else if (newCurrentPage > 0 && old.status == ReadingStatus.wantToRead) {
        newStatus = ReadingStatus.reading;
      }

      final updatedBook = old.copyWith(
        currentPage: newCurrentPage,
        status: newStatus,
        completedAt: completedAt,
        totalReadingHours: old.totalReadingHours + durationSeconds / 3600.0,
      );
      state = [...state]..[idx] = updatedBook;
      await ref.read(supabaseBookRepositoryProvider).saveFromBook(updatedBook);
    }

    await ref
        .read(dbServiceProvider)
        .saveSession(
          bookId: bookId,
          durationSeconds: durationSeconds,
          sentences: const [],
          startedAt: sessionDate,
          endedAt: sessionDate.add(Duration(seconds: durationSeconds)),
          pagesRead: pagesRead,
          clientSessionId:
              'manual_${sessionDate.millisecondsSinceEpoch}_$bookId',
        );
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, List<Book>>(
  LibraryNotifier.new,
);

// ─── 초기 목업 데이터 ────────────────────────────────────────────────────────
final _kMockBooks = [
  // reading
  Book(
    id: '1',
    title: '채식주의자 (리마스터판)',
    author: '한강',
    coverUrl:
        'https://image.aladin.co.kr/product/29137/2/cover500/8936434594_2.jpg',
    status: ReadingStatus.reading,
    totalPages: 276,
    currentPage: 196,
    totalReadingHours: 2.5,
    savedSentences: ['나는 채식주의자가 되기로 했다.', '꿈 때문에.'],
    genre: '소설',
    description:
        '어느 날 갑자기 채식을 선언한 영혜와 그를 둘러싼 가족의 시선을 따라가며, 몸과 욕망, 폭력과 침묵의 감각을 집요하게 묻는 소설입니다.',
  ),
  Book(
    id: '2',
    title: '파친코',
    author: '이민진',
    coverUrl:
        'https://image.aladin.co.kr/product/29496/39/cover500/s382931339_2.jpg',
    status: ReadingStatus.reading,
    totalPages: 688,
    currentPage: 234,
    totalReadingHours: 8.2,
    genre: '역사소설',
    description:
        '재일조선인 가족의 삶을 여러 세대에 걸쳐 따라가며, 이주와 생존, 가족의 선택이 개인의 운명을 어떻게 바꾸는지 보여주는 장편소설입니다.',
  ),
  Book(
    id: '3',
    title: '지구 끝의 온실',
    author: '김초엽',
    coverUrl:
        'https://image.aladin.co.kr/product/27692/63/cover500/s222930473_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 304,
    currentPage: 88,
    totalReadingHours: 4.6,
    genre: 'SF',
    description:
        '더스트로 무너진 세계 이후의 시간을 배경으로, 식물과 인간, 기억과 회복이 서로를 어떻게 붙드는지 그리는 한국 SF 소설입니다.',
  ),
  // completed
  Book(
    id: '4',
    title: '82년생 김지영',
    author: '조남주',
    coverUrl:
        'https://image.aladin.co.kr/product/9476/48/cover500/8937473135_1.jpg',
    status: ReadingStatus.completed,
    totalPages: 190,
    currentPage: 190,
    totalReadingHours: 4.1,
    completedAt: DateTime(2026, 5, 2),
    genre: '소설',
    description:
        '평범하게 보이는 한 여성의 생애를 통해 한국 사회의 성별 경험과 일상의 구조적 차별을 압축적으로 드러내는 소설입니다.',
  ),
  Book(
    id: '5',
    title: '아몬드',
    author: '손원평',
    coverUrl:
        'https://image.aladin.co.kr/product/31893/32/cover500/k212833749_2.jpg',
    status: ReadingStatus.completed,
    totalPages: 264,
    currentPage: 264,
    totalReadingHours: 6.3,
    completedAt: DateTime(2026, 5, 5),
    genre: '소설',
    description:
        '감정을 잘 느끼지 못하는 소년 윤재가 여러 만남을 지나며 타인의 마음과 자신의 감각을 배워가는 성장소설입니다.',
  ),
  // wantToRead
  Book(
    id: '6',
    title: '소년이 온다',
    author: '한강',
    coverUrl:
        'https://image.aladin.co.kr/product/4086/97/cover500/8936434128_2.jpg',
    status: ReadingStatus.wantToRead,
    totalPages: 216,
    currentPage: 0,
    genre: '소설',
    description:
        '1980년 광주의 시간을 여러 인물의 목소리로 따라가며, 폭력 이후에도 사라지지 않는 기억과 애도의 문제를 묻는 소설입니다.',
  ),
  Book(
    id: '7',
    title: '불편한 편의점',
    author: '김호연',
    coverUrl:
        'https://image.aladin.co.kr/product/29045/74/cover500/k192836746_2.jpg',
    status: ReadingStatus.wantToRead,
    totalPages: 312,
    currentPage: 0,
    genre: '소설',
    description:
        '서울역 노숙인 독고가 편의점 야간 알바를 맡으며 손님과 이웃들의 삶에 작은 균열과 온기를 만드는 이야기입니다.',
  ),
  Book(
    id: '8',
    title: '달러구트 꿈 백화점',
    author: '이미예',
    coverUrl:
        'https://image.aladin.co.kr/product/24512/70/cover500/k392630952_2.jpg',
    status: ReadingStatus.wantToRead,
    totalPages: 304,
    currentPage: 0,
    genre: '판타지',
    description:
        '잠든 사람들이 꿈을 사러 가는 백화점을 배경으로, 꿈의 의미와 일상의 감정을 다정하게 풀어낸 판타지 소설입니다.',
  ),
  // 장르 다양성 (문학 외 카테고리) — 취향 트리맵/통계 목업용. 알라딘 API 실조회로 표지·쪽수 확보.
  Book(
    id: '9',
    title: '코스모스 (100만 부 기념판)',
    author: '칼 세이건',
    coverUrl:
        'https://image.aladin.co.kr/product/39676/50/cover500/k382130398_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 720,
    currentPage: 320,
    totalReadingHours: 5.5,
    genre: '과학',
    description: '우주와 생명, 인간 문명을 넘나드는 통찰로 세대를 이어 사랑받아 온 칼 세이건의 대중 과학서 고전입니다.',
  ),
  Book(
    id: '10',
    title: '자본론 1 - 상',
    author: '카를 마르크스',
    coverUrl:
        'https://image.aladin.co.kr/product/7114/32/cover500/8937604329_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 532,
    currentPage: 180,
    totalReadingHours: 3.8,
    genre: '경제·경영',
    description:
        '자본주의에 대한 철저한 분석과 비판을 통해 새로운 사회를 향해 나아가고자 했던 마르크스의 이론적 정수를 담은 고전입니다.',
  ),
  Book(
    id: '11',
    title: '클린 코드',
    author: '로버트 C. 마틴',
    coverUrl:
        'https://image.aladin.co.kr/product/3408/36/cover500/8966260950_2.jpg',
    status: ReadingStatus.reading,
    totalPages: 584,
    currentPage: 240,
    totalReadingHours: 3.2,
    genre: '기술·IT',
    description: '애자일 소프트웨어 장인 정신을 이야기하는 클린 코드 작성법의 고전적인 지침서입니다.',
  ),
  Book(
    id: '12',
    title: '미생',
    author: '윤태호',
    coverUrl:
        'https://image.aladin.co.kr/product/33648/82/cover500/k492939413_1.jpg',
    status: ReadingStatus.completed,
    totalPages: 228,
    currentPage: 228,
    totalReadingHours: 1.5,
    completedAt: DateTime(2026, 4, 18),
    genre: '만화',
    description: '미생 장그래가 대기업 인턴 사원으로 겪는 조직 생활을 통해 일과 인간관계를 그린 만화입니다.',
  ),
  Book(
    id: '13',
    title: '미움받을 용기',
    author: '기시미 이치로, 고가 후미타케',
    coverUrl:
        'https://image.aladin.co.kr/product/30782/55/cover500/k442831368_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 332,
    currentPage: 150,
    totalReadingHours: 2.8,
    genre: '인문',
    description: '아들러 심리학을 대화체로 풀어내며 타인의 시선에서 벗어난 삶의 방식을 이야기하는 책입니다.',
  ),
  Book(
    id: '14',
    title: '총 균 쇠',
    author: '재레드 다이아몬드',
    coverUrl:
        'https://image.aladin.co.kr/product/31629/43/cover500/8934942460_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 792,
    currentPage: 300,
    totalReadingHours: 4.5,
    genre: '역사',
    description: '환경과 지리가 인류 문명의 불평등을 어떻게 갈랐는지 추적하는 인류사·역사서의 고전입니다.',
  ),
  Book(
    id: '15',
    title: '팩트풀니스',
    author: '한스 로슬링',
    coverUrl:
        'https://image.aladin.co.kr/product/34538/43/cover500/8934933879_1.jpg',
    status: ReadingStatus.completed,
    totalPages: 400,
    currentPage: 400,
    totalReadingHours: 2.0,
    completedAt: DateTime(2026, 5, 20),
    genre: '사회',
    description: '데이터로 세상을 보는 법을 알려주며 우리가 세상을 오해하는 이유를 짚어주는 책입니다.',
  ),
  Book(
    id: '16',
    title: '여행의 이유',
    author: '김영하',
    coverUrl:
        'https://image.aladin.co.kr/product/33763/31/cover500/s332036339_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 256,
    currentPage: 100,
    totalReadingHours: 1.2,
    genre: '실용·생활',
    description: '떠남과 돌아옴을 반복하는 여행자의 시선으로 삶과 글쓰기를 돌아보는 에세이입니다.',
  ),
  Book(
    id: '17',
    title: '반 고흐, 영혼의 편지',
    author: '빈센트 반 고흐',
    coverUrl:
        'https://image.aladin.co.kr/product/35328/70/cover500/k192035578_1.jpg',
    status: ReadingStatus.reading,
    totalPages: 623,
    currentPage: 200,
    totalReadingHours: 1.8,
    genre: '예술',
    description: '동생 테오에게 보낸 편지를 통해 고흐의 내면과 예술적 열망을 들여다보는 서한집입니다.',
  ),
  // 문학·역사·철학 등 다양한 장르 30권 — 디자인 앱 목업 강화용
  Book(
    id: '18',
    title: '죄와 벌',
    author: '표도르 도스토옙스키',
    status: ReadingStatus.completed,
    totalPages: 780,
    currentPage: 780,
    totalReadingHours: 9.5,
    completedAt: DateTime(2025, 9, 12),
    genre: '소설',
    description:
        '가난한 대학생 라스콜니코프가 전당포 노파를 살해한 뒤 죄의식과 구원 사이에서 갈등하는 심리를 그린 러시아 고전 장편소설입니다.',
  ),
  Book(
    id: '19',
    title: '참을 수 없는 존재의 가벼움',
    author: '밀란 쿤데라',
    status: ReadingStatus.completed,
    totalPages: 460,
    currentPage: 460,
    totalReadingHours: 5.5,
    completedAt: DateTime(2025, 9, 24),
    genre: '소설',
    description:
        '프라하의 봄을 배경으로 사랑과 자유, 존재의 무거움과 가벼움 사이에서 흔들리는 인물들을 그린 철학적 소설입니다.',
  ),
  Book(
    id: '20',
    title: '백년의 고독',
    author: '가브리엘 가르시아 마르케스',
    status: ReadingStatus.completed,
    totalPages: 650,
    currentPage: 650,
    totalReadingHours: 7.0,
    completedAt: DateTime(2025, 10, 5),
    genre: '소설',
    description:
        '마콘도라는 가상의 마을에서 부엔디아 가문 7대에 걸쳐 이어지는 고독과 반복의 역사를 마술적 사실주의로 그린 소설입니다.',
  ),
  Book(
    id: '21',
    title: '이방인',
    author: '알베르 카뮈',
    status: ReadingStatus.completed,
    totalPages: 190,
    currentPage: 190,
    totalReadingHours: 2.5,
    completedAt: DateTime(2025, 10, 17),
    genre: '소설',
    description:
        '어머니의 장례식 다음 날 무심히 일상을 이어가던 뫼르소가 우연한 살인 이후 세상의 부조리와 마주하는 소설입니다.',
  ),
  Book(
    id: '22',
    title: '위대한 개츠비',
    author: 'F. 스콧 피츠제럴드',
    status: ReadingStatus.completed,
    totalPages: 280,
    currentPage: 280,
    totalReadingHours: 3.0,
    completedAt: DateTime(2025, 10, 29),
    genre: '소설',
    description:
        '화려한 재즈 시대 뉴욕을 배경으로, 옛사랑 데이지를 되찾으려는 개츠비의 꿈과 몰락을 그린 미국 문학의 고전입니다.',
  ),
  Book(
    id: '23',
    title: '1984',
    author: '조지 오웰',
    status: ReadingStatus.completed,
    totalPages: 400,
    currentPage: 400,
    totalReadingHours: 4.5,
    completedAt: DateTime(2025, 11, 9),
    genre: '소설',
    description:
        '빅브라더가 지배하는 전체주의 사회에서 사상과 언어까지 통제당하는 개인의 저항과 좌절을 그린 디스토피아 소설입니다.',
  ),
  Book(
    id: '24',
    title: '데미안',
    author: '헤르만 헤세',
    status: ReadingStatus.completed,
    totalPages: 260,
    currentPage: 260,
    totalReadingHours: 3.0,
    completedAt: DateTime(2025, 11, 20),
    genre: '소설',
    description: '소년 싱클레어가 데미안을 만나며 선악의 경계를 넘어 자기 자신에게 이르는 길을 찾아가는 성장소설입니다.',
  ),
  Book(
    id: '25',
    title: '안나 카레니나',
    author: '레프 톨스토이',
    status: ReadingStatus.completed,
    totalPages: 960,
    currentPage: 960,
    totalReadingHours: 11.0,
    completedAt: DateTime(2025, 12, 2),
    genre: '소설',
    description:
        '사교계의 유부녀 안나가 브론스키와의 사랑에 빠지며 파멸해가는 과정과, 대비되는 레빈의 가정을 통해 사랑과 도덕, 삶의 의미를 그린 대작입니다.',
  ),
  Book(
    id: '26',
    title: '사피엔스',
    author: '유발 하라리',
    status: ReadingStatus.completed,
    totalPages: 636,
    currentPage: 636,
    totalReadingHours: 7.5,
    completedAt: DateTime(2025, 12, 14),
    genre: '역사',
    description:
        '인지혁명, 농업혁명, 과학혁명을 통해 호모 사피엔스가 지구를 지배하게 된 과정을 통합적으로 조망하는 빅히스토리입니다.',
  ),
  Book(
    id: '27',
    title: '로마인 이야기 1',
    author: '시오노 나나미',
    status: ReadingStatus.completed,
    totalPages: 480,
    currentPage: 480,
    totalReadingHours: 6.0,
    completedAt: DateTime(2025, 12, 26),
    genre: '역사',
    description:
        '작은 도시국가였던 로마가 지중해를 아우르는 대제국으로 성장해가는 초기 역사를 인물 중심으로 서술한 대하 역사서입니다.',
  ),
  Book(
    id: '28',
    title: '역사란 무엇인가',
    author: 'E. H. 카',
    status: ReadingStatus.completed,
    totalPages: 280,
    currentPage: 280,
    totalReadingHours: 3.5,
    completedAt: DateTime(2026, 1, 7),
    genre: '역사',
    description: '역사가와 사실의 관계, 역사 서술의 객관성과 해석의 문제를 다룬 역사학 방법론의 고전입니다.',
  ),
  Book(
    id: '29',
    title: '정관정요',
    author: '오긍',
    status: ReadingStatus.completed,
    totalPages: 420,
    currentPage: 420,
    totalReadingHours: 5.0,
    completedAt: DateTime(2026, 1, 18),
    genre: '역사',
    description:
        '당 태종과 신하들의 문답을 기록해, 어떻게 나라를 다스리고 간언을 받아들여야 하는지를 보여주는 동양 제왕학의 고전입니다.',
  ),
  Book(
    id: '30',
    title: '미국사 산책 1',
    author: '강준만',
    status: ReadingStatus.completed,
    totalPages: 350,
    currentPage: 350,
    totalReadingHours: 4.0,
    completedAt: DateTime(2026, 1, 29),
    genre: '역사',
    description:
        '콜럼버스의 신대륙 도착부터 미국 건국 초기까지, 인물과 사건을 중심으로 흥미롭게 풀어낸 대중 역사 교양서입니다.',
  ),
  Book(
    id: '31',
    title: '니코마코스 윤리학',
    author: '아리스토텔레스',
    status: ReadingStatus.completed,
    totalPages: 460,
    currentPage: 460,
    totalReadingHours: 6.5,
    completedAt: DateTime(2026, 2, 9),
    genre: '철학',
    description:
        '인간이 추구해야 할 최고선으로서의 행복(에우다이모니아)과 중용의 덕을 논한 서양 윤리학의 원류가 되는 고전입니다.',
  ),
  Book(
    id: '32',
    title: '차라투스트라는 이렇게 말했다',
    author: '프리드리히 니체',
    status: ReadingStatus.completed,
    totalPages: 560,
    currentPage: 560,
    totalReadingHours: 7.0,
    completedAt: DateTime(2026, 2, 20),
    genre: '철학',
    description:
        '예언자 차라투스트라의 입을 빌려 신의 죽음, 초인, 영원회귀 등 니체 철학의 핵심 사상을 시적 산문으로 풀어낸 작품입니다.',
  ),
  Book(
    id: '33',
    title: '소크라테스의 변명',
    author: '플라톤',
    status: ReadingStatus.completed,
    totalPages: 200,
    currentPage: 200,
    totalReadingHours: 2.5,
    completedAt: DateTime(2026, 3, 3),
    genre: '철학',
    description: '사형선고를 받은 소크라테스가 아테네 법정에서 자신의 철학과 삶의 방식을 변론하는 과정을 담은 대화편입니다.',
  ),
  Book(
    id: '34',
    title: '팡세',
    author: '블레즈 파스칼',
    status: ReadingStatus.completed,
    totalPages: 400,
    currentPage: 400,
    totalReadingHours: 5.5,
    completedAt: DateTime(2026, 3, 14),
    genre: '철학',
    description: '인간의 나약함과 위대함, 신앙과 이성의 관계를 단상 형식으로 기록한 파스칼의 미완성 유고집입니다.',
  ),
  Book(
    id: '35',
    title: '정의란 무엇인가',
    author: '마이클 샌델',
    status: ReadingStatus.completed,
    totalPages: 444,
    currentPage: 444,
    totalReadingHours: 5.5,
    completedAt: DateTime(2026, 3, 25),
    genre: '인문',
    description:
        '공리주의, 자유지상주의, 공동체주의 등 다양한 정의론을 실제 사례와 함께 검토하며 무엇이 옳은가를 함께 고민하게 하는 정치철학 교양서입니다.',
  ),
  Book(
    id: '36',
    title: '장자',
    author: '장자',
    status: ReadingStatus.completed,
    totalPages: 380,
    currentPage: 380,
    totalReadingHours: 5.0,
    completedAt: DateTime(2026, 4, 5),
    genre: '철학',
    description:
        '소요유, 제물론 등을 통해 상대적 가치와 자연스러운 삶, 무위의 철학을 우화와 비유로 풀어낸 동양 철학의 고전입니다.',
  ),
  Book(
    id: '37',
    title: '이기적 유전자',
    author: '리처드 도킨스',
    status: ReadingStatus.completed,
    totalPages: 704,
    currentPage: 704,
    totalReadingHours: 8.5,
    completedAt: DateTime(2026, 4, 16),
    genre: '과학',
    description:
        '진화의 진짜 주체는 개체나 종이 아니라 유전자라는 관점에서, 이타적 행동까지도 유전자의 생존 전략으로 설명하는 진화생물학 고전입니다.',
  ),
  Book(
    id: '38',
    title: '시간의 역사',
    author: '스티븐 호킹',
    status: ReadingStatus.completed,
    totalPages: 400,
    currentPage: 400,
    totalReadingHours: 5.0,
    completedAt: DateTime(2026, 4, 27),
    genre: '과학',
    description:
        '빅뱅부터 블랙홀, 시간의 본질까지 현대 우주론의 핵심 질문들을 대중의 눈높이에서 풀어낸 과학 교양서의 고전입니다.',
  ),
  Book(
    id: '39',
    title: '침묵의 봄',
    author: '레이첼 카슨',
    status: ReadingStatus.completed,
    totalPages: 400,
    currentPage: 400,
    totalReadingHours: 4.5,
    completedAt: DateTime(2026, 5, 8),
    genre: '과학',
    description:
        '살충제 DDT의 무분별한 사용이 생태계를 어떻게 파괴하는지 고발하며 현대 환경 운동의 출발점이 된 과학 저널리즘의 고전입니다.',
  ),
  Book(
    id: '40',
    title: '생각에 관한 생각',
    author: '대니얼 카너먼',
    status: ReadingStatus.completed,
    totalPages: 616,
    currentPage: 616,
    totalReadingHours: 8.0,
    completedAt: DateTime(2026, 5, 19),
    genre: '심리',
    description:
        '빠르고 직관적인 시스템 1과 느리고 논리적인 시스템 2라는 이중과정 이론으로 인간의 판단과 의사결정의 오류를 파헤치는 행동경제학의 고전입니다.',
  ),
  Book(
    id: '41',
    title: '몰입',
    author: '미하이 칙센트미하이',
    status: ReadingStatus.completed,
    totalPages: 408,
    currentPage: 408,
    totalReadingHours: 5.0,
    completedAt: DateTime(2026, 5, 30),
    genre: '심리',
    description:
        "시간 가는 줄 모르고 무언가에 완전히 빠져드는 '플로우' 상태의 심리적 구조를 규명하며 행복과 몰입의 관계를 탐구한 심리학 고전입니다.",
  ),
  Book(
    id: '42',
    title: '서양미술사',
    author: 'E. H. 곰브리치',
    status: ReadingStatus.completed,
    totalPages: 688,
    currentPage: 688,
    totalReadingHours: 7.0,
    completedAt: DateTime(2026, 6, 10),
    genre: '예술',
    description:
        '선사시대 동굴벽화부터 현대미술까지, 시대와 양식의 흐름을 인물과 작품 중심으로 쉽게 풀어낸 서양미술사 입문의 고전입니다.',
  ),
  Book(
    id: '43',
    title: '넛지',
    author: '리처드 탈러, 캐스 선스타인',
    status: ReadingStatus.completed,
    totalPages: 428,
    currentPage: 428,
    totalReadingHours: 4.5,
    completedAt: DateTime(2026, 6, 18),
    genre: '경제·경영',
    description:
        "강요 없이 선택 설계만으로 사람들의 행동을 더 나은 방향으로 유도할 수 있다는 행동경제학의 개념 '넛지'를 다양한 사례로 설명하는 책입니다.",
  ),
  Book(
    id: '44',
    title: '국부론',
    author: '애덤 스미스',
    status: ReadingStatus.completed,
    totalPages: 540,
    currentPage: 540,
    totalReadingHours: 6.0,
    completedAt: DateTime(2026, 6, 25),
    genre: '경제·경영',
    description:
        '분업, 시장, 보이지 않는 손이라는 개념으로 자유시장경제의 이론적 토대를 세운 근대 경제학의 출발점이 되는 고전입니다.',
  ),
  Book(
    id: '45',
    title: '사회계약론',
    author: '장 자크 루소',
    status: ReadingStatus.completed,
    totalPages: 300,
    currentPage: 300,
    totalReadingHours: 4.0,
    completedAt: DateTime(2026, 7, 1),
    genre: '사회',
    description:
        '인간은 자유롭게 태어났으나 어디서나 사슬에 묶여 있다는 문제의식에서 출발해, 정당한 정치 공동체의 근거를 일반의지에서 찾는 정치철학의 고전입니다.',
  ),
  Book(
    id: '46',
    title: '예루살렘의 아이히만',
    author: '한나 아렌트',
    status: ReadingStatus.completed,
    totalPages: 420,
    currentPage: 420,
    totalReadingHours: 5.0,
    completedAt: DateTime(2026, 7, 5),
    genre: '사회',
    description:
        "나치 전범 아돌프 아이히만의 재판을 취재하며 악이 광신자가 아니라 사유하지 않는 평범한 사람에게서도 비롯될 수 있음을 밝힌 '악의 평범성' 개념의 고전입니다.",
  ),
  Book(
    id: '47',
    title: '월든',
    author: '헨리 데이비드 소로우',
    status: ReadingStatus.completed,
    totalPages: 500,
    currentPage: 500,
    totalReadingHours: 6.0,
    completedAt: DateTime(2026, 7, 9),
    genre: '에세이',
    description:
        '월든 호숫가 숲속에서 2년간 홀로 살아가며 검소한 삶과 자연, 자립의 의미를 성찰한 소로우의 자전적 에세이입니다.',
  ),
];
