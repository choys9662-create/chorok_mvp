/// 세션 목표 유형
enum SessionGoalType {
  time,  // 시간 목표 (예: 30분)
  pages, // 페이지 목표 (예: 250쪽까지)
  free,  // 자유 독서 (목표 없음)
}

/// 독서 세션 목표 — 타이머 진입 전 설정
class SessionGoal {
  final SessionGoalType type;
  final int? targetMinutes; // time 유형일 때 사용
  final int? targetPage;    // pages 유형일 때 사용 (절대 페이지)
  final int startPage;      // 세션 시작 시점의 현재 페이지

  const SessionGoal({
    required this.type,
    this.targetMinutes,
    this.targetPage,
    this.startPage = 0,
  });

  const SessionGoal.free()
      : type = SessionGoalType.free,
        targetMinutes = null,
        targetPage = null,
        startPage = 0;

  const SessionGoal.time(int minutes)
      : type = SessionGoalType.time,
        targetMinutes = minutes,
        targetPage = null,
        startPage = 0;

  SessionGoal.pages({required int target, required this.startPage})
      : type = SessionGoalType.pages,
        targetMinutes = null,
        targetPage = target;

  /// 시간 목표를 초 단위로 환산
  int get targetSeconds => (targetMinutes ?? 0) * 60;

  /// 페이지 목표까지 남은 쪽수
  int get pagesToRead => (targetPage ?? startPage) - startPage;

  /// 시간 목표 대비 진행률 (0.0 ~ 1.0+)
  double timeProgress(int elapsedSeconds) {
    if (type != SessionGoalType.time || targetSeconds == 0) return 0.0;
    return elapsedSeconds / targetSeconds;
  }

  /// UI 표시용 라벨
  String get label {
    switch (type) {
      case SessionGoalType.time:
        if (targetMinutes! >= 60) {
          final h = targetMinutes! ~/ 60;
          final m = targetMinutes! % 60;
          return m > 0 ? '$h시간 $m분' : '$h시간';
        }
        return '$targetMinutes분';
      case SessionGoalType.pages:
        return '$targetPage쪽까지';
      case SessionGoalType.free:
        return '자유 독서';
    }
  }
}


/// 세션 중 수집한 문장 — 원문과 내 생각을 함께 보관
class CollectedSentence {
  final String content;
  final String thought;

  const CollectedSentence({required this.content, this.thought = ''});
}

/// 독서 세션 진입 시 라우터에 전달하는 통합 extra
///
/// goal + 책 메타데이터를 하나로 묶어 ReadingSessionScreen에 전달한다.
class SessionExtra {
  final SessionGoal? goal;
  final String? bookId;
  final String bookTitle;
  final String bookAuthor;
  final String? coverUrl;
  final int startPage;
  final int totalPages;

  const SessionExtra({
    this.goal,
    this.bookId,
    this.bookTitle = '',
    this.bookAuthor = '',
    this.coverUrl,
    this.startPage = 0,
    this.totalPages = 0,
  });
}
