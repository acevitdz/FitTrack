import '../models/program.dart';

/// Small, traceable catalog used until the Firebase catalog is loaded.
///
/// These are authored snapshots, not generated prescriptions. Enrollment code
/// should always pin one of the version IDs below.
abstract final class ProgramSeedData {
  static const defaultFallbackProgramVersionId =
      'program_bodyweight_foundation_v1';

  static const acsmSource = SourceReference(
    id: 'source_acsm_rt_2026',
    title: 'ACSM 2026 Resistance Training Guidelines',
    publisher: 'American College of Sports Medicine',
    url: 'https://acsm.org/resistance-training-guidelines-update-2026/',
    publicationYear: 2026,
    notes: 'Guardrail for published resistance-training content.',
  );

  static const whoSource = SourceReference(
    id: 'source_who_physical_activity_2020',
    title: 'WHO Guidelines on Physical Activity and Sedentary Behaviour',
    publisher: 'World Health Organization',
    url: 'https://www.who.int/publications/i/item/9789240015128',
    publicationYear: 2020,
    notes:
        'General physical-activity guardrail; not an individual prescription.',
  );

  static final programs = <Program>[
    Program(
      id: 'program_bodyweight_foundation',
      title: 'Nền tảng vận động tại nhà',
      description:
          'Chương trình hai tuần giúp người mới xây dựng thói quen với các '
          'bài toàn thân không cần dụng cụ.',
      status: ProgramLifecycleStatus.published,
      createdBy: 'system_seed',
      createdAt: DateTime.utc(2026, 7, 20),
      updatedAt: DateTime.utc(2026, 7, 24),
    ),
    Program(
      id: 'program_gym_strength_foundation',
      title: 'Nền tảng sức mạnh tại phòng tập',
      description:
          'Chương trình hai tuần làm quen với các mẫu chuyển động sức mạnh '
          'cơ bản tại phòng tập.',
      status: ProgramLifecycleStatus.published,
      createdBy: 'system_seed',
      createdAt: DateTime.utc(2026, 7, 20),
      updatedAt: DateTime.utc(2026, 7, 24),
    ),
  ];

  static final versions = <ProgramVersion>[
    _bodyweightFoundation(),
    _gymStrengthFoundation(),
  ];

  static ProgramVersion _bodyweightFoundation() {
    const versionId = 'program_bodyweight_foundation_v1';
    return ProgramVersion(
      id: versionId,
      programId: 'program_bodyweight_foundation',
      version: '1.0.0',
      status: ProgramLifecycleStatus.published,
      populationKeys: const ['healthy_adult_18_64'],
      audienceTags: const [ProgramAudiencePreference.unisex],
      goalKeys: const [
        TrainingGoalKey.generalFitness,
        TrainingGoalKey.fatLoss,
        TrainingGoalKey.flexibility,
      ],
      experienceKeys: const ['beginner'],
      equipmentKeys: const ['bodyweight'],
      cadence: const TrainingCadence(
        sessionsPerWeek: 3,
        preferredWeekdays: [
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        ],
        minimumRestDays: 1,
      ),
      sourceRefs: const [acsmSource, whoSource],
      changelog: 'Phát hành đầu tiên: hai tuần, ba buổi mỗi tuần.',
      safetyCopy:
          'Dừng tập nếu đau ngực, chóng mặt, khó thở bất thường hoặc đau sắc. '
          'FitTrack không thay thế tư vấn y tế.',
      accessibilityLabel:
          'Chương trình tại nhà; mọi bài có cue dạng chữ và Guided Confirmation.',
      guidedConfirmationAvailable: true,
      matchingPriority: 10,
      weeks: _materializeWeeks(
        versionId: versionId,
        recoveryExerciseId: 'glute_bridge',
        templates: _bodyweightWeeks,
      ),
      createdBy: 'system_seed',
      createdAt: DateTime.utc(2026, 7, 20),
      publishedBy: 'system_seed',
      publishedAt: DateTime.utc(2026, 7, 24, 1),
    );
  }

