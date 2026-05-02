import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/gradient_text.dart';

class QualitativeInsightCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const QualitativeInsightCard({super.key, 
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36, height: 36,
                decoration: AppTheme.smoothBox(
                  gradient: AppTheme.greenGradient,
                  radius: AppTheme.radiusMD,
                ),
                child: Icon(icon, color: Colors.black, size: 18),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message,
                    style: AppTheme.bodyMedium.copyWith(
                      color: context.appTextPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppTheme.spaceMD),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppTheme.smoothBox(
                color: AppTheme.primary.withValues(alpha: 0.2),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                radius: AppTheme.radiusMD,
              ),
              child: Text(
                subMessage!,
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ReadingPersonaCard extends StatelessWidget {
  final String persona;
  final IconData icon;
  final String description;

  const ReadingPersonaCard({super.key, 
    required this.persona,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: AppTheme.smoothBox(
              gradient: AppTheme.greenGradient,
              radius: AppTheme.radiusMD,
            ),
            child: Icon(icon, color: Colors.black, size: 24),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  persona,
                  style: AppTheme.headingMedium.copyWith(color: context.appPrimaryAccent),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    color: context.appTextSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReaderIdentityCard extends StatelessWidget {
  final String identity;
  final IconData icon;
  final String description;

  const ReaderIdentityCard({super.key, 
    required this.identity,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      padding: const EdgeInsets.all(AppTheme.cardPaddingLG),
      borderColor: AppTheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: AppTheme.smoothBox(
                  gradient: AppTheme.greenGradient,
                  radius: AppTheme.radiusMD,
                ),
                child: Icon(icon, color: Colors.black, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              Text(
                '올해 나는',
                style: AppTheme.captionLarge.copyWith(color: context.appTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),
          GradientText(
            identity,
            style: AppTheme.displaySmall.copyWith(height: 1.1),
            gradient: AppTheme.greenGradientVertical,
          ),
          const SizedBox(height: AppTheme.spaceMD),
          Divider(color: context.appBorder, height: 1),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: context.appTextSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}