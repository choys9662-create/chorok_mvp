import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/repositories/book_repository.dart';

/// 앱 초기 진입 경로 — main()에서 주입
final initialLocationProvider = Provider<String>((_) => AppConstants.routeHome);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // 목업 모드(USE_MOCK=true)이거나 웹이면 온보딩 체크 없이 바로 홈
  const useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);
  final onboardingDone = useMock || kIsWeb || await isOnboardingCompleted();
  final initialLocation = onboardingDone
      ? AppConstants.routeHome
      : AppConstants.routeOnboarding;

  final savedThemeMode = await loadSavedThemeMode();

  if (kIsWeb) {
    _initDeepLinks();
    runApp(
      ProviderScope(
        overrides: [
          initialLocationProvider.overrideWithValue(initialLocation),
          initialThemeModeProvider.overrideWithValue(savedThemeMode),
        ],
        child: const ChorokApp(),
      ),
    );
    return;
  }

  // 로컬 DB 초기화 (모바일/데스크톱)
  final Database db = await openAppDatabase();

  _initDeepLinks();

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(initialLocation),
        initialThemeModeProvider.overrideWithValue(savedThemeMode),
      ],
      child: const ChorokApp(),
    ),
  );
}

void _initDeepLinks() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    supabase.auth.getSessionFromUrl(uri);
  });
}

/// 앱 전역에서 Supabase 클라이언트 접근용 편의 getter
final supabase = Supabase.instance.client;

class ChorokApp extends ConsumerWidget {
  const ChorokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '초록',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: isDark
                ? AppTheme.darkSurface
                : AppTheme.lightSurface,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
