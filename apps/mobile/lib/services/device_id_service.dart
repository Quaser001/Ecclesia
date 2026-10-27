import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Anonymous per-device identifier.
///
/// We don't have accounts yet. The server only needs a stable id to attach
/// scan history and the daily scan cap to. We generate a UUIDv4 the first
/// time the app launches, store it in [SharedPreferences], and send it with
/// every API call. The id never leaves the device unless the user scans a
/// product — no silent telemetry, no analytics event on first open.
///
/// Rotating or clearing the id (e.g. "forget me" in a later settings pass)
/// is a one-liner on this service. For now, uninstalling the app or clearing
/// its data wipes the id, which matches how a user intuitively thinks about
/// resetting their footprint.
class DeviceIdService {
  static const _prefKey = 'calfit.device_id';

  final SharedPreferences _prefs;
  final Random _rng;

  DeviceIdService._(this._prefs, this._rng);

  /// Load the stored device id, or create one on first launch.
  ///
  /// Safe to call from `main()` before `runApp`.
  static Future<DeviceIdService> load({Random? rng}) async {
    final prefs = await SharedPreferences.getInstance();
    final service = DeviceIdService._(prefs, rng ?? Random.secure());
    await service._ensureId();
    return service;
  }

  String get deviceId => _prefs.getString(_prefKey)!;

  /// Discard the current id and generate a new one. Reserved for a future
  /// "reset data" settings action; nothing calls it today.
  Future<String> rotate() async {
    final fresh = _generateUuidV4();
    await _prefs.setString(_prefKey, fresh);
    return fresh;
  }

  /// Awaited rather than fire-and-forget: if the write doesn't land before
  /// the app is killed, the next launch mints a different id and the user
  /// silently loses their scan history.
  Future<void> _ensureId() async {
    final existing = _prefs.getString(_prefKey);
    if (existing == null || existing.isEmpty) {
      await _prefs.setString(_prefKey, _generateUuidV4());
    }
  }

  /// RFC 4122 version 4 UUID using the platform's secure RNG.
  /// We avoid adding a dependency for one function.
  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(hex).join();
    return '${b.substring(0, 8)}-${b.substring(8, 12)}-${b.substring(12, 16)}-'
        '${b.substring(16, 20)}-${b.substring(20, 32)}';
  }
}
