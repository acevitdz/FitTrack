import 'dart:async';

import 'exercise_repository.dart';

class InMemoryFavoriteExerciseRepository implements FavoriteExerciseRepository {
  final Map<String, Set<String>> _byUid = {
    'demo-user': {'day-nguc-ta-don-tren-ghe-phang', 'squat-ta-don-sau-gay'},
  };
  final _controller = StreamController<String>.broadcast();

  @override
  Stream<Set<String>> watchFavoriteIds(String uid) async* {
    yield Set.unmodifiable(_byUid[uid] ?? const {});
    yield* _controller.stream
        .where((changedUid) => changedUid == uid)
        .map((_) => Set.unmodifiable(_byUid[uid] ?? const {}));
  }

  @override
  Future<void> setFavorite(String uid, String exerciseId, bool isFavorite) async {
    final set = _byUid.putIfAbsent(uid, () => {});
    if (isFavorite) {
      set.add(exerciseId);
    } else {
      set.remove(exerciseId);
    }
    _controller.add(uid);
  }
}
