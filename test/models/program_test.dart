import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/models/program.dart';

const _prescription = ExercisePrescription(
  exerciseId: 'squat_pose_v1',
  order: 1,
  sets: 3,
  targetLabel: '12 lần',
);

const _block = ProgramBlock(
  type: ProgramBlockType.main,
  order: 1,
  prescriptions: [_prescription],
);

const _session = ProgramSession(
  id: 'bodyweight_fullbody_v1_w1s1',
  order: 1,
  title: 'Buổi A',
  estimatedDurationMinutes: 35,
  totalSets: 3,
  blocks: [_block],
);

const _week = ProgramWeek(weekNumber: 1, sessions: [_session]);

final _programVersion = ProgramVersion(
  id: 'bodyweight_fullbody_v1',
  programId: 'bodyweight_fullbody',
  version: 1,
  status: ProgramVersionStatus.published,
  cadence: const ProgramCadence(sessionsPerWeek: 2),
  weeks: const [_week],
  safetyCopy: 'Dừng tập ngay nếu thấy đau.',
  accessibilityLabel: 'Chương trình toàn thân.',
  sourceRefs: const [
    SourceRef(
      title: 'ACSM Guidelines',
      publisher: 'ACSM',
      publicationYear: 2021,
    ),
  ],
  readinessVariants: const [
    ReadinessVariant(
      sessionId: 'bodyweight_fullbody_v1_w1s1',
      readiness: ReadinessKey.ready,
      blocks: [_block],
    ),
  ],
  targetPopulationKeys: const ['healthy_adult_18_64'],
  targetGoalKeys: const ['general_fitness'],
  targetExperienceKeys: const ['beginner'],
  requiredEquipmentKeys: const ['bodyweight'],
  audiencePreference: ProgramAudiencePreference.unisex,
);

