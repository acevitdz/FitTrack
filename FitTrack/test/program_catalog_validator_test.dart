import 'package:fittrack/data/program_seed_data.dart';
import 'package:fittrack/data/seed_data.dart';
import 'package:fittrack/models/exercise.dart';
import 'package:fittrack/services/bundled_exercise_catalog.dart';
import 'package:fittrack/services/program_catalog_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Exercise> catalog;

  setUpAll(() async {
    final base = [
      ...SeedData.exercises,
      ...await const BundledExerciseCatalog().load(),
    ];
    final referenced = {
      for (final version in ProgramSeedData.versions)
        for (final session in version.allSessions)
          for (final block in session.blocks)
            for (final prescription in block.prescriptions)
              prescription.exerciseId,
    };
    final known = base.map((exercise) => exercise.id).toSet();
    catalog = [
      ...base,
      for (final id in referenced)
        if (!known.contains(id))
          Exercise(
            id: id,
            name: id,
            englishName: id,
            muscleGroup: 'Route fixture',
            difficulty: 'Cơ bản',
            equipment: 'Theo catalog Firebase',
            location: 'Theo catalog Firebase',
            instructions: const ['Thực hiện có kiểm soát.'],
            commonMistakes: const ['Không bỏ qua cue an toàn.'],
            suggestedSets: 1,
            suggestedReps: 1,
            sourceProvider: 'fittrack_route_catalog_fixture',
            sourceExerciseId: id,
            sourceUrl: 'https://fittrack-cse441-6c062.firebaseapp.com/',
            license: 'fittrack-authored',
            reviewedAt: '2026-07-31T00:00:00Z',
            reviewedBy: 'test-fixture',
          ),
    ];
  });

  test('every bundled program version passes catalog validation', () {
    const validator = ProgramCatalogValidator();

    for (final version in ProgramSeedData.versions) {
      final result = validator.validate(version, exercises: catalog);
      expect(
        result.errors,
        isEmpty,
        reason: '${version.id}: ${result.errors.join(', ')}',
      );
    }
  });

  test('bundled catalog publishes only implemented Camera Coach rules', () {
    final rules = {
      for (final version in ProgramSeedData.versions)
        for (final session in version.allSessions)
          for (final block in [
            ...session.blocks,
            for (final variant in session.readinessVariants) ...variant.blocks,
          ])
            for (final prescription in block.prescriptions)
              prescription.poseRuleVersionId,
    }.whereType<String>().toSet();

    expect(rules, {'squat_pose_v1'});
  });

  test('draft exercise cannot be referenced by a published program', () {
    final exercises = [
      for (final exercise in catalog)
        if (exercise.id == 'fedb_Pushups')
          exercise.copyWith(catalogStatus: 'draft')
        else
          exercise,
    ];

    final result = const ProgramCatalogValidator().validate(
      ProgramSeedData.versions.first,
      exercises: exercises,
    );

    expect(result.errors, contains('exercise_unavailable:fedb_Pushups'));
  });
}
