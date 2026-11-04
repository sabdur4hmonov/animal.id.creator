import 'dart:convert';
import 'package:flutter/services.dart';

/// The only source of production metric points. Tests inject an explicit fake.
class ArBridge {
  static const channel = MethodChannel('ai.biolivestock/ar_measurement');
  Future<Map<String, dynamic>> probe() async =>
      Map<String, dynamic>.from(await channel.invokeMethod('probe') as Map);
  Future<Map<String, dynamic>> measure(
    Map<String, dynamic> specification,
  ) async => Map<String, dynamic>.from(
    jsonDecode(
          await channel.invokeMethod<String>(
                'measure',
                jsonEncode(specification),
              )
              as String,
        )
        as Map,
  );
}
