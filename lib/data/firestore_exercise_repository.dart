import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/exercise.dart';
import 'exercise_repository.dart';

/// Real implementation of [ExerciseRepository] backed by Firestore
/// `exercises/{exerciseId}` (docs/TV2_TASKS.md §2.1). Not wired as the
/// default repository yet — the app has no Firebase.initializeApp() call
/// configured. Team lead: inject this in place of
/// InMemoryExerciseRepository once app-wide Firebase setup lands.
///
/// Filtering is applied client-side (matches ExerciseFilter.matches) rather
/// than as compound Firestore queries, since the catalog is small (~150
/// docs) and the filter combinations are ad-hoc (§5: "không query Firestore
/// trực tiếp trong build()" is respected by keeping this in the repo layer).
class FirestoreExerciseRepository implements ExerciseRepository {
  FirestoreExerciseRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('exercises');

  @override
  Stream<List<Exercise>> watchExercises({ExerciseFilter? filter}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final all = snapshot.docs
              .map((doc) => Exercise.fromMap(doc.id, doc.data()))
              .toList();
          if (filter == null) return all;
          return all.where(filter.matches).toList();
        });
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Exercise.fromMap(doc.id, doc.data()!);
  }

  @override
  Future<void> createExercise(Exercise value) async {
    await _collection.doc(value.id).set({
      ...value.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateExercise(Exercise value) async {
    await _collection.doc(value.id).set({
      ...value.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _collection.doc(id).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
