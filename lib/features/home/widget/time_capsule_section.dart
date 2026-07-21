import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/repositories/book_repository.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import 'package:smooth_corner/smooth_corner.dart';

final timeCapsuleProvider = FutureProvider<IsarChoseo?>((ref) async {
  return ref.read(bookRepositoryProvider)?.getTimeCapsuleChoseo();
});

class TimeCapsuleSection extends ConsumerWidget {
  const TimeCapsuleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsule = ref.watch(timeCapsuleProvider);
    return capsule.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (choseo) {
        if (choseo == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // 이모지 장식 — 16→행 텍스트(16)
                    const Text(
                      '⏳',
                      style: TextStyle(fontSize: AppTheme.fsRowText),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      '1년 전 오늘, 당신이 붙잡은 문장',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                decoration: ShapeDecoration(
                  color: context.appCard,
                  shape: SmoothRectangleBorder(
                    smoothness: 0.6,
                    borderRadius: BorderRadius.circular(AppTheme.radiusOuter),
                    side: BorderSide.none,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${choseo.content}"',
                      style: AppTheme.bodyMedium.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '— ${choseo.bookTitle}  ·  ${choseo.bookAuthor}',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(AppConstants.routeChoseoList);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: AppTheme.spaceSM,
                        ),
                        decoration: ShapeDecoration(
                          color: context.appPrimaryAccent.withValues(
                            alpha: 0.08,
                          ),
                          shape: AppTheme.smoothShape(
                            radius: AppTheme.radiusOuter,
                          ),
                        ),
                        child: Text(
                          '그때의 나는 무슨 생각을 했을까?',
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
