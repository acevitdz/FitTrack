import 'dart:math' as math;

import '../models/exercise.dart';
import '../models/program.dart';
import 'generated/training_route_spec.g.dart';

/// Bundled fallback for the reviewed 32-route Firebase catalog.
///
/// The authored exercise/session rows are generated verbatim from
/// `docs/32_lo_trinh_tap_luyen_firebase_v2.md`. This builder expands each stable
/// route into immutable 2-, 3- and 4-day versions while keeping all exercise
/// IDs traceable to the reviewed Firebase exercise catalog.
abstract final class TrainingRouteCatalog {
  static const defaultProgramVersionId = 'KD-NAM-MOI-NHA-3D-v1';

  static const _acsmSource = SourceReference(
    id: 'source_acsm_rt_2026',
    title: 'ACSM 2026 Resistance Training Guidelines',
    publisher: 'American College of Sports Medicine',
    url: 'https://acsm.org/resistance-training-guidelines-update-2026/',
    publicationYear: 2026,
    notes: 'Khung kiểm duyệt cho nội dung kháng lực đã phát hành.',
  );

  static const _whoSource = SourceReference(
    id: 'source_who_physical_activity_2020',
    title: 'WHO Guidelines on Physical Activity and Sedentary Behaviour',
    publisher: 'World Health Organization',
    url: 'https://www.who.int/publications/i/item/9789240014886',
    publicationYear: 2020,
    notes: 'Khung hoạt động thể chất tổng quát, không phải chỉ định cá nhân.',
  );

  static const _exerciseCatalogSource = SourceReference(
    id: 'source_fittrack_firebase_exercises_2026_07_31',
    title: 'Danh mục bài tập FitTrack đã kiểm duyệt',
    publisher: 'FitTrack',
    url: 'https://fittrack-cse441-6c062.firebaseapp.com/',
    publicationYear: 2026,
    notes:
        'Danh sách bài tập đã được đối chiếu với 163 bài đang phát hành và hiển thị ngày 31/07/2026.',
  );

  static final List<_RouteSpec> _routes = _parseRouteSpecs();

  static final List<Program> programs = List.unmodifiable([
    for (final route in _routes)
      Program(
        id: route.code,
        title: '${route.goalLabel} · ${route.profileLabel}',
        description:
            '${route.goalLabel}; ${route.profileLabel.toLowerCase()}. '
            '${route.weeks} tuần, hỗ trợ 2, 3 hoặc 4 buổi mỗi tuần.',
        status: ProgramLifecycleStatus.published,
        createdBy: 'system_catalog_32_routes',
        createdAt: DateTime.utc(2026, 7, 31),
        updatedAt: DateTime.utc(2026, 7, 31),
        frequencyVariants: {
          for (final frequency in const [2, 3, 4])
            frequency: route.versionId(frequency),
        },
      ),
  ]);

  static final List<ProgramVersion> versions = List.unmodifiable([
    for (final route in _routes)
      for (final frequency in const [2, 3, 4]) _buildVersion(route, frequency),
  ]);

  static ProgramVersion _buildVersion(_RouteSpec route, int frequency) {
    final versionId = route.versionId(frequency);
    return ProgramVersion(
      id: versionId,
      programId: route.code,
      version: '1.0.0',
      status: ProgramLifecycleStatus.published,
      populationKeys: const ['healthy_adult_18_64'],
      audienceTags: [route.audience],
      goalKeys: [route.goalKey],
      experienceKeys: [route.experienceKey],
      equipmentKeys: route.isGym
          ? const ['bodyweight', 'gym']
          : const ['bodyweight'],
      environmentKey: route.environmentKey,
      cadence: TrainingCadence(
        sessionsPerWeek: frequency,
        supportedSessionsPerWeek: [frequency],
        preferredWeekdays: _weekdaysFor(frequency),
        minimumRestDays: frequency == 4 ? 0 : 1,
        weekdayOptions: {frequency: _weekdaysFor(frequency)},
      ),
      sourceRefs: const [_acsmSource, _whoSource, _exerciseCatalogSource],
      changelog:
          'v1: materialized from ${route.code} in the reviewed 32-route design; '
          '$frequency sessions/week.',
      safetyCopy:
          'Khởi động 5–8 phút và hạ nhịp 5 phút. Dừng buổi tập nếu đau sắc, '
          'đau ngực, chóng mặt, khó thở bất thường hoặc có triệu chứng đáng lo. '
          'FitTrack không thay thế đánh giá của bác sĩ hoặc huấn luyện viên.',
      accessibilityLabel:
          '${route.profileLabel}; $frequency buổi mỗi tuần; hướng dẫn bằng chữ '
          'và tự xác nhận có hướng dẫn đều dùng được cho mọi bài.',
      guidedConfirmationAvailable: true,
      matchingPriority: 32,
      weeks: [
        for (var week = 1; week <= route.weeks; week++)
          _buildWeek(route, frequency, week, versionId),
      ],
      createdBy: 'system_catalog_32_routes',
      createdAt: DateTime.utc(2026, 7, 31),
      publishedBy: 'system_catalog_32_routes',
      publishedAt: DateTime.utc(2026, 7, 31),
    );
  }

