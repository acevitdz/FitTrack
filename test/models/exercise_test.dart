import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/models/exercise.dart';

void main() {
  group('Exercise.fromJson / toJson', () {
    test('round-trips a fully populated exercise', () {
      const exercise = Exercise(
        id: 'squat_pose_v1',
        name: 'Squat',
        englishName: 'Bodyweight Squat',
        muscleGroup: 'Chân',
        difficulty: ExerciseDifficulty.intermediate,
        equipment: 'Không dụng cụ',
        description: 'Bài tập toàn thân phần dưới.',
        instructions: ['Bước 1', 'Bước 2'],
        commonMistakes: ['Gối đổ vào trong'],
        isActive: true,
        imageUrl: 'https://example.com/squat.png',
      );

      final json = exercise.toJson();
      final decoded = Exercise.fromJson(json);

      expect(decoded, exercise);
      expect(json['imageUrl'], 'https://example.com/squat.png');
    });

    test('round-trips with empty lists and null imageUrl', () {
      const exercise = Exercise(
        id: 'plank',
        name: 'Plank',
        englishName: 'Plank',
        muscleGroup: 'Cơ lõi',
        difficulty: ExerciseDifficulty.beginner,
        equipment: 'Không dụng cụ',
        description: 'Giữ tư thế tĩnh.',
        instructions: [],
        commonMistakes: [],
        isActive: true,
      );

      final json = exercise.toJson();
      final decoded = Exercise.fromJson(json);

      expect(decoded, exercise);
      expect(decoded.imageUrl, isNull);
      expect(json.containsKey('imageUrl'), isFalse);
    });

    test('fromJson applies defaults for missing optional fields', () {
      final decoded = Exercise.fromJson(const {
        'id': 'lunge',
        'name': 'Lunge',
        'muscleGroup': 'Chân',
        'difficulty': ExerciseDifficulty.intermediate,
        'equipment': 'Không dụng cụ',
      });

      expect(decoded.englishName, '');
      expect(decoded.description, '');
      expect(decoded.instructions, isEmpty);
      expect(decoded.commonMistakes, isEmpty);
      expect(decoded.isActive, isTrue);
      expect(decoded.imageUrl, isNull);
    });
  });

  group('Exercise equality', () {
    test('two exercises with identical field values are equal', () {
      const a = Exercise(
        id: 'push_up',
        name: 'Chống đẩy',
        englishName: 'Push-up',
        muscleGroup: 'Ngực',
        difficulty: ExerciseDifficulty.beginner,
        equipment: 'Không dụng cụ',
        description: 'Bài đẩy toàn thân trên.',
        instructions: ['A', 'B'],
        commonMistakes: ['C'],
        isActive: true,
      );
      const b = Exercise(
        id: 'push_up',
        name: 'Chống đẩy',
        englishName: 'Push-up',
        muscleGroup: 'Ngực',
        difficulty: ExerciseDifficulty.beginner,
        equipment: 'Không dụng cụ',
        description: 'Bài đẩy toàn thân trên.',
        instructions: ['A', 'B'],
        commonMistakes: ['C'],
        isActive: true,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing instruction order breaks equality', () {
      const a = Exercise(
        id: 'push_up',
        name: 'Chống đẩy',
        englishName: 'Push-up',
        muscleGroup: 'Ngực',
        difficulty: ExerciseDifficulty.beginner,
        equipment: 'Không dụng cụ',
        description: 'Bài đẩy toàn thân trên.',
        instructions: ['A', 'B'],
        commonMistakes: [],
        isActive: true,
      );
      const b = Exercise(
        id: 'push_up',
        name: 'Chống đẩy',
        englishName: 'Push-up',
        muscleGroup: 'Ngực',
        difficulty: ExerciseDifficulty.beginner,
        equipment: 'Không dụng cụ',
        description: 'Bài đẩy toàn thân trên.',
        instructions: ['B', 'A'],
        commonMistakes: [],
        isActive: true,
      );

      expect(a == b, isFalse);
    });
  });

  test('ExerciseDifficulty.values contains all three levels in order', () {
    expect(ExerciseDifficulty.values, [
      ExerciseDifficulty.beginner,
      ExerciseDifficulty.intermediate,
      ExerciseDifficulty.advanced,
    ]);
  });
}