void main() {
  group('ExercisePrescription / ProgramBlock round-trip', () {
    test('ExercisePrescription round-trips', () {
      final json = _prescription.toJson();
      final decoded = ExercisePrescription.fromJson(json);

      expect(decoded.exerciseId, _prescription.exerciseId);
      expect(decoded.order, _prescription.order);
      expect(decoded.sets, _prescription.sets);
      expect(decoded.targetLabel, _prescription.targetLabel);
    });

    test('ProgramBlock round-trips with nested prescriptions', () {
      final json = _block.toJson();
      final decoded = ProgramBlock.fromJson(json);

      expect(decoded.type, _block.type);
      expect(decoded.order, _block.order);
      expect(decoded.prescriptions.length, 1);
      expect(decoded.prescriptions.first.exerciseId, 'squat_pose_v1');
    });
  });

  group('ProgramVersion round-trip', () {
    test('round-trips the full nested tree', () {
      final json = _programVersion.toJson();
      final decoded = ProgramVersion.fromJson(json);

      expect(decoded.id, _programVersion.id);
      expect(decoded.programId, _programVersion.programId);
      expect(decoded.version, _programVersion.version);
      expect(decoded.status, ProgramVersionStatus.published);
      expect(decoded.cadence.sessionsPerWeek, 2);

      expect(decoded.weeks.length, 1);
      expect(decoded.weeks.first.weekNumber, 1);
      expect(decoded.weeks.first.sessions.length, 1);

      final session = decoded.weeks.first.sessions.first;
      expect(session.id, 'bodyweight_fullbody_v1_w1s1');
      expect(session.blocks.length, 1);
      expect(
        session.blocks.first.prescriptions.first.exerciseId,
        'squat_pose_v1',
      );

      expect(decoded.sourceRefs.single.title, 'ACSM Guidelines');
      expect(decoded.readinessVariants.single.readiness, ReadinessKey.ready);

      expect(decoded.targetPopulationKeys, ['healthy_adult_18_64']);
      expect(decoded.targetGoalKeys, ['general_fitness']);
      expect(decoded.targetExperienceKeys, ['beginner']);
      expect(decoded.requiredEquipmentKeys, ['bodyweight']);
      expect(decoded.audiencePreference, ProgramAudiencePreference.unisex);
    });

    test('allSessions flattens sessions across all weeks', () {
      const secondSession = ProgramSession(
        id: 'bodyweight_fullbody_v1_w2s1',
        order: 1,
        title: 'Buổi A tuần 2',
        estimatedDurationMinutes: 38,
        totalSets: 4,
        blocks: [_block],
      );
      final version = ProgramVersion(
        id: _programVersion.id,
        programId: _programVersion.programId,
        version: _programVersion.version,
        status: _programVersion.status,
        cadence: _programVersion.cadence,
        weeks: [
          _week,
          const ProgramWeek(weekNumber: 2, sessions: [secondSession]),
        ],
        safetyCopy: _programVersion.safetyCopy,
        accessibilityLabel: _programVersion.accessibilityLabel,
        sourceRefs: _programVersion.sourceRefs,
        readinessVariants: _programVersion.readinessVariants,
        targetPopulationKeys: _programVersion.targetPopulationKeys,
        targetGoalKeys: _programVersion.targetGoalKeys,
        targetExperienceKeys: _programVersion.targetExperienceKeys,
        requiredEquipmentKeys: _programVersion.requiredEquipmentKeys,
        audiencePreference: _programVersion.audiencePreference,
      );

      expect(version.allSessions.map((s) => s.id), [
        'bodyweight_fullbody_v1_w1s1',
        'bodyweight_fullbody_v1_w2s1',
      ]);
    });
  });

  group('ProgramEnrollment and WorkoutOccurrence round-trip', () {
    test('ProgramEnrollment round-trips including nested preferences', () {
      final enrollment = ProgramEnrollment(
        id: 'enr_1',
        programId: 'bodyweight_fullbody',
        programVersionId: 'bodyweight_fullbody_v1',
        preferences: const UserTrainingPreferences(
          populationKey: 'healthy_adult_18_64',
          programAudiencePreference: ProgramAudiencePreference.unisex,
          goalKey: 'general_fitness',
          experienceKey: 'beginner',
          equipmentKeys: ['bodyweight'],
          sessionsPerWeek: 2,
        ),
        startedAt: DateTime.utc(2026, 1, 5),
      );

      final decoded = ProgramEnrollment.fromJson(enrollment.toJson());

      expect(decoded.id, enrollment.id);
      expect(decoded.programId, enrollment.programId);
      expect(decoded.programVersionId, enrollment.programVersionId);
      expect(decoded.preferences.goalKey, 'general_fitness');
      expect(decoded.preferences.equipmentKeys, ['bodyweight']);
      expect(decoded.startedAt, enrollment.startedAt);
    });

    test('WorkoutOccurrence round-trips and copyWith updates fields', () {
      final occurrence = WorkoutOccurrence(
        id: 'occ_1',
        enrollmentId: 'enr_1',
        sessionId: 'bodyweight_fullbody_v1_w1s1',
        scheduledDate: DateTime.utc(2026, 1, 6),
        status: WorkoutOccurrenceStatus.scheduled,
      );

      final decoded = WorkoutOccurrence.fromJson(occurrence.toJson());
      expect(decoded.status, WorkoutOccurrenceStatus.scheduled);
      expect(decoded.scheduledDate, occurrence.scheduledDate);

      final postponed = occurrence.copyWith(
        status: WorkoutOccurrenceStatus.postponed,
      );
      expect(postponed.status, WorkoutOccurrenceStatus.postponed);
      expect(postponed.id, occurrence.id);
      expect(postponed.scheduledDate, occurrence.scheduledDate);
    });
  });

  test(
    'TrainingGoalKey.labelFor returns Vietnamese label and falls back to key',
    () {
      expect(TrainingGoalKey.labelFor(TrainingGoalKey.fatLoss), 'Giảm mỡ');
      expect(TrainingGoalKey.labelFor('unknown_key'), 'unknown_key');
    },
  );
}
