import 'package:shared_preferences/shared_preferences.dart';

/// Where the signed device token issued by the backend is kept.
///
/// The token is a bearer credential for this install. Swap the
/// [SharedPreferences] implementation for platform secure storage before a
/// public release if the threat model includes rooted devices.
abstract class AuthTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();

  /// Set when the server stopped accepting the old identity and a new, empty
  /// one was made: scans are refused until the profile is saved again.
  Future<bool> profileResetPending();
  Future<void> setProfileResetPending(bool pending);
}

class PrefsAuthTokenStore implements AuthTokenStore {
  static const _key = 'calfit.auth_token';
  static const _resetKey = 'calfit.profile_reset_pending';

  @override
  Future<bool> profileResetPending() async =>
      (await SharedPreferences.getInstance()).getBool(_resetKey) ?? false;

  @override
  Future<void> setProfileResetPending(bool pending) async {
    final prefs = await SharedPreferences.getInstance();
    pending ? await prefs.setBool(_resetKey, true) : await prefs.remove(_resetKey);
  }

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String token) async =>
      (await SharedPreferences.getInstance()).setString(_key, token);

  @override
  Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(_key);
}

/// In-memory store for tests.
class MemoryAuthTokenStore implements AuthTokenStore {
  String? _token;
  bool _resetPending = false;

  @override
  Future<bool> profileResetPending() async => _resetPending;

  @override
  Future<void> setProfileResetPending(bool pending) async => _resetPending = pending;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
