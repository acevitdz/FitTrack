# FitTrack — Đặc tả yêu cầu hệ thống theo mã nguồn hiện tại

## 1. Mục đích tài liệu

FitTrack hướng tới một luồng đơn giản: người dùng khai báo thông tin cơ bản,
nhận một chương trình có sẵn, tập theo từng hiệp và xem lại kết quả đã được xác
nhận. Ứng dụng không cho người dùng tự kê prescription hoặc tự nhập một bộ số
liệu tập luyện phức tạp.

## 2. Phạm vi hệ thống

### 2.1. Phạm vi đang triển khai

Hệ thống hiện bao gồm:

- đăng ký, đăng nhập, đặt lại mật khẩu và đăng xuất bằng email;
- onboarding và Body Metrics;
- ghép chương trình deterministic từ catalog đã phát hành;
- enrollment và lịch tập tự động;
- readiness cho từng occurrence;
- Active Workout có checkpoint, nghỉ, pause/resume và completion;
- Guided Confirmation trên Android/Web;
- AI Camera Coach cho Squat trên Android;
- Voice Coach, rung và notification trên Android;
- thư viện bài tập chỉ đọc cho người dùng;
- tiến độ, lịch sử, streak, thành tích và biểu đồ cân nặng;
- hồ sơ, theme, hệ đơn vị và yêu cầu dữ liệu;
- chế độ chỉ đọc cho dữ liệu legacy;
- cache cục bộ theo UID và đồng bộ snapshot với Firebase.

### 2.2. Phạm vi chưa có

Phiên bản hiện tại không bao gồm:

- đăng nhập Google hoặc Facebook;
- plan builder, schedule builder hoặc bài tập cá nhân cho người dùng;
- form nhập actual reps, mức tạ, volume hoặc external load trong workout mới;
- AI Camera cho bài khác Squat;
- pose detection, local notification hoặc Text-to-Speech trên Web;
- source và cấu hình iOS;
- công cụ biên soạn catalog trong ứng dụng người dùng;
- backend đóng gói export hoặc xóa toàn bộ dữ liệu;
- hàng đợi đồng bộ offline bền vững;
- wearable, Health Connect, mạng xã hội, thanh toán hoặc live coach.

## 3. Actor và quyền truy cập

### Khách

Khách là trạng thái chưa đăng nhập, không phải một role được lưu. Khách chỉ
truy cập splash, đăng nhập, đăng ký và quên mật khẩu.

### Người dùng

Người dùng quản lý hồ sơ và dữ liệu của chính mình, theo chương trình, thực hiện
workout, xem tiến độ và thay đổi cài đặt. Ứng dụng người dùng không được sửa
catalog chung hoặc dữ liệu của tài khoản khác.

## 4. Luồng nghiệp vụ chính

```text
Đăng ký/đăng nhập
        ↓
Onboarding và Body Metrics
        ↓
ProgramMatcher
        ↓
ProgramEnrollment + WorkoutOccurrence
        ↓
Trang chủ + Readiness
        ↓
Active Workout
  ├── Guided Confirmation
  └── AI Camera Squat trên Android
        ↓
WorkoutCompletion
        ↓
Tiến độ, streak và thành tích
```

Catalog chỉ phân phối nội dung đã phát hành:

```text
draft → published → retired
                  ↘ recalled
```

Chỉ version `published` được phân phối cho người dùng. Một version đã
`published` không được sửa nội dung và không được đưa trở lại `draft`.

## 5. Yêu cầu chức năng

### FR-01 — Khởi động ứng dụng

1. Ứng dụng phải khởi tạo locale tiếng Việt trước khi render giao diện.
2. Ứng dụng phải thử khởi tạo Firebase nhưng không được crash nếu Firebase
   không khả dụng.
3. Notification service và AppState phải được khởi tạo trước `runApp`.
4. Sau splash, ứng dụng phải điều hướng theo auth state và trạng thái
   onboarding.
