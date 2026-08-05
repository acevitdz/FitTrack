import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/exercise.dart';
import '../models/program.dart';

class FirebaseGateway {
  static const int _templateExerciseLimit = 50;
  static const int _programLimit = 20;
  static const int _programVersionLimit = 40;
  static const int _activityDayLimit = 400;

  FirebaseGateway({
    required this.available,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = available ? auth ?? FirebaseAuth.instance : auth,
       _firestore = available
           ? firestore ?? FirebaseFirestore.instance
           : firestore,
       _storage = available ? storage ?? FirebaseStorage.instance : storage;

  final bool available;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  String? _currentUid;

  String? get currentUid => available ? _auth?.currentUser?.uid : _currentUid;

  Future<String> signIn(String email, String password) async {
    final normalizedEmail = email.trim();
    _validateCredentials(normalizedEmail, password);
    if (available) {
      final credential = await _authClient.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase không trả về tài khoản đã đăng nhập.');
      }
      return user.uid;
    }
    _currentUid = _localUid(normalizedEmail);
    return _currentUid!;
  }

  Future<String> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    final normalizedEmail = email.trim();
    _validateCredentials(normalizedEmail, password);
    if (available) {
      final credential = await _authClient.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw StateError('Firebase không trả về tài khoản vừa tạo.');
      }
      final normalizedName = displayName?.trim();
      if (normalizedName != null && normalizedName.isNotEmpty) {
        await user.updateDisplayName(normalizedName);
      }
      await _userDocument(user.uid).set({
        'email': normalizedEmail,
        'name': normalizedName?.isNotEmpty == true
            ? normalizedName
            : normalizedEmail.split('@').first,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return user.uid;
    }
    return signIn(normalizedEmail, password);
  }

  Future<void> signOut() async {
    if (available) await _authClient.signOut();
    _currentUid = null;
  }

  Future<void> resetPassword(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw ArgumentError('Email không hợp lệ.');
    }
    if (available) {
      await _authClient.sendPasswordResetEmail(email: normalizedEmail);
    }
  }