  static ProgramVersion _gymStrengthFoundation() {
    const versionId = 'program_gym_strength_foundation_v1';
    return ProgramVersion(
      id: versionId,
      programId: 'program_gym_strength_foundation',
      version: '1.0.0',
      status: ProgramLifecycleStatus.published,
      populationKeys: const ['healthy_adult_18_64'],
      audienceTags: const [
        ProgramAudiencePreference.unisex,
        ProgramAudiencePreference.male,
        ProgramAudiencePreference.female,
      ],
      goalKeys: const [TrainingGoalKey.strength],
      experienceKeys: const ['beginner', 'intermediate'],
      equipmentKeys: const ['gym'],
      cadence: const TrainingCadence(
        sessionsPerWeek: 3,
        preferredWeekdays: [
          DateTime.monday,
          DateTime.wednesday,
          DateTime.friday,
        ],
        minimumRestDays: 1,
      ),
      sourceRefs: const [acsmSource, whoSource],
      changelog:
          'Phát hành đầu tiên: kỹ thuật nền tảng và tiến triển tuần hai.',
      safetyCopy:
          'Chọn thiết bị có thể điều khiển an toàn và dừng tập khi có dấu hiệu '
          'bất thường. FitTrack không thay thế chuyên gia y tế.',
      accessibilityLabel:
          'Chương trình phòng tập; cue dạng chữ, mô tả media và Guided '
          'Confirmation luôn khả dụng.',
      guidedConfirmationAvailable: true,
      matchingPriority: 20,
      weeks: _materializeWeeks(
        versionId: versionId,
        recoveryExerciseId: 'glute_bridge',
        templates: _gymWeeks,
      ),
      createdBy: 'system_seed',
      createdAt: DateTime.utc(2026, 7, 20),
      publishedBy: 'system_seed',
      publishedAt: DateTime.utc(2026, 7, 24, 2),
    );
  }

  static List<ProgramWeek> _materializeWeeks({
    required String versionId,
    required String recoveryExerciseId,
    required List<_WeekTemplate> templates,
  }) => [
    for (final weekTemplate in templates)
      _materializeWeek(
        versionId: versionId,
        recoveryExerciseId: recoveryExerciseId,
        template: weekTemplate,
      ),
  ];

  static ProgramWeek _materializeWeek({
    required String versionId,
    required String recoveryExerciseId,
    required _WeekTemplate template,
  }) {
    final weekId = '${versionId}_week_${template.number}';
    return ProgramWeek(
      id: weekId,
      programVersionId: versionId,
      weekNumber: template.number,
      title: template.title,
      sessions: [
        for (var index = 0; index < template.sessions.length; index++)
          _materializeSession(
            weekId: weekId,
            order: index,
            recoveryExerciseId: recoveryExerciseId,
            template: template.sessions[index],
          ),
      ],
    );
  }

  static ProgramSession _materializeSession({
    required String weekId,
    required int order,
    required String recoveryExerciseId,
    required _SessionTemplate template,
  }) {
    final sessionId = '${weekId}_session_${order + 1}';
    final baseBlocks = _materializeBlocks(
      sessionId: sessionId,
      templates: template.blocks,
      idSuffix: 'ready',
    );
    final reducedBlocks = _materializeBlocks(
      sessionId: sessionId,
      templates: template.blocks,
      idSuffix: 'reduced',
      reduceSets: true,
    );
    final recoveryBlocks = _materializeBlocks(
      sessionId: sessionId,
      templates: [
        _BlockTemplate(
          type: ProgramBlockType.main,
          prescriptions: [
            _PrescriptionTemplate(
              exerciseId: recoveryExerciseId,
              sets: 2,
              targetType: PrescriptionTargetType.repetitions,
              minimum: 8,
              maximum: 10,
              restSeconds: 45,
              cues: const [
                'Di chuyển chậm trong biên độ thoải mái.',
                'Dừng lại nếu xuất hiện đau sắc.',
              ],
            ),
            const _PrescriptionTemplate(
              exerciseId: 'plank',
              sets: 2,
              targetType: PrescriptionTargetType.durationSeconds,
              minimum: 15,
              maximum: 20,
              restSeconds: 45,
              cues: ['Thở đều và chỉ giữ trong mức thoải mái.'],
            ),
          ],
        ),
      ],
      idSuffix: 'recovery',
    );

    return ProgramSession(
      id: sessionId,
      weekId: weekId,
      title: template.title,
      order: order,
      estimatedDurationMinutes: template.estimatedDurationMinutes,
      blocks: baseBlocks,
      readinessVariants: [
        ReadinessVariant(
          id: '${sessionId}_readiness_ready',
          sessionId: sessionId,
          choice: ReadinessChoice.ready,
          title: 'Sẵn sàng',
          guidance: 'Thực hiện đúng prescription của buổi tập.',
          blocks: baseBlocks,
        ),
        ReadinessVariant(
          id: '${sessionId}_readiness_reduce',
          sessionId: sessionId,
          choice: ReadinessChoice.reduceToday,
          title: 'Giảm nhẹ hôm nay',
          guidance: 'Dùng biến thể ít set hơn đã được cấu hình sẵn.',
          blocks: reducedBlocks,
        ),
        ReadinessVariant(
          id: '${sessionId}_readiness_recovery',
          sessionId: sessionId,
          choice: ReadinessChoice.recovery,
          title: 'Phục hồi',
          guidance: 'Chuyển sang vận động nhẹ và kiểm soát.',
          blocks: recoveryBlocks,
          safetyMessage: 'Dừng tập nếu triệu chứng không cải thiện.',
        ),
      ],
    );
  }