5. Theme phải phản ánh lựa chọn hệ thống, sáng hoặc tối đã lưu.

### FR-02 — Tài khoản và phiên đăng nhập

1. Hệ thống phải hỗ trợ đăng ký bằng tên, email và mật khẩu.
2. Form phải kiểm tra email, mật khẩu tối thiểu 8 ký tự, xác nhận mật khẩu và
   đồng ý điều khoản.
3. Hệ thống phải hỗ trợ đăng nhập, đăng xuất và yêu cầu đặt lại mật khẩu.
4. Khi Firebase hoạt động, tài khoản chỉ được vào ứng dụng nếu document người
   dùng có trạng thái `active`.
5. Ứng dụng phải theo dõi trạng thái tài khoản đang đăng nhập và đóng phiên nếu
   tài khoản bị khóa.
6. Phiên và cache local phải được scope theo UID. Dữ liệu của UID cũ không được
   gán lại cho UID mới.
7. Khi Firebase không hoạt động, adapter local có thể tạo UID demo theo email
   để phát triển; cơ chế này không được coi là xác thực production.
8. Đăng nhập Google/Facebook phải thông báo chưa hỗ trợ thay vì giả thành công.

### FR-03 — Onboarding và Body Metrics

1. Tài khoản mới phải hoàn thành onboarding trước khi vào MainShell.
2. Người dùng phải nhập tên hiển thị, chiều cao và cân nặng.
3. Chiều cao phải tương đương 100–250 cm.
4. Cân nặng phải lớn hơn 0 và không quá 500 kg.
5. Hệ thống phải nhận `cm/kg` và `in/lb`, sau đó lưu canonical value bằng
   `cm/kg`.
6. BMI phải được tính từ chiều cao và cân nặng, không cho nhập trực tiếp.
7. Mỗi lần cập nhật Body Metrics phải tạo một `WeightEntry` có thời điểm và
   snapshot chiều cao.
8. Không được lưu lần đo có thời điểm ở tương lai.
9. Người dùng phải chọn population, goal, experience, equipment, số buổi và
   audience preference.
10. Population ngoài phạm vi hỗ trợ không được vượt qua safety gate của
    ProgramMatcher.

### FR-04 — Ghép chương trình và tạo lịch

1. ProgramMatcher chỉ được xét `ProgramVersion.published`.
2. Population, experience và equipment là hard gate.
3. Goal là hard gate của match thông thường; fallback được phép nới goal nhưng
   không được nới các safety gate còn lại.
4. Audience và số buổi mong muốn dùng để xếp hạng, không phải safety gate.
5. Kết quả hòa phải được xử lý deterministic theo score, ngày phát hành và ID.
6. Khi có kết quả, hệ thống phải tạo `ProgramEnrollment` ghim vào version ID.
7. Hệ thống phải tạo occurrence từ các session theo cadence và ngày ưu tiên.
8. Gọi ghép lại khi enrollment hiện tại vẫn hợp lệ không được tạo enrollment
   hoặc occurrence trùng.
9. Khi preferences thay đổi, các occurrence mở của enrollment cũ phải bị hủy
   trước khi ghép lại.
10. Không cho đổi preferences khi còn Active Workout draft.

### FR-05 — Trang chủ và readiness

1. Trang chủ phải ưu tiên hiển thị draft đang dở trước occurrence mới.
2. Nếu có occurrence, hệ thống phải hiển thị tên session, tuần, thời lượng, số
   hiệp và số block.
3. Người dùng phải chọn một trong ba readiness: ready, reduceToday hoặc
   recovery.
4. Mỗi readiness chỉ được dùng block của variant thuộc đúng session/version.
5. Người dùng có thể dời occurrence sang ngày trống tiếp theo.
6. Người dùng có thể bỏ qua occurrence sau xác nhận.
7. Không được bắt đầu occurrence đã completed, skipped hoặc cancelled.
8. Không được mở occurrence thứ hai khi còn draft của occurrence khác.

