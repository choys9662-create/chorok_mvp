import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/follow_overlap_provider.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/chorok_section_header.dart';
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
        const SizedBox(height: AppTheme.sectionGap),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: ChorokSectionHeader(
            title: '겹문장',
            subtitle: '팔로우한 독자와 같은 문장에 멈췄어요',
            trailing: GestureDetector(
              onTap: () => context.push(AppConstants.routeFeed),
              child: Text(
                '피드 보기 ›',
                style: AppTheme.supportingText.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < items.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i < items.length - 1 ? AppTheme.spaceSM : 0,
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
        coverUrl: overlap.coverUrl,
        isbn13: overlap.isbn13,
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
        child: ChorokCard(
          clipBehavior: Clip.antiAlias,
          borderColor: context.appPrimaryAccent,
          padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppTheme.spaceSM,
            children: [
              // 겹문장 배지
              ChorokCard(
                inner: true,
                backgroundColor: context.appPrimaryAccent.withValues(
                  alpha: 0.08,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSM,
                  vertical: AppTheme.spaceXS,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.join_inner_rounded,
                      size: AppTheme.spaceMD,
                      color: context.appPrimaryAccent,
                    ),
                    const SizedBox(width: AppTheme.spaceXS),
                    Text(
                      '겹문장 · ${overlap.neighborName}',
                      style: AppTheme.caption.copyWith(
                        color: context.appPrimaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              // 공통 문구
              Text(
                '"${overlap.commonPhrase}"',
                style: AppTheme.body.copyWith(
                  color: context.appTextPrimary,
                  height: 1.6,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // 책 정보
              Text(
                '${overlap.bookTitle} · ${overlap.bookAuthor}',
                style: AppTheme.caption.copyWith(
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
