import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/data/exercise_catalog.dart';
import 'package:fittrack/data/program_catalog.dart';
import 'package:fittrack/models/program.dart';

void main() {
  group('exerciseCatalog integrity', () {
    test('has no duplicate exercise ids', () {
      final ids = exerciseCatalog.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'Trùng id bài tập: $ids');
    });

    test('no exercise has blank required text fields', () {
      for (final exercise in exerciseCatalog) {
        expect(exercise.id.trim(), isNotEmpty);
        expect(exercise.name.trim(), isNotEmpty);
        expect(exercise.muscleGroup.trim(), isNotEmpty);
        expect(exercise.equipment.trim(), isNotEmpty);
      }
    });
  });

  group('programCatalog integrity', () {
    test('has no duplicate program ids', () {
      final ids = programCatalog.map((p) => p.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Trùng id chương trình: $ids',
      );
    });

    test('has no duplicate programVersion ids', () {
      final ids = programVersionCatalog.map((v) => v.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Trùng id phiên bản chương trình: $ids',
      );
    });

    test('every ProgramVersion.programId references an existing Program', () {
      final programIds = programCatalog.map((p) => p.id).toSet();
      for (final version in programVersionCatalog) {
        expect(
          programIds.contains(version.programId),
          isTrue,
          reason:
              'ProgramVersion ${version.id} tham chiếu programId '
              '"${version.programId}" không tồn tại trong programCatalog',
        );
      }
    });
  });

  group('exerciseId references resolve to active catalog entries', () {
    final activeExerciseIds = exerciseCatalog
        .where((e) => e.isActive)
        .map((e) => e.id)
        .toSet();

    test(
      'every prescription in every session block uses an active exerciseId',
      () {
        for (final version in programVersionCatalog) {
          for (final session in version.allSessions) {
            for (final block in session.blocks) {
              for (final prescription in block.prescriptions) {
                expect(
                  activeExerciseIds.contains(prescription.exerciseId),
                  isTrue,
                  reason:
                      'Buổi ${session.id} dùng exerciseId '
                      '"${prescription.exerciseId}" không tồn tại hoặc không active',
                );
              }
            }
          }
        }
      },
    );

    test('every readiness variant block uses an active exerciseId', () {
      for (final version in programVersionCatalog) {
        for (final variant in version.readinessVariants) {
          for (final block in variant.blocks) {
            for (final prescription in block.prescriptions) {
              expect(
                activeExerciseIds.contains(prescription.exerciseId),
                isTrue,
                reason:
                    'ReadinessVariant (${variant.sessionId}, '
                    '${variant.readiness.name}) dùng exerciseId '
                    '"${prescription.exerciseId}" không tồn tại hoặc không active',
              );
            }
          }
        }
      }
    });
  });

  group('ProgramSession structural consistency', () {
    test('totalSets equals the sum of prescription sets across all blocks', () {
      for (final version in programVersionCatalog) {
        for (final session in version.allSessions) {
          final actualSets = session.blocks
              .expand((block) => block.prescriptions)
              .fold<int>(0, (sum, p) => sum + p.sets);
          expect(
            session.totalSets,
            actualSets,
            reason:
                'Buổi ${session.id} khai báo totalSets=${session.totalSets} '
                'nhưng tổng thực tế là $actualSets',
          );
        }
      }
    });

    test('ProgramWeek.weekNumber is unique within each ProgramVersion', () {
      for (final version in programVersionCatalog) {
        final weekNumbers = version.weeks.map((w) => w.weekNumber).toList();
        expect(
          weekNumbers.toSet().length,
          weekNumbers.length,
          reason: 'Phiên bản ${version.id} có weekNumber trùng: $weekNumbers',
        );
      }
    });

    test('ProgramSession.order is unique within each ProgramWeek', () {
      for (final version in programVersionCatalog) {
        for (final week in version.weeks) {
          final orders = week.sessions.map((s) => s.order).toList();
          expect(
            orders.toSet().length,
            orders.length,
            reason:
                'Tuần ${week.weekNumber} của ${version.id} có thứ tự buổi '
                'trùng: $orders',
          );
        }
      }
    });

    test('ProgramSession ids are unique within each ProgramVersion', () {
      for (final version in programVersionCatalog) {
        final ids = version.allSessions.map((s) => s.id).toList();
        expect(
          ids.toSet().length,
          ids.length,
          reason: 'Phiên bản ${version.id} có id buổi tập trùng: $ids',
        );
      }
    });
  });

  group('ProgramVersion matching-criteria are non-empty', () {
    test('published versions declare all hard-gate criteria', () {
      for (final version in programVersionCatalog) {
        if (version.status != ProgramVersionStatus.published) continue;
        expect(
          version.targetPopulationKeys,
          isNotEmpty,
          reason: '${version.id} thiếu targetPopulationKeys',
        );
        expect(
          version.targetGoalKeys,
          isNotEmpty,
          reason: '${version.id} thiếu targetGoalKeys',
        );
        expect(
          version.targetExperienceKeys,
          isNotEmpty,
          reason: '${version.id} thiếu targetExperienceKeys',
        );
        expect(
          version.requiredEquipmentKeys,
          isNotEmpty,
          reason: '${version.id} thiếu requiredEquipmentKeys',
        );
      }
    });
  });
}