### FR-06 — Active Workout

1. Controller phải bắt đầu ở phase `preparing`.
2. Start phải chuyển sang `working` và ghi thời điểm bắt đầu.
3. Complete set phải tạo `SetEvent.completed` và chuyển con trỏ.
4. Redo phải tạo `SetEvent.redone` nhưng không chuyển con trỏ.
5. Skip phải yêu cầu lý do không rỗng và tạo `SetEvent.skipped`.
6. Sau một set có rest, controller phải dùng `restEndsAt`.
7. Người dùng có thể cộng 15 giây hoặc bỏ qua phần nghỉ.
8. Pause phải đóng băng active duration và rest remaining.
9. Resume phải trở lại working hoặc phần rest còn lại.
10. Mỗi transition phải đổi `phaseId`. Callback có phase ID cũ không được sửa
    state hiện tại.
11. Draft phải lưu snapshot nội dung, con trỏ, event và timestamp theo UID.
12. Back khỏi working/resting phải pause và checkpoint, không tự tạo
    completion.
13. Finish phải chuyển qua `finishing` trước khi `completed`.
14. Completion phải có idempotency key ổn định để retry không tạo bản ghi
    trùng.
15. Draft chỉ bị xóa sau khi completion đã được lưu hoặc người dùng discard.
16. Completion thiếu hoặc có set bị skip phải có trạng thái
    `partiallyCompleted`.

### FR-07 — Chế độ xác nhận

1. Guided Confirmation phải luôn có cho workout.
2. Guided không được lưu detected rep count hoặc confidence.
3. AI evidence chỉ được chấp nhận khi confirmation mode là `aiCamera`.
4. Người dùng phải có thể đổi từ AI sang Guided trong khi tập.
5. Bài không hỗ trợ AI phải tiếp tục bằng Guided, không chặn workout.

### FR-08 — AI Camera Coach

1. Camera Coach hiện chỉ được coi là hỗ trợ với các ID Squat đã định nghĩa.
2. Tính năng chỉ khởi tạo trên Android khi prescription có `squat_pose_v1`.
3. Camera phải tắt audio và chỉ cho một inference hoạt động tại một thời điểm.
4. Frame và `InputImage` chỉ được giữ trong thời gian inference.
5. Service không được lưu hoặc upload frame/video/landmark.
6. PoseRuleEngine phải chọn bên cơ thể có chất lượng landmark tốt hơn.
7. Landmark thiếu, visibility thấp, confidence thấp, frame cũ hoặc sai thứ tự
   không được làm tăng rep.
8. Rep chỉ được đếm sau chu kỳ ổn định
   `standing → descending → bottom → ascending → standing`.
9. Một squat chưa đủ sâu phải đưa cue phù hợp, không tạo rep.
10. Khi camera, quyền, model, nền tảng hoặc độ tin cậy không đáp ứng, hệ thống
    phải fallback sang Guided Confirmation.
11. Người dùng phải có thể đổi camera và chủ động tắt camera.

### FR-09 — Tiến độ, streak và thành tích

1. Hệ thống phải tổng hợp completion mới theo 7 ngày, 30 ngày hoặc toàn bộ.
2. Báo cáo phải có số buổi, thời gian, hiệp hoàn tất và độ chuyên cần.
3. Hệ thống phải thống kê bài tập thường xuyên và phân bổ nhóm cơ từ completed
   sets.
4. Chi tiết completion phải giữ ProgramVersion, source, snapshot và
   confirmation mode.
5. Workout streak và Body Metrics streak phải dùng hai tập ngày riêng.
6. Nhiều event cùng loại trong một ngày chỉ được tính một ngày.
7. Thành tích phải được mở theo các mốc completion và streak đã cấu hình.
8. Legacy completion không được trộn vào báo cáo workout mới.

### FR-10 — Thư viện bài tập