  static ({int sets, int minTarget, int maxTarget}) calculateDeload({
    required int sets,
    required int minTarget,
    required int maxTarget,
  }) {
    if (sets >= 3) {
      return (sets: sets - 1, minTarget: minTarget, maxTarget: maxTarget);
    }
    return (
      sets: sets,
      minTarget: math.max(1, (minTarget * 0.85).round()),
      maxTarget: math.max(1, (maxTarget * 0.85).round()),
    );
  }

  static int calculateWeek8SetReduction({
    required int sets,
    required int sessionsPerWeek,
  }) {
    final factor = sessionsPerWeek == 4 ? 0.70 : 0.75;
    return math.max(1, (sets * factor).round());
  }

  static ProgramWeek _buildWeek(
    _RouteSpec route,
    int frequency,
    int weekNumber,
    String versionId,
  ) {
    final weekId = '${versionId}_W$weekNumber';
    final templates = _sessionTemplatesFor(route, frequency, weekNumber);
    return ProgramWeek(
      id: weekId,
      programVersionId: versionId,
      weekNumber: weekNumber,
      title: _weekTitle(route, weekNumber),
      sessions: [
        for (var index = 0; index < templates.length; index++)
          _buildSession(
            route: route,
            template: templates[index],
            weekId: weekId,
            weekNumber: weekNumber,
            order: index,
            frequency: frequency,
          ),
      ],
    );
  }

  static ProgramSession _buildSession({
    required _RouteSpec route,
    required _SessionTemplate template,
    required String weekId,
    required int weekNumber,
    required int order,
    required int frequency,
  }) {
    final sessionId = '${weekId}_S${order + 1}';
    final progressed = [
      for (final prescription in template.prescriptions)
        _progressPrescription(
          prescription,
          route: route,
          weekNumber: weekNumber,
          keepLight: template.isLight,
          frequency: frequency,
        ),
    ];
    final baseBlocks = [
      _materializeBlock(
        sessionId: sessionId,
        idSuffix: 'ready',
        prescriptions: progressed,
        route: route,
      ),
    ];
    final reducedBlocks = [
      _materializeBlock(
        sessionId: sessionId,
        idSuffix: 'reduced',
        prescriptions: [
          for (final prescription in progressed)
            prescription.copyWith(
              sets: math.max(1, (prescription.sets * .7).round()),
            ),
        ],
        route: route,
      ),
    ];
    final recovery = _recoveryPrescription(progressed.first);
    final recoveryBlocks = [
      _materializeBlock(
        sessionId: sessionId,
        idSuffix: 'recovery',
        prescriptions: [recovery],
        route: route,
      ),
    ];

    return ProgramSession(
      id: sessionId,
      weekId: weekId,
      title: template.focus,
      order: order,
      minimumSessionsPerWeek: 1,
      estimatedDurationMinutes: _estimatedDuration(route, template),
      blocks: baseBlocks,
      readinessVariants: [
        ReadinessVariant(
          id: '${sessionId}_readiness_ready',
          sessionId: sessionId,
          choice: ReadinessChoice.ready,
          title: 'Sẵn sàng',
          guidance: _progressGuidance(route, weekNumber),
          blocks: baseBlocks,
        ),
        ReadinessVariant(
          id: '${sessionId}_readiness_reduce',
          sessionId: sessionId,
          choice: ReadinessChoice.reduceToday,
          title: 'Giảm nhẹ hôm nay',
          guidance:
              'Giảm khoảng 30% số hiệp, vẫn giữ nhịp và kỹ thuật kiểm soát.',
          blocks: reducedBlocks,
        ),
        ReadinessVariant(
          id: '${sessionId}_readiness_recovery',
          sessionId: sessionId,
          choice: ReadinessChoice.recovery,
          title: 'Phục hồi',
          guidance:
              'Thực hiện một bài quen thuộc ở mức nhẹ, trong biên độ thoải mái.',
          blocks: recoveryBlocks,
          safetyMessage:
              'Dừng tập nếu triệu chứng không cải thiện hoặc xuất hiện dấu hiệu đáng lo.',
        ),
      ],
    );
  }

