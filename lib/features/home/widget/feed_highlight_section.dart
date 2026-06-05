import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../feed/controller/feed_provider.dart';

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

class FeedHighlightSection extends ConsumerWidget {
  const FeedHighlightSection({super.key});

  List<HighlightSentence> _fromFeed(List<FeedSentence> sentences) {
    final firstByContent = <String, FeedSentence>{};
    final counts = <String, int>{};
    final empathy = <String, int>{};
    for (final sentence in sentences) {
      final key = sentence.content.trim();
      if (key.isEmpty) continue;
      firstByContent.putIfAbsent(key, () => sentence);
      counts[key] = (counts[key] ?? 0) + 1;
      empathy[key] = (empathy[key] ?? 0) + sentence.empathyCount;
    }

    final sorted = firstByContent.entries.toList()
      ..sort((a, b) {
        final countCompare = (counts[b.key] ?? 0).compareTo(counts[a.key] ?? 0);
        if (countCompare != 0) return countCompare;
        return (empathy[b.key] ?? 0).compareTo(empathy[a.key] ?? 0);
      });

    return sorted.take(3).map((entry) {
      final sentence = entry.value;
      final recordCount = counts[entry.key] ?? 1;
      return HighlightSentence(
        content: sentence.content,
        bookTitle: sentence.bookTitle,
        author: sentence.bookAuthor,
        recordCount: recordCount,
        empathyCount: empathy[entry.key] ?? sentence.empathyCount,
        isOverlap: recordCount > 1,
        gradientIndex: sentence.bookTitle.hashCode.abs().remainder(7),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<HighlightSentence> highlights;
    const title = '지금 많이 기록된 문장';
    const subtitle = '독자들이 가장 많이 수집한 문장이에요';

    if (kUseMock) {
      highlights = kHighlightSentences;
    } else {
      final sentences = ref.watch(feedProvider).valueOrNull ?? const [];
      if (sentences.isEmpty) return const SizedBox.shrink();
      highlights = _fromFeed(sentences);
      if (highlights.isEmpty) return const SizedBox.shrink();
    }

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
                      title,
                      style: AppTheme.headingSmall.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
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
            children: highlights
                .asMap()
                .entries
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(
                      bottom: e.key < highlights.length - 1 ? 10 : 0,
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
            side: BorderSide.none,
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
                                    '겹문장 · ${sentence.recordCount}명 수집',
                                    style: AppTheme.captionSmall.copyWith(
                                      color: context.appPrimaryAccent,
                                      fontWeight: FontWeight.w400,
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
