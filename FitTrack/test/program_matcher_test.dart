import 'package:fittrack/data/program_seed_data.dart';
import 'package:fittrack/models/program.dart';
import 'package:fittrack/services/program_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('program domain JSON', () {
    test('training preferences preserve all one-tap matching choices', () {
      const preferences = UserTrainingPreferences(
        populationKey: 'healthy_adult_18_64',
        programAudiencePreference: ProgramAudiencePreference.female,
        goalKey: 'strength',
        experienceKey: 'intermediate',
        equipmentKeys: ['gym', 'bodyweight'],
      );

      final restored = UserTrainingPreferences.fromJson(preferences.toJson());

      expect(restored.populationKey, preferences.populationKey);
      expect(
        restored.programAudiencePreference,
        ProgramAudiencePreference.female,
      );
      expect(restored.goalKey, 'strength');
      expect(restored.experienceKey, 'intermediate');
      expect(restored.equipmentKeys, ['gym', 'bodyweight']);
    });

    test('program version round trip keeps the complete authored tree', () {
      final source = ProgramSeedData.versions.first;
      final restored = ProgramVersion.fromJson(source.toJson());

      expect(restored.id, source.id);
      expect(restored.status, ProgramLifecycleStatus.published);
      expect(restored.publishedBy, 'system_catalog_32_routes');
      expect(restored.sourceRefs, hasLength(source.sourceRefs.length));
      expect(
        restored.sourceRefs.map((item) => item.id),
        source.sourceRefs.map((item) => item.id),
      );
      expect(restored.environmentKey, 'home');
      expect(restored.cadence.sessionsPerWeek, 2);
      expect(restored.weeks, hasLength(6));
      expect(restored.allSessions, hasLength(12));
      expect(restored.sessionById(restored.allSessions.first.id), isNotNull);
      expect(restored.totalSets, greaterThan(0));
      expect(restored.estimatedTotalDurationMinutes, greaterThan(0));

      final firstSession = restored.allSessions.first;
      expect(firstSession.blocks, isNotEmpty);
      expect(firstSession.blocks.first.prescriptions, isNotEmpty);
      expect(
        firstSession.readinessVariants.map((item) => item.choice).toSet(),
        ReadinessChoice.values.toSet(),
      );
    });

    test('enrollment and occurrence stay pinned to a program version', () {
      final enrollment = ProgramEnrollment(
        id: 'enrollment_1',
        userId: 'user_1',
        programVersionId: ProgramSeedData.defaultFallbackProgramVersionId,
        startedAt: DateTime.utc(2026, 7, 24),
        status: ProgramEnrollmentStatus.active,
      );
      final occurrence = WorkoutOccurrence(
        id: 'occurrence_1',
        enrollmentId: enrollment.id,
        programVersionId: enrollment.programVersionId,
        sessionId: ProgramSeedData.versions.first.allSessions.first.id,
        weekNumber: 1,
        scheduledDate: DateTime.utc(2026, 7, 25),
        status: WorkoutOccurrenceStatus.postponed,
        originalScheduledDate: DateTime.utc(2026, 7, 24),
        readinessChoice: ReadinessChoice.reduceToday,
      );

      final restoredEnrollment = ProgramEnrollment.fromJson(
        enrollment.toJson(),
      );
      final restoredOccurrence = WorkoutOccurrence.fromJson(
        occurrence.toJson(),
      );

      expect(
        restoredEnrollment.programVersionId,
        ProgramSeedData.defaultFallbackProgramVersionId,
      );
      expect(
        restoredOccurrence.programVersionId,
        restoredEnrollment.programVersionId,
      );
      expect(restoredOccurrence.status, WorkoutOccurrenceStatus.postponed);
      expect(restoredOccurrence.readinessChoice, ReadinessChoice.reduceToday);
    });
  });

  group('ProgramMatcher', () {
    const matcher = ProgramMatcher(
      fallbackProgramVersionId: ProgramSeedData.defaultFallbackProgramVersionId,
    );

    test('matches a published program through all hard filters', () {
      const preferences = UserTrainingPreferences.defaults();

      final result = matcher.match(
        preferences: preferences,
        catalog: ProgramSeedData.versions,
      );

      expect(result.status, ProgramMatchStatus.matched);
      expect(
        result.version?.id,
        ProgramSeedData.defaultFallbackProgramVersionId,
      );
      expect(result.candidate?.reasons, contains('goal_match'));
    });

    test('never distributes draft, retired or recalled versions', () {
      const preferences = UserTrainingPreferences.defaults();
      final source = ProgramSeedData.versions.first;
      final unavailable = ProgramLifecycleStatus.values
          .where((status) => status != ProgramLifecycleStatus.published)
          .map(
            (status) => _versionFrom(
              source,
              id: 'version_${status.name}',
              status: status,
            ),
          )
          .toList();

      final result = const ProgramMatcher().match(
        preferences: preferences,
        catalog: unavailable,
      );

      expect(result.status, ProgramMatchStatus.noSupportedProgram);
      expect(result.version, isNull);
    });

    test(
      'uses audience only for ranking and is independent of input order',
      () {
        final source = ProgramSeedData.versions.first;
        final female = _versionFrom(
          source,
          id: 'female_program',
          audienceTags: const [ProgramAudiencePreference.female],
          publishedAt: DateTime.utc(2026, 7, 24),
        );
        final unisex = _versionFrom(
          source,
          id: 'unisex_program',
          audienceTags: const [ProgramAudiencePreference.unisex],
          publishedAt: DateTime.utc(2026, 7, 24),
        );
        const preferences = UserTrainingPreferences(
          populationKey: 'healthy_adult_18_64',
          programAudiencePreference: ProgramAudiencePreference.female,
          goalKey: TrainingGoalKey.fatLoss,
          experienceKey: 'beginner',
          equipmentKeys: ['bodyweight'],
          sessionsPerWeek: 2,
        );

        final first = const ProgramMatcher().match(
          preferences: preferences,
          catalog: [unisex, female],
        );
        final second = const ProgramMatcher().match(
          preferences: preferences,
          catalog: [female, unisex],
        );

        expect(first.version?.id, 'female_program');
        expect(second.version?.id, 'female_program');
        expect(first.rankedCandidates, hasLength(2));
      },
    );

    test('hard-filters missing equipment', () {
      const preferences = UserTrainingPreferences(
        populationKey: 'healthy_adult_18_64',
        programAudiencePreference: ProgramAudiencePreference.unisex,
        goalKey: 'strength',
        experienceKey: 'beginner',
        equipmentKeys: ['bodyweight'],
      );

      final result = const ProgramMatcher().match(
        preferences: preferences,
        catalog: [ProgramSeedData.versions.last],
      );

      expect(result.status, ProgramMatchStatus.noSupportedProgram);
    });

    test('hard-filters unsupported weekly frequency', () {
      const preferences = UserTrainingPreferences(
        populationKey: 'healthy_adult_18_64',
        programAudiencePreference: ProgramAudiencePreference.unisex,
        goalKey: TrainingGoalKey.generalFitness,
        experienceKey: 'beginner',
        equipmentKeys: ['bodyweight'],
        sessionsPerWeek: 7,
      );

      final result = const ProgramMatcher().match(
        preferences: preferences,
        catalog: ProgramSeedData.versions,
      );

      expect(result.status, ProgramMatchStatus.noSupportedProgram);
      expect(result.version, isNull);
    });

    test('configured fallback may relax goal but never safety gates', () {
      const compatiblePopulation = UserTrainingPreferences(
        populationKey: 'healthy_adult_18_64',
        programAudiencePreference: ProgramAudiencePreference.unisex,
        goalKey: 'unsupported_goal',
        experienceKey: 'beginner',
        equipmentKeys: ['bodyweight'],
      );
      const unsupportedPopulation = UserTrainingPreferences(
        populationKey: 'unsupported_population',
        programAudiencePreference: ProgramAudiencePreference.unisex,
        goalKey: 'strength',
        experienceKey: 'beginner',
        equipmentKeys: ['bodyweight'],
      );

      final fallback = matcher.match(
        preferences: compatiblePopulation,
        catalog: ProgramSeedData.versions,
      );
      final rejected = matcher.match(
        preferences: unsupportedPopulation,
        catalog: ProgramSeedData.versions,
      );

      expect(fallback.status, ProgramMatchStatus.fallback);
      expect(
        fallback.version?.id,
        ProgramSeedData.defaultFallbackProgramVersionId,
      );
      expect(
        fallback.candidate?.reasons,
        contains('goal_relaxed_for_fallback'),
      );
      expect(rejected.status, ProgramMatchStatus.noSupportedProgram);
    });
  });

  test('seed catalog is published, traceable and structurally complete', () {
    expect(ProgramSeedData.programs, hasLength(32));
    expect(ProgramSeedData.versions, hasLength(96));
    expect(
      ProgramSeedData.programs.expand(
        (program) => program.frequencyVariants.keys,
      ),
      everyElement(isIn(const [2, 3, 4])),
    );

    for (final version in ProgramSeedData.versions) {
      expect(version.status, ProgramLifecycleStatus.published);
      expect(version.publishedBy, isNotEmpty);
      expect(version.publishedAt, isNotNull);
      expect(version.sourceRefs, isNotEmpty);
      expect(version.changelog, isNotEmpty);
      expect(version.safetyCopy, isNotEmpty);
      expect(version.accessibilityLabel, isNotEmpty);
      expect(version.cadence.sessionsPerWeek, greaterThan(0));
      expect(version.cadence.supportedFrequencies, hasLength(1));
      expect(version.cadence.preferredWeekdays, isNotEmpty);
      expect(
        version.weeks.length,
        version.experienceKeys.single == 'beginner' ? 6 : 8,
      );
      expect(
        version.weeks.every(
          (week) => week.sessions.length == version.cadence.sessionsPerWeek,
        ),
        isTrue,
      );

      for (final session in version.allSessions) {
        expect(session.blocks, isNotEmpty);
        expect(
          session.blocks.every((block) => block.prescriptions.isNotEmpty),
          isTrue,
        );
        expect(
          session.readinessVariants.map((item) => item.choice).toSet(),
          ReadinessChoice.values.toSet(),
        );
      }

      final jsonKeys = _allJsonKeys(version.toJson());
      expect(jsonKeys, isNot(contains('load')));
      expect(jsonKeys, isNot(contains('volume')));
      expect(jsonKeys, isNot(contains('ocr')));
    }
  });
}

ProgramVersion _versionFrom(
  ProgramVersion source, {
  required String id,
  ProgramLifecycleStatus? status,
  List<ProgramAudiencePreference>? audienceTags,
  DateTime? publishedAt,
}) {
  final json = source.toJson();
  json['id'] = id;
  json['status'] = (status ?? source.status).name;
  if (audienceTags != null) {
    json['audienceTags'] = audienceTags.map((item) => item.name).toList();
  }
  if (publishedAt != null) {
    json['publishedAt'] = publishedAt.toIso8601String();
  }
  return ProgramVersion.fromJson(json);
}

Set<String> _allJsonKeys(Object? value) {
  final keys = <String>{};
  if (value is Map) {
    for (final entry in value.entries) {
      keys.add(entry.key.toString().toLowerCase());
      keys.addAll(_allJsonKeys(entry.value));
    }
  } else if (value is Iterable) {
    for (final item in value) {
      keys.addAll(_allJsonKeys(item));
    }
  }
  return keys;
}
