import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_token_store.dart';

/// One person on this phone. Each has their own anonymous server identity
/// (its own signed token), so conditions, scans, history and quota never mix:
/// the server can't even tell that two profiles share a phone.
@immutable
class DeviceProfile {
  final String id; // local only; never sent anywhere
  final String label; // the name shown in the switcher ("" = the first one, "Me")
  final String? token;
  final bool resetPending;

  const DeviceProfile({required this.id, this.label = '', this.token, this.resetPending = false});

  DeviceProfile copyWith({String? label, String? token, bool clearToken = false, bool? resetPending}) =>
      DeviceProfile(
        id: id,
        label: label ?? this.label,
        token: clearToken ? null : (token ?? this.token),
        resetPending: resetPending ?? this.resetPending,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'token': token, 'reset_pending': resetPending};

  factory DeviceProfile.fromJson(Map<String, dynamic> j) => DeviceProfile(
        id: j['id'] as String,
        label: (j['label'] as String?) ?? '',
        token: j['token'] as String?,
        resetPending: j['reset_pending'] == true,
      );
}

/// The profiles on this phone and which one is active.
///
/// Switching notifies listeners; the app then rebuilds every screen for the
/// new profile, so nothing on screen belongs to the previous person.
class ProfileRegistry extends ChangeNotifier {
  static const _key = 'calfit.profiles.v1';
  static const _activeKey = 'calfit.profiles.active';
  static const _legacyTokenKey = 'calfit.auth_token';
  static const _legacyResetKey = 'calfit.profile_reset_pending';

  /// The loaded registry, for per-profile device settings (prescription
  /// consent). Null in tests that never load one.
  static ProfileRegistry? current;

  final SharedPreferences _prefs;
  List<DeviceProfile> _profiles;
  String _activeId;

  ProfileRegistry._(this._prefs, this._profiles, this._activeId);

  List<DeviceProfile> get profiles => List.unmodifiable(_profiles);
  String get activeId => _activeId;
  DeviceProfile get active => _profiles.firstWhere((p) => p.id == _activeId);
  DeviceProfile? byId(String id) => _profiles.where((p) => p.id == id).firstOrNull;

  /// Loads the profiles. The first run after this update turns the single
  /// existing sign-in into the first profile, so nobody loses their data.
  static Future<ProfileRegistry> load() async {
    final prefs = await SharedPreferences.getInstance();
    var profiles = <DeviceProfile>[];
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        profiles = [
          for (final p in jsonDecode(raw) as List<dynamic>)
            DeviceProfile.fromJson(p as Map<String, dynamic>),
        ];
      } catch (_) {
        profiles = []; // unreadable: start again rather than crash
      }
    }
    if (profiles.isEmpty) {
      profiles = [
        DeviceProfile(
          id: _newId(),
          token: prefs.getString(_legacyTokenKey),
          resetPending: prefs.getBool(_legacyResetKey) ?? false,
        ),
      ];
    }
    final saved = prefs.getString(_activeKey);
    final activeId = profiles.any((p) => p.id == saved) ? saved! : profiles.first.id;
    final registry = ProfileRegistry._(prefs, profiles, activeId);
    await registry._save();
    // Only after the token is safely in the registry.
    await prefs.remove(_legacyTokenKey);
    await prefs.remove(_legacyResetKey);
    return current = registry;
  }

  static String _newId() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  Future<void> _save() async {
    await _prefs.setString(_key, jsonEncode([for (final p in _profiles) p.toJson()]));
    await _prefs.setString(_activeKey, _activeId);
  }

  Future<void> _update(String id, DeviceProfile Function(DeviceProfile) change) async {
    final i = _profiles.indexWhere((p) => p.id == id);
    if (i < 0) return; // removed meanwhile: a late response must not resurrect it
    _profiles = [..._profiles]..[i] = change(_profiles[i]);
    await _save();
  }

  /// Adds a person and makes them active. Their server identity is created
  /// on their first request.
  Future<String> add(String label) async {
    final p = DeviceProfile(id: _newId(), label: label.trim());
    _profiles = [..._profiles, p];
    _activeId = p.id;
    await _save();
    notifyListeners();
    return p.id;
  }

  Future<void> switchTo(String id) async {
    if (id == _activeId || byId(id) == null) return;
    _activeId = id;
    await _save();
    notifyListeners();
  }

  /// Keeps the switcher's label in step with the name saved on the server.
  Future<void> rename(String id, String label) async {
    if (byId(id)?.label == label.trim()) return;
    await _update(id, (p) => p.copyWith(label: label.trim()));
    notifyListeners();
  }

  /// After "Delete my data": the profile goes, unless it's the only one,
  /// which stays as a fresh, empty profile (its token is already cleared).
  Future<void> forget(String id) async {
    if (_profiles.length == 1) {
      await _update(id, (p) => p.copyWith(label: '', clearToken: true, resetPending: false));
    } else {
      _profiles = _profiles.where((p) => p.id != id).toList();
      if (_activeId == id) _activeId = _profiles.first.id;
      await _save();
    }
    notifyListeners();
  }

  Future<void> setToken(String id, String? token) =>
      _update(id, (p) => p.copyWith(token: token, clearToken: token == null));

  Future<void> setResetPending(String id, bool pending) =>
      _update(id, (p) => p.copyWith(resetPending: pending));
}

/// The sign-in of ONE profile. Bound to that profile's id rather than to
/// "whichever is active", so a request that finishes after a switch still
/// saves its token, and its result, to the person it was made for.
class ProfileTokenStore implements AuthTokenStore {
  final ProfileRegistry registry;
  final String profileId;
  ProfileTokenStore(this.registry, this.profileId);

  @override
  Future<String?> read() async => registry.byId(profileId)?.token;

  @override
  Future<void> write(String token) => registry.setToken(profileId, token);

  @override
  Future<void> clear() => registry.setToken(profileId, null);

  @override
  Future<bool> profileResetPending() async => registry.byId(profileId)?.resetPending ?? false;

  @override
  Future<void> setProfileResetPending(bool pending) => registry.setResetPending(profileId, pending);
}
