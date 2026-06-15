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
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              '오늘도 같이 읽어요',
              style: AppTheme.headingLarge.copyWith(
                color: context.appTextSecondary,
                fontSize: 28,
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
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.push(AppConstants.routeNotifications);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: context.appTextSecondary,
                      size: 32,
                    ),
                    Positioned(
                      top: 7,
                      right: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
