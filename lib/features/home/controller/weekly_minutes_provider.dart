import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_flags.dart';
import '../widget/home_helpers.dart';

final weeklyMinutesProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) async {
  if (kUseMock) return kWeeklyMinutes;
  return _loadWeeklyMinutesFromSupabase();
});

Future<List<int>> _loadWeeklyMinutesFromSupabase() async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return List.filled(7, 0);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));

  final rows = await client
      .from('reading_sessions')
      .select('ended_at, duration_seconds')
      .eq('user_id', userId)
      // timestamptz 비교라 오프셋을 붙여 보내야 창이 로컬 자정에 맞는다.
      .gte('ended_at', weekStart.toUtc().toIso8601String())
      .lt('ended_at', weekEnd.toUtc().toIso8601String());

  final result = List<int>.filled(7, 0);
  for (final row in rows as List) {
    final map = row as Map<String, dynamic>;
    // UTC 로 파싱되므로 weekday 를 로컬 기준으로 읽으려면 변환이 필요하다.
    final endedAt = DateTime.tryParse(
      map['ended_at'] as String? ?? '',
    )?.toLocal();
    if (endedAt == null) continue;
    final dur = (map['duration_seconds'] as num?)?.toInt() ?? 0;
    final idx = (endedAt.weekday - 1).clamp(0, 6);
    result[idx] += dur ~/ 60;
  }
  return result;
}
