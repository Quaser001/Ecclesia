import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/prescription_suggestions.dart';
import '../models/scan_result.dart';
import '../models/insights.dart';
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
    // A release build must be pointed at the real (https) server. Falling
    // back to the emulator's cleartext address would send health data
    // unencrypted to whatever answers on 10.0.2.2.
    if (kReleaseMode) {
      throw StateError('Release builds need --dart-define=API_BASE_URL=https://...');
    }
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
/// What went wrong, so the app can show a message in the user's language.
enum ApiErrorKind {
  network, timeout, badRequest, unauthorized, notFound, rateLimited, server, other,
  // The old identity was replaced by a new, empty one: set up the profile again.
  profileReset,
  prescriptionLimit,
}

class ApiException implements Exception {
  final String message; // English, for logs only
  final int? statusCode;
  final ApiErrorKind kind;

  ApiException(this.message, {this.statusCode, this.kind = ApiErrorKind.other});

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
  /// (401), drops it and registers a fresh identity once.
  ///
  /// The fresh identity has an EMPTY profile on the server, so a scan scored
  /// with it would ignore the user's allergies. A call that [scores] a
  /// product is therefore never retried: it fails with
  /// [ApiErrorKind.profileReset], and so does every scan until the profile is
  /// saved again. Other calls retry so the app keeps working.
  Future<http.Response> _authed(
    Future<http.Response> Function(Map<String, String> authHeader) send, {
    bool scores = false,
  }) async {
    if (scores && await tokenStore.profileResetPending()) throw _profileReset();
    var res = await send({'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode == 401) {
      await tokenStore.clear();
      await tokenStore.setProfileResetPending(true);
      if (scores) throw _profileReset();
      res = await send({'Authorization': 'Bearer ${await _token()}'});
    }
    return res;
  }

  static ApiException _profileReset() => ApiException(
      'Identity was reset; the profile must be saved again before scanning.',
      statusCode: 401,
      kind: ApiErrorKind.profileReset);

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
            body: jsonEncode(profile.toRequestJson()),
          )
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        await tokenStore.setProfileResetPending(false);
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
      }, scores: true);

      if (response.statusCode == 200) {
        return ScanResult.fromJson(jsonDecode(response.body));
      }
      throw _fromResponse('analyze this product', response);
    });
  }

  /// Scores the product the user confirmed or picked after a front-of-pack
  /// scan. Only its code goes up; the server fetches the product's data
  /// itself. The photo is sent again so it is saved with the scan.
  Future<ScanResult> confirmScan({
    required Uint8List photoBytes,
    required ProductOption option,
    String filename = 'product_photo.jpg',
  }) async {
    return _run(() async {
      final response = await _authed((h) async {
        final request = http.MultipartRequest('POST', _uri('/api/v1/scans/confirm'));
        request.headers.addAll(h);
        request.fields['product_code'] = option.code;
        request.fields['source'] = option.source;
        request.files.add(http.MultipartFile.fromBytes(
          'photo',
          photoBytes,
          filename: filename,
          contentType: _contentTypeFor(filename),
        ));
        final streamed = await client.send(request).timeout(ApiConfig.scanTimeout);
        return http.Response.fromStream(streamed);
      }, scores: true);
      if (response.statusCode == 200) {
        return ScanResult.fromJson(jsonDecode(response.body));
      }
      throw _fromResponse('check this product', response);
    });
  }

  /// Remembers the serving size for this scan's product; used next time.
  /// [labelBasis] is 'per_100' or 'per_serving'.
  Future<void> saveServingSize(
    String scanId, {
    required double servingSizeG,
    required String labelBasis,
  }) async {
    return _run(() async {
      final res = await _authed((h) => client
          .put(
            _uri('/api/v1/scans/${Uri.encodeComponent(scanId)}/serving'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'serving_size_g': servingSizeG, 'label_basis': labelBasis}),
          )
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 204 || res.statusCode == 200) return;
      throw _fromResponse('save the serving size', res);
    });
  }

  /// Deletes one of the user's scans and its photo.
  Future<void> deleteScan(String scanId) async {
    return _run(() async {
      final res = await _authed((h) => client
          .delete(_uri('/api/v1/scans/${Uri.encodeComponent(scanId)}'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 204 || res.statusCode == 200) return;
      throw _fromResponse('remove this scan', res);
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
        // Keep the kind too: the screen maps it (a 429 is the daily limit).
        final code = response.statusCode;
        throw ApiException(detail,
            statusCode: code,
            kind: switch (code) {
              429 => ApiErrorKind.prescriptionLimit,
              503 => ApiErrorKind.other, // switched off on this server: retrying won't help
              _ => _kindFor(code),
            });
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

  /// One page of history, newest first. Pass the oldest [before] time you
  /// already have to get the next page.
  Future<List<ScanHistoryItem>> getScanHistory({int limit = 20, DateTime? before}) async {
    return _run(() async {
      final query = <String, String>{
        'limit': '$limit',
        if (before != null) 'before': before.toUtc().toIso8601String(),
      };
      final res = await _authed((h) => client
          .get(_uri('/api/v1/scans/history', query), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((e) => ScanHistoryItem.fromJson(e)).toList();
      }
      throw _fromResponse('load your scan history', res);
    });
  }

  /// Deletes the user's profile, scans, photos and usage on the server.
  /// The local sign-in token is dropped too, so the next request starts a
  /// fresh, empty identity.
  Future<void> deleteMyData() async {
    await _run(() async {
      // Not through _authed: on a 401 that would register a brand-new
      // identity and "delete" its empty account, while the real data stays.
      final token = await tokenStore.read();
      if (token == null) return; // never registered: nothing on the server
      final res = await client
          .delete(_uri('/api/v1/profile'), headers: {'Authorization': 'Bearer $token'})
          .timeout(ApiConfig.lightTimeout);
      if (res.statusCode != 200) throw _fromResponse('delete your data', res);
    });
    await tokenStore.clear();
    await tokenStore.setProfileResetPending(false); // deliberate: nothing to warn about
  }

  /// Totals across every scan (Home's numbers), not just the latest page.
  Future<ScanStats> getScanStats() async {
    return _run(() async {
      final res = await _authed((h) => client
          .get(_uri('/api/v1/scans/stats'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        return ScanStats.fromJson(jsonDecode(res.body));
      }
      throw _fromResponse('load your scan totals', res);
    });
  }

  /// One past scan in full (findings, nutrition, explanation).
  Future<ScanResult> getScan(String scanId) async {
    return _run(() async {
      final res = await _authed((h) => client
          .get(_uri('/api/v1/scans/${Uri.encodeComponent(scanId)}'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        return ScanResult.fromJson(jsonDecode(res.body));
      }
      throw _fromResponse('open this scan', res);
    });
  }

  /// "Was this result right?" for one of the user's scans. [issues] are the
  /// backend's fixed keys (wrong_product, wrong_nutrition, ...); no free text.
  Future<void> sendScanFeedback(
    String scanId, {
    required bool accurate,
    List<String> issues = const [],
  }) async {
    return _run(() async {
      final res = await _authed((h) => client
          .post(
            _uri('/api/v1/scans/${Uri.encodeComponent(scanId)}/feedback'),
            headers: {...h, 'Content-Type': 'application/json'},
            body: jsonEncode({'accurate': accurate, 'issues': accurate ? [] : issues}),
          )
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 204 || res.statusCode == 200) return;
      throw _fromResponse('send your feedback', res);
    });
  }

  /// Trends computed by the backend from the user's own scans.
  Future<Insights> getInsights() async {
    return _run(() async {
      final res = await _authed((h) => client
          .get(_uri('/api/v1/insights'), headers: h)
          .timeout(ApiConfig.lightTimeout));
      if (res.statusCode == 200) {
        return Insights.fromJson(jsonDecode(res.body));
      }
      throw _fromResponse('load your insights', res);
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
      throw ApiException('Request timed out.', kind: ApiErrorKind.timeout);
    } on SocketException catch (e) {
      debugPrint('Network error: $e');
      throw ApiException("Can't reach the server.", kind: ApiErrorKind.network);
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
    // Status only: an error body can echo the profile (health data), and
    // debugPrint is not stripped from release builds.
    debugPrint('API ${res.statusCode} on $action');
    final code = res.statusCode;
    return ApiException("Couldn't $action (HTTP $code).", statusCode: code, kind: _kindFor(code));
  }

  static ApiErrorKind _kindFor(int code) => switch (code) {
        400 || 413 || 422 => ApiErrorKind.badRequest,
        401 || 403 => ApiErrorKind.unauthorized,
        404 => ApiErrorKind.notFound,
        429 => ApiErrorKind.rateLimited,
        >= 500 => ApiErrorKind.server,
        _ => ApiErrorKind.other,
      };
}
