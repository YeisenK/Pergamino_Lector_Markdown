import 'package:flutter/services.dart';

/// Nivel de batería (0–100) leído en Android con BatteryManager. Null si no se puede.
Future<int?> batteryLevel() async {
  try {
    const ch = MethodChannel('pergamino/battery');
    final v = await ch.invokeMethod<int>('level');
    return v;
  } catch (_) {
    return null;
  }
}
