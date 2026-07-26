import '../models/program.dart';

/// Dữ liệu chương trình mẫu, dùng khi Firebase chưa khởi tạo được và cho
/// test toàn vẹn dữ liệu trong `test/`. Tiêu chí ghép của phiên bản này
/// khớp với lựa chọn mặc định trong `onboarding_screen.dart`
/// (`healthy_adult_18_64` / `general_fitness` / `beginner` / `bodyweight`)
/// để luồng ghép chương trình mặc định luôn có kết quả khi chạy cục bộ.
const programCatalog = <Program>[
  Program(
    id: 'bodyweight_fullbody',
    title: 'Toàn thân không dụng cụ',
    description:
        'Chương trình toàn thân 2 buổi mỗi tuần dành cho người mới bắt đầu, '
        'không cần dụng cụ.',
  ),
];

const _week1SessionABlocks = [
  ProgramBlock(
    type: ProgramBlockType.warmUp,
    order: 1,
    prescriptions: [
      ExercisePrescription(
        exerciseId: 'lunge',
        order: 1,
        sets: 2,
        targetLabel: '10 lần mỗi bên, nhịp chậm',
      ),
    ],
  ),
  ProgramBlock(
    type: ProgramBlockType.main,
    order: 2,
    prescriptions: [
      ExercisePrescription(
        exerciseId: 'squat_pose_v1',
        order: 1,
        sets: 3,
        targetLabel: '12 lần',
      ),
      ExercisePrescription(
        exerciseId: 'push_up',
        order: 2,
        sets: 3,
        targetLabel: '10 lần',
      ),
    ],
  ),
  ProgramBlock(
    type: ProgramBlockType.coolDown,
    order: 3,
    prescriptions: [
      ExercisePrescription(
        exerciseId: 'plank',
        order: 1,
        sets: 1,
        targetLabel: 'Giữ 30 giây',
      ),
    ],
  ),
];

const _week1SessionA = ProgramSession(
  id: 'bodyweight_fullbody_v1_w1s1',
  order: 1,
  title: 'Buổi A · Toàn thân — Chân & Đẩy',
  estimatedDurationMinutes: 35,
  totalSets: 9,
  blocks: _week1SessionABlocks,
);

const _week1SessionB = ProgramSession(
  id: 'bodyweight_fullbody_v1_w1s2',
  order: 2,
  title: 'Buổi B · Toàn thân — Kéo & Lõi',
  estimatedDurationMinutes: 35,
  totalSets: 9,
  blocks: [
    ProgramBlock(
      type: ProgramBlockType.warmUp,
      order: 1,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'glute_bridge',
          order: 1,
          sets: 2,
          targetLabel: '15 lần',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.main,
      order: 2,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'lunge',
          order: 1,
          sets: 3,
          targetLabel: '10 lần mỗi bên',
        ),
        ExercisePrescription(
          exerciseId: 'plank',
          order: 2,
          sets: 3,
          targetLabel: 'Giữ 30 giây',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.coolDown,
      order: 3,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'glute_bridge',
          order: 1,
          sets: 1,
          targetLabel: 'Giữ 20 giây',
        ),
      ],
    ),
  ],
);

const _week2SessionA = ProgramSession(
  id: 'bodyweight_fullbody_v1_w2s1',
  order: 1,
  title: 'Buổi A · Toàn thân — Chân & Đẩy',
  estimatedDurationMinutes: 38,
  totalSets: 11,
  blocks: [
    ProgramBlock(
      type: ProgramBlockType.warmUp,
      order: 1,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'lunge',
          order: 1,
          sets: 2,
          targetLabel: '10 lần mỗi bên, nhịp chậm',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.main,
      order: 2,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'squat_pose_v1',
          order: 1,
          sets: 4,
          targetLabel: '12 lần',
        ),
        ExercisePrescription(
          exerciseId: 'push_up',
          order: 2,
          sets: 4,
          targetLabel: '10 lần',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.coolDown,
      order: 3,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'plank',
          order: 1,
          sets: 1,
          targetLabel: 'Giữ 35 giây',
        ),
      ],
    ),
  ],
);

const _week2SessionB = ProgramSession(
  id: 'bodyweight_fullbody_v1_w2s2',
  order: 2,
  title: 'Buổi B · Toàn thân — Kéo & Lõi',
  estimatedDurationMinutes: 38,
  totalSets: 11,
  blocks: [
    ProgramBlock(
      type: ProgramBlockType.warmUp,
      order: 1,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'glute_bridge',
          order: 1,
          sets: 2,
          targetLabel: '15 lần',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.main,
      order: 2,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'lunge',
          order: 1,
          sets: 4,
          targetLabel: '10 lần mỗi bên',
        ),
        ExercisePrescription(
          exerciseId: 'plank',
          order: 2,
          sets: 4,
          targetLabel: 'Giữ 30 giây',
        ),
      ],
    ),
    ProgramBlock(
      type: ProgramBlockType.coolDown,
      order: 3,
      prescriptions: [
        ExercisePrescription(
          exerciseId: 'glute_bridge',
          order: 1,
          sets: 1,
          targetLabel: 'Giữ 25 giây',
        ),
      ],
    ),
  ],
);

