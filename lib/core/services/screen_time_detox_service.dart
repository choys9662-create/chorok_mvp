import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DetoxStartStatus {
  enabled,
  denied,
  cancelled,
  emptySelection,
  unsupported,
  failed,
}

class ScreenTimeDetoxService {
  ScreenTimeDetoxService._();

  static final instance = ScreenTimeDetoxService._();
  static const _channel = MethodChannel('chorok/screen_time');

  Future<DetoxStartStatus> startDetox() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return DetoxStartStatus.unsupported;
    }

    try {
      final status = await _channel.invokeMethod<String>('startDetox');
      return switch (status) {
        'enabled' => DetoxStartStatus.enabled,
        'denied' => DetoxStartStatus.denied,
        'cancelled' => DetoxStartStatus.cancelled,
        'emptySelection' => DetoxStartStatus.emptySelection,
        _ => DetoxStartStatus.unsupported,
      };
    } on MissingPluginException {
      return DetoxStartStatus.unsupported;
    } on PlatformException {
      return DetoxStartStatus.failed;
    }
  }

  Future<void> stopDetox() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _channel.invokeMethod<void>('stopDetox');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  Future<bool> isDetoxEnabled() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isDetoxEnabled') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
