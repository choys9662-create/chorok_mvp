import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/isar/isar_book.dart';
import '../models/isar/isar_book_reflection.dart';
import '../models/isar/isar_choseo.dart';
import '../models/isar/isar_reading_session.dart';
import '../models/reading_session.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

/// sqflite Database — main.dart에서 override (웹은 null)
final dbProvider = Provider<Database?>((_) => null);

final bookRepositoryProvider = Provider<BookRepository?>((ref) {
  final db = ref.watch(dbProvider);
  if (db == null) return null;
  return BookRepository(db);
});

final readingStreakProvider = FutureProvider<int>((ref) async {
  return (await ref.read(bookRepositoryProvider)?.getReadingStreak()) ?? 0;
});

// ─── 결과 타입 ────────────────────────────────────────────────────────────────

class ProgressResult {
  /// 이번 세션으로 처음 완독 달성
  final bool justCompleted;

  /// 업데이트된 책 (bookId 미매칭 시 null)
  final IsarBook? book;

  const ProgressResult({required this.justCompleted, this.book});
}

// ─── DB 초기화 헬퍼 ──────────────────────────────────────────────────────────

Future<Database> openAppDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'chorok.db');

  return openDatabase(
    path,
    version: 4,
    onCreate: (db, version) async {
      await _createAllTables(db);
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS book_reflections (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            reflection_id   TEXT    NOT NULL UNIQUE,
            book_id         TEXT    NOT NULL,
            book_title      TEXT    NOT NULL,
            book_author     TEXT    NOT NULL,
            star_rating     INTEGER NOT NULL DEFAULT 0,
            memorable_line  TEXT,
            legacy          TEXT,
            created_at      TEXT    NOT NULL
          )
        ''');
      }
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS choseo (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            choseo_id   TEXT    NOT NULL UNIQUE,
            book_id     TEXT    NOT NULL DEFAULT '',
            book_title  TEXT    NOT NULL DEFAULT '',
            book_author TEXT    NOT NULL DEFAULT '',
            content     TEXT    NOT NULL,
            my_thought  TEXT,
            cover_url   TEXT,
            page_number INTEGER,
            created_at  TEXT    NOT NULL
          )
        ''');
      }
      if (oldVersion < 4) {
        // reading_sessions에 이탈 횟수/시간 컬럼 추가
        await db.execute('ALTER TABLE reading_sessions ADD COLUMN exit_count INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE reading_sessions ADD COLUMN exit_duration_seconds INTEGER NOT NULL DEFAULT 0');
        // choseo에 reflection 컬럼 추가
        await db.execute('ALTER TABLE choseo ADD COLUMN reflection TEXT');
      }
    },
  );
}