const programVersionCatalog = <ProgramVersion>[
  ProgramVersion(
    id: 'bodyweight_fullbody_v1',
    programId: 'bodyweight_fullbody',
    version: 1,
    status: ProgramVersionStatus.published,
    cadence: ProgramCadence(sessionsPerWeek: 2),
    weeks: [
      ProgramWeek(weekNumber: 1, sessions: [_week1SessionA, _week1SessionB]),
      ProgramWeek(weekNumber: 2, sessions: [_week2SessionA, _week2SessionB]),
    ],
    safetyCopy:
        'Dừng tập ngay nếu thấy đau, chóng mặt, khó thở hoặc khó chịu bất '
        'thường. FitTrack không chẩn đoán, điều trị hoặc thay thế tư vấn của '
        'bác sĩ hay huấn luyện viên. Chương trình dành cho người trưởng '
        'thành khỏe mạnh 18–64 tuổi.',
    accessibilityLabel:
        'Chương trình toàn thân 2 buổi mỗi tuần, không dụng cụ, phù hợp '
        'người mới bắt đầu. Mỗi buổi có hướng dẫn bằng văn bản và xác nhận '
        'bằng nút bấm, không bắt buộc dùng camera.',
    sourceRefs: [
      SourceRef(
        title: 'ACSM Guidelines for Exercise Testing and Prescription',
        publisher: 'American College of Sports Medicine',
        publicationYear: 2021,
      ),
      SourceRef(
        title: 'Physical Activity Guidelines for Americans, 2nd edition',
        publisher: 'U.S. Department of Health and Human Services',
        publicationYear: 2018,
      ),
    ],
    readinessVariants: [
      ReadinessVariant(
        sessionId: 'bodyweight_fullbody_v1_w1s1',
        readiness: ReadinessKey.ready,
        blocks: _week1SessionABlocks,
      ),
      ReadinessVariant(
        sessionId: 'bodyweight_fullbody_v1_w1s1',
        readiness: ReadinessKey.reduceToday,
        blocks: [
          ProgramBlock(
            type: ProgramBlockType.warmUp,
            order: 1,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'lunge',
                order: 1,
                sets: 1,
                targetLabel: '8 lần mỗi bên, nhẹ nhàng',
              ),
            ],
          ),
          ProgramBlock(
            type: ProgramBlockType.main,
            order: 2,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'squat_pose_v1',
                order: 1,
                sets: 2,
                targetLabel: '10 lần',
              ),
              ExercisePrescription(
                exerciseId: 'push_up',
                order: 2,
                sets: 2,
                targetLabel: '8 lần',
              ),
            ],
          ),
          ProgramBlock(
            type: ProgramBlockType.coolDown,
            order: 3,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'plank',
                order: 1,
                sets: 1,
                targetLabel: 'Giữ 20 giây',
              ),
            ],
          ),
        ],
      ),
      ReadinessVariant(
        sessionId: 'bodyweight_fullbody_v1_w1s1',
        readiness: ReadinessKey.recovery,
        blocks: [
          ProgramBlock(
            type: ProgramBlockType.warmUp,
            order: 1,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'lunge',
                order: 1,
                sets: 1,
                targetLabel: '6 lần mỗi bên, rất nhẹ',
              ),
            ],
          ),
          ProgramBlock(
            type: ProgramBlockType.main,
            order: 2,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'glute_bridge',
                order: 1,
                sets: 2,
                targetLabel: '12 lần, nhẹ nhàng',
              ),
            ],
          ),
          ProgramBlock(
            type: ProgramBlockType.coolDown,
            order: 3,
            prescriptions: [
              ExercisePrescription(
                exerciseId: 'plank',
                order: 1,
                sets: 1,
                targetLabel: 'Giữ 15 giây',
              ),
            ],
          ),
        ],
      ),
    ],
    targetPopulationKeys: ['healthy_adult_18_64'],
    targetGoalKeys: ['general_fitness'],
    targetExperienceKeys: ['beginner'],
    requiredEquipmentKeys: ['bodyweight'],
    audiencePreference: ProgramAudiencePreference.unisex,
  ),
];
