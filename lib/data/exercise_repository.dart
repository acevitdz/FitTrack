import '../models/exercise.dart';
import '../models/exercise_enums.dart';

/// Filter combination for [ExerciseRepository.watchExercises].
/// All fields combine with AND; empty sets/null mean "no restriction".
class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.muscle,
    this.difficulties = const {},
    this.equipment = const {},
    this.favoriteIds,
  });

  final String query;
  final Muscle? muscle;
  final Set<Difficulty> difficulties;
  final Set<Equipment> equipment;

  /// When non-null, only exercises whose id is in this set are kept.
  /// The screen passes the current user's favorite id set here for the
  /// "chỉ hiện thị mức yêu thích" toggle.
  final Set<String>? favoriteIds;

  int get activeCount =>
      (muscle != null ? 1 : 0) +
      difficulties.length +
      equipment.length +
      (favoriteIds != null ? 1 : 0);

  bool matches(Exercise exercise) {
    final normalizedQuery = query.trim().toLowerCase();
    final matchesQuery =
        normalizedQuery.isEmpty ||
        exercise.name.toLowerCase().contains(normalizedQuery);
    final matchesMuscle = muscle == null || exercise.allMuscles.contains(muscle);
    final matchesDifficulty =
        difficulties.isEmpty || difficulties.contains(exercise.difficulty);
    final matchesEquipment =
        equipment.isEmpty ||
        exercise.equipment.any((e) => equipment.contains(e));
    final matchesFavorite =
        favoriteIds == null || favoriteIds!.contains(exercise.id);
    return matchesQuery &&
        matchesMuscle &&
        matchesDifficulty &&
        matchesEquipment &&
        matchesFavorite;
  }

  ExerciseFilter copyWith({
    String? query,
    Muscle? muscle,
    bool clearMuscle = false,
    Set<Difficulty>? difficulties,
    Set<Equipment>? equipment,
    Set<String>? favoriteIds,
    bool clearFavoriteIds = false,
  }) {
    return ExerciseFilter(
      query: query ?? this.query,
      muscle: clearMuscle ? null : (muscle ?? this.muscle),
      difficulties: difficulties ?? this.difficulties,
      equipment: equipment ?? this.equipment,
      favoriteIds: clearFavoriteIds ? null : (favoriteIds ?? this.favoriteIds),
    );
  }
}

/// docs/TV2_TASKS.md §10 — `exercises/{exerciseId}`, admin-write-only.
abstract interface class ExerciseRepository {
  Stream<List<Exercise>> watchExercises({ExerciseFilter? filter});
  Future<Exercise?> getExercise(String id);
  Future<void> createExercise(Exercise value); // admin only
  Future<void> updateExercise(Exercise value); // admin only
  Future<void> setActive(String id, bool isActive); // soft delete, admin only
}

/// docs/TV2_TASKS.md §10 — `users/{uid}/personalExercises/{exerciseId}`.
abstract interface class PersonalExerciseRepository {
  Stream<List<PersonalExercise>> watchPersonalExercises(String uid);
  Future<void> create(String uid, PersonalExercise value);
  Future<void> update(String uid, PersonalExercise value);
  Future<void> delete(String uid, String id); // confirm dialog required in UI
}

/// Not in the original schema doc: per-uid favorite marks on shared template
/// exercises (§4.4 "đánh dấu yêu thích"). `exercises/` itself is shared and
/// admin-write-only, so favorite state can't live on the Exercise document —
/// this stores it at `users/{uid}/favoriteExerciseIds/{exerciseId}` instead.
abstract interface class FavoriteExerciseRepository {
  Stream<Set<String>> watchFavoriteIds(String uid);
  Future<void> setFavorite(String uid, String exerciseId, bool isFavorite);
}