  static ProgramBlock _materializeBlock({
    required String sessionId,
    required String idSuffix,
    required List<_PrescriptionSpec> prescriptions,
    required _RouteSpec route,
  }) => ProgramBlock(
    id: '${sessionId}_${idSuffix}_block',
    sessionId: sessionId,
    type: ProgramBlockType.main,
    order: 0,
    prescriptions: [
      for (var index = 0; index < prescriptions.length; index++)
        _materializePrescription(
          id: '${sessionId}_${idSuffix}_P${index + 1}',
          order: index,
          spec: prescriptions[index],
          route: route,
        ),
    ],
  );

  static ExercisePrescription _materializePrescription({
    required String id,
    required int order,
    required _PrescriptionSpec spec,
    required _RouteSpec route,
  }) {
    final restSeconds = switch (route.goalKey) {
      TrainingGoalKey.fatLoss => 45,
      TrainingGoalKey.muscleGain => 75,
      TrainingGoalKey.strength => (order <= 1 ? 150 : 75),
      _ => 45,
    };
    return ExercisePrescription(
      id: id,
      exerciseId: spec.exerciseId,
      exerciseName: spec.name,
      order: order,
      sets: spec.sets,
      targetType: spec.targetType,
      targetRange: PrescriptionTargetRange(
        minimum: spec.minimum,
        maximum: spec.maximum,
      ),
      restSeconds: restSeconds,
      transitionAfterExerciseSeconds: math.min(restSeconds, 90),
      cues: [
        'Thực hiện ${spec.name} với nhịp kiểm soát và đúng kỹ thuật.',
        if (spec.perSide) 'Hoàn thành đủ mục tiêu cho từng bên.',
      ],
      alternativeExerciseIds: const [],
      prescriptionVersion: '32-routes-v2',
      mediaVersion: 'firebase-exercise-catalog-2026-07-31',
      cueVersion: 'vi-v2',
      poseRuleVersionId: spec.exerciseId == 'squat' ? 'squat_pose_v1' : null,
      cameraTargetReps: _cameraTargetReps(spec),
      perSide: spec.perSide,
      executionMode: spec.targetType == PrescriptionTargetType.durationSeconds
          ? ExerciseExecutionMode.timer
          : ExerciseExecutionMode.repetition,
      cueMode: spec.targetType == PrescriptionTargetType.durationSeconds
          ? ExerciseCueMode.countdown
          : ExerciseCueMode.voice,
      tempoUp: spec.targetType == PrescriptionTargetType.repetitions ? 2 : null,
      tempoHold: spec.targetType == PrescriptionTargetType.repetitions
          ? 1
          : null,
      tempoDown: spec.targetType == PrescriptionTargetType.repetitions
          ? 2
          : null,
    );
  }

  static int? _cameraTargetReps(_PrescriptionSpec spec) {
    if (spec.exerciseId != 'squat' ||
        spec.targetType != PrescriptionTargetType.durationSeconds) {
      return null;
    }
    return spec.cameraTargetReps ??
        math.min(50, math.max(1, (spec.minimum / 3).round()));
  }

