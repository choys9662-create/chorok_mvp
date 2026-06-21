import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/core/services/screen_time_detox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('chorok/screen_time');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('네이티브 Shield 활성화 결과를 enabled로 변환한다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startDetox');
      return 'enabled';
    });

    final status = await ScreenTimeDetoxService.instance.startDetox();

    expect(status, DetoxStartStatus.enabled);
  });

  test('정상 종료 시 네이티브 Shield 해제를 요청한다', () async {
    var stopped = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stopDetox') stopped = true;
      return null;
    });

    await ScreenTimeDetoxService.instance.stopDetox();

    expect(stopped, isTrue);
  });
}
