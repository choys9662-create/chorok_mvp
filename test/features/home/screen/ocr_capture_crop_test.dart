import 'package:chorok_app/features/home/screen/ocr_capture_crop.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('quoteGuideFrameRect', () {
    test('keeps the guide frame inside the viewport', () {
      final frame = quoteGuideFrameRect(
        const Size(390, 844),
        const EdgeInsets.only(top: 47, bottom: 34),
      );

      expect(frame.left, greaterThanOrEqualTo(0));
      expect(frame.top, greaterThanOrEqualTo(0));
      expect(frame.right, lessThanOrEqualTo(390));
      expect(frame.bottom, lessThanOrEqualTo(844));
    });
  });

  group('ocrCaptureCropRect', () {
    test('uses an inner rect so OCR excludes the visible frame edge', () {
      final guide = Rect.fromLTWH(20, 120, 350, 230);
      final crop = ocrCaptureCropRect(guide);

      expect(guide.contains(crop.topLeft), isTrue);
      expect(guide.contains(crop.bottomRight), isTrue);
      expect(crop.left, greaterThan(guide.left));
      expect(crop.top, greaterThan(guide.top));
      expect(crop.right, lessThan(guide.right));
      expect(crop.bottom, lessThan(guide.bottom));
    });
  });

  group('sourceRectForViewportCrop', () {
    test('maps a cover-fitted viewport rect back to source pixels', () {
      final source = sourceRectForViewportCrop(
        sourceSize: const Size(1000, 500),
        viewportSize: const Size(400, 400),
        cropRect: Rect.fromLTWH(100, 50, 200, 100),
      );

      expect(source.left, closeTo(375, 0.001));
      expect(source.top, closeTo(62.5, 0.001));
      expect(source.right, closeTo(625, 0.001));
      expect(source.bottom, closeTo(187.5, 0.001));
    });

    test('returns the whole source when crop data is unavailable', () {
      final source = sourceRectForViewportCrop(
        sourceSize: const Size(1080, 1920),
        viewportSize: null,
        cropRect: Rect.fromLTWH(0, 0, 100, 100),
      );

      expect(source, Offset.zero & const Size(1080, 1920));
    });
  });
}
