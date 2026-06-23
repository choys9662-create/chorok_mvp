import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_corner/smooth_corner.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/follow_overlap_provider.dart';
import '../../feed/screen/sentence_detail_screen.dart';

/// 홈 — 전용 겹문장 카드 섹션.
/// 팔로우한 독자와 같은 책에서 겹친 문장을 보여준다. 없으면 숨김.
class OverlapSection extends ConsumerWidget {
  const OverlapSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlaps = ref.watch(followOverlapProvider).valueOrNull ?? const [];
    if (overlaps.isEmpty) return const SizedBox.shrink();

    final items = overlaps.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '겹문장',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '팔로우한 독자와 같은 문장에 멈췄어요',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppConstants.routeFeed),
                child: Text(
                  '피드 보기 ›',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i < items.length - 1 ? 10 : 0,
                  ),
                  child: OverlapCard(overlap: items[i]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class OverlapCard extends StatelessWidget {
  final FollowOverlap overlap;
  const OverlapCard({super.key, required this.overlap});

  void _open(BuildContext context) {
    HapticFeedback.selectionClick();
    context.push(
      AppConstants.routeSentenceDetail,
      extra: SentenceDetailExtra(
        sentenceContent: overlap.mergedContent,
        bookTitle: overlap.bookTitle,
        bookAuthor: overlap.bookAuthor,
        collectorUsername: overlap.neighborName,
        collectorUserHandle: overlap.neighborHandle,
        collectorUserId: overlap.neighborUserId,
        collectorThought: overlap.neighborThought,
        sentenceId: overlap.neighborSentenceId,
        overlapCommonPhrase: overlap.commonPhrase,
        overlapHighlight: overlap.mergedHighlight,
        bookId: overlap.bookId,
        globalBookId: overlap.globalBookId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${overlap.bookTitle} 겹문장 보기',
      button: true,
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusLG,
            side: const BorderSide(color: Color(0xFF8DFF54)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 겹문장 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: ShapeDecoration(
                  color: context.appPrimaryAccent.withValues(alpha: 0.08),
                  shape: SmoothRectangleBorder(
                    smoothness: 0.6,
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide.none,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.join_inner_rounded,
                      size: 11,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '겹문장 · ${overlap.neighborName}',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 공통 문구
              Text(
                '"${overlap.commonPhrase}"',
                style: AppTheme.bodySmall.copyWith(
                  color: context.appTextPrimary,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              // 책 정보
              Text(
                '${overlap.bookTitle} · ${overlap.bookAuthor}',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
