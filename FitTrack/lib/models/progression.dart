import 'program.dart';

enum ProgressionDecisionKind { increase, hold, regress, safetyHold, deload }

class ProgressionTarget {
  const ProgressionTarget({
    required this.sets,
    required this.targetType,
    required this.minimum,
    required this.maximum,
  }) : assert(sets > 0),
       assert(minimum > 0),
       assert(maximum >= minimum);

  final int sets;
  final PrescriptionTargetType targetType;
  final int minimum;
  final int maximum;

  Map<String, dynamic> toJson() => {
    'sets': sets,
    'targetType': targetType.name,
    'minimum': minimum,
    'maximum': maximum,
  };

  factory ProgressionTarget.fromJson(Map<String, dynamic> json) =>
      ProgressionTarget(
        sets: (json['sets'] as num).toInt(),
        targetType: PrescriptionTargetType.values.byName(
          json['targetType'] as String,
        ),
        minimum: (json['minimum'] as num).toInt(),
        maximum: (json['maximum'] as num).toInt(),
      );
}

class ProgressionDecision {
  ProgressionDecision({
    required this.id,
    required this.policyVersion,
    required this.enrollmentId,
    required this.programVersionId,
    required this.prescriptionId,
    required this.progressionKey,
    required this.sourceWeek,
    required this.targetWeek,
    required this.kind,
    required this.previousTarget,
    required this.nextTarget,
    required List<String> reasonCodes,
    required this.createdAt,
    this.adherenceRate,
    this.changedVariable,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  final String id;
  final String policyVersion;
  final String enrollmentId;
  final String programVersionId;
  final String prescriptionId;
  final String progressionKey;
  final int sourceWeek;
  final int targetWeek;
  final ProgressionDecisionKind kind;
  final double? adherenceRate;
  final ProgressionTarget previousTarget;
  final ProgressionTarget nextTarget;
  final String? changedVariable;
  final List<String> reasonCodes;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'idempotencyKey': id,
    'policyVersion': policyVersion,
    'enrollmentId': enrollmentId,
    'programVersionId': programVersionId,
    'prescriptionId': prescriptionId,
    'progressionKey': progressionKey,
    'sourceWeek': sourceWeek,
    'targetWeek': targetWeek,
    'decision': kind.name,
    'completionRate': adherenceRate,
    'previousTarget': previousTarget.toJson(),
    'nextTarget': nextTarget.toJson(),
    'changedVariable': changedVariable,
    'reasonCodes': reasonCodes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ProgressionDecision.fromJson(
    Map<String, dynamic> json,
  ) => ProgressionDecision(
    id: (json['id'] ?? json['idempotencyKey']) as String,
    policyVersion: json['policyVersion'] as String? ?? 'progression_v1',
    enrollmentId: json['enrollmentId'] as String,
    programVersionId: json['programVersionId'] as String,
    prescriptionId:
        json['prescriptionId'] as String? ?? json['progressionKey'] as String,
    progressionKey: json['progressionKey'] as String,
    sourceWeek: (json['sourceWeek'] as num).toInt(),
    targetWeek: (json['targetWeek'] as num).toInt(),
    kind: ProgressionDecisionKind.values.byName(json['decision'] as String),
    adherenceRate:
        (json['completionRate'] as num? ?? json['adherenceRate'] as num?)
            ?.toDouble(),
    previousTarget: ProgressionTarget.fromJson(
      Map<String, dynamic>.from(json['previousTarget'] as Map),
    ),
    nextTarget: ProgressionTarget.fromJson(
      Map<String, dynamic>.from(json['nextTarget'] as Map),
    ),
    changedVariable: json['changedVariable'] as String?,
    reasonCodes: List<String>.from(json['reasonCodes'] as List? ?? const []),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
