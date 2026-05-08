import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:figma_squircle/figma_squircle.dart';

class HighlightSentence {
  final String content;
  final String bookTitle;
  final String author;
  final int recordCount;
  final int empathyCount;
  final bool isOverlap;
  final int gradientIndex;

  const HighlightSentence({
    required this.content,
    required this.bookTitle,
    required this.author,
    required this.recordCount,
    required this.empathyCount,
    this.isOverlap = false,
    this.gradientIndex = 0,
  });
}
const kHighlightSentences = [
  HighlightSentence(
    content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
    bookTitle: '채식주의자',
    author: '한강',
    recordCount: 142,
    empathyCount: 384,
    isOverlap: true,
    gradientIndex: 0,
  ),
  HighlightSentence(
    content: '우리는 모두 누군가의 이민자다. 다만 시간이 다를 뿐.',
    bookTitle: '파친코',
    author: '이민진',
    recordCount: 98,
    empathyCount: 271,
    isOverlap: false,
    gradientIndex: 2,
  ),
  HighlightSentence(
    content: '사랑한다는 것은 서로의 고독을 인정하는 것이다.',
    bookTitle: '노르웨이의 숲',
    author: '무라카미 하루키',
    recordCount: 214,
    empathyCount: 512,
    isOverlap: true,
    gradientIndex: 4,
  ),
];

class FeedHighlightSection extends StatelessWidget {
  const FeedHighlightSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
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
                      '지금 많이 기록된 문장',
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '독자들이 가장 많이 수집한 문장이에요',
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
        // 문장 카드 리스트
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
          ),
          child: Column(
            children: kHighlightSentences
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(
                      bottom: e.key < kHighlightSentences.length - 1 ? 10 : 0,
                    ),
                    child: HighlightCard(sentence: e.value),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
class HighlightCard extends StatelessWidget {
  final HighlightSentence sentence;
  const HighlightCard({super.key, required this.sentence});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${sentence.bookTitle} 문장 보기',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push(AppConstants.routeFeed);
        },
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusLG,
            side: BorderSide(color: context.appBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 문장 + 메타
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 겹문장 배지
                        if (sentence.isOverlap)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: ShapeDecoration(
                                color: context.appPrimaryAccent.withValues(
                                  alpha: 0.08,
                                ),
                                shape: SmoothRectangleBorder(
                                  borderRadius: SmoothBorderRadius(
                                    cornerRadius: 6,
                                    cornerSmoothing: 0.6,
                                  ),
                                  side: BorderSide(
                                    color: context.appPrimaryAccent.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
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
                                    '겹문장 · ${sentence.recordCount}명 수집',
                                    style: AppTheme.captionSmall.copyWith(
                                      color: context.appPrimaryAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // 문장 본문
                        Text(
                          '"${sentence.content}"',
                          style: AppTheme.bodySmall.copyWith(
                            color: context.appTextPrimary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // 책 정보 + 공감
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${sentence.bookTitle} · ${sentence.author}',
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: context.appAccentColor.withValues(
                                alpha: 0.8,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${sentence.empathyCount}',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
