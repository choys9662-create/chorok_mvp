import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/providers/user_library_providers.dart';
import '../../../shared/widgets/chorok_card.dart';
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
                AppTheme.spaceLG,
                AppTheme.screenPadding,
                AppTheme.spaceLG,
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
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: ChorokCard(
                          inner: true,
                          padding: EdgeInsets.zero,
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: context.appTextSecondary,
                              size: AppTheme.spaceXL,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceLG),
                  Text(
                    '독서 기록',
                    style: AppTheme.screenTitle.copyWith(
                      color: context.appTextPrimary,
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
