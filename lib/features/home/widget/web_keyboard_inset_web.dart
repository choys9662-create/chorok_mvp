import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class WebKeyboardInsetController extends ChangeNotifier {
  static const _minimumKeyboardInset = 80.0;

  final List<StreamSubscription<web.Event>> _subscriptions = [];
  double _inset = 0;

  double get inset => _inset;

  void start() {
    if (_subscriptions.isNotEmpty) return;

    final visualViewport = web.window.visualViewport;
    if (visualViewport != null) {
      _subscriptions
        ..add(
          web.EventStreamProviders.resizeEvent
              .forTarget(visualViewport)
              .listen((_) => _updateInset()),
        )
        ..add(
          web.EventStreamProviders.scrollEvent
              .forTarget(visualViewport)
              .listen((_) => _updateInset()),
        );
    }

    _subscriptions.add(
      web.EventStreamProviders.resizeEvent
          .forTarget(web.window)
          .listen((_) => _updateInset()),
    );
    _updateInset();
  }

  void _updateInset() {
    final visualViewport = web.window.visualViewport;
    final viewportInset = visualViewport == null
        ? 0.0
        : web.window.innerHeight -
              visualViewport.height -
              visualViewport.offsetTop;
    final nextInset = math.max(0.0, viewportInset);
    final keyboardInset = nextInset >= _minimumKeyboardInset ? nextInset : 0.0;

    if ((_inset - keyboardInset).abs() < 1) return;
    _inset = keyboardInset;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
