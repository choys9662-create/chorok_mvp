import 'package:flutter/material.dart';

/// 인사이트 유형
enum InsightType {
  completionEstimate, // 완독 예상
  streakEncouragement, // 연속 독서 격려
  sentenceMilestone, // 초서 문장 마일스톤
  paceAnalysis, // 독서 속도 분석
  sessionSuggestion, // 다음 세션 제안
}

/// 단일 인사이트 메시지
class ReadingInsight {
  final InsightType type;
  final String message;
  final String? subMessage;
  final IconData icon;

  const ReadingInsight({
    required this.type,
    required this.message,
    this.subMessage,
    this.icon = Icons.auto_awesome_rounded,
  });
}

/// 책별 독서 통계 입력 구조체
class BookReadingStats {
  final String title;
  final int currentPage;
  final int totalPages;
  final double avgPagesPerHour; // 시간당 평균 페이지 수
  final int savedSentences; // 초서한 문장 수
  final int streakDays; // 연속 독서 일수
  final double totalReadingHours;

  const BookReadingStats({
    required this.title,
    required this.currentPage,
    required this.totalPages,
    required this.avgPagesPerHour,
    required this.savedSentences,
    required this.streakDays,
    required this.totalReadingHours,
  });

  int get remainingPages => totalPages - currentPage;
  double get progress => totalPages > 0 ? currentPage / totalPages : 0.0;
}

/// 독서 데이터 기반 정성적 동기부여 메시지 엔진
///
/// 사용자의 누적 독서 데이터(시간, 문장 수, 속도)를 분석하여
/// 맥락에 맞는 동기부여 메시지를 산출한다.
class ReadingInsightEngine {
  ReadingInsightEngine._();

  // ─── 완독 예상 ─────────────────────────────────────────────────

  /// 남은 페이지와 평균 독서 속도를 기반으로 완독 시간을 추산한다.
  /// 반환값: "오늘 O시간만 읽으면 완독할 수 있어요!" 형태의 메시지
  static String completionEstimate({
    required int remainingPages,
    required double avgPagesPerHour,
  }) {
    if (remainingPages <= 0) return '이미 완독한 책이에요!';
    if (avgPagesPerHour <= 0) return '독서를 시작하면 완독 예상 시간을 알려드릴게요';

    final hoursNeeded = remainingPages / avgPagesPerHour;

    if (hoursNeeded <= 1) {
      final minutes = (hoursNeeded * 60).ceil();
      return '오늘 $minutes분만 읽으면 완독할 수 있어요!';
    }
    if (hoursNeeded <= 3) {
      return '약 ${hoursNeeded.toStringAsFixed(1)}시간이면 완독이에요!';
    }
    if (hoursNeeded <= 8) {
      final sessions = (hoursNeeded / 0.75).ceil(); // 45분 세션 기준
      return '$sessions번의 독서 세션이면 완독할 수 있어요';
    }
    final days = (hoursNeeded / 1.5).ceil(); // 하루 1.5시간 기준
    return '하루 1시간씩 약 $days일이면 만날 수 있어요';
  }

  // ─── 연속 독서 격려 ────────────────────────────────────────────

  /// 연속 독서 일수에 따른 격려 메시지를 반환한다.
  static String streakMessage(int consecutiveDays) {
    if (consecutiveDays <= 0) return '오늘 독서를 시작해볼까요?';
    if (consecutiveDays == 1) return '첫걸음을 뗐어요! 내일도 이어가볼까요?';
    if (consecutiveDays <= 3) {
      return '$consecutiveDays일 연속 독서 중! 좋은 습관이 만들어지고 있어요';
    }
    if (consecutiveDays <= 7) return '$consecutiveDays일째 꾸준히! 이미 습관이 되어가고 있어요';
    if (consecutiveDays <= 14) return '$consecutiveDays일 연속! 대단한 독서 습관이에요';
    if (consecutiveDays <= 30) {
      return '$consecutiveDays일째 멈추지 않는 독서! 당신은 진짜 독서가예요';
    }
    return '$consecutiveDays일 연속 독서, 놀라운 기록이에요!';
  }

  // ─── 초서 문장 마일스톤 ────────────────────────────────────────

