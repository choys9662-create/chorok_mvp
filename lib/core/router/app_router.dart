import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart' show initialLocationProvider;

import '../../features/analytics/screen/analytics_screen.dart';
import '../../features/auth/screen/auth_screen.dart';
import '../../features/explore/screen/explore_screen.dart';
import '../../features/feed/screen/feed_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/search/screen/search_screen.dart';
import '../../shared/models/session_goal.dart';
import '../../features/home/screen/book_detail_screen.dart';
import '../../features/home/screen/home_screen.dart';
import '../../features/home/screen/notification_screen.dart';
import '../../features/home/screen/reading_session_screen.dart';
import '../../features/home/screen/session_recap_screen.dart';
import '../../features/library/book_reflection_screen.dart';
import '../../features/library/screen/library_screen.dart';
import '../../features/search/barcode_scanner_screen.dart';
import '../../features/library/choseo_list_screen.dart';
import '../../features/settings/screen/settings_screen.dart';
import '../../features/achievements/screen/achievements_screen.dart';
import '../../shared/models/reading_session.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../constants/app_constants.dart';

/// go_router 인스턴스 프로바이더
final appRouterProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.read(initialLocationProvider);
  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,

    // ── 인증 가드 ────────────────────────────────────────────────
    redirect: (context, state) {
      // 목업 모드(USE_MOCK=true): 인증 우회, 항상 홈으로
      const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
      if (useMock) {
        final loc = state.matchedLocation;
        if (loc == AppConstants.routeAuth || loc == AppConstants.routeOnboarding) {
          return AppConstants.routeHome;
        }
        return null;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isPublic = loc == AppConstants.routeAuth ||
          loc == AppConstants.routeOnboarding;
      if (!isLoggedIn && !isPublic) return AppConstants.routeAuth;
      if (isLoggedIn && loc == AppConstants.routeAuth) return AppConstants.routeHome;
      return null;
    },

    routes: [
      // 온보딩
      GoRoute(
        path: AppConstants.routeOnboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // 인증
      GoRoute(
        path: AppConstants.routeAuth,
        builder: (context, state) => const AuthScreen(),
      ),

      // 알림 — 쉘 밖에서 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeNotifications,
        builder: (context, state) => const NotificationScreen(),
      ),

      // 탐색 — 홈 검색 아이콘에서 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeExplore,
        builder: (context, state) => const ExploreScreen(),
      ),

      // 책 검색 (알라딘 API)
      GoRoute(
        path: AppConstants.routeSearch,
        builder: (context, state) => const SearchScreen(),
      ),

      // 책 상세 — 쉘 밖에서 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeBookDetail,
        builder: (context, state) {
          final data = state.extra as BookDetailExtra;
          return BookDetailScreen(book: data);
        },
      ),

      // 독서 세션 — 쉘 밖에서 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeSession,
        builder: (context, state) {
          final extra = state.extra;
          // SessionExtra (신규) 또는 SessionGoal? (레거시 호환)
          if (extra is SessionExtra) {
            return ReadingSessionScreen(
              goal: extra.goal,
              bookId: extra.bookId,
              bookTitle: extra.bookTitle,
              bookAuthor: extra.bookAuthor,
              startPage: extra.startPage,
              totalPages: extra.totalPages,
            );
          }
          return ReadingSessionScreen(goal: extra as SessionGoal?);
        },
      ),

      // 독서 리캡 — 세션 종료 후 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeRecap,
        builder: (context, state) {
          final data = state.extra as RecapData;
          return SessionRecapScreen(data: data);
        },
      ),

      // 완독 감상 — 완독 감지 후 이동 (3단계 PageView)
      GoRoute(
        path: AppConstants.routeReflection,
        builder: (context, state) {
          final extra = state.extra as Book;
          return BookReflectionScreen(book: extra);
        },
      ),

      // ISBN 바코드 스캐너
      GoRoute(
        path: AppConstants.routeBarcode,
        builder: (context, state) => const BarcodeScannerScreen(),
      ),

      // 수집한 문장 전체 보기
      GoRoute(
        path: AppConstants.routeChoseoList,
        builder: (context, state) => const ChoseoListScreen(),
      ),

      // 설정
      GoRoute(
        path: AppConstants.routeSettings,
        builder: (context, state) => const SettingsScreen(),
      ),

      // 성취 & 뱃지
      GoRoute(
        path: AppConstants.routeAchievements,
        builder: (context, state) => const AchievementsScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // 홈
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeHome,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          // 피드
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeFeed,
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          // 분석
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeAnalytics,
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          // 서재
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeLibrary,
                builder: (context, state) => const LibraryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
