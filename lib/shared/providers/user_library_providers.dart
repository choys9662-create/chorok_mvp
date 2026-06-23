import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../features/library/widget/library_calendar_view.dart' show ReadingLog;
import '../models/reading_session.dart';
import '../repositories/supabase_book_repository.dart';

/// 소셜 — 팔로우한 사용자의 서재를 보기 위한 userId 파라미터 프로바이더들.
///
/// 내 서재(libraryProvider / readingLogsProvider / readingStreakProvider)는
/// 플랫폼에 따라 sqflite 또는 Supabase를 쓰지만, 다른 사용자의 데이터는
/// 로컬에 없으므로 항상 Supabase에서 읽는다. RLS의 `*_select_following`
/// 정책이 팔로워에게만 읽기를 허용한다.

/// 특정 사용자의 책장.
final userBooksProvider = FutureProvider.family<List<Book>, String>((
  ref,
  userId,
) async {
  return ref.read(supabaseBookRepositoryProvider).getBooksByUser(userId);
});

/// 특정 사용자의 독서 기록(캘린더/통계용). library_screen의
/// _fetchSupabaseReadingLogs 로직을 userId로 파라미터화한 버전.
final userReadingLogsProvider = FutureProvider.family<List<ReadingLog>, String>((
  ref,
  userId,
) async {
  final client = Supabase.instance.client;
  final rows = await _fetchReadingLogs(client, userId);
  return rows.map<ReadingLog>((r) {
    final book = r['books'] as Map<String, dynamic>?;
    final secs = (r['duration_seconds'] as num?)?.toInt() ?? 0;
    final dateStr = r['ended_at'] as String? ?? r['started_at'] as String?;
    final title = book?['title'] as String? ?? '알 수 없는 책';
    return (
      // UTC로 저장된 시각을 로컬 날짜로 변환해야 캘린더 날짜가 맞는다.
      date: dateStr != null
          ? DateTime.parse(dateStr).toLocal()
          : DateTime.now(),
      bookTitle: title,
      bookAuthor: book?['author'] as String? ?? '',
      minutes: (secs / 60).round(),
      pages: (r['pages_read'] as num?)?.toInt() ?? 0,
      coverUrl: book?['cover_url'] as String?,
      gradientIndex: title.hashCode.abs() % AppTheme.coverGradients.length,
    );
  }).toList();
});

Future<List<dynamic>> _fetchReadingLogs(
  SupabaseClient client,
  String userId,
) async {
  try {
    return await client
        .from('reading_sessions')
        .select(
          'ended_at, started_at, duration_seconds, pages_read, books(title, author, cover_url)',
        )
        .eq('user_id', userId)
        .order('ended_at', ascending: false);
  } catch (_) {
    return await client
        .from('reading_sessions')
        .select(
          'ended_at, started_at, duration_seconds, books(title, author, cover_url)',
        )
        .eq('user_id', userId)
        .order('ended_at', ascending: false);
  }
}

/// 특정 사용자의 연속 독서일(streak).
/// book_repository의 _readingStreakFromSupabase를 userId로 파라미터화.
final userReadingStreakProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  final client = Supabase.instance.client;
  final rows = await client
      .from('reading_sessions')
      .select('ended_at')
      .eq('user_id', userId)
      .order('ended_at', ascending: false);

  final days = <DateTime>{};
  for (final row in rows as List) {
    final dt = DateTime.tryParse(
      (row as Map<String, dynamic>)['ended_at'] as String? ?? '',
    )?.toLocal();
    if (dt != null) days.add(DateTime(dt.year, dt.month, dt.day));
  }
  if (days.isEmpty) return 0;

  final now = DateTime.now();
  var cursor = DateTime(now.year, now.month, now.day);
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});