  static List<_SessionTemplate> _sessionTemplatesFor(
    _RouteSpec route,
    int frequency,
    int weekNumber,
  ) {
    final bank = route.sessions;
    if (frequency == 2) {
      final secondRight = route.isBeginner ? bank[2] : bank[3];
      return [
        _combineSessions('FB1', bank[0], bank[1]),
        _combineSessions(
          'FB2',
          route.isBeginner ? bank[1] : bank[2],
          secondRight,
        ),
      ];
    }
    if (frequency == 3) {
      if (route.isBeginner) {
        return [
          for (final session in bank.take(3))
            _SessionTemplate.fromSpec(session),
        ];
      }
      final start = ((weekNumber - 1) * 3) % 4;
      return [
        for (var offset = 0; offset < 3; offset++)
          _SessionTemplate.fromSpec(bank[(start + offset) % 4]),
      ];
    }
    return [
      for (final session in bank) _SessionTemplate.fromSpec(session),
      if (route.isBeginner) _lightSession(route),
    ];
  }

  static _SessionTemplate _combineSessions(
    String label,
    _SessionSpec left,
    _SessionSpec right,
  ) => _SessionTemplate(
    label: label,
    focus: '${left.focus} + ${right.focus}',
    prescriptions: [
      ...left.prescriptions.take(3),
      ...right.prescriptions.take(3),
    ],
  );

  static _SessionTemplate _lightSession(_RouteSpec route) {
    final a = route.sessions[0];
    final b = route.sessions[1];
    final c = route.sessions[2];
    final selected = switch (route.goalKey) {
      TrainingGoalKey.strength => [
        a.prescriptions.first,
        b.prescriptions.first,
        c.prescriptions.first,
      ],
      TrainingGoalKey.muscleGain => [
        a.prescriptions.first,
        a.prescriptions[1],
        b.prescriptions.first,
        c.prescriptions.first,
      ],
      TrainingGoalKey.fatLoss => [
        a.prescriptions.first,
        a.prescriptions[1],
        b.prescriptions.first,
        _conditioningPrescription(route),
      ],
      _ => [
        a.prescriptions.first,
        b.prescriptions.first,
        c.prescriptions.first,
        _conditioningPrescription(route),
      ],
    };
    return _SessionTemplate(
      label: 'LIGHT-${route.code.substring(0, 2)}',
      focus: 'Phục hồi nhẹ',
      isLight: true,
      prescriptions: [
        for (final item in selected)
          if (route.goalKey == TrainingGoalKey.strength)
            item.copyWith(sets: 2)
          else if (item.targetType == PrescriptionTargetType.durationSeconds &&
              (route.goalKey == TrainingGoalKey.fatLoss ||
                  route.goalKey == TrainingGoalKey.generalFitness))
            item.copyWith(sets: 1, minimum: 600, maximum: 900)
          else
            item.copyWith(sets: 2),
      ],
    );
  }

  static _PrescriptionSpec _conditioningPrescription(_RouteSpec route) {
    final all = [
      for (final session in route.sessions) ...session.prescriptions,
    ];
    for (final prescription in all.reversed) {
      if (prescription.targetType == PrescriptionTargetType.durationSeconds) {
        return prescription;
      }
    }
    return all.last;
  }

  static _PrescriptionSpec _progressPrescription(
    _PrescriptionSpec source, {
    required _RouteSpec route,
    required int weekNumber,
    required bool keepLight,
    int frequency = 3,
  }) {
    if (route.isBeginner) {
      var result = source;
      if (weekNumber <= 2 && !keepLight) {
        result = result.copyWith(sets: math.min(result.sets, 2));
      }
      if (weekNumber >= 5) {
        final increment =
            result.targetType == PrescriptionTargetType.durationSeconds ? 5 : 1;
        result = result.copyWith(
          minimum: result.minimum + increment,
          maximum: result.maximum + increment,
        );
      }
      return result;
    }

    if (weekNumber == 4) {
      final deload = calculateDeload(
        sets: source.sets,
        minTarget: source.minimum,
        maxTarget: source.maximum,
      );
      return source.copyWith(
        sets: deload.sets,
        minimum: deload.minTarget,
        maximum: deload.maxTarget,
      );
    }

    if (weekNumber == 8) {
      final newSets = calculateWeek8SetReduction(
        sets: source.sets,
        sessionsPerWeek: frequency,
      );
      return source.copyWith(sets: newSets);
    }

    if (weekNumber >= 5 && weekNumber <= 7) {
      final increment =
          source.targetType == PrescriptionTargetType.durationSeconds ? 5 : 1;
      return source.copyWith(
        minimum: source.minimum + increment,
        maximum: source.maximum + increment,
      );
    }
    return source;
  }

