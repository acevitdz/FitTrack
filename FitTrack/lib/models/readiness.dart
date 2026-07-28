import 'workout_completion.dart';
import 'workout_plan.dart';

enum ReadinessLevel { none, light, moderate, recovery }

class ReadinessInput {
  const ReadinessInput({
    required this.energy,
    required this.soreness,
    required this.soreMuscles,
    required this.availableMinutes,
    required this.availableEquipment,
  });

  final int energy;
  final int soreness;
  final Set<String> soreMuscles;
  final int availableMinutes;
  final Set<String> availableEquipment;
}

class ReadinessResult {
  const ReadinessResult({
    required this.level,
    required this.original,
    required this.adjusted,
    required this.reasons,
  });

  final ReadinessLevel level;
  final WorkoutPlanSnapshot original;
  final WorkoutPlanSnapshot adjusted;
  final List<String> reasons;
}

abstract final class ReadinessRuleEngine {
  static ReadinessResult evaluate(
    WorkoutPlanSnapshot original,
    ReadinessInput input,
  ) {
    final level = _level(input);
    final reasons = <String>[];
    if (level == ReadinessLevel.recovery) {
      reasons.add(
        'Năng lượng hoặc mức đau/mỏi hôm nay phù hợp với phục hồi chủ động.',
      );
      return ReadinessResult(
        level: level,
        original: original,
        adjusted: original.copyWith(
          exercises: const [],
          adjusted: true,
          adjustmentReasons: reasons,
        ),
        reasons: reasons,
      );
    }

    var exercises = original.exercises.map((item) => item.copyWith()).toList();
    if (input.soreness >= 3 && input.soreMuscles.isNotEmpty) {
      final before = exercises.length;
      exercises = exercises
          .where((item) => !input.soreMuscles.contains(item.muscleGroup))
          .toList();
      if (exercises.length < before) {
        reasons.add('Đã bỏ bài tác động trực tiếp lên nhóm cơ đang đau/mỏi.');
      }
    }
    if (input.availableEquipment.isNotEmpty) {
      final before = exercises.length;
      exercises = exercises.where((item) {
        final noEquipment = item.equipment.toLowerCase().contains('không');
        return noEquipment || input.availableEquipment.contains(item.equipment);
      }).toList();
      if (exercises.length < before) {
        reasons.add('Đã bỏ bài cần dụng cụ hiện không có.');
      }
    }

    final factor = switch (level) {
      ReadinessLevel.light => .8,
      ReadinessLevel.moderate => .6,
      _ => 1.0,
    };
    if (factor < 1) {
      exercises = exercises
          .map(
            (item) => item.copyWith(
              sets: (item.sets * factor).floor().clamp(1, item.sets),
            ),
          )
          .toList();
      reasons.add(
        level == ReadinessLevel.light
            ? 'Giảm nhẹ số hiệp theo mức sẵn sàng hôm nay.'
            : 'Giảm số hiệp để ưu tiên chất lượng và phục hồi.',
      );
    }

    while (exercises.isNotEmpty &&
        _estimateMinutes(exercises) > input.availableMinutes) {
      exercises.removeLast();
    }
    if (exercises.length < original.exercises.length &&
        !reasons.any((reason) => reason.contains('dụng cụ')) &&
        !reasons.any((reason) => reason.contains('đau/mỏi'))) {
      reasons.add('Rút gọn bài phụ để phù hợp thời gian bạn có.');
    }
    if (reasons.isEmpty) {
      reasons.add('Kế hoạch hiện tại phù hợp với mức sẵn sàng.');
    }

    final adjusted = original.copyWith(
      exercises: exercises,
      adjusted:
          level != ReadinessLevel.none ||
          exercises.length != original.exercises.length,
      adjustmentReasons: reasons,
    );
    return ReadinessResult(
      level: level,
      original: original,
      adjusted: adjusted,
      reasons: reasons,
    );
  }

  static ReadinessLevel _level(ReadinessInput input) {
    if (input.energy <= 1 || input.soreness >= 5) {
      return ReadinessLevel.recovery;
    }
    if (input.energy <= 2 || input.soreness >= 4) {
      return ReadinessLevel.moderate;
    }
    if (input.energy == 3 || input.soreness == 3) {
      return ReadinessLevel.light;
    }
    return ReadinessLevel.none;
  }

  static int _estimateMinutes(List<PlanExercise> exercises) {
    final seconds = exercises.fold<int>(
      0,
      (sum, item) => sum + item.sets * 45 + item.sets * item.restSeconds,
    );
    return (seconds / 60).ceil();
  }
}
