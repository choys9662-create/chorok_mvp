import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

/// 책 표지 이미지에서 강조색(테두리·진행바 틴트)을 추출한다.
///
/// 표지가 파란색이면 파란색, 초록색이면 초록색 — 표지 테마를 따라간다.
/// 추출 실패(이미지 없음/네트워크 오류) 시 null 을 반환하므로,
/// 호출부에서 브랜드 기본색으로 폴백한다.
final coverColorProvider = FutureProvider.family<Color?, String?>((
  ref,
  coverUrl,
) async {
  if (coverUrl == null || coverUrl.isEmpty) return null;

  final palette = await PaletteGenerator.fromImageProvider(
    CachedNetworkImageProvider(coverUrl),
    size: const Size(80, 120), // 다운샘플 — 추출은 작은 이미지로 충분
    maximumColorCount: 16,
  );

  // 선명한 색을 우선 — vibrant > lightVibrant > dominant
  final swatch = palette.vibrantColor ??
      palette.lightVibrantColor ??
      palette.dominantColor;
  return swatch?.color;
});
