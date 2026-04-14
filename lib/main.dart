import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/onboarding_screen.dart';
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

  // 온보딩 완료 여부 — 웹은 항상 완료로 처리
  final onboardingDone = kIsWeb ? true : await isOnboardingCompleted();
  final initialLocation = onboardingDone
      ? AppConstants.routeHome
      : AppConstants.routeOnboarding;

  if (kIsWeb) {
    _initDeepLinks();
    runApp(ProviderScope(
      overrides: [initialLocationProvider.overrideWithValue(initialLocation)],
      child: const ChorokApp(),
    ));
    return;
  }

  // 로컬 DB 초기화 (모바일/데스크톱)
  final Database db = await openAppDatabase();

  _initDeepLinks();

  runApp(ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      initialLocationProvider.overrideWithValue(initialLocation),
    ],
    child: const ChorokApp(),
  ));
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
    return MaterialApp.router(
      title: '초록',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
