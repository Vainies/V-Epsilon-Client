import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports uncaught Flutter / Dart errors to the server.
/// Gracefully degrades to debugPrint on network failure.
class CrashReporter {
  final String baseUrl;
  String _appVersion = '0.0.0';
  String _platform = 'unknown';
  String _device = 'unknown';
  String _deviceId = 'unknown';

  CrashReporter(this.baseUrl);

  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = info.version;
    } catch (_) {}
    if (Platform.isAndroid) {
      _platform = 'android';
    } else if (Platform.isLinux) {
      _platform = 'linux';
    } else if (Platform.isWindows) {
      _platform = 'windows';
    } else if (Platform.isIOS) {
      _platform = 'ios';
    } else if (Platform.isMacOS) {
      _platform = 'macos';
    }
    _device = Platform.operatingSystemVersion;
    // Generate / load a stable device ID
    final sp = await SharedPreferences.getInstance();
    var id = sp.getString('device_id');
    if (id == null || id.isEmpty) {
      id = '${DateTime.now().microsecondsSinceEpoch}-${1000000 + (DateTime.now().millisecond * 7919)}';
      await sp.setString('device_id', id);
    }
    _deviceId = id;

    // Install Flutter error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // still print to console
      _report(
        errorType: details.exception.runtimeType.toString(),
        message: details.exceptionAsString(),
        stack: details.stack?.toString() ?? '',
        context: details.library ?? '',
      );
    };

    // Install async error handler
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(
        errorType: error.runtimeType.toString(),
        message: error.toString(),
        stack: stack.toString(),
        context: 'uncaught-async',
      );
      return false; // let default handler continue
    };

    // Send heartbeat so server knows this version is in use
    unawaited(_heartbeat());
  }

  Future<void> _heartbeat() async {
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/v1/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'app_version': _appVersion,
              'device_id': _deviceId,
              'platform': _platform,
            }),
          )
          .timeout( const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _report({
    required String errorType,
    required String message,
    required String stack,
    required String context,
  }) async {
    if (kDebugMode) {
      debugPrint('[crash] $errorType: $message');
    }
    try {
      await http
          .post(
            Uri.parse('$baseUrl/api/v1/crash'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'app_version': _appVersion,
              'platform': _platform,
              'device': _device,
              'device_id': _deviceId,
              'error_type': errorType,
              'message': message,
              'stack': stack,
              'context': context,
            }),
          )
          .timeout( const Duration(seconds: 8));
    } catch (_) {}
  }

  String get appVersion => _appVersion;
  String get deviceId => _deviceId;
}