  static List<ProgramBlock> _materializeBlocks({
    required String sessionId,
    required List<_BlockTemplate> templates,
    required String idSuffix,
    bool reduceSets = false,
  }) => [
    for (var blockIndex = 0; blockIndex < templates.length; blockIndex++)
      ProgramBlock(
        id: '${sessionId}_${idSuffix}_block_${blockIndex + 1}',
        sessionId: sessionId,
        type: templates[blockIndex].type,
        order: blockIndex,
        prescriptions: [
          for (
            var exerciseIndex = 0;
            exerciseIndex < templates[blockIndex].prescriptions.length;
            exerciseIndex++
          )
            _materializePrescription(
              id: '${sessionId}_${idSuffix}_p_${blockIndex + 1}_${exerciseIndex + 1}',
              order: exerciseIndex,
              template: templates[blockIndex].prescriptions[exerciseIndex],
              reduceSets: reduceSets,
            ),
        ],
      ),
  ];

  static ExercisePrescription _materializePrescription({
    required String id,
    required int order,
    required _PrescriptionTemplate template,
    required bool reduceSets,
  }) => ExercisePrescription(
    id: id,
    exerciseId: template.exerciseId,
    order: order,
    sets: reduceSets && template.sets > 1 ? template.sets - 1 : template.sets,
    targetType: template.targetType,
    targetRange: PrescriptionTargetRange(
      minimum: template.minimum,
      maximum: template.maximum,
    ),
    restSeconds: template.restSeconds,
    cues: template.cues,
    alternativeExerciseIds: template.alternatives,
    prescriptionVersion: '1',
    mediaVersion: 'seed_media_v1',
    cueVersion: 'seed_cue_v1',
    poseRuleVersionId: template.poseRuleVersionId,
  );

