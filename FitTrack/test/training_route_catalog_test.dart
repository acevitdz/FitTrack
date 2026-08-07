import 'package:fittrack/data/program_seed_data.dart';
import 'package:fittrack/data/training_route_catalog.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/program_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog exposes the complete 4 × 2 × 2 × 2 route matrix', () {
    expect(ProgramSeedData.programs, hasLength(32));
    expect(ProgramSeedData.versions, hasLength(96));

    final axes = {
      for (final version in ProgramSeedData.versions)
        (
          version.goalKeys.single,
          version.audienceTags.single,
          version.experienceKeys.single,
          version.environmentKey,
          version.cadence.sessionsPerWeek,
        ),
    };
    expect(axes, hasLength(96));

    for (final program in ProgramSeedData.programs) {
      expect(program.title, isNot(startsWith(program.id)));
      expect(program.title, contains('·'));
      expect(program.frequencyVariants.keys.toSet(), {2, 3, 4});
      for (final entry in program.frequencyVariants.entries) {
        expect(entry.value, '${program.id}-${entry.key}D-v1');
      }
    }
  });

  test('matcher selects the exact immutable frequency version', () {
    const preferences = UserTrainingPreferences(
      populationKey: 'healthy_adult_18_64',
      programAudiencePreference: ProgramAudiencePreference.female,
      goalKey: TrainingGoalKey.muscleGain,
      experienceKey: 'intermediate',
      equipmentKeys: ['bodyweight', 'gym'],
      sessionsPerWeek: 4,
    );

    final result = const ProgramMatcher().match(
      preferences: preferences,
      catalog: ProgramSeedData.versions,
    );

    expect(result.status, ProgramMatchStatus.matched);
    expect(result.version?.id, 'TC-NU-DATAP-GYM-4D-v1');
  });

  test('beginner progression and per-side target follow the design', () {
    final version = _version('GM-NAM-MOI-NHA-3D-v1');
    final week1 = version.weeks[0];
    final week3 = version.weeks[2];
    final week5 = version.weeks[4];

    expect(week1.sessions, hasLength(3));
    expect(_prescriptions(week1.sessions.first).first.sets, 2);
    expect(_prescriptions(week3.sessions.first).first.sets, 3);
    expect(_prescriptions(week5.sessions.first).first.targetRange.minimum, 40);

    final lunge = _prescriptions(
      week1.sessions.first,
    ).singleWhere((item) => item.exerciseId == 'fedb_Bodyweight_Walking_Lunge');
    expect(lunge.perSide, isTrue);
    expect(lunge.targetType, PrescriptionTargetType.durationSeconds);
    expect(lunge.targetLabel, '30 giây/bên');
  });

  test('advanced 3-day version rotates session focus and deloads week 4', () {
    final version = _version('SM-NAM-DATAP-GYM-3D-v1');

    expect(version.weeks[0].sessions.map((item) => item.title), [
      'Squat',
      'Bench',
      'Deadlift',
    ]);
    expect(version.weeks[1].sessions.map((item) => item.title), [
      'Vai và kéo',
      'Squat',
      'Bench',
    ]);
    expect(version.weeks[2].sessions.map((item) => item.title), [
      'Deadlift',
      'Vai và kéo',
      'Squat',
    ]);
    expect(version.weeks[3].sessions.map((item) => item.title), [
      'Bench',
      'Deadlift',
      'Vai và kéo',
    ]);

    final standardSets = _prescriptions(
      version.weeks[0].sessions.first,
    ).first.sets;
    final deloadSets = _prescriptions(version.weeks[3].sessions[1]).first.sets;
    expect(standardSets, 5);
    expect(deloadSets, 4);
  });

  test('bodyweight timer ignores the legacy repetition cap annotation', () {
    final version = _version('TC-NAM-MOI-NHA-3D-v1');
    final prescriptions = _prescriptions(version.weeks.first.sessions.first);
    final pushup = prescriptions.singleWhere(
      (item) => item.exerciseId == 'fedb_Pushups',
    );
    final squat = prescriptions.singleWhere(
      (item) => item.exerciseId == 'squat',
    );

    expect(pushup.targetType, PrescriptionTargetType.durationSeconds);
    expect(pushup.targetRange.minimum, 25);
    expect(pushup.targetRange.maximum, 25);
    expect(pushup.targetLabel, '25 giây');
    expect(pushup.cameraTargetReps, isNull);
    expect(squat.targetType, PrescriptionTargetType.durationSeconds);
    expect(squat.targetLabel, '35 giây');
    expect(squat.cameraTargetReps, 15);
  });

  test('minute prescriptions render as minutes instead of raw seconds', () {
    final version = _version('KD-NU-MOI-GYM-3D-v1');
    final first = _prescriptions(version.weeks.first.sessions.first).first;

    expect(first.exerciseId, 'fedb_Elliptical_Trainer');
    expect(first.targetType, PrescriptionTargetType.durationSeconds);
    expect(first.targetRange.minimum, 15 * 60);
    expect(first.targetLabel, '15 phút');
  });

  test('calculateWeek8SetReduction covers rounding cases correctly', () {
    // 4-day routes (0.70 factor)
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 5,
        sessionsPerWeek: 4,
      ),
      4,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 4,
        sessionsPerWeek: 4,
      ),
      3,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 3,
        sessionsPerWeek: 4,
      ),
      2,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 2,
        sessionsPerWeek: 4,
      ),
      1,
    );

    // 2 or 3 day routes (0.75 factor)
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 5,
        sessionsPerWeek: 3,
      ),
      4,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 4,
        sessionsPerWeek: 3,
      ),
      3,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 3,
        sessionsPerWeek: 3,
      ),
      2,
    );
    expect(
      TrainingRouteCatalog.calculateWeek8SetReduction(
        sets: 2,
        sessionsPerWeek: 3,
      ),
      2,
    );
  });
}

ProgramVersion _version(String id) =>
    ProgramSeedData.versions.singleWhere((item) => item.id == id);

List<ExercisePrescription> _prescriptions(ProgramSession session) => [
  for (final block in session.blocks) ...block.prescriptions,
];
