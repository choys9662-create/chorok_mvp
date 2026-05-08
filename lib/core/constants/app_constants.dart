/// 앱 전역 상수
class AppConstants {
  // ─── 라우트 경로 ─────────────────────────────────────────────────
  static const String routeHome = '/home';
  static const String routeExplore = '/explore';
  static const String routeAnalytics = '/analytics';
  static const String routeFeed = '/feed';
  static const String routeLibrary = '/library';
  static const String routeSession = '/session';
  static const String routeRecap = '/recap';
  static const String routeAuth = '/auth';
  static const String routeSignUp = '/sign-up';
  static const String routeNotifications = '/notifications';
  static const String routeBookDetail = '/book-detail';
  static const String routeSearch = '/search';
  static const String routeReflection = '/reflection';
  static const String routeBarcode = '/barcode';
  static const String routeChoseoList = '/choseo-list';
  static const String routeOnboarding = '/onboarding';
  static const String routeSettings = '/settings';
  static const String routeAchievements = '/achievements';
  static const String routeSentenceDetail = '/sentence-detail';

  // ─── 타이머 설정 ─────────────────────────────────────────────────
  static const int defaultReadingMinutes = 25; // 기본 독서 시간 (분)
  static const int shortBreakMinutes = 5;      // 짧은 휴식 (분)
  static const int longBreakMinutes = 15;      // 긴 휴식 (분)

  // ─── 라이브 포레스트 ────────────────────────────────────────────
  static const int maxFireflies = 80;
  static const double fireflyActiveOpacity = 1.0;   // 현재 읽는 중
  static const double fireflyTodayOpacity = 0.45;   // 오늘 읽음
  static const double fireflyWeekOpacity = 0.18;    // 이번 주 읽음

  // ─── 더미 데이터 (MVP 용) ──────────────────────────────────────
  static const int mockActiveReaders = 15;
  static const int mockTodayReaders = 48;
  static const int mockWeekReaders = 134;
}
