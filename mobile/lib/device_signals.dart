import 'package:flutter/services.dart';

const _channel = MethodChannel('ai.biolivestock/device_signals');

/// Device heuristics are advisory, bypassable and not hardware attestation.
Future<Map<String, dynamic>> readDeviceSignals() async {
  try {
    final result = await _channel.invokeMapMethod<String, dynamic>('readSignals');
    if (result != null) return Map<String, dynamic>.from(result);
  } on PlatformException {
    // Unsupported or failing native checks remain unknown, never "safe".
  } on MissingPluginException {
    // iOS has no native implementation in this milestone.
  }
  return {'source': 'unsupported', 'is_rooted': null, 'is_emulator': null};
}
