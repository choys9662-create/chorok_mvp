import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/analytics/screen/analytics_screen.dart';
import '../../features/auth/screen/auth_screen.dart';
import '../../features/explore/screen/explore_screen.dart';
import '../../features/feed/screen/feed_screen.dart';
import '../../shared/models/session_goal.dart';
import '../../features/home/screen/book_detail_screen.dart';
import '../../features/home/screen/home_screen.dart';
import '../../features/home/screen/notification_screen.dart';
import '../../features/home/screen/reading_session_screen.dart';
import '../../features/home/screen/session_recap_screen.dart';
import '../../features/library/screen/library_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../constants/app_constants.dart';

/// go_router 인스턴스 프로바이더
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppConstants.routeHome,
    debugLogDiagnostics: false,

    // ── 인증 가드 (디자인 작업 중 비활성화) ─────────────────────────
    // redirect: (context, state) {
    //   final session = Supabase.instance.client.auth.currentSession;
    //   final isLoggedIn = session != null;
    //   final isAuthRoute = state.matchedLocation == AppConstants.routeAuth;
    //   if (!isLoggedIn && !isAuthRoute) return AppConstants.routeAuth;
    //   if (isLoggedIn && isAuthRoute) return AppConstants.routeHome;
    //   return null;
    // },

    routes: [
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
          final goal = state.extra as SessionGoal?;
          return ReadingSessionScreen(goal: goal);
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
