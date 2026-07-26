import '../models/exercise.dart';

/// Dữ liệu bài tập mẫu, dùng khi Firebase chưa khởi tạo được và cho test
/// toàn vẹn dữ liệu trong `test/`. `squat_pose_v1` là id cố định mà
/// `CameraCoachPanel.supportsExercise()` so khớp — không đổi id này khi
/// chưa thống nhất với người phụ trách Active Workout.
const List<Exercise> exerciseCatalog = [
  Exercise(
    id: 'squat_pose_v1',
    name: 'Squat',
    englishName: 'Bodyweight Squat',
    muscleGroup: 'Chân',
    difficulty: ExerciseDifficulty.intermediate,
    equipment: 'Không dụng cụ',
    description:
        'Bài tập toàn thân phần dưới, kích hoạt đùi trước, đùi sau và mông.',
    instructions: [
      'Đứng hai chân rộng bằng vai, mũi chân hơi mở ra ngoài.',
      'Hạ hông xuống và ra sau như đang ngồi ghế, giữ lưng thẳng.',
      'Hạ đến khi đùi song song mặt đất hoặc thấp hơn nếu biên độ cho phép.',
      'Đẩy gót chân xuống sàn để đứng thẳng trở lại.',
    ],
    commonMistakes: [
      'Gối đổ vào trong khi hạ xuống.',
      'Nhấc gót chân khỏi sàn.',
      'Cong lưng dưới thay vì giữ cột sống trung tính.',
    ],
    isActive: true,
  ),
  Exercise(
    id: 'push_up',
    name: 'Chống đẩy',
    englishName: 'Push-up',
    muscleGroup: 'Ngực',
    difficulty: ExerciseDifficulty.beginner,
    equipment: 'Không dụng cụ',
    description:
        'Bài đẩy toàn thân trên, tập trung ngực, vai trước và tay sau.',
    instructions: [
      'Chống hai tay rộng hơn vai một chút, cơ thể tạo thành đường thẳng.',
      'Hạ ngực xuống gần sàn, khuỷu tay hướng chéo ra sau.',
      'Đẩy người lên vị trí ban đầu, siết bụng trong suốt chuyển động.',
    ],
    commonMistakes: ['Võng lưng hoặc đẩy hông lên cao.', 'Hạ không đủ sâu.'],
    isActive: true,
  ),
  Exercise(
    id: 'plank',
    name: 'Plank',
    englishName: 'Plank',
    muscleGroup: 'Cơ lõi',
    difficulty: ExerciseDifficulty.beginner,
    equipment: 'Không dụng cụ',
    description: 'Bài giữ tư thế tĩnh, tăng sức bền cơ bụng và cơ lưng dưới.',
    instructions: [
      'Chống hai khuỷu tay và mũi chân, cơ thể tạo đường thẳng từ đầu đến gót.',
      'Siết bụng và mông, tránh để hông võng xuống hoặc nhô lên cao.',
      'Giữ tư thế trong thời gian mục tiêu, thở đều.',
    ],
    commonMistakes: ['Hông võng xuống thấp.', 'Nín thở trong lúc giữ.'],
    isActive: true,
  ),
  Exercise(
    id: 'lunge',
    name: 'Lunge',
    englishName: 'Forward Lunge',
    muscleGroup: 'Chân',
    difficulty: ExerciseDifficulty.intermediate,
    equipment: 'Không dụng cụ',
    description:
        'Bài bước đơn chân, cải thiện thăng bằng và sức mạnh từng bên.',
    instructions: [
      'Bước một chân về phía trước, hạ gối sau gần chạm sàn.',
      'Giữ thân trên thẳng, đầu gối trước không vượt quá mũi chân.',
      'Đẩy chân trước để trở về vị trí đứng ban đầu.',
    ],
    commonMistakes: [
      'Bước quá ngắn khiến gối trước dồn áp lực.',
      'Nghiêng người về phía trước.',
    ],
    isActive: true,
  ),
  Exercise(
    id: 'glute_bridge',
    name: 'Cầu mông',
    englishName: 'Glute Bridge',
    muscleGroup: 'Mông',
    difficulty: ExerciseDifficulty.beginner,
    equipment: 'Không dụng cụ',
    description:
        'Bài kích hoạt mông và gân kheo, phù hợp khởi động hoặc thả lỏng nhẹ.',
    instructions: [
      'Nằm ngửa, co gối, hai bàn chân đặt sát sàn rộng bằng hông.',
      'Siết mông để nâng hông lên đến khi thân tạo đường thẳng vai–hông–gối.',
      'Hạ hông xuống chậm rãi và lặp lại.',
    ],
    commonMistakes: ['Ưỡn lưng dưới quá mức thay vì dùng lực mông.'],
    isActive: true,
  ),
  Exercise(
    id: 'dumbbell_shoulder_press',
    name: 'Đẩy vai tạ đơn',
    englishName: 'Dumbbell Shoulder Press',
    muscleGroup: 'Vai',
    difficulty: ExerciseDifficulty.intermediate,
    equipment: 'Phòng gym',
    description: 'Bài đẩy vai bằng tạ đơn, cần dụng cụ phòng gym.',
    instructions: [
      'Ngồi hoặc đứng, giữ tạ ngang vai, lòng bàn tay hướng về trước.',
      'Đẩy tạ thẳng lên trên đầu đến khi tay gần thẳng.',
      'Hạ tạ về vị trí ngang vai một cách kiểm soát.',
    ],
    commonMistakes: ['Ưỡn lưng dưới để đẩy tạ lên.'],
    isActive: true,
  ),
  Exercise(
    id: 'lat_pulldown',
    name: 'Kéo xô',
    englishName: 'Lat Pulldown',
    muscleGroup: 'Lưng',
    difficulty: ExerciseDifficulty.advanced,
    equipment: 'Phòng gym',
    description: 'Bài kéo bằng máy cáp, tập trung nhóm cơ lưng xô.',
    instructions: [
      'Ngồi vào máy, nắm thanh kéo rộng hơn vai.',
      'Kéo thanh xuống ngang ngực trên, ưỡn ngực nhẹ.',
      'Thả thanh trở lại có kiểm soát, không để tay duỗi thẳng đột ngột.',
    ],
    commonMistakes: ['Dùng đà thân trên để kéo thay vì lực lưng.'],
    isActive: true,
  ),
  Exercise(
    id: 'bicep_curl',
    name: 'Cuốn tay trước',
    englishName: 'Biceps Curl',
    muscleGroup: 'Tay',
    difficulty: ExerciseDifficulty.beginner,
    equipment: 'Phòng gym',
    description: 'Bài cô lập cơ tay trước bằng tạ đơn.',
    instructions: [
      'Đứng thẳng, giữ tạ hai tay, khuỷu tay sát thân người.',
      'Cuốn tạ lên phía vai, chỉ xoay ở khớp khuỷu tay.',
      'Hạ tạ xuống chậm rãi về vị trí ban đầu.',
    ],
    commonMistakes: ['Đung đưa thân người để tạo đà.'],
    isActive: false,
  ),
];
