import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/services/screen_time_detox_service.dart';
import 'core/theme/app_theme.dart';
import 'features/timer/controller/timer_controller.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/repositories/book_repository.dart';

/// 앱 초기 진입 경로 — main()에서 주입
final initialLocationProvider = Provider<String>((_) => AppConstants.routeHome);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final authStorage = SharedPreferencesLocalStorage(
    persistSessionKey: _supabasePersistSessionKey(supabaseUrl),
  );

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: authStorage,
    ),
  );
  await _restoreCachedAuthSession(authStorage);

  final restoredTimer = await loadPersistedTimerData();
  if (restoredTimer.isIdle) {
    await ScreenTimeDetoxService.instance.stopDetox();
  }
  final initialLocation = restoredTimer.isIdle
      ? AppConstants.routeHome
      : AppConstants.routeSession;

  final savedThemeMode = await loadSavedThemeMode();

  if (kIsWeb) {
    runApp(
      ProviderScope(
        overrides: [
          initialLocationProvider.overrideWithValue(initialLocation),
          initialThemeModeProvider.overrideWithValue(savedThemeMode),
          initialTimerDataProvider.overrideWithValue(restoredTimer),
        ],
        child: const ChorokApp(),
      ),
    );
    return;
  }

  // 로컬 DB 초기화 (모바일/데스크톱)
  final Database db = await openAppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        initialLocationProvider.overrideWithValue(initialLocation),
        initialThemeModeProvider.overrideWithValue(savedThemeMode),
        initialTimerDataProvider.overrideWithValue(restoredTimer),
      ],
      child: const ChorokApp(),
    ),
  );
}

/// 앱 전역에서 Supabase 클라이언트 접근용 편의 getter
final supabase = Supabase.instance.client;

String _supabasePersistSessionKey(String supabaseUrl) {
  final projectRef = Uri.parse(supabaseUrl).host.split('.').first;
  return 'sb-$projectRef-auth-token';
}

Future<void> _restoreCachedAuthSession(LocalStorage authStorage) async {
  final currentSession = supabase.auth.currentSession;
  if (currentSession != null && !currentSession.isExpired) return;
  if (!await authStorage.hasAccessToken()) return;

  final persistedSession = await authStorage.accessToken();
  if (persistedSession == null) return;

  try {
    await supabase.auth.recoverSession(persistedSession);
  } on AuthException catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'cached auth session',
      ),
    );
  }
}

class ChorokApp extends ConsumerWidget {
  const ChorokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: '초록',
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: AppTheme.darkSurface,
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
