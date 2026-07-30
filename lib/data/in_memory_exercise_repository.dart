import 'dart:async';

import '../models/exercise.dart';
import 'exercise_repository.dart';
import 'sample_exercises.dart';

/// Demo-only implementation backed by an in-memory list, seeded from
/// [sampleExercises]. Swap for FirestoreExerciseRepository once Firebase is
/// configured app-wide — same interface, no screen changes needed.
class InMemoryExerciseRepository implements ExerciseRepository {
  InMemoryExerciseRepository({List<Exercise>? seed})
    : _exercises = List.of(seed ?? sampleExercises);

  final List<Exercise> _exercises;
  final _controller = StreamController<List<Exercise>>.broadcast();

  void _emit() => _controller.add(List.unmodifiable(_exercises));

  @override
  Stream<List<Exercise>> watchExercises({ExerciseFilter? filter}) async* {
    yield _apply(filter);
    yield* _controller.stream.map((_) => _apply(filter));
  }

  List<Exercise> _apply(ExerciseFilter? filter) {
    final active = _exercises.where((e) => e.isActive);
    if (filter == null) return active.toList();
    return active.where(filter.matches).toList();
  }

  @override
  Future<Exercise?> getExercise(String id) async {
    for (final exercise in _exercises) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  @override
  Future<void> createExercise(Exercise value) async {
    _exercises.removeWhere((e) => e.id == value.id);
    _exercises.add(value);
    _emit();
  }

  @override
  Future<void> updateExercise(Exercise value) async {
    final index = _exercises.indexWhere((e) => e.id == value.id);
    if (index == -1) return;
    _exercises[index] = value;
    _emit();
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    final index = _exercises.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _exercises[index] = _exercises[index].copyWith(isActive: isActive);
    _emit();
  }
}