  Future<void> updateDisplayName(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Tên hiển thị không được để trống.');
    }
    if (!available) return;
    final user = _authClient.currentUser;
    if (user == null) {
      throw StateError('Người dùng chưa đăng nhập.');
    }
    await user.updateDisplayName(normalizedName);
  }

  Future<Map<String, dynamic>?> loadSnapshot(String uid) async {
    if (!available) return null;
    final snapshot = await _stateDocument(uid).get();
    return snapshot.data();
  }

  Future<void> syncSnapshot(String uid, Map<String, dynamic> snapshot) async {
    if (!available) return;
    final cloudSnapshot = compactSnapshotForCloud(snapshot);
    final batch = _database.batch();
    final profile = cloudSnapshot['profile'];
    if (profile is Map) {
      final email = profile['email'];
      final name = profile['name'];
      batch.set(_userDocument(uid), {
        if (email is String && email.trim().isNotEmpty) 'email': email.trim(),
        if (name is String && name.trim().isNotEmpty) 'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    batch.set(_stateDocument(uid), {
      ...cloudSnapshot,
      'cloudUpdatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<List<Exercise>> loadTemplateExercises() async {
    if (!available) return const [];
    final result = await _database
        .collection('exercises')
        .where('isActive', isEqualTo: true)
        .where('catalogStatus', isEqualTo: 'published')
        .limit(_templateExerciseLimit)
        .get();
    return result.docs
        .map((document) {
          final data = document.data();
          data.putIfAbsent('id', () => document.id);
          return Exercise.fromJson(data);
        })
        .toList(growable: false);
  }

  Future<List<Program>> loadPrograms() async {
    if (!available) return const [];
    final result = await _database
        .collection('programs')
        .where('status', isEqualTo: ProgramLifecycleStatus.published.name)
        .limit(_programLimit)
        .get();
    return result.docs
        .map((document) {
          final data = document.data();
          data.putIfAbsent('id', () => document.id);
          return Program.fromJson(data);
        })
        .toList(growable: false);
  }

  Future<List<ProgramVersion>> loadProgramVersions() async {
    if (!available) return const [];
    final result = await _database
        .collection('programVersions')
        .where('status', isEqualTo: ProgramLifecycleStatus.published.name)
        .limit(_programVersionLimit)
        .get();
    return result.docs
        .map((document) {
          final data = document.data();
          data.putIfAbsent('id', () => document.id);
          return ProgramVersion.fromJson(data);
        })
        .toList(growable: false);
  }

  Future<void> requestDataExport() async {
    await _submitAccountRequest('data_export');
  }

  Future<void> requestAccountDeletion() async {
    await _submitAccountRequest('account_deletion');
  }

  Future<void> _submitAccountRequest(String type) async {
    if (!available) return;
    final uid = _requireUid();
    await _database
        .collection('users')
        .doc(uid)
        .collection('requests')
        .doc(type)
        .set({
          'type': type,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> recordWeightActivityDay({
    required String uid,
    required String dateKey,
  }) async {
    if (!available) return;
    await _activityDocument(uid, 'weightActivityDays', dateKey).set({
      'dateKey': dateKey,
      'source': 'weight_entry',
      'recordedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordWorkoutActivityDay({
    required String uid,
    required String dateKey,
  }) async {
    if (!available) return;
    await _activityDocument(uid, 'workoutActivityDays', dateKey).set({
      'dateKey': dateKey,
      'source': 'workout_completion',
      'recordedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Set<String>> loadActivityDays({
    required String uid,
    required String collection,
    required String source,
  }) async {
    if (!available) return <String>{};
    final result = await _database
        .collection('users')
        .doc(uid)
        .collection(collection)
        .where('source', isEqualTo: source)
        .limit(_activityDayLimit)
        .get();
    return result.docs
        .map((document) => document.data()['dateKey'])
        .whereType<String>()
        .toSet();
  }

  Future<String> uploadUserImage({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (available) {
      final reference = _storageClient.ref('users/$uid/$path');
      await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return reference.getDownloadURL();
    }
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }

  FirebaseAuth get _authClient =>
      _auth ?? (throw StateError('Firebase Authentication chưa sẵn sàng.'));

  FirebaseFirestore get _database =>
      _firestore ?? (throw StateError('Cloud Firestore chưa sẵn sàng.'));

  FirebaseStorage get _storageClient =>
      _storage ?? (throw StateError('Firebase Storage chưa sẵn sàng.'));

  DocumentReference<Map<String, dynamic>> _stateDocument(String uid) =>
      _userDocument(uid).collection('appState').doc('current');

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) =>
      _database.collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> _activityDocument(
    String uid,
    String collection,
    String dateKey,
  ) => _database
      .collection('users')
      .doc(uid)
      .collection(collection)
      .doc(dateKey);

  String _requireUid() {
    final uid = _authClient.currentUser?.uid;
    if (uid == null) throw StateError('Người dùng chưa đăng nhập.');
    return uid;
  }

  void _validateCredentials(String email, String password) {
    if (email.isEmpty || !email.contains('@') || password.length < 6) {
      throw ArgumentError('Email hoặc mật khẩu không hợp lệ.');
    }
  }

  String _localUid(String email) {
    final normalized = email.trim().toLowerCase();
    return 'local-${normalized.hashCode.abs()}';
  }
}

Map<String, dynamic> compactSnapshotForCloud(Map<String, dynamic> snapshot) {
  final compact = Map<String, dynamic>.from(snapshot)..remove('exercises');
  final target = snapshot['target'];
  if (target is Map) {
    compact['target'] = Map<String, dynamic>.from(target)
      ..remove('programs')
      ..remove('programVersions');
  }
  return compact;
}