  /// 저장한 문장 개수에 따른 마일스톤 메시지를 반환한다.
  static String sentenceCountMessage(int totalSentences) {
    if (totalSentences <= 0) return '마음에 드는 문장을 수집해보세요';
    if (totalSentences < 5) return '수집한 문장 $totalSentences개, 나만의 문장 서재가 시작됐어요';
    if (totalSentences < 10) return '$totalSentences개의 문장을 모았어요! 곧 두 자릿수 돌파';
    if (totalSentences < 25) return '$totalSentences개의 문장! 하나하나가 당신만의 기록이에요';
    if (totalSentences < 50) return '$totalSentences개의 문장이 쌓였어요. 작은 문장 도서관이네요';
    if (totalSentences < 100) return '$totalSentences개! 곧 100개 돌파, 문장 수집가의 길';
    return '$totalSentences개의 문장, 당신만의 문장 도서관이 완성되어가요';
  }

  // ─── 독서 속도 분석 ────────────────────────────────────────────

  /// 평균 독서 속도를 분석하여 피드백 메시지를 반환한다.
  static String paceAnalysis({
    required double avgPagesPerHour,
    required double totalReadingHours,
  }) {
    if (totalReadingHours < 0.5) return '아직 데이터가 쌓이는 중이에요';

    if (avgPagesPerHour >= 40) {
      return '시간당 ${avgPagesPerHour.round()}쪽, 빠른 독서가예요!';
    }
    if (avgPagesPerHour >= 25) {
      return '시간당 ${avgPagesPerHour.round()}쪽, 안정적인 속도예요';
    }
    if (avgPagesPerHour >= 15) {
      return '시간당 ${avgPagesPerHour.round()}쪽, 깊이 있게 읽고 있어요';
    }
    return '시간당 ${avgPagesPerHour.round()}쪽, 천천히 음미하며 읽는 스타일이네요';
  }

  // ─── 종합 인사이트 생성 ────────────────────────────────────────

  /// 책의 독서 통계를 종합 분석하여 가장 적합한 인사이트를 반환한다.
  ///
  /// 우선순위:
  /// 1. 완독 임박 (남은 페이지 < 전체의 15%) → completionEstimate
  /// 2. 연속 독서 7일 이상 → streakEncouragement
  /// 3. 문장 마일스톤 (10, 25, 50, 100 근처) → sentenceMilestone
  /// 4. 독서 속도 분석 → paceAnalysis
  /// 5. 기본 완독 예상 → completionEstimate
  static ReadingInsight generateForBook(BookReadingStats stats) {
    final progress = stats.progress;

    // ① 완독 임박
    if (progress >= 0.85 && stats.remainingPages > 0) {
      return ReadingInsight(
        type: InsightType.completionEstimate,
        message: completionEstimate(
          remainingPages: stats.remainingPages,
          avgPagesPerHour: stats.avgPagesPerHour,
        ),
        subMessage: '${stats.remainingPages}쪽 남음',
        icon: Icons.flag_rounded,
      );
    }

    // ② 연속 독서 강조
    if (stats.streakDays >= 7) {
      return ReadingInsight(
        type: InsightType.streakEncouragement,
        message: streakMessage(stats.streakDays),
        icon: Icons.local_fire_department_rounded,
      );
    }

    // ③ 문장 마일스톤
    if (_isNearMilestone(stats.savedSentences)) {
      return ReadingInsight(
        type: InsightType.sentenceMilestone,
        message: sentenceCountMessage(stats.savedSentences),
        icon: Icons.format_quote_rounded,
      );
    }

    // ④ 독서 속도 분석 (충분한 데이터 누적 시)
    if (stats.totalReadingHours >= 2) {
      return ReadingInsight(
        type: InsightType.paceAnalysis,
        message: paceAnalysis(
          avgPagesPerHour: stats.avgPagesPerHour,
          totalReadingHours: stats.totalReadingHours,
        ),
        icon: Icons.speed_rounded,
      );
    }

    // ⑤ 기본: 완독 예상
    return ReadingInsight(
      type: InsightType.completionEstimate,
      message: completionEstimate(
        remainingPages: stats.remainingPages,
        avgPagesPerHour: stats.avgPagesPerHour,
      ),
      subMessage: '${(progress * 100).round()}% 읽음',
      icon: Icons.menu_book_rounded,
    );
  }

  /// 마일스톤 근처인지 판별 (±2 범위)
  static bool _isNearMilestone(int count) {
    const milestones = [10, 25, 50, 100, 200, 500];
    return milestones.any((m) => count >= m - 2 && count <= m + 2);
  }
}
