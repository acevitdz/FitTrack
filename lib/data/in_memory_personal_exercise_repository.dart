import 'dart:async';

import '../models/exercise.dart';
import 'exercise_repository.dart';

/// Demo-only implementation, keyed by uid, seeded with a couple of sample
/// personal exercises so Personal Exercise Library isn't empty by default.
class InMemoryPersonalExerciseRepository implements PersonalExerciseRepository {
  final Map<String, List<PersonalExercise>> _byUid = {
    'demo-user': [
      PersonalExercise.fromMap('personal_1', {
        'name': 'Đẩy ngực máy Smith tự chế',
        'primaryMuscle': 'nguc',
        'secondaryMuscles': ['tay_sau'],
        'equipment': ['may_tap_nguc'],
        'difficulty': 'intermediate',
        'instructions': [
          'Chỉnh ghế Smith machine ở góc 15 độ.',
          'Đẩy thanh lên hết tay, hạ xuống chạm ngực nhẹ.',
        ],
        'personalNote': 'Máy ở phòng gym khu nhà mình hơi rung, để tạ nhẹ hơn bình thường.',
        'isFavorite': true,
      }),
      PersonalExercise.fromMap('personal_2', {
        'name': 'Plank nghiêng có tạ',
        'primaryMuscle': 'bung',
        'secondaryMuscles': ['vai_giua'],
        'equipment': ['ta_don'],
        'difficulty': 'advanced',
        'instructions': [
          'Vào tư thế plank nghiêng, tạ đơn đặt trên hông.',
          'Giữ thân người thẳng 30-45 giây mỗi bên.',
        ],
        'personalNote': '',
        'isFavorite': false,
      }),
    ],
  };

  final _controller = StreamController<String>.broadcast();

  @override
  Stream<List<PersonalExercise>> watchPersonalExercises(String uid) async* {
    yield List.unmodifiable(_byUid[uid] ?? const []);
    yield* _controller.stream
        .where((changedUid) => changedUid == uid)
        .map((_) => List.unmodifiable(_byUid[uid] ?? const []));
  }

  @override
  Future<void> create(String uid, PersonalExercise value) async {
    final list = _byUid.putIfAbsent(uid, () => []);
    list.removeWhere((e) => e.id == value.id);
    list.add(value);
    _controller.add(uid);
  }

  @override
  Future<void> update(String uid, PersonalExercise value) async {
    final list = _byUid[uid];
    if (list == null) return;
    final index = list.indexWhere((e) => e.id == value.id);
    if (index == -1) return;
    list[index] = value;
    _controller.add(uid);
  }

  @override
  Future<void> delete(String uid, String id) async {
    final list = _byUid[uid];
    if (list == null) return;
    list.removeWhere((e) => e.id == id);
    _controller.add(uid);
  }
}
