import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';

/// 알라딘 cover150 은 1px 흰 테두리가 이미지에 박혀 있고(표지 좌우에 흰 선으로 보임)
/// 3x 기기엔 해상도도 모자람. cover500 은 테두리가 없다.
/// ponytail: 문자열 치환으로 충분. 알라딘 외 URL 은 그대로 통과.
String? normalizedCoverUrl(String? url) =>
    url?.replaceFirst('/cover150/', '/cover500/');

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
    final fallback = coverUrl == null || coverUrl!.isEmpty;
    final url = normalizedCoverUrl(coverUrl);

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
                size: (width != null && width!.isFinite ? width! / 2.5 : 24),
              ),
            ),

          // 실제 이미지 (캐싱 적용)
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 200),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
              placeholder: (context, url) => const SizedBox.shrink(),
            ),

          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: fallback
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.10),
              ),
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: fallback ? 0.06 : 0.02),
                  Colors.black.withValues(alpha: fallback ? 0.12 : 0.18),
                ],
              ),
            ),
          ),

          // 추가 자식 위젯 (이미지 위에 렌더링)
          ?child,
        ],
      ),
    );
  }
}
