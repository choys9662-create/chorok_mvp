import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_flags.dart';
import '../../core/services/db_service.dart';
import '../models/isar/isar_book.dart';
import '../models/reading_session.dart';
import '../repositories/book_repository.dart';
import '../repositories/supabase_book_repository.dart';

/// USE_MOCK=true (--dart-define) → 목업 데이터 (디자인 작업용)
/// 기본값 false:
///   - kUseRemoteDb=true → 모든 플랫폼이 Supabase (SupabaseBookRepository)
///   - kUseRemoteDb=false → 모바일/데스크톱은 SQLite (BookRepository)

Book _fromIsarBook(IsarBook b) => Book(
  id: b.bookId,
  title: b.title,
  author: b.author,
  isbn: b.isbn,
  coverUrl: b.coverUrl,
  currentPage: b.currentPage,
  totalPages: b.totalPages,
  status: switch (b.status) {
    IsarReadingStatus.reading => ReadingStatus.reading,
    IsarReadingStatus.completed => ReadingStatus.completed,
    IsarReadingStatus.wantToRead => ReadingStatus.wantToRead,
  },
  completedAt: b.completedAt,
  genre: b.genre,
  description: b.description,
);

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
      final List<Book> loaded;
      if (kUseRemoteDb) {
        final repo = ref.read(supabaseBookRepositoryProvider);
        loaded = await repo.getAllBooks();
      } else {
        final repo = ref.read(bookRepositoryProvider);
        if (repo == null) {
          _isLoading = false;
          return;
        }
        final rows = await repo.getAllBooks();
        final totalSecsMap = await repo.getBookTotalSecondsByBookId();
        loaded = rows.map((b) {
          final secs = totalSecsMap[b.bookId] ?? 0;
          return _fromIsarBook(b).copyWith(totalReadingHours: secs / 3600.0);
        }).toList();
      }

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

  bool addBook(Book book) {
    final isDuplicate =
        book.isbn != null &&
        book.isbn!.isNotEmpty &&
        state.any((b) => b.isbn == book.isbn);
    if (isDuplicate) return false;
    state = [...state, book];
    if (kUseMock) return true;
    if (kUseRemoteDb) {
      // fire-and-forget — UX는 즉시 반영, Supabase 저장은 백그라운드
      ref.read(supabaseBookRepositoryProvider).saveFromBook(book);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(book);
    }
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

    final updated = old.copyWith(
      currentPage: clamped,
      status: newStatus,
      completedAt:
          (newStatus == ReadingStatus.completed &&
              old.status != ReadingStatus.completed)
          ? DateTime.now()
          : (newStatus != ReadingStatus.completed ? null : old.completedAt),
    );

    debugPrint('LibraryProvider: Updated status to ${updated.status}');
    state = [...state]..[idx] = updated;

    if (kUseMock) return;
    if (kUseRemoteDb) {
      ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(updated);
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
    );

    state = [...state]..[idx] = updated;

    if (kUseMock) return;
    if (kUseRemoteDb) {
      await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      await ref.read(bookRepositoryProvider)?.saveFromBook(updated);
    }
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
    if (kUseRemoteDb) {
      await ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      await ref.read(bookRepositoryProvider)?.saveFromBook(updated);
    }
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
    final updated = Book(
      id: old.id,
      title: old.title,
      author: old.author,
      isbn: old.isbn,
      coverUrl: old.coverUrl,
      currentPage: clampedCurrent,
      totalPages: totalPages,
      status: old.status,
      totalReadingHours: old.totalReadingHours,
      savedSentences: old.savedSentences,
      completedAt: old.completedAt,
      genre: old.genre,
      description: old.description,
    );
    state = [...state]..[idx] = updated;
    if (kUseMock) return;
    if (kUseRemoteDb) {
      ref.read(supabaseBookRepositoryProvider).saveFromBook(updated);
    } else {
      ref.read(bookRepositoryProvider)?.saveFromBook(updated);
    }
  }

  void deleteBook(String bookId) {
    state = state.where((b) => b.id != bookId).toList();
    if (kUseMock) return;
    if (kUseRemoteDb) {
      ref.read(supabaseBookRepositoryProvider).deleteByBookId(bookId);
    } else {
      ref.read(bookRepositoryProvider)?.deleteByBookId(bookId);
    }
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

    if (kUseMock) {
      final updated = old.copyWith(
        savedSentences: [...old.savedSentences, trimmed],
      );
      state = [...state]..[idx] = updated;
      return;
    }

    if (kUseRemoteDb) {
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
    } else {
      await ref
          .read(bookRepositoryProvider)
          ?.saveChoseo(
            bookId: bookId,
            bookTitle: old.title,
            bookAuthor: old.author,
            content: trimmed,
            myThought: thought,
            pageNumber: pageNumber,
          );
    }
  }

  Future<void> updateSentenceThought({
    required String sentenceId,
    String? thought,
  }) async {
    if (kUseMock) return;
    if (kUseRemoteDb) {
      await ref
          .read(dbServiceProvider)
          .updateSentenceThought(sentenceId, thought);
    } else {
      await ref
          .read(bookRepositoryProvider)
          ?.updateChoseoThought(sentenceId, thought);
    }
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
    if (kUseRemoteDb) {
      await _addManualReadingLogToSupabase(
        bookId: bookId,
        startPage: startPage,
        endPage: endPage,
        durationSeconds: durationSeconds,
        sessionDate: sessionDate,
      );
      return;
    }

    final repo = ref.read(bookRepositoryProvider);
    if (repo == null) return;

    final result = await repo.addManualSession(
      bookId: bookId,
      startPage: startPage,
      endPage: endPage,
      durationSeconds: durationSeconds,
      sessionDate: sessionDate,
    );

    if (result.book != null) {
      final idx = state.indexWhere((b) => b.id == bookId);
      if (idx >= 0) {
        final b = state[idx];
        final updated = b.copyWith(
          currentPage: result.book!.currentPage,
          status: result.book!.status == IsarReadingStatus.completed
              ? ReadingStatus.completed
              : ReadingStatus.reading,
          completedAt: result.book!.completedAt,
          totalReadingHours: b.totalReadingHours + durationSeconds / 3600.0,
        );
        state = [...state]..[idx] = updated;
      }
    }
  }

  Future<void> _addManualReadingLogToSupabase({
    required String bookId,
    required int startPage,
    required int endPage,
    required int durationSeconds,
    required DateTime sessionDate,
  }) async {
    final pagesRead = (endPage - startPage).clamp(0, 999999);
    final idx = state.indexWhere((b) => b.id == bookId);
    Book? updatedBook;

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

      updatedBook = old.copyWith(
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
];
