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
}

class PrefsAuthTokenStore implements AuthTokenStore {
  static const _key = 'calfit.auth_token';

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

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}
