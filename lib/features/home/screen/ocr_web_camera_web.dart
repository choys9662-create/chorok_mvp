import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'ocr_capture_crop.dart';

const _webCameraStartTimeout = Duration(seconds: 10);

class OcrWebCameraController {
  OcrWebCameraController()
    : _viewType = 'ocr-web-camera-${_nextViewId++}',
      _videoElement = web.HTMLVideoElement(),
      _containerElement = web.HTMLDivElement() {
    _configureElements();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (_) => _containerElement,
    );
  }

  static int _nextViewId = 0;

  final String _viewType;
  final web.HTMLVideoElement _videoElement;
  final web.HTMLDivElement _containerElement;
  web.MediaStream? _stream;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> initialize() async {
    final stream = await _openCameraStream();
    _stream = stream;
    _videoElement.srcObject = stream;
    await _videoElement.play().toDart.timeout(_webCameraStartTimeout);
    await _waitForVideoFrame();
    _ready = true;
  }

  Future<Uint8List> captureJpeg({Rect? cropRect, Size? viewportSize}) async {
    final width = _videoElement.videoWidth;
    final height = _videoElement.videoHeight;
    if (!_ready || width <= 0 || height <= 0) {
      throw StateError('Web camera video frame is not ready.');
    }

    final sourceRect = sourceRectForViewportCrop(
      sourceSize: Size(width.toDouble(), height.toDouble()),
      cropRect: cropRect,
      viewportSize: viewportSize,
    );
    final canvas = web.HTMLCanvasElement()
      ..width = sourceRect.width.round()
      ..height = sourceRect.height.round();
    canvas.context2D.drawImage(
      _videoElement,
      sourceRect.left,
      sourceRect.top,
      sourceRect.width,
      sourceRect.height,
      0,
      0,
      canvas.width,
      canvas.height,
    );

    final completer = Completer<web.Blob>();
    canvas.toBlob(
      (web.Blob blob) {
        completer.complete(blob);
      }.toJS,
      'image/jpeg',
      0.88.toJS,
    );
    final blob = await completer.future;
    final buffer = await blob.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  }

  void dispose() {
    final tracks = _stream?.getTracks().toDart;
    if (tracks != null) {
      for (final track in tracks) {
        track.stop();
      }
    }
    _videoElement.srcObject = null;
    _stream = null;
    _ready = false;
  }

  void _configureElements() {
    _containerElement.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('overflow', 'hidden')
      ..setProperty('background', '#000');

    _videoElement
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '')
      ..setAttribute('webkit-playsinline', '');

    _videoElement.style
      ..setProperty('width', '100%')
      ..setProperty('height', '100%')
      ..setProperty('object-fit', 'cover')
      ..setProperty('pointer-events', 'none')
      ..setProperty('background', '#000');

    _containerElement.appendChild(_videoElement);
  }

  Future<web.MediaStream> _openCameraStream() async {
    final mediaDevices = web.window.navigator.mediaDevices;
    try {
      return await mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: {
                'facingMode': {'ideal': 'environment'},
                'width': {'ideal': 1920},
                'height': {'ideal': 1080},
              }.jsify()!,
            ),
          )
          .toDart;
    } catch (_) {
      return mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: {
                'facingMode': {'ideal': 'environment'},
              }.jsify()!,
            ),
          )
          .toDart;
    }
  }

  Future<void> _waitForVideoFrame() async {
    if (_videoElement.videoWidth > 0 && _videoElement.videoHeight > 0) {
      return;
    }

    final completer = Completer<void>();
    late final StreamSubscription<web.Event> metadataSub;
    late final StreamSubscription<web.Event> playingSub;
    late final StreamSubscription<web.Event> errorSub;

    void completeIfReady() {
      if (completer.isCompleted) return;
      if (_videoElement.videoWidth > 0 && _videoElement.videoHeight > 0) {
        completer.complete();
      }
    }

    metadataSub = web.EventStreamProviders.loadedMetadataEvent
        .forElement(_videoElement)
        .listen((_) => completeIfReady());
    playingSub = web.EventStreamProviders.playingEvent
        .forElement(_videoElement)
        .listen((_) => completeIfReady());
    errorSub = web.EventStreamProviders.errorElementEvent
        .forElement(_videoElement)
        .listen((_) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('Web camera video failed.'));
          }
        });
    completeIfReady();

    try {
      await completer.future.timeout(_webCameraStartTimeout);
    } finally {
      await metadataSub.cancel();
      await playingSub.cancel();
      await errorSub.cancel();
    }
  }
}

class OcrWebCameraPreview extends StatelessWidget {
  final OcrWebCameraController controller;

  const OcrWebCameraPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: controller._viewType);
  }
}
