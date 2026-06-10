import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '오늘도 같이 읽어요',
              style: AppTheme.headingLarge.copyWith(
                color: context.appPrimaryAccent,
                fontSize: 24,
                letterSpacing: 0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // 알림 버튼
          Semantics(
            label: '알림',
            button: true,
            child: SizedBox(
              width: 28,
              height: 28,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeNotifications);
                },
                child: DecoratedBox(
                  decoration: AppTheme.smoothBox(
                    color: context.appCard,
                    radius: 6,
                    side: BorderSide.none,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: context.appTextSecondary,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
