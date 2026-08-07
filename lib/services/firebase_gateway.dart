import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/account.dart';
import '../models/exercise.dart';
import '../models/program.dart';

class SyncConflictException implements Exception {
  const SyncConflictException(this.remoteRevision);

  final int remoteRevision;

  @override
  String toString() => 'Sync conflict at remote revision $remoteRevision';
}

class FirebaseGateway {
  FirebaseGateway({required this.available});

  // Firebase retries reads and writes while offline.  That is useful for
  // background sync, but it must not keep an auth form in a permanent
  // loading state.  Every operation used by the auth/bootstrap path gets a
  // bounded wait; callers can then keep the local state and retry later.
  static const _operationTimeout = Duration(seconds: 15);

  final bool available;

  String? get currentUid =>
      available ? FirebaseAuth.instance.currentUser?.uid : null;

  String _offlineUid(String email) {
    final normalized = email.trim().toLowerCase();
    final encoded = base64Url
        .encode(utf8.encode(normalized))
        .replaceAll('=', '');
    return 'demo-$encoded';
  }

  Future<String> signIn(String email, String password) async {
    if (!available) return _offlineUid(email);
    final credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(_operationTimeout);
    final user = credential.user;
    if (user == null) throw StateError('firebase-user-missing');
    return user.uid;
  }

  Future<String> register(String email, String password) async {
    if (!available) return _offlineUid(email);
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(email: email, password: password)
        .timeout(_operationTimeout);
    final user = credential.user;
    if (user == null) throw StateError('firebase-user-missing');

    // Auth creation is the critical part of registration.  The profile
    // document is also written by the first snapshot sync, so a temporary
    // Firestore outage must not turn a successful registration into a failed
    // one (or leave the button spinning while Firestore retries forever).
    unawaited(_writeUserProfile(user.uid, email));
    return user.uid;
  }

