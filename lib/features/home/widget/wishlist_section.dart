import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/widgets/chorok_section_header.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../shared/models/session_goal.dart';

import '../../search/util/book_info_navigation.dart';

class WishlistSection extends ConsumerWidget {
  const WishlistSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBooks = ref.watch(libraryProvider);
    final wishlistBooks = allBooks
        .where((b) => b.status == ReadingStatus.wantToRead)
        .toList();

    // 위시리스트가 비어있으면 섹션 자체를 숨김 (신규 사용자 화면 정리)
    if (wishlistBooks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: '다음에 읽을 책',
            count: wishlistBooks.length,
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: wishlistBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < wishlistBooks.length - 1 ? 12 : 0,
                ),
                child: WishlistBookCard(book: wishlistBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class WishlistBookCard extends StatefulWidget {
  final Book book;
  const WishlistBookCard({super.key, required this.book});

  @override
  State<WishlistBookCard> createState() => WishlistBookCardState();
}

class WishlistBookCardState extends State<WishlistBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.book;
    const daysText = '위시리스트';

    return GestureDetector(
      onTap: () {
        pushBookInfo(context, b);
      },
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 150,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCardElevated,
            radius: AppTheme.radiusOuter,
            side: isDark
                ? BorderSide(
                    color: Colors.white.withValues(alpha: 0.07),
                    width: 0.5,
                  )
                : BorderSide.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [context.appPrimaryAccent, context.appAccentColor],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: Icon(
                        Icons.bookmark_rounded,
                        size: 56,
                        color: context.primaryBg(0.08),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: AppTheme.spaceXS,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.75),
                          shape: SmoothRectangleBorder(
                            smoothness: 0.6,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusOuter,
                            ),
                          ),
                        ),
                        child: Text(
                          daysText,
                          style: AppTheme.captionSmall.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Semantics(
                  label: '${b.title} 읽기',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      context.push(
                        AppConstants.routeSession,
                        extra: SessionExtra(
                          bookId: b.id,
                          bookTitle: b.title,
                          bookAuthor: b.author,
                          coverUrl: b.coverUrl,
                          startPage: 0,
                          totalPages: b.totalPages,
                        ),
                      );
                    },
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothPill(
                        color: context.appPrimaryAccent.withValues(
                          alpha: 0.15,
                        ),
                        side: BorderSide.none,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: context.appPrimaryAccent,
                          ),
                          const SizedBox(width: AppTheme.spaceXS),
                          Text(
                            '읽기',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
