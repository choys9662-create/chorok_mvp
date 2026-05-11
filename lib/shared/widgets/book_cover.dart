import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

class BookCover extends StatelessWidget {
  final String? coverUrl;
  final int gradientIndex;
  final double? width;
  final double? height;
  final double radius;
  final List<BoxShadow>? shadows;
  final Widget? fallbackIcon;
  final Widget? child;

  const BookCover({
    super.key,
    this.coverUrl,
    this.gradientIndex = 0,
    this.width,
    this.height,
    this.radius = AppTheme.radiusMD,
    this.shadows,
    this.fallbackIcon,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final gradColors = AppTheme.coverGradientByIndex(gradientIndex);

    return Container(
      width: width,
      height: height,
      decoration: AppTheme.smoothBox(
        radius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fallback 배경 및 아이콘
          if (fallbackIcon != null)
            fallbackIcon!
          else
            Center(
              child: Icon(
                Icons.menu_book,
                color: Colors.white.withValues(alpha: 0.5),
                size: (width != null ? width! / 2.5 : 24),
              ),
            ),

          // 실제 이미지 (캐싱 적용)
          if (coverUrl != null && coverUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: coverUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
              placeholder: (context, url) => const SizedBox.shrink(),
            ),

          // 추가 자식 위젯 (이미지 위에 렌더링)
          ?child,
        ],
      ),
    );
  }
}
