import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../main.dart' show initialLocationProvider;

import '../../features/analytics/screen/analytics_screen.dart';
import '../../features/auth/screen/auth_screen.dart';
import '../../features/auth/screen/sign_up_screen.dart';
import '../../features/explore/screen/explore_screen.dart';
import '../../features/feed/screen/feed_screen.dart';
import '../../features/forest/widget/forest_lock_layer.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/search/screen/search_screen.dart';
import '../../shared/models/session_goal.dart';
import '../../features/library/screen/book_detail_screen.dart';
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
import '../../features/feed/screen/sentence_detail_screen.dart';
import '../../features/search/screen/book_info_screen.dart';
import '../../features/search/model/aladin_book.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/reading_session.dart';
import '../../shared/widgets/main_scaffold.dart';
import '../constants/app_constants.dart';

/// Supabase auth 상태 변경을 GoRouter가 감지하도록 래핑.
/// 로그인/로그아웃 직후 router가 redirect를 재평가하게 만든다.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// go_router 인스턴스 프로바이더
final appRouterProvider = Provider<GoRouter>((ref) {
  final initialLocation = ref.read(initialLocationProvider);
  final authRefresh = _AuthRefreshNotifier(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(authRefresh.dispose);

  return GoRouter(
    initialLocation: initialLocation,
    debugLogDiagnostics: false,
    refreshListenable: authRefresh,

    // ── 인증 가드 ────────────────────────────────────────────────
    redirect: (context, state) {
      // 목업 모드(USE_MOCK=true): 인증 우회, 항상 홈으로
      const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
      if (useMock) {
        final loc = state.matchedLocation;
        if (loc == AppConstants.routeAuth ||
            loc == AppConstants.routeOnboarding) {
          return AppConstants.routeHome;
        }
        return null;
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isPublic =
          loc == AppConstants.routeAuth ||
          loc == AppConstants.routeSignUp ||
          loc == AppConstants.routeOnboarding;
      if (!isLoggedIn && !isPublic) return AppConstants.routeAuth;
      if (isLoggedIn && loc == AppConstants.routeAuth) {
        return AppConstants.routeHome;
      }
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

      // 회원가입
      GoRoute(
        path: AppConstants.routeSignUp,
        builder: (context, state) => const SignUpScreen(),
      ),

      // 알림 — 쉘 밖에서 전체 화면으로 표시
      GoRoute(
        path: AppConstants.routeNotifications,
        builder: (context, state) => const NotificationScreen(),
      ),

      // 분석 — 탭에서 제거됨. 홈 카드·서재에서 드릴다운(push)으로 진입
      GoRoute(
        path: AppConstants.routeAnalytics,
        builder: (context, state) => const AnalyticsScreen(),
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
          final bookId = state.extra as String;
          return BookDetailScreen(bookId: bookId);
        },
      ),

      GoRoute(
        path: AppConstants.routeSession,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final screen = () {
            if (extra is SessionExtra) {
              return ReadingSessionScreen(
                goal: extra.goal,
                bookId: extra.bookId,
                bookTitle: extra.bookTitle,
                bookAuthor: extra.bookAuthor,
                coverUrl: extra.coverUrl,
                startPage: extra.startPage,
                totalPages: extra.totalPages,
              );
            }
            return ReadingSessionScreen(goal: extra as SessionGoal?);
          }();

          return CustomTransitionPage(
            key: state.pageKey,
            child: ForestLockLayer(child: screen),
            transitionDuration: const Duration(milliseconds: 700),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  // 진입: fade + scale 0.94 → 1.0  (집중 모드로 몰입하는 느낌)
                  final fade = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  );
                  final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  // 퇴장(pop): 빠르게 fade만
                  final exitFade = CurvedAnimation(
                    parent: secondaryAnimation,
                    curve: Curves.easeIn,
                  );
                  return FadeTransition(
                    opacity: Tween<double>(
                      begin: 1.0,
                      end: 0.0,
                    ).animate(exitFade),
                    child: FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(scale: scale, child: child),
                    ),
                  );
                },
          );
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

      // 문장 상세
      GoRoute(
        path: AppConstants.routeSentenceDetail,
        builder: (context, state) {
          final data = state.extra as SentenceDetailExtra;
          return SentenceDetailScreen(data: data);
        },
      ),

      // 검색 결과 책 상세 (공개 정보 + 커뮤니티 문장)
      GoRoute(
        path: AppConstants.routeBookInfo,
        builder: (context, state) {
          final book = state.extra as AladinBook;
          return BookInfoScreen(book: book);
        },
      ),

      // 유저 프로필 — 그 사용자의 서재(읽기 전용 소셜 뷰)
      GoRoute(
        path: AppConstants.routeUserProfile,
        builder: (context, state) {
          final profile = state.extra as UserProfile;
          return LibraryScreen(viewedUser: profile);
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
          // 검색 (탐색) — 우상단 아이콘에서 하단 탭으로 승격
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppConstants.routeExplore,
                builder: (context, state) => const ExploreScreen(),
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
          // 서재 (분석 통계 뷰 흡수)
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
