/// Where the signed device token issued by the backend is kept.
///
/// The token is a bearer credential for one person on this phone. In the
/// app it's a [ProfileTokenStore], which keeps it in the Android Keystore.
abstract class AuthTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();

  /// Set when the server stopped accepting the old identity and a new, empty
  /// one was made: scans are refused until the profile is saved again.
  Future<bool> profileResetPending();
  Future<void> setProfileResetPending(bool pending);
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
