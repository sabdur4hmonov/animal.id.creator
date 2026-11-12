import 'dart:io';
import 'package:flutter/services.dart';

/// Populated from the installed package before constructing any native workflow.
/// Demo safety is independent of a Dart target or API_TOKEN build argument.
class AppRuntimeMode {
  const AppRuntimeMode({required this.demo});
  final bool demo;
  static const channel = MethodChannel('ai.biolivestock/app_mode');
  static Future<AppRuntimeMode> readAndroidMode() async {
    final value = await channel.invokeMethod<bool>('isDemo');
    if (value == null) throw StateError('Application mode unavailable');
    return AppRuntimeMode(demo: value);
  }

  static Future<AppRuntimeMode> detect() async => Platform.isAndroid
      ? readAndroidMode()
      : const AppRuntimeMode(demo: false);
}

AppRuntimeMode runtimeMode = const AppRuntimeMode(demo: false);