  static _PrescriptionSpec _recoveryPrescription(_PrescriptionSpec source) {
    if (source.targetType == PrescriptionTargetType.durationSeconds) {
      final duration = math.min(source.minimum, 300);
      return source.copyWith(
        sets: 1,
        minimum: math.max(30, duration),
        maximum: math.max(30, duration),
      );
    }
    final repetitions = math.min(source.minimum, 8);
    return source.copyWith(
      sets: 1,
      minimum: math.max(3, repetitions),
      maximum: math.max(3, repetitions),
    );
  }

  static int _estimatedDuration(_RouteSpec route, _SessionTemplate template) {
    if (template.isLight) {
      return route.goalKey == TrainingGoalKey.generalFitness ? 25 : 30;
    }
    final midpoint = (route.minimumMinutes + route.maximumMinutes) ~/ 2;
    if (template.label.startsWith('FB')) {
      return math.min(route.maximumMinutes + 10, 90);
    }
    return midpoint;
  }

  static String _weekTitle(_RouteSpec route, int weekNumber) {
    if (route.isBeginner) {
      if (weekNumber <= 2) return 'Tuần $weekNumber · Học kỹ thuật (2 hiệp)';
      if (weekNumber <= 4) return 'Tuần $weekNumber · Khối lượng chuẩn';
      return 'Tuần $weekNumber · Tăng nhẹ số lần hoặc thời gian';
    }
    if (weekNumber == 4) return 'Tuần 4 · Giảm tải 30% số hiệp';
    if (weekNumber == 8) return 'Tuần 8 · Giảm tải và đánh giá kỹ thuật';
    if (weekNumber >= 5) return 'Tuần $weekNumber · Tiến triển có kiểm soát';
    return 'Tuần $weekNumber · Khối lượng chuẩn';
  }

  static String _progressGuidance(_RouteSpec route, int weekNumber) {
    if (route.isBeginner && weekNumber <= 2) {
      return 'Dùng 2 hiệp mỗi bài, ưu tiên học kỹ thuật và duy trì đều đặn.';
    }
    if (route.isBeginner && weekNumber >= 5) {
      return 'Tăng nhẹ 1–2 lần hoặc 5–10 giây khi vẫn giữ đúng kỹ thuật.';
    }
    if (!route.isBeginner && (weekNumber == 4 || weekNumber == 8)) {
      return 'Tuần giảm tải: giảm khoảng 30% số hiệp và đánh giá kỹ thuật.';
    }
    if (!route.isBeginner && weekNumber >= 5) {
      return 'Tăng có kiểm soát; không thử mức tối đa và dừng khi mất kỹ thuật.';
    }
    return 'Thực hiện đúng khối lượng đã phát hành của buổi tập.';
  }

  static List<int> _weekdaysFor(int frequency) => switch (frequency) {
    2 => const [DateTime.monday, DateTime.thursday],
    3 => const [DateTime.monday, DateTime.wednesday, DateTime.friday],
    4 => const [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.thursday,
      DateTime.saturday,
    ],
    _ => throw ArgumentError.value(frequency, 'frequency'),
  };

