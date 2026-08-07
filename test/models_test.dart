import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/models/health_models.dart';
import 'package:fittrack/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile round trip keeps current body metrics and derives BMI', () {
    const profile = UserProfile(
      id: 'u1',
      email: 'user@example.com',
      name: 'Nguyễn An',
      heightCm: 170,
      currentWeightKg: 68,
      goal: 'Duy trì sức khỏe',
      weeklyWorkoutGoal: 3,
    );

    final json = profile.toJson();
    final restored = UserProfile.fromJson(json);

    expect(restored.name, profile.name);
    expect(restored.bmi, closeTo(23.53, .01));
    expect(json, isNot(contains('targetWeightKg')));
    expect(json, isNot(contains('actualReps')));
    expect(json, isNot(contains('load')));
  });

  test('body measurement keeps a height snapshot for historical BMI', () {
    final measurement = WeightEntry(
      id: 'body-1',
      heightCm: 175,
      weightKg: 70,
      recordedAt: DateTime.utc(2026, 7, 24, 8),
    );

    final restored = WeightEntry.fromJson(measurement.toJson());

    expect(restored.heightCm, 175);
    expect(restored.weightKg, 70);
    expect(restored.bmi, closeTo(22.86, .01));
    expect(restored.recordedAt, measurement.recordedAt);
  });

  test('migrated measurement without height reports unknown BMI, not zero', () {
    final restored = WeightEntry.fromJson({
      'id': 'legacy-body',
      'weightKg': 65,
      'recordedAt': DateTime.utc(2026, 7, 20).toIso8601String(),
    });

    expect(restored.heightCm, isNull);
    expect(restored.bmi, isNull);
  });

  test('exercise library visibility defaults to visible and round trips', () {
    final base = <String, dynamic>{
      'id': 'push-up',
      'name': 'Chống đẩy',
      'englishName': 'Push-up',
      'muscleGroup': 'Ngực',
      'difficulty': 'Cơ bản',
      'equipment': 'Không dụng cụ',
      'location': 'Tại nhà',
      'instructions': ['Giữ thân người thẳng.'],
      'commonMistakes': ['Để hông võng xuống.'],
      'suggestedSets': 3,
      'suggestedReps': 10,
    };

    expect(Exercise.fromJson(base).isLibraryVisible, true);
    final hidden = Exercise.fromJson({...base, 'isLibraryVisible': false});
    expect(hidden.isLibraryVisible, false);
    expect(hidden.toJson()['isLibraryVisible'], false);
  });
}
