import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _authenticatedKey = 'fittrack.authenticated';
  static const _authenticatedUidKey = 'fittrack.authenticated_uid';

  String? _scope;

  void scopeTo(String uid) => _scope = uid.trim();

  void clearScope() => _scope = null;

  String get _stateKey => 'fittrack.state.${_scope ?? 'anonymous'}';

  Future<bool> loadAuthenticated() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_authenticatedKey) ?? false;
  }

  Future<void> saveAuthenticated(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_authenticatedKey, value);
  }

  Future<String?> loadAuthenticatedUid() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_authenticatedUidKey);
  }

  Future<void> saveAuthenticatedUid(String? uid) async {
    final preferences = await SharedPreferences.getInstance();
    if (uid == null || uid.trim().isEmpty) {
      await preferences.remove(_authenticatedUidKey);
    } else {
      await preferences.setString(_authenticatedUidKey, uid.trim());
    }
  }

  Future<Map<String, dynamic>?> loadState() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_stateKey);
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> saveState(Map<String, dynamic> state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_stateKey, jsonEncode(state));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_stateKey);
    await preferences.remove(_authenticatedKey);
    await preferences.remove(_authenticatedUidKey);
  }
}
