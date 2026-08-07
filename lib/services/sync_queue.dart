import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingSyncOperation {
  const PendingSyncOperation({
    required this.uid,
    required this.snapshot,
    required this.expectedRemoteRevision,
    required this.enqueuedAt,
  });

  final String uid;
  final Map<String, dynamic> snapshot;
  final int expectedRemoteRevision;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'snapshot': snapshot,
    'expectedRemoteRevision': expectedRemoteRevision,
    'enqueuedAt': enqueuedAt.toIso8601String(),
  };

  factory PendingSyncOperation.fromJson(Map<String, dynamic> json) =>
      PendingSyncOperation(
        uid: json['uid'] as String,
        snapshot: Map<String, dynamic>.from(json['snapshot'] as Map),
        expectedRemoteRevision:
            (json['expectedRemoteRevision'] as num?)?.toInt() ?? 0,
        enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      );
}

/// Keeps the newest complete local state until Firebase acknowledges it.
///
/// A full-state operation is intentionally coalesced per UID: all domain
/// mutations are idempotent, and a later snapshot contains every earlier
/// mutation that has not yet reached the cloud.
class SyncQueue {
  static const _prefix = 'fittrack_sync_queue_v1_';

  Future<void> enqueueLatest({
    required String uid,
    required Map<String, dynamic> snapshot,
    required int expectedRemoteRevision,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final operation = PendingSyncOperation(
      uid: uid,
      snapshot: snapshot,
      expectedRemoteRevision: expectedRemoteRevision,
      enqueuedAt: DateTime.now(),
    );
    await preferences.setString(_key(uid), jsonEncode(operation.toJson()));
  }

  Future<PendingSyncOperation?> peek(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key(uid));
    if (raw == null) return null;
    try {
      return PendingSyncOperation.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      await preferences.remove(_key(uid));
      return null;
    }
  }

  Future<void> clear(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(uid));
  }

  String _key(String uid) {
    final encoded = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return '$_prefix$encoded';
  }
}
