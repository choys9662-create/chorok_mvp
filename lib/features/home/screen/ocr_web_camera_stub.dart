import 'dart:typed_data';

import 'package:flutter/widgets.dart';

class OcrWebCameraController {
  bool get isReady => false;

  Future<void> initialize() {
    throw UnsupportedError('Web camera is only available on web.');
  }

  Future<Uint8List> captureJpeg() {
    throw UnsupportedError('Web camera is only available on web.');
  }

  void dispose() {}
}

class OcrWebCameraPreview extends StatelessWidget {
  final OcrWebCameraController controller;

  const OcrWebCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