1. Người dùng chỉ được thấy bài template `isActive`.
2. Thư viện phải tìm theo tên tiếng Việt hoặc tiếng Anh.
3. Thư viện phải lọc theo nhóm cơ.
4. Người dùng có thể yêu thích và bỏ yêu thích.
5. Trang chi tiết phải hiển thị mô tả, độ khó, dụng cụ, hướng dẫn và lỗi thường
   gặp.
6. Người dùng không được tạo/sửa bài, thêm bài vào plan hoặc sửa prescription.

### FR-11 — Hồ sơ và cài đặt

1. Người dùng có thể đổi tên và ảnh đại diện.
2. Ảnh người dùng không được lớn hơn 5 MB.
3. Người dùng có thể đổi theme và hệ đơn vị.
4. Người dùng có thể bật/tắt Voice Coach và haptic.
5. Người dùng có thể bật notification, chọn giờ và chọn nhắc trước 0, 15, 30
   hoặc 60 phút.
6. Notification bị từ chối không được chặn workout.
7. Người dùng phải xem được danh sách occurrence sắp tới.
8. Người dùng có thể gửi request export hoặc deletion.
9. Deletion trong app chỉ tạo request và đăng xuất; backend mới chịu trách
   nhiệm xóa dữ liệu.

### FR-12 — Notification và Voice Coach

1. Notification chỉ được lập lịch sau khi người dùng bật và cấp quyền.
2. Lịch nhắc phải được tạo từ occurrence đang scheduled/postponed.
3. Occurrence completed, skipped, cancelled hoặc inProgress không được giữ
   notification lịch cũ.
4. Khi rest ở background, hệ thống có thể lập notification hết giờ nghỉ.
5. Payload `today:` và `active:` phải được route an toàn theo state hiện tại.
6. Voice Coach chỉ đọc cue đã có; service không tự sinh lời khuyên.
7. TTS hoặc notification lỗi không được thay đổi state machine của workout.

### FR-13 — Dữ liệu legacy

1. Kế hoạch, lịch và completion schema cũ có thể được deserialize để xem.
2. UI legacy phải có nhãn chỉ đọc.
3. AppState phải từ chối mọi thao tác tạo, sửa, xóa, sao chép hoặc dùng lại dữ
   liệu legacy.
4. Dữ liệu parse lỗi không được làm ứng dụng crash khi khởi động.

## 6. Quy tắc nghiệp vụ trọng tâm

| Mã | Quy tắc |
|---|---|
| BR-01 | Dữ liệu riêng phải được phân tách theo UID |
| BR-02 | Chỉ catalog published/active được phân phối cho user |
| BR-03 | Enrollment và completion phải ghim version/snapshot |
| BR-04 | Người dùng không tự sửa prescription |
| BR-05 | Guided Confirmation không suy ra số liệu AI |
| BR-06 | Chỉ event đã xác nhận được tính vào completion |
| BR-07 | Completion retry phải idempotent |
| BR-08 | Weight streak và workout streak không được trộn |
| BR-09 | Published ProgramVersion là bất biến về nội dung |
| BR-10 | Camera không được lưu hoặc upload frame theo mặc định |
| BR-11 | Legacy chỉ đọc và không tham gia analytics mới |
| BR-12 | FitTrack không đưa ra chẩn đoán y khoa |

## 7. Mô hình dữ liệu

### Tài khoản và hồ sơ

- `UserProfile`: UID, email, tên, chiều cao, cân nặng hiện tại, mục tiêu, số buổi
  tuần, audience, avatar và onboarding state.

### Chương trình

- `UserTrainingPreferences`
- `Program`
- `ProgramVersion`
- `ProgramWeek`
- `ProgramSession`
- `ProgramBlock`
- `ExercisePrescription`
- `ReadinessVariant`
- `ProgramEnrollment`
- `WorkoutOccurrence`

`ProgramVersion` chứa cadence, nguồn, safety copy, accessibility label,
readiness variants và toàn bộ cây nội dung được phát hành.

### Active Workout

