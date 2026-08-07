import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _scopedStatePrefix = 'fittrack_state_v3_';
  static const _stateKey = 'fittrack_state_v2';
  static const _legacyStateKey = 'fittrack_state_v1';
  static const _sessionKey = 'fittrack_authenticated';
  static const _sessionUidKey = 'fittrack_authenticated_uid';

  String? _scopedUid;

  /// Selects the only user namespace that subsequent state operations may
  /// read or write. Calling this is mandatory before entering a private route.
  void scopeTo(String uid) {
    if (uid.trim().isEmpty) {
      throw ArgumentError.value(uid, 'uid', 'UID must not be empty.');
    }
    _scopedUid = uid;
  }

  void clearScope() => _scopedUid = null;

  Future<Map<String, dynamic>?> loadState() async {
    final preferences = await SharedPreferences.getInstance();
    final scopedKey = _scopedStateKey;
    var raw = scopedKey == null ? null : preferences.getString(scopedKey);

    // Migrate the former app-wide snapshot only when its profile belongs to
    // the selected UID. A snapshot from another account is never re-owned.
    if (raw == null && scopedKey != null) {
      final legacyRaw =
          preferences.getString(_stateKey) ??
          preferences.getString(_legacyStateKey);
      final legacy = _decode(legacyRaw);
      if (legacy != null && _belongsToScope(legacy)) {
        raw = legacyRaw;
        await preferences.setString(scopedKey, legacyRaw!);
      }
    }

    // Kept for standalone callers that have not selected a namespace yet.
    raw ??= _scopedUid == null
        ? preferences.getString(_stateKey) ??
              preferences.getString(_legacyStateKey)
        : null;
    return _decode(raw);
  }

  Map<String, dynamic>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  Future<void> saveState(Map<String, dynamic> data) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_scopedStateKey ?? _stateKey, jsonEncode(data));
  }

  Future<bool> loadAuthenticated() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_sessionKey) ?? false;
  }

  Future<void> saveAuthenticated(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_sessionKey, value);
  }

  Future<String?> loadAuthenticatedUid() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_sessionUidKey);
  }

  Future<void> saveAuthenticatedUid(String? uid) async {
    final preferences = await SharedPreferences.getInstance();
    if (uid == null) {
      await preferences.remove(_sessionUidKey);
    } else {
      await preferences.setString(_sessionUidKey, uid);
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    final scopedKey = _scopedStateKey;
    if (scopedKey != null) {
      await preferences.remove(scopedKey);
    }
    final legacy = _decode(
      preferences.getString(_stateKey) ??
          preferences.getString(_legacyStateKey),
    );
    if (legacy != null && _belongsToScope(legacy)) {
      await preferences.remove(_stateKey);
      await preferences.remove(_legacyStateKey);
    }
    await preferences.remove(_sessionKey);
    await preferences.remove(_sessionUidKey);
  }

  String? get _scopedStateKey {
    final uid = _scopedUid;
    if (uid == null) return null;
    final encoded = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return '$_scopedStatePrefix$encoded';
  }

  bool _belongsToScope(Map<String, dynamic> state) {
    final uid = _scopedUid;
    if (uid == null) return false;
    final profile = state['profile'];
    if (profile is! Map) return false;
    return profile['id'] == uid;
  }
}
