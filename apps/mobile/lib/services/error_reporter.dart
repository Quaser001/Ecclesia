import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// Catches Flutter-level errors and sends them to our API as structured
/// crash reports. The API logs them in Cloud Logging — no third-party
/// crash service on the phone (agents.md §5: the app talks only to our API).
///
/// What is sent: the error's runtime type and stack frames (file, line,
/// function). Never the error message — it can echo health data from
/// prompts, API responses or profile fields.
class ErrorReporter {
  final String _baseUrl;
  final http.Client _client;
  int _reportsSent = 0;

  static const _maxPerRun = 5;
  static const _timeout = Duration(seconds: 5);

  ErrorReporter({String? baseUrl, http.Client? client})
      : _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Wire into Flutter's global error hooks. Call once, from main().
  void install() {
    if (kDebugMode) return;

    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      _send(details.exception, details.stack);
      prev?.call(details);
    };

    final prevPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _send(error, stack);
      return prevPlatform?.call(error, stack) ?? false;
    };
  }

  void _send(Object error, StackTrace? stack) {
    if (_reportsSent >= _maxPerRun) return;
    _reportsSent++;

    final frames = _parseFrames(stack);
    final body = {
      'error_type': error.runtimeType.toString(),
      'frames': frames,
      'app_version': const String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
      'platform': 'android',
    };

    _post(body);
  }

  Future<void> _post(Map<String, dynamic> body) async {
    try {
      await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/client-errors'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } catch (_) {
      // A failure while reporting must never report itself.
    }
  }

  @visibleForTesting
  Future<void> postForTest(Map<String, dynamic> body) => _post(body);

  @visibleForTesting
  static List<Map<String, dynamic>> parseFramesForTest(StackTrace? stack) =>
      _parseFrames(stack);

  static List<Map<String, dynamic>> _parseFrames(StackTrace? stack) {
    if (stack == null) return [];
    final lines = stack.toString().split('\n');
    final result = <Map<String, dynamic>>[];
    final pattern = RegExp(r'#\d+\s+(\S+)\s+\((.+?):(\d+)(?::\d+)?\)');
    for (final line in lines) {
      if (result.length >= 20) break;
      final m = pattern.firstMatch(line);
      if (m != null) {
        result.add({
          'file': m.group(2)!.split('/').last,
          'line': int.tryParse(m.group(3)!) ?? 0,
          'fn': m.group(1)!,
        });
      }
    }
    return result;
  }
}
