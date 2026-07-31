import '../models/exercise.dart';
import '../models/program.dart';

class ProgramCatalogValidation {
  const ProgramCatalogValidation(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// Validates authored catalog content before it can be matched or enrolled.
class ProgramCatalogValidator {
  const ProgramCatalogValidator({
    this.allowedPoseRuleVersionIds = const {'squat_pose_v1'},
  });

  final Set<String> allowedPoseRuleVersionIds;

  ProgramCatalogValidation validate(
    ProgramVersion version, {
    required Iterable<Exercise> exercises,
  }) {
    final errors = <String>[];
    final activeExercises = {
      for (final exercise in exercises)
        if (exercise.isCatalogApproved && exercise.isLibraryVisible)
          exercise.id: exercise,
    };
    if (version.id.trim().isEmpty || version.programId.trim().isEmpty) {
      errors.add('version_identity_missing');
    }
    if (!version.guidedConfirmationAvailable) {
      errors.add('guided_confirmation_required');
    }
    if (version.sourceRefs.isEmpty ||
        version.sourceRefs.any(
          (source) =>
              source.title.trim().isEmpty ||
              !(Uri.tryParse(source.url)?.isScheme('https') ?? false),
        )) {
      errors.add('source_reference_invalid');
    }
    if (version.safetyCopy.trim().isEmpty ||
        version.accessibilityLabel.trim().isEmpty) {
      errors.add('safety_or_accessibility_copy_missing');
    }
    final frequencies = version.cadence.supportedFrequencies;
    if (frequencies.length != 1 ||
        frequencies.any((value) => value < 2 || value > 4)) {
      errors.add('cadence_frequency_invalid');
    }
    if (version.goalKeys.length != 1 ||
        !TrainingGoalKey.values.contains(version.goalKeys.singleOrNull) ||
        version.experienceKeys.length != 1 ||
        !const {
          'beginner',
          'intermediate',
        }.contains(version.experienceKeys.singleOrNull) ||
        version.audienceTags.length != 1 ||
        !const {
          ProgramAudiencePreference.male,
          ProgramAudiencePreference.female,
        }.contains(version.audienceTags.singleOrNull) ||
        !const {'home', 'gym'}.contains(version.environmentKey)) {
      errors.add('route_axis_invalid');
    }
    if (version.environmentKey == 'gym' &&
            !version.equipmentKeys.contains('gym') ||
        version.environmentKey == 'home' &&
            version.equipmentKeys.contains('gym')) {
      errors.add('route_environment_equipment_mismatch');
    }
    final expectedWeekCount =
        version.experienceKeys.singleOrNull == 'intermediate' ? 8 : 6;
    if (version.weeks.length != expectedWeekCount) {
      errors.add('route_week_count_invalid');
    }
    for (final frequency in frequencies) {
      final weekdays = version.cadence.weekdaysFor(frequency);
      if (weekdays.length != frequency ||
          weekdays.toSet().length != weekdays.length ||
          weekdays.any((day) => day < 1 || day > 7)) {
        errors.add('cadence_weekdays_invalid:$frequency');
      }
    }

    final ids = <String>{};
    final orderedWeeks = [...version.weeks]
      ..sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    for (var index = 0; index < orderedWeeks.length; index++) {
      final week = orderedWeeks[index];
      if (week.weekNumber != index + 1) {
        errors.add('week_sequence_invalid:${week.id}');
      }
      if (!ids.add(week.id)) errors.add('duplicate_id:${week.id}');
      for (final frequency in frequencies) {
        final available = week.sessions
            .where((session) => session.minimumSessionsPerWeek <= frequency)
            .length;
        if (available != frequency) {
          errors.add('insufficient_sessions:${week.id}:$frequency');
        }
      }
      for (final session in week.sessions) {
        if (!ids.add(session.id)) errors.add('duplicate_id:${session.id}');
        if (session.blocks.isEmpty || session.readinessVariants.isEmpty) {
          errors.add('session_content_missing:${session.id}');
        }
        final choices = session.readinessVariants
            .map((variant) => variant.choice)
            .toSet();
        if (!choices.containsAll(ReadinessChoice.values)) {
          errors.add('readiness_variants_incomplete:${session.id}');
        }
        for (final block in [
          ...session.blocks,
          for (final variant in session.readinessVariants) ...variant.blocks,
        ]) {
          if (!ids.add(block.id)) {
            // Ready variants may deliberately reference the immutable base
            // blocks, so an exact repeated object is allowed.
            final isBaseReference = session.blocks.any(
              (base) => identical(base, block),
            );
            if (!isBaseReference) errors.add('duplicate_id:${block.id}');
          }
          for (final prescription in block.prescriptions) {
            if (!ids.add(prescription.id)) {
              final isBaseReference = session.blocks.any(
                (base) => base.prescriptions.any(
                  (item) => identical(item, prescription),
                ),
              );
              if (!isBaseReference) {
                errors.add('duplicate_id:${prescription.id}');
              }
            }
            if (!activeExercises.containsKey(prescription.exerciseId)) {
              errors.add('exercise_unavailable:${prescription.exerciseId}');
            }
            if (prescription.restBetweenSetsSeconds < 0 ||
                prescription.restBetweenSetsSeconds > 300) {
              errors.add('rest_between_sets_invalid:${prescription.id}');
            }
            if (prescription.transitionAfterExerciseSeconds < 0 ||
                prescription.transitionAfterExerciseSeconds > 300) {
              errors.add('exercise_transition_rest_invalid:${prescription.id}');
            }
            for (final alternative in prescription.alternativeExerciseIds) {
              if (alternative == prescription.exerciseId ||
                  !activeExercises.containsKey(alternative)) {
                errors.add('alternative_invalid:$alternative');
              }
            }
            final poseRule = prescription.poseRuleVersionId;
            if (poseRule != null &&
                !allowedPoseRuleVersionIds.contains(poseRule)) {
              errors.add('pose_rule_not_allowed:$poseRule');
            }
          }
        }
      }
    }
    return ProgramCatalogValidation(List.unmodifiable(errors));
  }
}
