import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

class SessionList extends StatelessWidget {
  final List<({String title, String author, String duration, String date})>
  sessions;
  const SessionList({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(sessions.length, (i) {
          final s = sessions[i];
          return Column(
            children: [
              SessionTile(
                title: s.title,
                author: s.author,
                duration: s.duration,
                date: s.date,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class SessionTile extends StatelessWidget {
  final String title, author, duration, date;
  const SessionTile({
    super.key,
    required this.title,
    required this.author,
    required this.duration,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPaddingMD,
        vertical: AppTheme.spaceMD,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 48,
            decoration: ShapeDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              shape: SmoothRectangleBorder(
                smoothness: 0.6,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppTheme.accent,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  author,
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                duration,
                style: AppTheme.bodySmall.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FinishedBookList extends StatelessWidget {
  final List<({String title, String author, String date, int pages})> books;
  const FinishedBookList({super.key, required this.books});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(books.length, (i) {
          final b = books[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.cardPaddingMD,
                  vertical: AppTheme.spaceMD,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 48,
                      decoration: ShapeDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: SmoothRectangleBorder(
                          smoothness: 0.6,
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide.none,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: context.appPrimaryAccent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.title,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w400,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.author,
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          b.date,
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.pages}p',
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
