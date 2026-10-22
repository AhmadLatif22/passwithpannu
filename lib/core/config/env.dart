import 'package:flutter/foundation.dart';

/// Build-time flags only (`--dart-define`). Never put secrets here.
abstract final class Env {
  static const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');
  static const String _host = String.fromEnvironment('EMULATOR_HOST');

  static String get emulatorHost {
    if (_host.isNotEmpty) return _host;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }
}
