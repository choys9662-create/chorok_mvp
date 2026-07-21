import 'package:flutter/material.dart';
import 'package:smooth_corner/smooth_corner.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';

class HighlightPreview extends StatelessWidget {
  final List<({String text, String book})> highlights;

  const HighlightPreview({super.key, required this.highlights});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(highlights.length, (i) {
          final h = highlights[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: AppTheme.spaceSM,
                          children: [
                            Text(
                              '\u201c${h.text}\u201d',
                              style: AppTheme.bodySmall.copyWith(
                                color: context.appTextSecondary,
                                height: 1.6,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '— ${h.book}',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < highlights.length - 1)
                const SizedBox(height: AppTheme.spaceXS),
            ],
          );
        }),
      ),
    );
  }
}

class SentenceReactionsCard extends StatelessWidget {
  final List<({String text, String book, int reactions, bool isTop})> sentences;

  const SentenceReactionsCard({super.key, required this.sentences});

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(sentences.length, (i) {
          final s = sentences[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppTheme.spaceXS,
                        children: [
                          Text(
                            '\u201c${s.text}\u201d',
                            style: AppTheme.bodySmall.copyWith(
                              color: context.appTextSecondary,
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '— ${s.book}',
                            style: AppTheme.captionSmall.copyWith(
                              color: context.appTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (s.isTop)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: AppTheme.smoothPill(
                              gradient: AppTheme.greenGradient,
                            ),
                            child: Text(
                              'TOP',
                              style: AppTheme.captionSmall.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                                fontSize: AppTheme.fsCaption,
                              ),
                            ),
                          ),
                        const SizedBox(height: AppTheme.spaceXS),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: context.appPrimaryAccent,
                            ),
                            const SizedBox(width: AppTheme.spaceXS),
                            Text(
                              '${s.reactions}',
                              style: AppTheme.captionSmall.copyWith(
                                color: context.appPrimaryAccent,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < sentences.length - 1)
                const SizedBox(height: AppTheme.spaceXS),
            ],
          );
        }),
      ),
    );
  }
}

class CommunityHighlightsCard extends StatelessWidget {
  final List<({String text, String book, int reactions})> highlights;

  const CommunityHighlightsCard({super.key, required this.highlights});

  String _formatReactions(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(highlights.length, (i) {
          final h = highlights[i];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: ShapeDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        shape: SmoothRectangleBorder(
                          smoothness: 0.6,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusInner,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: AppTheme.captionLarge.copyWith(
                            color: context.appPrimaryAccent,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            '\u201c${h.text}\u201d',
                            style: AppTheme.bodySmall.copyWith(
                              color: context.appTextPrimary,
                              height: 1.55,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                '— ${h.book}',
                                style: AppTheme.captionSmall.copyWith(
                                  color: context.appTextTertiary,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.favorite_rounded,
                                size: 11,
                                color: AppTheme.accent,
                              ),
                              const SizedBox(width: AppTheme.spaceXS),
                              Text(
                                _formatReactions(h.reactions),
                                style: AppTheme.captionSmall.copyWith(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (i < highlights.length - 1)
                const SizedBox(height: AppTheme.spaceXS),
            ],
          );
        }),
      ),
    );
  }
}