  Future<void> _writeUserProfile(String uid, String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'email': email.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_operationTimeout);
    } on Object {
      // Keep the authenticated session.  The durable sync queue will retry
      // the profile write once connectivity is restored.
    }
  }

  Future<List<Program>> loadPrograms(Iterable<String> programIds) async {
    if (!available) return const [];
    final programs = <Program>[];
    for (final id in programIds.map((item) => item.trim()).toSet()) {
      if (id.isEmpty) continue;
      final document = await FirebaseFirestore.instance
          .collection('programs')
          .doc(id)
          .get()
          .timeout(_operationTimeout);
      final data = document.data();
      if (data != null) {
        programs.add(Program.fromJson({...data, 'id': data['id'] ?? id}));
      }
    }
    return programs;
  }

  Future<List<ProgramVersion>> loadProgramVersions(
    Iterable<String> versionIds,
  ) async {
    if (!available) return const [];
    final versions = <ProgramVersion>[];
    // Program versions contain every authored week/session and can be several
    // hundred KB each. Read only the IDs selected by the bundled matcher;
    // querying the whole collection can exceed Android's platform-channel
    // heap while an Active Workout is also holding media/camera buffers.
    for (final id in versionIds.map((item) => item.trim()).toSet()) {
      if (id.isEmpty) continue;
      final document = await FirebaseFirestore.instance
          .collection('programVersions')
          .doc(id)
          .get()
          .timeout(_operationTimeout);
      final data = document.data();
      if (data != null) {
        versions.add(
          ProgramVersion.fromJson({...data, 'id': data['id'] ?? id}),
        );
      }
    }
    return versions;
  }

  Future<void> resetPassword(String email) async {
    if (!available) return;
    await FirebaseAuth.instance
        .sendPasswordResetEmail(email: email)
        .timeout(_operationTimeout);
  }

  Future<void> signOut() async {
    if (available) await FirebaseAuth.instance.signOut();
  }

  Future<AccountAccess> loadAccountAccess(String uid) async {
    if (!available || uid == 'demo-user') {
      return const AccountAccess.active();
    }
    final firestore = FirebaseFirestore.instance;
    final accessDocuments = await Future.wait<Object>([
      firestore.collection('users').doc(uid).get(),
      firestore
          .collection('accountDeletionRequests')
          .where('userId', isEqualTo: uid)
          .get(),
    ]).timeout(_operationTimeout);
    final user = accessDocuments[0] as DocumentSnapshot<Map<String, dynamic>>;
    final data = user.data() ?? const <String, dynamic>{};
    final storedStatus = accountStatusFromStored(data['status'] as String?);
    if (storedStatus != AccountStatus.active) {
      return AccountAccess(
        status: storedStatus,
        reason: data['statusReason'] as String?,
        updatedAt: _timestampDate(data['statusUpdatedAt']),
      );
    }
    final pendingDeletion =
        accessDocuments[1] as QuerySnapshot<Map<String, dynamic>>;
    final hasPending = pendingDeletion.docs.any((document) {
      final status = accountJobStatusFromStored(
        document.data()['status'] as String?,
      );
      return status == AccountJobStatus.requested ||
          status == AccountJobStatus.processing;
    });
    return hasPending
        ? const AccountAccess(status: AccountStatus.deletionPending)
        : const AccountAccess.active();
  }

  Future<DataExportRequest?> latestDataExportRequest(String uid) async {
    if (!available || uid == 'demo-user') return null;
    final snapshot = await FirebaseFirestore.instance
        .collection('dataExportRequests')
        .where('userId', isEqualTo: uid)
        .get()
        .timeout(_operationTimeout);
    final requests =
        snapshot.docs
            .map(
              (document) =>
                  DataExportRequest.fromJson(document.id, document.data()),
            )
            .toList()
          ..sort(
            (left, right) => right.requestedAt.compareTo(left.requestedAt),
          );
    return requests.firstOrNull;
  }

  Future<DataExportRequest?> requestDataExport() async {
    if (!available) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('not-authenticated');
    final existing = await latestDataExportRequest(user.uid);
    if (existing != null && (existing.isPending || existing.canDownload)) {
      return existing;
    }
    final now = DateTime.now();
    final requestId = '${user.uid}-${now.microsecondsSinceEpoch}';
    await FirebaseFirestore.instance
        .collection('dataExportRequests')
        .doc(requestId)
        .set({
          'userId': user.uid,
          'status': 'requested',
          'schemaVersion': 1,
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_operationTimeout);
    return DataExportRequest(
      id: requestId,
      status: AccountJobStatus.requested,
      requestedAt: now,
      updatedAt: now,
    );
  }

  Future<Uint8List> downloadDataExport(DataExportRequest request) async {
    final path = request.storagePath;
    if (!available || path == null || !request.canDownload) {
      throw StateError('data-export-not-ready');
    }
    final bytes = await FirebaseStorage.instance
        .ref(path)
        .getData(20 * 1024 * 1024);
    if (bytes == null) throw StateError('data-export-empty');
    return bytes;
  }

  Future<AccountDeletionRequest?> requestAccountDeletion() async {
    if (!available) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('not-authenticated');
    final existing = await FirebaseFirestore.instance
        .collection('accountDeletionRequests')
        .where('userId', isEqualTo: user.uid)
        .get()
        .timeout(_operationTimeout);
    for (final document in existing.docs) {
      final request = AccountDeletionRequest.fromJson(
        document.id,
        document.data(),
      );
      if (request.isPending) return request;
    }
    final now = DateTime.now();
    final requestId = '${user.uid}-${now.microsecondsSinceEpoch}';
    await FirebaseFirestore.instance
        .collection('accountDeletionRequests')
        .doc(requestId)
        .set({
          'userId': user.uid,
          'status': 'requested',
          'schemaVersion': 1,
          'requestedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_operationTimeout);
    return AccountDeletionRequest(
      id: requestId,
      status: AccountJobStatus.requested,
      requestedAt: now,
      updatedAt: now,
    );
  }

  Future<AccountDeletionRequest?> deleteCurrentAccount() async {
    if (!available) return null;
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final request = await requestAccountDeletion();
    if (user != null && uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .delete()
            .timeout(_operationTimeout);
      } on Object catch (_) {}

      try {
        await FirebaseStorage.instance
            .ref('users/$uid/avatar.jpg')
            .delete()
            .timeout(_operationTimeout);
      } on Object catch (_) {}
      try {
        await FirebaseStorage.instance
            .ref('users/$uid/avatar.png')
            .delete()
            .timeout(_operationTimeout);
      } on Object catch (_) {}

      try {
        await user.delete().timeout(_operationTimeout);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          // The authenticated deletion request was already created. The
          // trusted backend finishes removing Auth, Firestore and Storage
          // data even when the client session is too old for user.delete().
          await signOut();
        }
      } on Object catch (_) {}
    }
    await signOut();
    return request;
  }

  Future<void> updateDisplayName(String name) async {
    if (!available) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final trimmed = name.trim();
      if (trimmed.isNotEmpty) {
        await user.updateDisplayName(trimmed).timeout(_operationTimeout);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'name': trimmed,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(_operationTimeout);
      }
    }
  }

  Future<int> syncSnapshot(
    String uid,
    Map<String, dynamic> data, {
    int expectedRemoteRevision = 0,
  }) async {
    if (!available || uid == 'demo-user') return expectedRemoteRevision;
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(uid);
    final syncRef = userRef.collection('sync').doc('current');
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    final settings = Map<String, dynamic>.from(data['settings'] as Map? ?? {});
    final target = Map<String, dynamic>.from(data['target'] as Map? ?? {});
    final nextRevision = await firestore
        .runTransaction<int>((transaction) async {
          final syncDocument = await transaction.get(syncRef);
          final remoteRevision =
              (syncDocument.data()?['revision'] as num?)?.toInt() ?? 0;
          if (remoteRevision != expectedRemoteRevision) {
            throw SyncConflictException(remoteRevision);
          }
          final revision = remoteRevision + 1;
          final metadata = {
            'revision': revision,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          transaction.set(userRef, {
            'name': profile['name'],
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          transaction.set(userRef.collection('profile').doc('current'), {
            'value': profile,
            ...metadata,
          });
          transaction.set(userRef.collection('settings').doc('current'), {
            'value': settings,
            ...metadata,
          });
          transaction.set(userRef.collection('training').doc('current'), {
            'value': {
              'trainingPreferences': target['trainingPreferences'],
              'lastProgramMatchStatus': target['lastProgramMatchStatus'],
            },
            ...metadata,
          });
          transaction.set(userRef.collection('schedule').doc('current'), {
            'value': {
              'enrollment': target['enrollment'],
              'occurrences': target['occurrences'] ?? const [],
            },
            ...metadata,
          });
          transaction.set(userRef.collection('workoutHistory').doc('current'), {
            'value': {
              'workoutCompletions': target['workoutCompletions'] ?? const [],
              'workoutDays': data['workoutDays'] ?? const [],
              'workoutStreak': data['workoutStreak'] ?? const {},
            },
            ...metadata,
          });
          transaction.set(userRef.collection('health').doc('current'), {
            'value': {
              'weightEntries': data['weightEntries'] ?? const [],
              'weightActivityDays': data['weightActivityDays'] ?? const [],
              'streak': data['streak'] ?? const {},
            },
            ...metadata,
          });
          transaction.set(userRef.collection('library').doc('current'), {
            'value': {
              'exercises': (data['exercises'] as List? ?? const [])
                  .where(
                    (item) =>
                        item is Map && (item['ownerId'] as String?) == uid,
                  )
                  .toList(growable: false),
              'favoriteExerciseIds': data['favoriteExerciseIds'] ?? const [],
              'plans': data['plans'] ?? const [],
              'schedules': data['schedules'] ?? const [],
              'completions': data['completions'] ?? const [],
              'reminders': data['reminders'] ?? const [],
            },
            ...metadata,
          });
          transaction.set(userRef.collection('achievements').doc('current'), {
            'value': data['achievements'] ?? const [],
            ...metadata,
          });
          transaction.set(syncRef, metadata);
          return revision;
        })
        .timeout(_operationTimeout);
    return nextRevision;
  }

  Future<Map<String, dynamic>?> loadSnapshot(String uid) async {
    if (!available || uid == 'demo-user') return null;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final documents = await Future.wait([
      userRef.collection('profile').doc('current').get(),
      userRef.collection('settings').doc('current').get(),
      userRef.collection('training').doc('current').get(),
      userRef.collection('schedule').doc('current').get(),
      userRef.collection('workoutHistory').doc('current').get(),
      userRef.collection('health').doc('current').get(),
      userRef.collection('library').doc('current').get(),
      userRef.collection('achievements').doc('current').get(),
      userRef.collection('sync').doc('current').get(),
    ]).timeout(_operationTimeout);
    if (!documents.first.exists) {
      final legacy = await userRef
          .collection('appState')
          .doc('current')
          .get()
          .timeout(_operationTimeout);
      return legacy.data();
    }

    Map<String, dynamic> valueAt(int index) => Map<String, dynamic>.from(
      documents[index].data()?['value'] as Map? ?? const {},
    );

    final profile = valueAt(0);
    final settings = valueAt(1);
    final training = valueAt(2);
    final schedule = valueAt(3);
    final workoutHistory = valueAt(4);
    final health = valueAt(5);
    final library = valueAt(6);
    final achievementData = documents[7].data()?['value'];
    final achievements = achievementData is List
        ? achievementData
        : const <dynamic>[];
    final remoteRevision =
        (documents[8].data()?['revision'] as num?)?.toInt() ?? 0;
    return {
      'profile': profile,
      'settings': settings,
      'exercises': library['exercises'] ?? const [],
      'favoriteExerciseIds':
          library['favoriteExerciseIds'] ?? const <dynamic>[],
      'plans': library['plans'] ?? const [],
      'schedules': library['schedules'] ?? const [],
      'completions': library['completions'] ?? const [],
      'reminders': library['reminders'] ?? const [],
      'achievements': achievements,
      'weightEntries': health['weightEntries'] ?? const [],
      'weightActivityDays': health['weightActivityDays'] ?? const [],
      'streak': health['streak'] ?? const {},
      'workoutDays': workoutHistory['workoutDays'] ?? const [],
      'workoutStreak': workoutHistory['workoutStreak'] ?? const {},
      'target': {
        'trainingPreferences': training['trainingPreferences'],
        'enrollment': schedule['enrollment'],
        'occurrences': schedule['occurrences'] ?? const [],
        'workoutCompletions': workoutHistory['workoutCompletions'] ?? const [],
        'lastProgramMatchStatus': training['lastProgramMatchStatus'],
      },
      '_sync': {'remoteRevision': remoteRevision},
    };
  }

  Future<String> uploadUserImage({
    required String uid,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!available || uid == 'demo-user') {
      return Uri.dataFromBytes(bytes, mimeType: contentType).toString();
    }
    final reference = FirebaseStorage.instance.ref('users/$uid/$path');
    await reference
        .putData(bytes, SettableMetadata(contentType: contentType))
        .timeout(_operationTimeout);
    return reference.getDownloadURL().timeout(_operationTimeout);
  }

  Future<List<Exercise>> loadTemplateExercises() async {
    if (!available) return const [];
    final query = FirebaseFirestore.instance
        .collection('exercises')
        .where('isActive', isEqualTo: true)
        .where('catalogStatus', isEqualTo: 'published');
    final snapshot = await query.get().timeout(_operationTimeout);
    return snapshot.docs.map((document) {
      final data = document.data();
      return Exercise.fromJson({...data, 'id': data['id'] ?? document.id});
    }).toList();
  }

  Future<bool> recordWeightActivityDay({
    required String uid,
    required String dateKey,
  }) => _recordActivityDay(
    uid: uid,
    collection: 'weightActivityDays',
    dateKey: dateKey,
    source: 'weight_entry',
  );

  Future<bool> recordWorkoutActivityDay({
    required String uid,
    required String dateKey,
  }) => _recordActivityDay(
    uid: uid,
    collection: 'workoutActivityDays',
    dateKey: dateKey,
    source: 'workout_completion',
  );

  Future<Set<String>> loadActivityDays({
    required String uid,
    required String collection,
    required String source,
  }) async {
    if (!available || uid == 'demo-user') return <String>{};
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(collection)
        .get()
        .timeout(_operationTimeout);
    return snapshot.docs
        .where((document) => document.data()['source'] == source)
        .map((document) => document.data()['dateKey'] as String? ?? document.id)
        .where((dateKey) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey))
        .toSet();
  }

  Future<bool> _recordActivityDay({
    required String uid,
    required String collection,
    required String dateKey,
    required String source,
  }) async {
    if (!available || uid == 'demo-user') return false;
    final activityDayRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(dateKey);
    return FirebaseFirestore.instance
        .runTransaction((transaction) async {
          final activityDay = await transaction.get(activityDayRef);
          if (activityDay.exists) return false;
          transaction.set(activityDayRef, {
            'dateKey': dateKey,
            'source': source,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return true;
        })
        .timeout(_operationTimeout);
  }
}

DateTime? _timestampDate(Object? value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