  static List<_RouteSpec> _parseRouteSpecs() {
    final routes = <_RouteSpec>[];
    _MutableRouteSpec? current;
    final headingPattern = RegExp(r'^### \d{2}\. ([A-Z-]+) — ');
    final durationPattern = RegExp(
      r'^\*\*Thời lượng:\*\* (\d+) tuần .*'
      r'\*\*Mỗi buổi:\*\* (\d+)–(\d+) phút',
    );

    for (final rawLine in trainingRouteMarkdownSpec.split('\n')) {
      final line = rawLine.trim();
      final heading = headingPattern.firstMatch(line);
      if (heading != null) {
        if (current != null) routes.add(current.build());
        current = _MutableRouteSpec(heading.group(1)!);
        continue;
      }
      final duration = durationPattern.firstMatch(line);
      if (duration != null) {
        if (current == null) {
          throw const FormatException('Duration before route');
        }
        current
          ..weeks = int.parse(duration.group(1)!)
          ..minimumMinutes = int.parse(duration.group(2)!)
          ..maximumMinutes = int.parse(duration.group(3)!);
        continue;
      }
      if (RegExp(r'^\| [ABCD] \|').hasMatch(line)) {
        if (current == null) {
          throw const FormatException('Session before route');
        }
        final columns = line.split('|').map((item) => item.trim()).toList();
        current.sessions.add(
          _SessionSpec(
            label: columns[1],
            focus: columns[2],
            prescriptions: [
              for (final item in columns[3].split('; '))
                _parsePrescription(item),
            ],
          ),
        );
      }
    }
    if (current != null) routes.add(current.build());

    if (routes.length != 32) {
      throw StateError(
        'Catalog must contain 32 routes, found ${routes.length}',
      );
    }
    for (final route in routes) {
      final expectedSessions = route.isBeginner ? 3 : 4;
      if (route.sessions.length != expectedSessions) {
        throw StateError(
          '${route.code} must contain $expectedSessions authored sessions',
        );
      }
    }
    return List.unmodifiable(routes);
  }

  static _PrescriptionSpec _parsePrescription(String source) {
    final match = RegExp(r'^(.+?) \[`([^`]+)`\] (.+)$').firstMatch(source);
    if (match == null) {
      throw FormatException('Invalid exercise prescription: $source');
    }
    final name = match.group(1)!;
    final exerciseId = match.group(2)!;
    final target = match.group(3)!;
    final minutes = RegExp(r'^(\d+) phút$').firstMatch(target);
    if (minutes != null) {
      final seconds = int.parse(minutes.group(1)!) * 60;
      return _PrescriptionSpec(
        name: name,
        exerciseId: exerciseId,
        sets: 1,
        targetType: PrescriptionTargetType.durationSeconds,
        minimum: seconds,
        maximum: seconds,
      );
    }
    final timedWithLegacyRepCap = RegExp(
      r'^(\d+)×(\d+) giây–(\d+)(\/bên)?$',
    ).firstMatch(target);
    if (timedWithLegacyRepCap != null) {
      final seconds = int.parse(timedWithLegacyRepCap.group(2)!);
      return _PrescriptionSpec(
        name: name,
        exerciseId: exerciseId,
        sets: int.parse(timedWithLegacyRepCap.group(1)!),
        targetType: PrescriptionTargetType.durationSeconds,
        minimum: seconds,
        maximum: seconds,
        cameraTargetReps: int.parse(timedWithLegacyRepCap.group(3)!),
        perSide: timedWithLegacyRepCap.group(4) != null,
      );
    }
    final setsAndTarget = RegExp(
      r'^(\d+)×(\d+)(?:–(\d+))?(?: (giây))?(\/bên)?$',
    ).firstMatch(target);
    if (setsAndTarget == null) {
      throw FormatException('Invalid target "$target" for $exerciseId');
    }
    return _PrescriptionSpec(
      name: name,
      exerciseId: exerciseId,
      sets: int.parse(setsAndTarget.group(1)!),
      targetType: setsAndTarget.group(4) == null
          ? PrescriptionTargetType.repetitions
          : PrescriptionTargetType.durationSeconds,
      minimum: int.parse(setsAndTarget.group(2)!),
      maximum: int.parse(setsAndTarget.group(3) ?? setsAndTarget.group(2)!),
      perSide: setsAndTarget.group(5) != null,
    );
  }
}

class _MutableRouteSpec {
  _MutableRouteSpec(this.code);

  final String code;
  int? weeks;
  int? minimumMinutes;
  int? maximumMinutes;
  final List<_SessionSpec> sessions = [];