Future<void> _createAllTables(Database db) async {
  await db.execute('''
    CREATE TABLE books (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id      TEXT    NOT NULL UNIQUE,
      title        TEXT    NOT NULL,
      author       TEXT    NOT NULL,
      isbn         TEXT,
      cover_url    TEXT,
      current_page INTEGER NOT NULL DEFAULT 0,
      total_pages  INTEGER NOT NULL DEFAULT 0,
      status       TEXT    NOT NULL DEFAULT 'reading',
      created_at   TEXT    NOT NULL,
      updated_at   TEXT    NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE reading_sessions (
      id                     INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id             TEXT    NOT NULL UNIQUE,
      book_id                TEXT,
      started_at             TEXT    NOT NULL,
      ended_at               TEXT    NOT NULL,
      duration_seconds       INTEGER NOT NULL DEFAULT 0,
      pages_read             INTEGER NOT NULL DEFAULT 0,
      choseo_count           INTEGER NOT NULL DEFAULT 0,
      exit_count             INTEGER NOT NULL DEFAULT 0,
      exit_duration_seconds  INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute('''
    CREATE TABLE choseo (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      choseo_id   TEXT    NOT NULL UNIQUE,
      book_id     TEXT    NOT NULL DEFAULT '',
      book_title  TEXT    NOT NULL DEFAULT '',
      book_author TEXT    NOT NULL DEFAULT '',
      content     TEXT    NOT NULL,
      my_thought  TEXT,
      cover_url   TEXT,
      page_number INTEGER,
      reflection  TEXT,
      created_at  TEXT    NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE book_reflections (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      reflection_id   TEXT    NOT NULL UNIQUE,
      book_id         TEXT    NOT NULL,
      book_title      TEXT    NOT NULL,
      book_author     TEXT    NOT NULL,
      star_rating     INTEGER NOT NULL DEFAULT 0,
      memorable_line  TEXT,
      legacy          TEXT,
      created_at      TEXT    NOT NULL
    )
  ''');
}

// ─── Repository ──────────────────────────────────────────────────────────────

class BookRepository {
  final Database _db;

  BookRepository(this._db);

  // ── 책 추가 / 업서트 ───────────────────────────────────────────────────────

  Future<IsarBook> upsertBook({
    required String bookId,
    required String title,
    required String author,
    String? isbn,
    String? coverUrl,
    int totalPages = 0,
    int currentPage = 0,
    IsarReadingStatus status = IsarReadingStatus.reading,
  }) async {
    final now = DateTime.now();

    final existing = await getBook(bookId);
    if (existing != null) {
      // 존재하면 title/author/meta만 업데이트, 진행 상황은 유지
      await _db.update(
        'books',
        {
          'title': title,
          'author': author,
          'isbn': isbn,
          'cover_url': coverUrl,
          'total_pages': totalPages,
          'updated_at': now.toIso8601String(),
        },
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
      return (await getBook(bookId))!;
    }

    final book = IsarBook(
      bookId: bookId,
      title: title,
      author: author,
      isbn: isbn,
      coverUrl: coverUrl,
      currentPage: currentPage,
      totalPages: totalPages,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return (await getBook(bookId))!;
  }

  // ── 진행 업데이트 + 세션 저장 ─────────────────────────────────────────────

  /// 세션 완료 시 호출:
  ///   1. bookId → currentPage 업데이트
  ///   2. currentPage >= totalPages → status = completed
  ///   3. IsarReadingSession 저장
  Future<ProgressResult> updateProgress({
    required String bookId,
    required int newCurrentPage,
    required int durationSeconds,
    required int choseoCount,
    DateTime? startedAt,
    int exitCount = 0,
    int exitDurationSeconds = 0,
  }) async {
    final existing = await getBook(bookId);
    bool justCompleted = false;
    IsarBook? updatedBook;

    if (existing != null) {
      final wasCompleted = existing.status == IsarReadingStatus.completed;
      final pagesRead =
          (newCurrentPage - existing.currentPage).clamp(0, 999999);

      IsarReadingStatus newStatus = existing.status;
      if (!wasCompleted &&
          existing.totalPages > 0 &&
          newCurrentPage >= existing.totalPages) {
        newStatus = IsarReadingStatus.completed;
        justCompleted = true;
      }

      await _db.update(
        'books',
        {
          'current_page': newCurrentPage,
          'status': newStatus.name,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'book_id = ?',
        whereArgs: [bookId],
      );

      updatedBook = existing.copyWith(
        currentPage: newCurrentPage,
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      // 세션 저장
      final session = IsarReadingSession(
        sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}_$bookId',
        bookId: bookId,
        startedAt: startedAt ?? DateTime.now(),
        endedAt: DateTime.now(),
        durationSeconds: durationSeconds,
        pagesRead: pagesRead,
        choseoCount: choseoCount,
        exitCount: exitCount,
        exitDurationSeconds: exitDurationSeconds,
      );
      await _db.insert(
        'reading_sessions',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return ProgressResult(justCompleted: justCompleted, book: updatedBook);
    }

    // 책 없이도 orphan 세션은 저장
    final session = IsarReadingSession(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      bookId: bookId,
      startedAt: startedAt ?? DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      pagesRead: 0,
      choseoCount: choseoCount,
      exitCount: exitCount,
      exitDurationSeconds: exitDurationSeconds,
    );
    await _db.insert(
      'reading_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return const ProgressResult(justCompleted: false, book: null);
  }

  // ── 조회 ──────────────────────────────────────────────────────────────────

  Future<IsarBook?> getBook(String bookId) async {
    final rows = await _db.query(
      'books',
      where: 'book_id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IsarBook.fromMap(rows.first);
  }

  Future<List<IsarBook>> getAllBooks() async {
    final rows = await _db.query('books', orderBy: 'updated_at DESC');
    return rows.map(IsarBook.fromMap).toList();
  }

  Future<List<IsarBook>> getBooksByStatus(IsarReadingStatus status) async {
    final rows = await _db.query(
      'books',
      where: 'status = ?',
      whereArgs: [status.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map(IsarBook.fromMap).toList();
  }

  Future<List<IsarReadingSession>> getSessionsForBook(String bookId) async {
    final rows = await _db.query(
      'reading_sessions',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'started_at DESC',
    );
    return rows.map(IsarReadingSession.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getAllReadingLogs() async {
    return _db.rawQuery('''
      SELECT rs.started_at, rs.duration_seconds, rs.pages_read,
             COALESCE(b.title, '알 수 없는 책') AS book_title,
             COALESCE(b.author, '') AS book_author
      FROM reading_sessions rs
      LEFT JOIN books b ON rs.book_id = b.book_id
      ORDER BY rs.started_at DESC
    ''');
  }

  // ── 앱 Book 모델 → DB upsert ──────────────────────────────────────────────

  Future<IsarBook> saveFromBook(Book book) {
    final status = switch (book.status) {
      ReadingStatus.reading => IsarReadingStatus.reading,
      ReadingStatus.completed => IsarReadingStatus.completed,
      ReadingStatus.wantToRead => IsarReadingStatus.wantToRead,
    };
    return upsertBook(
      bookId: book.id,
      title: book.title,
      author: book.author,
      isbn: book.isbn,
      coverUrl: book.coverUrl,
      totalPages: book.totalPages,
      currentPage: book.currentPage,
      status: status,
    );
  }

  Future<void> deleteByBookId(String bookId) async {
    await _db.delete(
      'books',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  // ── 완독 회고 저장 ────────────────────────────────────────────────────────

  Future<IsarBookReflection> saveReflection({
    required String bookId,
    required String bookTitle,
    required String bookAuthor,
    required int starRating,
    String? memorableLine,
    String? legacy,
  }) async {
    final now = DateTime.now();
    final reflection = IsarBookReflection(
      reflectionId: 'reflection_${now.millisecondsSinceEpoch}_$bookId',
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      starRating: starRating,
      memorableLine:
          memorableLine != null && memorableLine.trim().isNotEmpty ? memorableLine.trim() : null,
      legacy: legacy != null && legacy.trim().isNotEmpty ? legacy.trim() : null,
      createdAt: now,
    );
    await _db.insert(
      'book_reflections',
      reflection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return reflection;
  }

  Future<List<IsarBookReflection>> getReflectionsForBook(String bookId) async {
    final rows = await _db.query(
      'book_reflections',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(IsarBookReflection.fromMap).toList();
  }

  // ── 초서 저장 / 조회 ──────────────────────────────────────────────────────

  Future<IsarChoseo> saveChoseo({
    required String bookId,
    required String bookTitle,
    required String bookAuthor,
    required String content,
    String? myThought,
    String? coverUrl,
    int? pageNumber,
  }) async {
    final now = DateTime.now();
    final choseo = IsarChoseo(
      choseoId: 'choseo_${now.millisecondsSinceEpoch}_${content.hashCode.abs()}',
      bookId: bookId,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      content: content.trim(),
      myThought: myThought?.trim().isNotEmpty == true ? myThought!.trim() : null,
      coverUrl: coverUrl,
      pageNumber: pageNumber,
      createdAt: now,
    );
    await _db.insert(
      'choseo',
      choseo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // 중복 내용 무시
    );
    return choseo;
  }

  Future<List<IsarChoseo>> getAllChoseo() async {
    final rows = await _db.query('choseo', orderBy: 'created_at DESC');
    return rows.map(IsarChoseo.fromMap).toList();
  }

  Future<int> getChoseoCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) as cnt FROM choseo');
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<List<IsarChoseo>> searchChoseo(String query) async {
    final q = '%${query.trim()}%';
    final rows = await _db.query(
      'choseo',
      where: 'content LIKE ? OR my_thought LIKE ? OR book_title LIKE ? OR book_author LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'created_at DESC',
    );
    return rows.map(IsarChoseo.fromMap).toList();
  }

  Future<List<IsarChoseo>> getChoseoByBook(String bookId) async {
    final rows = await _db.query(
      'choseo',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(IsarChoseo.fromMap).toList();
  }

  // ── 초서 리플렉션 메모 업데이트 ─────────────────────────────────────────────

  Future<void> updateChoseoReflection(String choseoId, String? reflection) async {
    await _db.update(
      'choseo',
      {'reflection': reflection},
      where: 'choseo_id = ?',
      whereArgs: [choseoId],
    );
  }

  // ── 책별 초서 개수 ────────────────────────────────────────────────────────

  Future<Map<String, int>> getChoseoCountByBook() async {
    final rows = await _db.rawQuery(
      'SELECT book_id, COUNT(*) as cnt FROM choseo GROUP BY book_id',
    );
    return {
      for (final r in rows) r['book_id'] as String: r['cnt'] as int,
    };
  }

  Future<int> getChoseoCountForBook(String bookId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM choseo WHERE book_id = ?',
      [bookId],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  // ── 타임캡슐: 1년 전 수집 문장 ──────────────────────────────────────────────

  /// 오늘로부터 정확히 1년 전 ±3일 범위의 초서 중 1개 반환
  Future<IsarChoseo?> getTimeCapsuleChoseo() async {
    final now = DateTime.now();
    final yearAgo = DateTime(now.year - 1, now.month, now.day);
    final from = yearAgo.subtract(const Duration(days: 3));
    final to = yearAgo.add(const Duration(days: 3));
    final rows = await _db.rawQuery(
      '''
      SELECT * FROM choseo
      WHERE date(created_at) BETWEEN date(?) AND date(?)
      ORDER BY RANDOM()
      LIMIT 1
      ''',
      [from.toIso8601String(), to.toIso8601String()],
    );
    if (rows.isEmpty) return null;
    return IsarChoseo.fromMap(rows.first);
  }

  // ── 오늘 세션 인사이트 데이터 ────────────────────────────────────────────────

  /// 오늘 독서 세션 목록
  Future<List<IsarReadingSession>> getTodaySessions() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();
    final rows = await _db.query(
      'reading_sessions',
      where: 'started_at BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'started_at DESC',
    );
    return rows.map(IsarReadingSession.fromMap).toList();
  }

  /// 최근 7일 평균 일일 페이지 수 (완독 예상일 계산용)
  Future<double> getAvgDailyPagesLast7Days(String bookId) async {
    final from = DateTime.now().subtract(const Duration(days: 7));
    final rows = await _db.rawQuery(
      '''
      SELECT SUM(pages_read) as total, COUNT(DISTINCT date(started_at)) as days
      FROM reading_sessions
      WHERE book_id = ? AND started_at >= ?
      ''',
      [bookId, from.toIso8601String()],
    );
    if (rows.isEmpty) return 0;
    final total = (rows.first['total'] as int?) ?? 0;
    final days = (rows.first['days'] as int?) ?? 0;
    if (days <= 0) return 0;
    return total / days;
  }

  // ── 독서 스트릭 계산 ──────────────────────────────────────────────────────

  // ── 날짜 범위 조회 ────────────────────────────────────────────────────────

  Future<List<IsarReadingSession>> getSessionsInRange(
      DateTime from, DateTime to) async {
    final rows = await _db.query(
      'reading_sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'started_at DESC',
    );
    return rows.map(IsarReadingSession.fromMap).toList();
  }

  Future<List<IsarChoseo>> getChoseoInRange(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'choseo',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return rows.map(IsarChoseo.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getReadingLogsInRange(
      DateTime from, DateTime to) async {
    return _db.rawQuery('''
      SELECT rs.started_at, rs.duration_seconds, rs.pages_read,
             COALESCE(b.title, '알 수 없는 책') AS book_title,
             COALESCE(b.author, '') AS book_author
      FROM reading_sessions rs
      LEFT JOIN books b ON rs.book_id = b.book_id
      WHERE rs.started_at >= ? AND rs.started_at < ?
      ORDER BY rs.started_at DESC
    ''', [from.toIso8601String(), to.toIso8601String()]);
  }

  // 날짜별 독서 분(分) 맵 (히트맵 데이터)
  Future<Map<DateTime, int>> getHeatmapDataForYear(int year) async {
    final from = DateTime(year, 1, 1).toIso8601String();
    final to = DateTime(year + 1, 1, 1).toIso8601String();
    final rows = await _db.rawQuery('''
      SELECT date(started_at) as day, SUM(duration_seconds) as total
      FROM reading_sessions
      WHERE started_at >= ? AND started_at < ?
      GROUP BY date(started_at)
    ''', [from, to]);
    final result = <DateTime, int>{};
    for (final row in rows) {
      final day = DateTime.parse(row['day'] as String);
      result[DateTime(day.year, day.month, day.day)] =
          ((row['total'] as int?) ?? 0) ~/ 60;
    }
    return result;
  }

  // 월별 독서 시간(분) 12개 배열 (1월=인덱스 0)
  Future<List<int>> getMonthlyMinutesForYear(int year) async {
    final from = DateTime(year, 1, 1).toIso8601String();
    final to = DateTime(year + 1, 1, 1).toIso8601String();
    final rows = await _db.rawQuery('''
      SELECT CAST(strftime('%m', started_at) AS INTEGER) as month,
             SUM(duration_seconds) as total
      FROM reading_sessions
      WHERE started_at >= ? AND started_at < ?
      GROUP BY month
    ''', [from, to]);
    final result = List<int>.filled(12, 0);
    for (final row in rows) {
      final idx = (row['month'] as int) - 1;
      result[idx] = ((row['total'] as int?) ?? 0) ~/ 60;
    }
    return result;
  }

  // ── 독서 스트릭 계산 ──────────────────────────────────────────────────────

  /// 오늘부터 역순으로 연속 독서 일수 반환
  Future<int> getReadingStreak() async {
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT date(started_at) AS day
      FROM reading_sessions
      ORDER BY day DESC
      ''',
    );
    if (rows.isEmpty) return 0;

    int streak = 0;
    DateTime cursor = DateTime.now();
    final today = DateTime(cursor.year, cursor.month, cursor.day);

    for (final row in rows) {
      final dayStr = row['day'] as String;
      final day = DateTime.parse(dayStr);
      final diff = today.difference(day).inDays - streak;
      if (diff == 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}