  static const _bodyweightWeeks = <_WeekTemplate>[
    _WeekTemplate(
      number: 1,
      title: 'Tuần 1 · Làm quen kỹ thuật',
      sessions: [
        _SessionTemplate(
          title: 'Toàn thân A',
          estimatedDurationMinutes: 30,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.warmUp,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'mountain_climber',
                  sets: 1,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 20,
                  maximum: 30,
                  restSeconds: 20,
                  cues: ['Giữ nhịp vừa phải để làm nóng cơ thể.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'squat',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 60,
                  cues: ['Đẩy hông về sau.', 'Giữ gối theo hướng mũi chân.'],
                  alternatives: ['glute_bridge'],
                  poseRuleVersionId: 'squat_pose_v1',
                ),
                _PrescriptionTemplate(
                  exerciseId: 'push_up',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 6,
                  maximum: 10,
                  restSeconds: 60,
                  cues: ['Giữ thân người thành một đường thẳng.'],
                  poseRuleVersionId: 'push_up_pose_v1',
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'plank',
                  sets: 2,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 20,
                  maximum: 30,
                  restSeconds: 45,
                  cues: ['Siết bụng và thở đều.'],
                  poseRuleVersionId: 'plank_pose_v1',
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Chân và thân giữa',
          estimatedDurationMinutes: 28,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'lunges',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 60,
                  cues: ['Bước đủ dài và giữ thăng bằng.'],
                  alternatives: ['squat'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'glute_bridge',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 45,
                  cues: ['Siết mông ở vị trí cao nhất.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'crunch',
                  sets: 2,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 45,
                  cues: ['Nâng vai có kiểm soát, không kéo cổ.'],
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Toàn thân B',
          estimatedDurationMinutes: 32,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'squat',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Kiểm soát cả nhịp xuống và đứng lên.'],
                  poseRuleVersionId: 'squat_pose_v1',
                ),
                _PrescriptionTemplate(
                  exerciseId: 'push_up',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 6,
                  maximum: 10,
                  restSeconds: 60,
                  cues: ['Hạ ngực có kiểm soát.'],
                  poseRuleVersionId: 'push_up_pose_v1',
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.conditioning,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'mountain_climber',
                  sets: 3,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 20,
                  maximum: 30,
                  restSeconds: 45,
                  cues: ['Giữ hông ổn định.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.coolDown,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'glute_bridge',
                  sets: 1,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 8,
                  restSeconds: 0,
                  cues: ['Di chuyển chậm và thở đều.'],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _WeekTemplate(
      number: 2,
      title: 'Tuần 2 · Củng cố kiểm soát',
      sessions: [
        _SessionTemplate(
          title: 'Toàn thân A+',
          estimatedDurationMinutes: 34,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'squat',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Giữ nhịp ổn định qua mọi lần lặp.'],
                  poseRuleVersionId: 'squat_pose_v1',
                ),
                _PrescriptionTemplate(
                  exerciseId: 'push_up',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Siết bụng để giữ thân người ổn định.'],
                  poseRuleVersionId: 'push_up_pose_v1',
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'plank',
                  sets: 3,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 25,
                  maximum: 35,
                  restSeconds: 45,
                  cues: ['Thở đều, không nâng hông quá cao.'],
                  poseRuleVersionId: 'plank_pose_v1',
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Chân và thân giữa+',
          estimatedDurationMinutes: 32,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'lunges',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Giữ thân người thẳng và kiểm soát gối sau.'],
                  alternatives: ['squat'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'glute_bridge',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 12,
                  maximum: 15,
                  restSeconds: 45,
                  cues: ['Không ưỡn lưng ở vị trí cao nhất.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'crunch',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 15,
                  restSeconds: 45,
                  cues: ['Thở ra khi nâng vai.'],
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Toàn thân thử thách',
          estimatedDurationMinutes: 35,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'squat',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 12,
                  maximum: 15,
                  restSeconds: 60,
                  cues: ['Ưu tiên kỹ thuật, không chạy theo tốc độ.'],
                  poseRuleVersionId: 'squat_pose_v1',
                ),
                _PrescriptionTemplate(
                  exerciseId: 'push_up',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Giữ vai ổn định trong toàn bộ chuyển động.'],
                  poseRuleVersionId: 'push_up_pose_v1',
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.conditioning,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'mountain_climber',
                  sets: 3,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 25,
                  maximum: 35,
                  restSeconds: 45,
                  cues: ['Duy trì nhịp có thể kiểm soát.'],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static const _gymWeeks = <_WeekTemplate>[
    _WeekTemplate(
      number: 1,
      title: 'Tuần 1 · Học mẫu chuyển động',
      sessions: [
        _SessionTemplate(
          title: 'Đẩy và kéo thân trên',
          estimatedDurationMinutes: 42,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'bench_press',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Giữ bả vai ổn định trên ghế.'],
                  alternatives: ['push_up'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'row',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 90,
                  cues: ['Kéo khuỷu tay về sau, không nhún vai.'],
                  alternatives: ['lat_pulldown'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'plank',
                  sets: 2,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 20,
                  maximum: 30,
                  restSeconds: 45,
                  cues: ['Giữ thân người thẳng và thở đều.'],
                  poseRuleVersionId: 'plank_pose_v1',
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Chân nền tảng',
          estimatedDurationMinutes: 40,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'leg_press',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 90,
                  cues: ['Giữ bàn chân ổn định trên bàn đạp.'],
                  alternatives: ['squat'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'romanian_deadlift',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Đẩy hông về sau và giữ lưng trung lập.'],
                  alternatives: ['glute_bridge'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'calf_raise',
                  sets: 2,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 12,
                  maximum: 15,
                  restSeconds: 45,
                  cues: ['Dừng ngắn ở vị trí cao nhất.'],
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Toàn thân kỹ thuật',
          estimatedDurationMinutes: 45,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'deadlift',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 6,
                  maximum: 8,
                  restSeconds: 120,
                  cues: ['Giữ thanh gần cơ thể và lưng trung lập.'],
                  alternatives: ['romanian_deadlift'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'shoulder_press',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Không ưỡn lưng khi đưa tay lên.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'lat_pulldown',
                  sets: 2,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Kéo bằng khuỷu tay, không giật thân người.'],
                  alternatives: ['row'],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _WeekTemplate(
      number: 2,
      title: 'Tuần 2 · Củng cố kỹ thuật',
      sessions: [
        _SessionTemplate(
          title: 'Đẩy và kéo thân trên+',
          estimatedDurationMinutes: 45,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'bench_press',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Giữ chuyển động lặp lại ổn định giữa các set.'],
                  alternatives: ['push_up'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'row',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 12,
                  restSeconds: 90,
                  cues: ['Giữ cổ trung lập và kiểm soát nhịp trả về.'],
                  alternatives: ['lat_pulldown'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'tricep_pushdown',
                  sets: 2,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Giữ khuỷu tay gần thân người.'],
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Chân nền tảng+',
          estimatedDurationMinutes: 44,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'leg_press',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 90,
                  cues: ['Không khóa gối ở cuối chuyển động.'],
                  alternatives: ['squat'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'romanian_deadlift',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Giữ chuyển động xuất phát từ hông.'],
                  alternatives: ['glute_bridge'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'calf_raise',
                  sets: 3,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 12,
                  maximum: 15,
                  restSeconds: 45,
                  cues: ['Kiểm soát cả nhịp nâng và hạ.'],
                ),
              ],
            ),
          ],
        ),
        _SessionTemplate(
          title: 'Toàn thân củng cố',
          estimatedDurationMinutes: 48,
          blocks: [
            _BlockTemplate(
              type: ProgramBlockType.main,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'deadlift',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 6,
                  maximum: 8,
                  restSeconds: 120,
                  cues: ['Dừng set nếu không còn giữ được lưng trung lập.'],
                  alternatives: ['romanian_deadlift'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'shoulder_press',
                  sets: 4,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 8,
                  maximum: 10,
                  restSeconds: 90,
                  cues: ['Giữ xương sườn ổn định khi đưa tay lên.'],
                ),
              ],
            ),
            _BlockTemplate(
              type: ProgramBlockType.accessory,
              prescriptions: [
                _PrescriptionTemplate(
                  exerciseId: 'bicep_curl',
                  sets: 2,
                  targetType: PrescriptionTargetType.repetitions,
                  minimum: 10,
                  maximum: 12,
                  restSeconds: 60,
                  cues: ['Không đung đưa thân người.'],
                ),
                _PrescriptionTemplate(
                  exerciseId: 'plank',
                  sets: 2,
                  targetType: PrescriptionTargetType.durationSeconds,
                  minimum: 25,
                  maximum: 35,
                  restSeconds: 45,
                  cues: ['Thở đều và giữ thân người thẳng.'],
                  poseRuleVersionId: 'plank_pose_v1',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];
}

class _WeekTemplate {
  const _WeekTemplate({
    required this.number,
    required this.title,
    required this.sessions,
  });

  final int number;
  final String title;
  final List<_SessionTemplate> sessions;
}

class _SessionTemplate {
  const _SessionTemplate({
    required this.title,
    required this.estimatedDurationMinutes,
    required this.blocks,
  });

  final String title;
  final int estimatedDurationMinutes;
  final List<_BlockTemplate> blocks;
}

class _BlockTemplate {
  const _BlockTemplate({required this.type, required this.prescriptions});

  final ProgramBlockType type;
  final List<_PrescriptionTemplate> prescriptions;
}

class _PrescriptionTemplate {
  const _PrescriptionTemplate({
    required this.exerciseId,
    required this.sets,
    required this.targetType,
    required this.minimum,
    required this.maximum,
    required this.restSeconds,
    required this.cues,
    this.alternatives = const [],
    this.poseRuleVersionId,
  });

  final String exerciseId;
  final int sets;
  final PrescriptionTargetType targetType;
  final int minimum;
  final int maximum;
  final int restSeconds;
  final List<String> cues;
  final List<String> alternatives;
  final String? poseRuleVersionId;
}
