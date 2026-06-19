import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/theme/app_theme.dart';
import 'package:chorok_app/features/library/screen/library_screen.dart';
import 'package:chorok_app/features/library/screen/reading_history_screen.dart';
import 'package:chorok_app/features/library/widget/profile_header.dart';
import 'package:chorok_app/shared/models/reading_session.dart';
import 'package:chorok_app/shared/providers/library_provider.dart';

class _FakeLibraryNotifier extends LibraryNotifier {
  @override
  List<Book> build() => const [];
}

void main() {
  testWidgets('독서 기록은 프로필과 하단 탭이 없는 독립 화면으로 열린다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(_FakeLibraryNotifier.new),
          readingLogsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const ReadingHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('독서 기록'), findsOneWidget);
    expect(find.byType(ProfileHeader), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });
}
