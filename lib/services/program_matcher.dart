import '../models/program.dart';

enum ProgramMatchStatus { matched, fallback, noSupportedProgram }

class ProgramMatchCandidate {
  const ProgramMatchCandidate({
    required this.version,
    required this.score,
    required this.reasons,
  });

  final ProgramVersion version;
  final int score;
  final List<String> reasons;
}

class ProgramMatchResult {
  const ProgramMatchResult({
    required this.status,
    required this.candidate,
    required this.rankedCandidates,
    required this.reasons,
  });

  final ProgramMatchStatus status;
  final ProgramMatchCandidate? candidate;
  final List<ProgramMatchCandidate> rankedCandidates;
  final List<String> reasons;

  ProgramVersion? get version => candidate?.version;
  bool get hasMatch => candidate != null;
  bool get isFallback => status == ProgramMatchStatus.fallback;
}

/// Selects only published catalog content through deterministic rules.
///
/// Normal matching hard-filters status, population, goal, experience,
/// equipment and published weekly frequency. Audience remains a ranking
/// preference. A configured fallback may relax the goal only; it must still
/// pass every other catalog gate.
class ProgramMatcher {
  const ProgramMatcher({this.fallbackProgramVersionId});

  final String? fallbackProgramVersionId;

  ProgramMatchResult match({
    required UserTrainingPreferences preferences,
    required Iterable<ProgramVersion> catalog,
    String? fallbackProgramVersionId,
  }) {
    final versions = catalog.toList(growable: false);
    final ranked =
        versions
            .where((version) => _isExactMatch(version, preferences))
            .map((version) => _rank(version, preferences))
            .toList()
          ..sort(_compareCandidates);

    if (ranked.isNotEmpty) {
      return ProgramMatchResult(
        status: ProgramMatchStatus.matched,
        candidate: ranked.first,
        rankedCandidates: List.unmodifiable(ranked),
        reasons: const ['deterministic_match'],
      );
    }

    final fallbackId =
        fallbackProgramVersionId ?? this.fallbackProgramVersionId;
    if (fallbackId != null) {
      final eligibleFallbacks =
          versions
              .where(
                (version) =>
                    version.id == fallbackId &&
                    _passesFallbackGate(version, preferences),
              )
              .toList()
            ..sort((left, right) => left.id.compareTo(right.id));
      if (eligibleFallbacks.isNotEmpty) {
        final fallback = _rank(
          eligibleFallbacks.first,
          preferences,
          isFallback: true,
        );
        return ProgramMatchResult(
          status: ProgramMatchStatus.fallback,
          candidate: fallback,
          rankedCandidates: List.unmodifiable([fallback]),
          reasons: const ['configured_fallback'],
        );
      }
    }

    return const ProgramMatchResult(
      status: ProgramMatchStatus.noSupportedProgram,
      candidate: null,
      rankedCandidates: [],
      reasons: ['no_supported_program'],
    );
  }

  bool _isExactMatch(
    ProgramVersion version,
    UserTrainingPreferences preferences,
  ) =>
      _passesFallbackGate(version, preferences) &&
      _contains(version.goalKeys, preferences.goalKey);

  bool _passesFallbackGate(
    ProgramVersion version,
    UserTrainingPreferences preferences,
  ) =>
      version.status == ProgramLifecycleStatus.published &&
      version.guidedConfirmationAvailable &&
      _contains(version.populationKeys, preferences.populationKey) &&
      _contains(version.experienceKeys, preferences.experienceKey) &&
      version.cadence.supports(preferences.sessionsPerWeek) &&
      _hasRequiredEquipment(
        required: version.equipmentKeys,
        available: preferences.equipmentKeys,
      );

  ProgramMatchCandidate _rank(
    ProgramVersion version,
    UserTrainingPreferences preferences, {
    bool isFallback = false,
  }) {
    var score = version.matchingPriority * 1000;
    final reasons = <String>[
      'published',
      'population_match',
      'experience_match',
      'equipment_match',
    ];

    if (_contains(version.goalKeys, preferences.goalKey)) {
      score += 200;
      reasons.add('goal_match');
    } else if (isFallback) {
      reasons.add('goal_relaxed_for_fallback');
    }

    final audience = preferences.programAudiencePreference;
    if (version.audienceTags.contains(audience)) {
      score += 100;
      reasons.add('audience_exact');
    } else if (audience != ProgramAudiencePreference.unisex &&
        version.audienceTags.contains(ProgramAudiencePreference.unisex)) {
      score += 60;
      reasons.add('audience_unisex');
    } else {
      reasons.add('audience_not_preferred');
    }

    final requiredEquipment = _normalizedSet(version.equipmentKeys);
    final availableEquipment = _normalizedSet(preferences.equipmentKeys);
    if (_setsEqual(requiredEquipment, availableEquipment)) {
      score += 30;
      reasons.add('equipment_exact');
    } else {
      score += requiredEquipment.length * 5;
    }

    score += 40;
    reasons.add('cadence_exact');

    // Prefer a focused eligibility definition over a broad catch-all when all
    // user-facing criteria otherwise tie.
    if (version.populationKeys.length == 1) score += 3;
    if (version.goalKeys.length == 1) score += 2;
    if (version.experienceKeys.length == 1) score += 1;

    return ProgramMatchCandidate(
      version: version,
      score: score,
      reasons: List.unmodifiable(reasons),
    );
  }

  static int _compareCandidates(
    ProgramMatchCandidate left,
    ProgramMatchCandidate right,
  ) {
    final scoreOrder = right.score.compareTo(left.score);
    if (scoreOrder != 0) return scoreOrder;

    final leftPublished = left.version.publishedAt;
    final rightPublished = right.version.publishedAt;
    if (leftPublished != null && rightPublished != null) {
      final dateOrder = rightPublished.compareTo(leftPublished);
      if (dateOrder != 0) return dateOrder;
    } else if (leftPublished != null) {
      return -1;
    } else if (rightPublished != null) {
      return 1;
    }

    return left.version.id.compareTo(right.version.id);
  }

  static bool _contains(Iterable<String> values, String expected) {
    final normalizedExpected = _normalize(expected);
    return values.any((value) => _normalize(value) == normalizedExpected);
  }

  static bool _hasRequiredEquipment({
    required Iterable<String> required,
    required Iterable<String> available,
  }) {
    final requiredKeys = _normalizedSet(required);
    final availableKeys = _normalizedSet(available);
    return availableKeys.containsAll(requiredKeys);
  }

  static Set<String> _normalizedSet(Iterable<String> values) =>
      values.map(_normalize).where((value) => value.isNotEmpty).toSet();

  static String _normalize(String value) => value.trim().toLowerCase();

  static bool _setsEqual(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);
}
