import 'dart:math' as math;

import 'package:flutter/widgets.dart';

Rect quoteGuideFrameRect(Size size, EdgeInsets padding) {
  final frameW = math.min(size.width - 60, 330.0);
  final maxFrameH = math.max(
    260.0,
    size.height - padding.top - padding.bottom - 360,
  );
  final frameH = math.min(math.max(frameW * 1.03, 300.0), maxFrameH);
  final frameLeft = (size.width - frameW) / 2;
  final frameTop = math.max(padding.top + 83, (size.height - frameH) * 0.18);
  return Rect.fromLTWH(frameLeft, frameTop, frameW, frameH);
}

Rect ocrCaptureCropRect(Rect guideFrame) {
  final horizontalInset = math.min(guideFrame.width * 0.035, 12.0);
  final verticalInset = math.min(guideFrame.height * 0.04, 10.0);

  if (guideFrame.width <= horizontalInset * 2 ||
      guideFrame.height <= verticalInset * 2) {
    return guideFrame;
  }

  return Rect.fromLTRB(
    guideFrame.left + horizontalInset,
    guideFrame.top + verticalInset,
    guideFrame.right - horizontalInset,
    guideFrame.bottom - verticalInset,
  );
}

Rect sourceRectForViewportCrop({
  required Size sourceSize,
  required Rect? cropRect,
  required Size? viewportSize,
}) {
  if (cropRect == null ||
      viewportSize == null ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0) {
    return Offset.zero & sourceSize;
  }

  final scale = math.max(
    viewportSize.width / sourceSize.width,
    viewportSize.height / sourceSize.height,
  );
  final displayedWidth = sourceSize.width * scale;
  final displayedHeight = sourceSize.height * scale;
  final overflowX = (displayedWidth - viewportSize.width) / 2;
  final overflowY = (displayedHeight - viewportSize.height) / 2;
  final left = ((cropRect.left + overflowX) / scale).clamp(
    0.0,
    sourceSize.width - 1,
  );
  final top = ((cropRect.top + overflowY) / scale).clamp(
    0.0,
    sourceSize.height - 1,
  );
  final right = ((cropRect.right + overflowX) / scale).clamp(
    left + 1,
    sourceSize.width,
  );
  final bottom = ((cropRect.bottom + overflowY) / scale).clamp(
    top + 1,
    sourceSize.height,
  );

  return Rect.fromLTRB(left, top, right, bottom);
}
