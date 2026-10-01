import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biolivestock_capture/device_signals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai.biolivestock/device_signals');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('reported Android device signals are preserved', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readSignals');
      return {'source': 'android_heuristic', 'is_rooted': true, 'is_emulator': false};
    });
    final report = await readDeviceSignals();
    expect(report['is_rooted'], true);
    expect(report['is_emulator'], false);
  });

  test('missing native implementation stays unknown', () async {
    final report = await readDeviceSignals();
    expect(report['source'], 'unsupported');
    expect(report['is_rooted'], isNull);
    expect(report['is_emulator'], isNull);
  });

  test('native failure stays unknown', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    expect((await readDeviceSignals())['is_rooted'], isNull);
  });
}
