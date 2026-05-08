/// 공용 시간/날짜 포맷터
library;

/// "5분 전", "3시간 전", "2일 전"
String formatRelative(DateTime dt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return '${diff.inDays}일 전';
}

/// 분 단위 → "1시간 30분" / "1시간" / "30분"
String formatMinutes(int minutes) {
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m > 0 ? '$h시간 $m분' : '$h시간';
  }
  return '$minutes분';
}

/// 초 단위 → "1시간 30분" / "30분" / "45초"
String formatDurationSeconds(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h시간 $m분';
  if (m > 0) return '$m분';
  return '$seconds초';
}

/// "2026.05.08"
String formatDate(DateTime dt) {
  return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
}