- `WorkoutSessionSnapshot`
- `WorkoutExerciseSnapshot`
- `WorkoutTargetContext`
- `ActiveWorkoutDraft`
- `SetEvent`
- `WorkoutCompletion`

Schema workout mới nằm trong `models/active_workout.dart`. Các model
`WorkoutPlan`, `WorkoutSchedule` và `models/workout_completion.dart` được giữ
chủ yếu để đọc dữ liệu legacy.

### Sức khỏe và thư viện

- `WeightEntry`: cân nặng, snapshot chiều cao, thời điểm và BMI suy ra.
- `Achievement`: mốc mở khóa.
- `Exercise`: metadata bài, hướng dẫn, lỗi thường gặp, media và trạng thái.

### Pose

- `PoseFrame` và `NormalizedPoseLandmark` chỉ là dữ liệu tạm trong pipeline.
- `PoseCoachResult` chứa status, phase, rep count, confidence và feedback.
- `SquatRuleConfiguration` chứa ngưỡng, smoothing và debounce.

## 8. Lưu trữ và đồng bộ

### Local

`LocalStore` dùng SharedPreferences:

- snapshot state được scope bằng UID;
- session flag và authenticated UID được lưu riêng;
- state cũ chỉ được migrate khi profile ID trùng UID hiện tại.

`ActiveWorkoutDraftStore` dùng một key riêng cho mỗi UID. Draft lỗi định dạng
không được làm crash app và không được tự gán cho tài khoản khác.

### Firebase

Các đường dẫn chính:

```text
users/{uid}
users/{uid}/appState/current
users/{uid}/weightActivityDays/{yyyy-mm-dd}
users/{uid}/workoutActivityDays/{yyyy-mm-dd}
exercises/{exerciseId}
programs/{programId}
programVersions/{versionId}
dataExportRequests/{uid}
accountDeletionRequests/{uid}
```

Ảnh người dùng nằm trong `users/{uid}/...`; ảnh bài tập mẫu nằm trong
`exercise-templates/{exerciseId}/...`.

Khi cloud sync lỗi, `_commit()` giữ bản local và không làm mất thao tác người
dùng. Tuy nhiên, hệ thống chưa có durable retry queue hoặc conflict resolution.

## 9. Yêu cầu phi chức năng

### An toàn và riêng tư

- Không lưu hoặc upload camera frame/video/landmark.
- Dữ liệu tài khoản phải được scope theo UID.
- Security Rules phải phân tách dữ liệu theo UID và không dựa riêng vào UI.
- Ảnh người dùng tối đa 5 MB; media catalog tối đa 25 MB theo Storage Rules.
- BMI phải có lời giải thích là chỉ số tham khảo.
- Mọi màn tập phải nhắc dừng khi đau, chóng mặt, khó thở hoặc khó chịu bất
  thường.
- Không commit service account, mật khẩu hoặc dữ liệu sức khỏe thật vào Git.

### Tin cậy

- Firebase init lỗi không được làm ứng dụng crash.
- Draft phải khôi phục được sau khi app mở lại.
- Timer nghỉ phải dựa trên timestamp.
- Callback cũ phải bị chặn bằng phase ID.
- Completion phải idempotent.
- Notification và TTS là enhancement; lỗi của chúng không được chặn workout.

### Hiệu năng

- Pose detector chỉ xử lý một inference tại một thời điểm.
- Exercise search debounce 250 ms.
- Camera, detector và TTS phải được giải phóng khi không còn sử dụng.
- Danh sách thư viện phải đổi số cột theo chiều rộng để tránh layout quá dài.

### Khả dụng và accessibility

- Các tác vụ chính phải có nhãn text, không chỉ có icon.
- Trạng thái đúng/sai không chỉ biểu đạt bằng màu.
- Feedback camera dùng live region cho screen reader.
- Các màn hình chính không được overflow ở 360×800 và 412×915.
- Empty, loading, permission denied và error state phải có lời giải thích.

### Khả năng bảo trì

