import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/prescription_suggestions.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import 'auth_token_store.dart';

/// Build-time configuration for the API.
///
/// Override the base URL at build or run time with:
///
///   flutter run --dart-define=API_BASE_URL=https://api.calfit.app
///
/// so staging and production URLs never need a code change.
class ApiConfig {
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// The base URL the app will hit.
  ///
  /// Priority: `--dart-define=API_BASE_URL` > sensible platform default.
  /// On the Android emulator `127.0.0.1` points at the device, not the host,
  /// so Android dev builds default to `10.0.2.2` (the loopback alias to the
  /// host machine). Everything else falls back to `127.0.0.1`.
  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
    } catch (_) {
      // Platform not available (e.g. tests on web); fall through.
    }
    return 'http://127.0.0.1:8000';
  }

  static const Duration lightTimeout = Duration(seconds: 10);
  static const Duration scanTimeout = Duration(seconds: 45);
}

/// A thin, typed exception the UI can show without leaking stack details.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl;
  final http.Client client;
  final AuthTokenStore tokenStore;

  ApiService({String? baseUrl, http.Client? client, AuthTokenStore? tokenStore})
      : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        client = client ?? http.Client(),
        tokenStore = tokenStore ?? PrefsAuthTokenStore();

  /// Returns the stored device token, registering this install with the
  /// backend the first time. The server picks the user id; the app never does.
  Future<String>? _registering;

  Future<String> _token() async {
    final existing = await tokenStore.read();
    if (existing != null && existing.isNotEmpty) return existing;
    // Screens fire several calls at once on first launch; share one
    // registration so they don't each mint (and fight over) an identity.
    final inFlight = _registering ??= _register();
    try {
      return await inFlight;
    } finally {
      _registering = null;
    }
  }

  Future<String> _register() async {
    final res = await client
        .post(_uri('/api/v1/auth/device'))
        .timeout(ApiConfig.lightTimeout);
    if (res.statusCode != 200) {
      throw _fromResponse('register this device', res);
    }
    final token = (jsonDecode(res.body) as Map<String, dynamic>)['token'];
    if (token is! String || token.isEmpty) {
      throw ApiException('The server returned an unexpected response.');
    }
    await tokenStore.write(token);
    return token;
  }

  /// Runs [send] with the bearer token. If the server rejects the token
  /// (401), drops it, registers a fresh identity once and retries.
  Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> authHeader) send,
  ) async {
    var res = await send({'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode == 401) {
      await tokenStore.clear();
      res = await send({'Authorization': 'Bearer ${await _token()}'});
    }
    return res;
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<bool> checkHealth() async {
    try {
      final res = await client
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile> getProfile() async {
    return _run(() async {
      final res = await _authed((h) => client
          .get(_uri('/api/v1/profile'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(res.body));
      }
      throw _fromResponse('load your profile', res);
    });
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    return _run(() async {
      final res = await _authed((h) => client
          .put(
            _uri('/api/v1/profile'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': profile.name,
              'health_conditions': profile.healthConditions,
              'allergies': profile.allergies,
              'dietary_preferences': profile.dietaryPreferences,
              'health_goals': profile.healthGoals,
            }),
          )
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        return UserProfile.fromJson(jsonDecode(res.body));
      }
      throw _fromResponse('save your profile', res);
    });
  }

  Future<ScanResult> submitScan({
    required Uint8List photoBytes,
    String filename = 'product_photo.jpg',
  }) async {
    return _run(() async {
      // A MultipartRequest can only be sent once, so build a fresh one per
      // attempt (the helper may retry after a 401).
      final response = await _authed((h) async {
        final request = http.MultipartRequest('POST', _uri('/api/v1/scans'));
        request.headers.addAll(h);
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: filename,
          contentType: _contentTypeFor(filename),
        ));
        final streamed = await client.send(request).timeout(ApiConfig.scanTimeout);
        return http.Response.fromStream(streamed);
      });

      if (response.statusCode == 200) {
        return ScanResult.fromJson(jsonDecode(response.body));
      }
      throw _fromResponse('analyze this product', response);
    });
  }

  /// Sends a prescription photo for reading and returns *suggestions only*.
  /// The server does not store the photo or what it read.
  Future<PrescriptionSuggestions> analyzePrescription({
    required Uint8List photoBytes,
    String filename = 'prescription.jpg',
  }) async {
    return _run(() async {
      final response = await _authed((h) async {
        final request = http.MultipartRequest(
            'POST', _uri('/api/v1/profile/prescription-suggestions'));
        request.headers.addAll(h);
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: filename,
          contentType: _contentTypeFor(filename),
        ));
        final streamed =
            await client.send(request).timeout(ApiConfig.scanTimeout);
        return http.Response.fromStream(streamed);
      });

      if (response.statusCode == 200) {
        return PrescriptionSuggestions.fromJson(jsonDecode(response.body));
      }
      // These messages are written for the user (feature off, daily limit,
      // unreadable photo), so show them rather than a generic error.
      final detail = _detailOf(response);
      if (detail != null) {
        throw ApiException(detail, statusCode: response.statusCode);
      }
      throw _fromResponse('read this prescription', response);
    });
  }

  static String? _detailOf(http.Response res) {
    try {
      final d = (jsonDecode(res.body) as Map<String, dynamic>)['detail'];
      return d is String && d.isNotEmpty ? d : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<ScanHistoryItem>> getScanHistory() async {
    return _run(() async {
      final res = await _authed((h) => client
          .get(_uri('/api/v1/scans/history'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ScanHistoryItem.fromJson(e)).toList();
      }
      throw _fromResponse('load your scan history', res);
    });
  }

  // ---- helpers ----

  /// Wraps a network call and converts platform exceptions into [ApiException].
  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
          "That took too long. Check your connection and try again.");
    } on SocketException catch (e) {
      debugPrint('Network error: $e');
      throw ApiException(
          "Can't reach the CalFit server. Check your internet and try again.");
    } on FormatException catch (e) {
      // Type only: FormatException text includes a snippet of the response,
      // which for some endpoints is health data.
      debugPrint('Bad response format: ${e.runtimeType}');
      throw ApiException('The server returned an unexpected response.');
    } catch (e) {
      debugPrint('Unexpected API error: $e');
      throw ApiException('Something went wrong. Please try again.');
    }
  }

  static MediaType _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return MediaType('image', 'heic');
    }
    return MediaType('image', 'jpeg');
  }

  ApiException _fromResponse(String action, http.Response res) {
    debugPrint('API ${res.statusCode} on $action: ${res.body}');
    if (res.statusCode == 400) {
      return ApiException(
          "We couldn't $action — the request looks invalid.",
          statusCode: res.statusCode);
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      return ApiException("You're not authorized for this action.",
          statusCode: res.statusCode);
    }
    if (res.statusCode == 404) {
      return ApiException("We couldn't find what you're looking for.",
          statusCode: res.statusCode);
    }
    if (res.statusCode >= 500) {
      return ApiException(
          "The CalFit server is having a bad moment. Please try again shortly.",
          statusCode: res.statusCode);
    }
    return ApiException("We couldn't $action right now.",
        statusCode: res.statusCode);
  }
}
