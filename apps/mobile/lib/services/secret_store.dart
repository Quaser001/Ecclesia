import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where bearer credentials live on the phone, away from plain preferences.
abstract class SecretStore {
  /// Null when nothing is stored. Throws when the store can't be read,
  /// which is NOT the same as "nothing stored": callers must tell them apart.
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The Android Keystore (via flutter_secure_storage): the value is encrypted
/// with a key that never leaves the phone's secure hardware.
class KeystoreSecretStore implements SecretStore {
  // resetOnError is off: the plugin's default wipes EVERY stored value on a
  // decrypt error. We'd rather see the error and handle it (ADR-006).
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory store for tests. [failReads] / [failWrites] simulate a broken
/// Keystore.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('keystore unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('keystore unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failWrites) throw StateError('keystore unavailable');
    values.remove(key);
  }
}
