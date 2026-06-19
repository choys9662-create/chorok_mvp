import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../widget/library_calendar_view.dart';
import 'library_screen.dart' show readingLogsProvider;

class ReadingHistoryScreen extends ConsumerWidget {
  final String? userId;

  const ReadingHistoryScreen({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = userId == null;
    final List<Book> books;
    final List<ReadingLog> logs;

    if (isOwner) {
      books = ref.watch(libraryProvider);
      logs = kUseMock
          ? mockReadingLogs
          : ref.watch(readingLogsProvider).valueOrNull ?? const <ReadingLog>[];
    } else {
      books =
          ref.watch(userBooksProvider(userId!)).valueOrNull ?? const <Book>[];
      logs =
          ref.watch(userReadingLogsProvider(userId!)).valueOrNull ??
          const <ReadingLog>[];
    }

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.screenPadding,
                18,
                AppTheme.screenPadding,
                16,
              ),
              child: Row(
                children: [
                  Semantics(
                    label: '뒤로 가기',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: AppTheme.smoothBox(
                          color: context.appCard,
                          radius: 27,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: context.appTextSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Text(
                    '독서 기록',
                    style: AppTheme.headingLarge.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LibraryCalendarView(
                logs: logs,
                books: books,
                scrollController: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