  _RouteSpec build() {
    final parts = code.split('-');
    if (parts.length != 4 ||
        weeks == null ||
        minimumMinutes == null ||
        maximumMinutes == null) {
      throw FormatException('Incomplete route: $code');
    }
    return _RouteSpec(
      code: code,
      goalKey: switch (parts[0]) {
        'GM' => TrainingGoalKey.fatLoss,
        'TC' => TrainingGoalKey.muscleGain,
        'SM' => TrainingGoalKey.strength,
        'KD' => TrainingGoalKey.generalFitness,
        _ => throw FormatException('Unknown goal in $code'),
      },
      audience: switch (parts[1]) {
        'NAM' => ProgramAudiencePreference.male,
        'NU' => ProgramAudiencePreference.female,
        _ => throw FormatException('Unknown audience in $code'),
      },
      experienceKey: switch (parts[2]) {
        'MOI' => 'beginner',
        'DATAP' => 'intermediate',
        _ => throw FormatException('Unknown experience in $code'),
      },
      environmentKey: switch (parts[3]) {
        'NHA' => 'home',
        'GYM' => 'gym',
        _ => throw FormatException('Unknown environment in $code'),
      },
      weeks: weeks!,
      minimumMinutes: minimumMinutes!,
      maximumMinutes: maximumMinutes!,
      sessions: List.unmodifiable(sessions),
    );
  }
}

class _RouteSpec {
  const _RouteSpec({
    required this.code,
    required this.goalKey,
    required this.audience,
    required this.experienceKey,
    required this.environmentKey,
    required this.weeks,
    required this.minimumMinutes,
    required this.maximumMinutes,
    required this.sessions,
  });

  final String code;
  final String goalKey;
  final ProgramAudiencePreference audience;
  final String experienceKey;
  final String environmentKey;
  final int weeks;
  final int minimumMinutes;
  final int maximumMinutes;
  final List<_SessionSpec> sessions;

  bool get isBeginner => experienceKey == 'beginner';
  bool get isGym => environmentKey == 'gym';
  String get goalLabel => TrainingGoalKey.labelFor(goalKey);
  String get profileLabel =>
      '${audience == ProgramAudiencePreference.male ? 'Nam' : 'Nữ'} · '
      '${isBeginner ? 'Mới bắt đầu' : 'Đã tập'} · '
      '${isGym ? 'Phòng tập' : 'Tại nhà'}';

  String versionId(int frequency) => '$code-${frequency}D-v1';
}

class _SessionSpec {
  const _SessionSpec({
    required this.label,
    required this.focus,
    required this.prescriptions,
  });

  final String label;
  final String focus;
  final List<_PrescriptionSpec> prescriptions;
}

class _SessionTemplate {
  const _SessionTemplate({
    required this.label,
    required this.focus,
    required this.prescriptions,
    this.isLight = false,
  });

  factory _SessionTemplate.fromSpec(_SessionSpec source) => _SessionTemplate(
    label: source.label,
    focus: source.focus,
    prescriptions: source.prescriptions,
  );

  final String label;
  final String focus;
  final List<_PrescriptionSpec> prescriptions;
  final bool isLight;
}

class _PrescriptionSpec {
  const _PrescriptionSpec({
    required this.name,
    required this.exerciseId,
    required this.sets,
    required this.targetType,
    required this.minimum,
    required this.maximum,
    this.cameraTargetReps,
    this.perSide = false,
  });

  final String name;
  final String exerciseId;
  final int sets;
  final PrescriptionTargetType targetType;
  final int minimum;
  final int maximum;
  final int? cameraTargetReps;
  final bool perSide;

  _PrescriptionSpec copyWith({
    int? sets,
    PrescriptionTargetType? targetType,
    int? minimum,
    int? maximum,
    int? cameraTargetReps,
  }) => _PrescriptionSpec(
    name: name,
    exerciseId: exerciseId,
    sets: sets ?? this.sets,
    targetType: targetType ?? this.targetType,
    minimum: minimum ?? this.minimum,
    maximum: maximum ?? this.maximum,
    cameraTargetReps: cameraTargetReps ?? this.cameraTargetReps,
    perSide: perSide,
  );
}