- Code phải qua `flutter analyze`.
- Các luật deterministic phải có unit test.
- Các màn hình và hành động chính phải có widget test.
- Thành viên không tự thêm dependency hoặc đổi contract chung mà chưa thống
  nhất.

## 10. Bảo mật Firebase hiện có

Firestore Rules hiện thực hiện các kiểm tra chính:

- người dùng chỉ đọc/ghi app state và activity day của chính mình;
- người dùng không sửa các trường quyền và trạng thái tài khoản;
- ứng dụng người dùng không được ghi catalog;
- người dùng đã đăng nhập chỉ đọc exercise active và program/version published;
- export/deletion request phải thuộc UID đang đăng nhập.

Storage Rules:

- người dùng chỉ thao tác file dưới UID của chính mình;
- file người dùng phải là ảnh và nhỏ hơn 5 MB;
- ứng dụng người dùng không được ghi media catalog;
- người dùng chỉ đọc media của nội dung đang active/published.

Security Rules chưa có bằng chứng Firebase Emulator test trong repository, vì
vậy vẫn là hạng mục cần nghiệm thu trước khi phát hành.

## 11. Tương thích nền tảng

| Thành phần | Android | Web |
|---|---:|---:|
| Firebase Auth/Firestore/Storage | Có cấu hình | Có cấu hình |
| Guided Confirmation | Có | Có |
| Camera + ML Kit | Có code path | Không khởi tạo |
| Android TTS MethodChannel | Có code path | Không |
| Local notification | Có code path | Không |
| Theme, chart và history | Có | Có |

Project chưa có platform directory iOS và Firebase iOS chưa được cấu hình.

## 12. Tiêu chí nghiệm thu hệ thống

Phiên bản hiện tại được xem là đạt ở mức source khi:

1. `dart format --output=none --set-exit-if-changed lib test` thành công.
2. `flutter analyze` không báo lỗi.
3. `flutter test` thành công.
4. Đăng ký mới đi qua onboarding và ghép chương trình.
5. Published-version gate, fallback và enrollment không tạo trùng.
6. Active Workout đi qua working/resting/paused/finishing/completed.
7. Draft khôi phục đúng con trỏ và completion retry không tạo trùng.
8. Guided không lưu AI evidence.
9. Squat rule không đếm rep từ frame thiếu tin cậy hoặc chuyển động chưa đủ.
10. Người dùng không thấy mutation route của plan/prescription/legacy.
11. MainShell và các màn chính không overflow ở kích thước đã test.

Trước khi phát hành Android còn cần:

1. Device QA camera trước/sau, quyền camera và ML Kit latency.
2. QA TTS, notification, deep link, background và process death.
3. Firebase Emulator test cho Auth, Rules, UID isolation và catalog read-only.
4. Kiểm tra network/privacy để xác nhận frame camera không rời thiết bị.
5. Accessibility, hiệu năng, pin và nhiều cấu hình Android hơn.

## 13. Truy vết yêu cầu vào source

| Nhóm yêu cầu | Source chính |
|---|---|
| Bootstrap và route guard | `lib/main.dart`, `lib/app.dart` |
| Tài khoản và state | `lib/state/app_state.dart`, `lib/services/firebase_gateway.dart` |
| Program matching | `lib/services/program_matcher.dart` |
| Active Workout | `lib/services/active_workout_controller.dart` |
| Draft và local state | `lib/services/active_workout_draft_store.dart`, `lib/services/local_store.dart` |
| Camera Coach | `lib/widgets/camera_coach_panel.dart`, `lib/services/pose_rule_engine.dart` |
| ML Kit adapter | `lib/services/mlkit_pose_detection_service.dart` |
| Notification/TTS | `lib/services/notification_service.dart`, `lib/services/speech_cue_service.dart` |
| Giao diện | `lib/screens/` |
| Phân quyền dữ liệu | `firestore.rules`, `storage.rules` |
| Kiểm thử | `test/` |
