import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_workout.dart';

typedef SharedPreferencesFactory = Future<SharedPreferences> Function();

/// One local active-workout checkpoint per UID.
class ActiveWorkoutDraftStore {
  ActiveWorkoutDraftStore({SharedPreferencesFactory? preferencesFactory})
    : _preferencesFactory = preferencesFactory ?? SharedPreferences.getInstance;

  static const _keyPrefix = 'fittrack_active_workout_v1_';
  final SharedPreferencesFactory _preferencesFactory;

  Future<ActiveWorkoutDraft?> load(String userId) async {
    _validateUserId(userId);
    final preferences = await _preferencesFactory();
    final raw = preferences.getString(_key(userId));
    if (raw == null) return null;
    try {
      return ActiveWorkoutDraft.fromJsonString(raw);
    } on Object {
      // A malformed or future-version checkpoint must not crash app startup.
      // Keep the raw value so migration/support can inspect it.
      return null;
    }
  }

  Future<void> save(String userId, ActiveWorkoutDraft draft) async {
    _validateUserId(userId);
    if (draft.userId != userId) {
      throw ArgumentError(
        'Cannot save a workout draft under a different user ID',
      );
    }
    final preferences = await _preferencesFactory();
    await preferences.setString(_key(userId), draft.toJsonString());
  }

  Future<bool> contains(String userId) async {
    _validateUserId(userId);
    final preferences = await _preferencesFactory();
    return preferences.containsKey(_key(userId));
  }

  Future<void> clear(String userId) async {
    _validateUserId(userId);
    final preferences = await _preferencesFactory();
    await preferences.remove(_key(userId));
  }

  static String _key(String userId) {
    final encoded = base64Url.encode(utf8.encode(userId)).replaceAll('=', '');
    return '$_keyPrefix$encoded';
  }

  static void _validateUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be empty');
    }
  }
}
