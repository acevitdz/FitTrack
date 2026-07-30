import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exercise.dart';
import 'exercise_repository.dart';

/// Real implementation backed by `users/{uid}/personalExercises/{exerciseId}`
/// (docs/TV2_TASKS.md §2.2). Not wired as default — see
/// FirestoreExerciseRepository for why.
class FirestorePersonalExerciseRepository
    implements PersonalExerciseRepository {
  FirestorePersonalExerciseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('personalExercises');

  @override
  Stream<List<PersonalExercise>> watchPersonalExercises(String uid) {
    return _collection(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => PersonalExercise.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  @override
  Future<void> create(String uid, PersonalExercise value) async {
    await _collection(uid).doc(value.id).set({
      ...value.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> update(String uid, PersonalExercise value) async {
    await _collection(uid).doc(value.id).set({
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> delete(String uid, String id) async {
    await _collection(uid).doc(id).delete();
  }
}

/// Real implementation backed by `users/{uid}/favoriteExerciseIds/{exerciseId}`.
/// See [FavoriteExerciseRepository] doc comment for why this collection
/// exists outside the original schema doc.
class FirestoreFavoriteExerciseRepository
    implements FavoriteExerciseRepository {
  FirestoreFavoriteExerciseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('favoriteExerciseIds');

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) {
    return _collection(
      uid,
    ).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  @override
  Future<void> setFavorite(
    String uid,
    String exerciseId,
    bool isFavorite,
  ) async {
    final doc = _collection(uid).doc(exerciseId);
    if (isFavorite) {
      await doc.set({'createdAt': FieldValue.serverTimestamp()});
    } else {
      await doc.delete();
    }
  }
}
