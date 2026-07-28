import 'dart:convert';
import 'dart:typed_data';

import '../models/exercise.dart';
import '../models/program.dart';

class FirebaseGateway {
  FirebaseGateway({required this.available});

  final bool available;
  String? _currentUid;

  String? get currentUid => _currentUid;

  Future<String> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw ArgumentError('Email hoặc mật khẩu không hợp lệ.');
    }
    _currentUid = _localUid(email);
    return _currentUid!;
  }

  Future<String> register(String email, String password) =>
      signIn(email, password);

  Future<void> signOut() async => _currentUid = null;

  Future<void> resetPassword(String email) async {
    if (email.trim().isEmpty || !email.contains('@')) {
      throw ArgumentError('Email không hợp lệ.');
    }
  }

  Future<Map<String, dynamic>?> loadSnapshot(String uid) async => null;

  Future<void> syncSnapshot(String uid, Map<String, dynamic> snapshot) async {}

  Future<List<Exercise>> loadTemplateExercises() async => const [];

  Future<List<Program>> loadPrograms() async => const [];

  Future<List<ProgramVersion>> loadProgramVersions() async => const [];

  Future<void> requestDataExport() async {}

  Future<void> deleteCurrentAccount() async => _currentUid = null;

  Future<void> recordWeightActivityDay({
    required String uid,
    required String dateKey,
  }) async {}

  Future<void> recordWorkoutActivityDay({
    required String uid,
    required String dateKey,
  }) async {}

  Future<Set<String>> loadActivityDays({
    required String uid,
    required String collection,
    required String source,
  }) async => <String>{};

  Future<String> uploadUserImage({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  String _localUid(String email) {
    final normalized = email.trim().toLowerCase();
    return 'local-${normalized.hashCode.abs()}';
  }
}
