# FITTRACK — ĐẶC TẢ YÊU CẦU HỆ THỐNG (SRS)

## 1. Giới thiệu dự án

### 1.1. Mục tiêu

FitTrack giúp người dùng quản lý hồ sơ, bài tập, kế hoạch, lịch tập và kết quả thực tế; theo dõi tiến độ, streak, kỷ lục và mức cân bằng nhóm cơ. Điểm khác biệt là Readiness Adjustment dựa trên luật minh bạch.

### 1.2. Luồng sản phẩm

```text
Tạo WorkoutPlan → Xếp WorkoutSchedule → Readiness tùy chọn
→ Người dùng tự tập ngoài app → Bấm Done → Nhập kết quả
→ Lưu WorkoutCompletion → Cập nhật Dashboard/Report/Streak/PR/Muscle Balance
```

Không có Active Workout, Rest Timer, Pause hoặc Resume.

### 1.3. Công nghệ

- Flutter/Dart, null safety và Material 3.
- Firebase Authentication, Cloud Firestore, Storage nếu có ảnh.
- Local notification cho lịch tập và streak reminder.
- State management thống nhất (Riverpod/Provider hoặc tương đương).
- Android là nền tảng chính; Chrome dùng kiểm tra khi phù hợp.

### 1.4. Phạm vi ngoài hệ thống

- Chẩn đoán y khoa/chấn thương.
- AI tạo giáo án hoặc chatbot.
- Theo dõi buổi tập theo thời gian thực.
- Health Connect, thiết bị đeo, thanh toán và mạng xã hội.

## 2. Phân tích yêu cầu

### 2.1. Actor

- **Khách:** đăng ký, đăng nhập, quên mật khẩu.
- **User:** quản lý dữ liệu của chính mình; đọc bài mẫu đang hoạt động.
- **Admin:** quản lý bài mẫu; không mặc nhiên đọc dữ liệu sức khỏe người khác.

### 2.2. Ràng buộc

- Mọi dữ liệu cá nhân gắn UID từ Firebase Auth.
- UI không gọi Firebase trực tiếp.
- Plan không có cờ Done toàn cục.
- Completion thuộc một occurrence/ngày và lưu snapshot.
- Readiness không sửa plan gốc.
- Không commit secret/dữ liệu cá nhân thật.

### 2.3. Ưu tiên

**Must:** Auth, Profile, Body Metrics, Exercises, Plan, Schedule, Done/Completion, Dashboard cơ bản, Firebase Rules, test.

**Should:** Reports, Streak, Reminder, PR, Readiness, Muscle Balance.

**Could:** Dark theme, avatar upload, báo cáo nâng cao, song ngữ.

## 3. Functional Requirements

### 3.1. Quản lý tài khoản

| ID | Yêu cầu |
|---|---|
| FR-01.1 | Đăng ký bằng họ tên, email, mật khẩu hợp lệ. |
| FR-01.2 | Đăng nhập, duy trì phiên và đăng xuất. |
| FR-01.3 | Gửi email đặt lại mật khẩu. |
| FR-01.4 | Điều hướng theo auth state; route riêng tư cần xác thực. |

### 3.2. Quản lý hồ sơ

| ID | Yêu cầu |
|---|---|
| FR-02.1 | Xem/cập nhật thông tin cá nhân và avatar. |
| FR-02.2 | Chọn mục tiêu luyện tập và số buổi/tuần 1–7. |
| FR-02.3 | Chỉ chủ tài khoản đọc/sửa hồ sơ. |

### 3.3. Chỉ số cơ thể

| ID | Yêu cầu |
|---|---|
| FR-03.1 | Cập nhật chiều cao và CRUD cân nặng. |
| FR-03.2 | Tính `BMI = kg/m²` từ dữ liệu hợp lệ. |
| FR-03.3 | Hiển thị lịch sử/biểu đồ theo thời gian tăng dần. |
| FR-03.4 | BMI có disclaimer “mang tính tham khảo”. |

### 3.4. Thư viện bài tập mẫu

| ID | Yêu cầu |
|---|---|
| FR-04.1 | Xem danh sách/chi tiết bài mẫu đang hoạt động. |
| FR-04.2 | Tìm kiếm tên không phân biệt hoa/thường. |
| FR-04.3 | Lọc nhóm cơ và kết hợp/đặt lại bộ lọc. |
| FR-04.4 | Thêm/bỏ yêu thích theo UID. |

### 3.5. Kho bài tập cá nhân

| ID | Yêu cầu |
|---|---|
| FR-05.1 | CRUD bài cá nhân. |
| FR-05.2 | Xem bài tự tạo, yêu thích và đã dùng. |
| FR-05.3 | Tính số lần tập, lần gần nhất và PR từ completed sets. |
| FR-05.4 | Xóa/sửa bài không thay đổi snapshot lịch sử. |

### 3.6. Quản lý kế hoạch luyện tập

| ID | Yêu cầu |
|---|---|
| FR-06.1 | CRUD/sao chép WorkoutPlan; thêm/reorder bài. |
| FR-06.2 | Cấu hình target sets, rep range, weight, rest và note. |
| FR-06.3 | Plan hợp lệ có tên và ít nhất một bài; không có `isDone`. |
| FR-06.4 | Tạo WorkoutSchedule None/Once/Weekly. |
| FR-06.5 | Weekly chọn weekdays, start/end; once chọn date; time tùy chọn. |
| FR-06.6 | Hiển thị occurrence theo ngày và trạng thái scheduled/completed/partial/overdue. |
| FR-06.7 | Bấm Done mở form nhập actual sets/reps/weight, duration và note. |
| FR-06.8 | Chỉ completed set tính volume; bodyweight cho phép 0 kg. |
| FR-06.9 | Completion lưu snapshot và không sửa plan gốc. |
| FR-06.10 | Không tạo hai completion cho cùng schedule occurrence. |
| FR-06.11 | User xem, sửa, xóa completion; thống kê phải cập nhật lại. |

### 3.7. Dashboard và mục tiêu

| ID | Yêu cầu |
|---|---|
| FR-07.1 | Hiển thị lịch hôm nay và tiến độ buổi/tuần. |
| FR-07.2 | Hiển thị duration, sets, volume, BMI và PR gần nhất. |
| FR-07.3 | Chỉ completion completed/partial được tính. |
| FR-07.4 | Một card lỗi không khóa toàn Dashboard. |

### 3.8. Báo cáo

| ID | Yêu cầu |
|---|---|
| FR-08.1 | Lọc tuần, tháng hoặc khoảng ngày. |
| FR-08.2 | Tổng hợp số buổi, sets, volume, thời gian và top exercises. |
| FR-08.3 | Dùng completion thực tế; không dùng kế hoạch dự kiến. |
| FR-08.4 | Sửa/xóa completion cập nhật báo cáo. |

### 3.9. Chuỗi hoạt động

| ID | Yêu cầu |
|---|---|
| FR-09.1 | Login streak tăng tối đa một lần/ngày theo Asia/Ho_Chi_Minh. |
| FR-09.2 | Workout streak chỉ tính ngày có completion hợp lệ. |
| FR-09.3 | Current/longest streak và heatmap được hiển thị tách biệt. |
| FR-09.4 | Xóa completion phải tính lại workout streak. |

### 3.10. Nhắc lịch tập

| ID | Yêu cầu |
|---|---|
| FR-10.1 | Lên lịch notification từ schedule ngày/giờ. |
| FR-10.2 | Sửa/xóa/tắt schedule hủy notification liên quan. |
| FR-10.3 | Nhấn notification mở đúng plan nếu đã xác thực. |
| FR-10.4 | Local reminder nhắc duy trì streak nếu chưa check-in trên thiết bị. |
| FR-10.5 | Từ chối quyền không làm app crash và có lối mở Settings. |

### 3.11. Readiness Adjustment

| ID | Yêu cầu |
|---|---|
| FR-11.1 | Thu thập energy, soreness, sore muscles, time và equipment. |
| FR-11.2 | Rule engine xác định none/light/moderate/recovery. |
| FR-11.3 | Giảm sets/bài, loại xung đột soreness/dụng cụ và khớp thời gian. |
| FR-11.4 | Hiển thị before/after và reasons. |
| FR-11.5 | User dùng adjusted snapshot hoặc giữ plan gốc. |
| FR-11.6 | Không sửa WorkoutPlan; Done dùng snapshot đã chọn. |

### 3.12. Bản đồ cân bằng nhóm cơ

| ID | Yêu cầu |
|---|---|
| FR-12.1 | Tính working sets từ completed sets theo tuần/tháng. |
| FR-12.2 | Primary nhận 1; secondary nhận trọng số cấu hình nếu áp dụng. |
| FR-12.3 | Phân loại neutral/low/balanced/high bằng ngưỡng cấu hình. |
| FR-12.4 | Không có dữ liệu không bị kết luận mất cân bằng. |

### 3.13. Admin bài mẫu

| ID | Yêu cầu |
|---|---|
| FR-13.1 | Admin thêm/sửa/upload ảnh/ẩn-hiện bài mẫu. |
| FR-13.2 | User thường chỉ đọc bài đang hoạt động. |
| FR-13.3 | Quyền được kiểm tra trong Security Rules. |

## 4. Non-Functional Requirements

### Hiệu năng

- Không chặn main isolate; danh sách dùng lazy builder.
- Không query Firebase trong `build()`.
- Ảnh có cache/placeholder; dashboard tải từng vùng khi phù hợp.

### Tin cậy

- Không tạo dữ liệu trùng do double tap/retry.
- Completion snapshot không đổi khi plan/exercise thay đổi.
- Transaction/idempotency cho streak và completion uniqueness.
- Mất mạng/dữ liệu thiếu trường không làm crash.

### Bảo mật

- `request.auth != null` và `request.auth.uid == uid` cho dữ liệu cá nhân.
- Chỉ admin được ghi collection bài mẫu.
- Storage chỉ cho chủ sở hữu/avatar hoặc admin/template image theo Rules.
- Rules test chứng minh User A không truy cập dữ liệu User B.

### UI/UX

- Material 3, navy blue, responsive 360×800 và 412×915.
- Contrast hướng WCAG AA; touch target khoảng 48 dp.
- Loading/success/empty/error/offline; form có validation/submitting/unsaved guard.

### Chất lượng mã

- Feature-first; presentation/domain/data.
- Dart thuần cho business rules; unit/widget test.
- `dart format`, `flutter analyze`, `flutter test` đạt.

## 5. Use Case

| Mã | Use case | Actor |
|---|---|---|
| UC-01 | Đăng ký/đăng nhập/quên mật khẩu | Khách |
| UC-02 | Quản lý hồ sơ và chỉ số | User |
| UC-03 | Khám phá/quản lý bài tập | User |
| UC-04 | Tạo nội dung kế hoạch | User |
| UC-05 | Xếp lịch once/weekly | User |
| UC-06 | Kiểm tra readiness và chọn snapshot | User |
| UC-07 | Bấm Done và lưu kết quả | User |
| UC-08 | Xem/sửa/xóa lịch sử kết quả | User |
| UC-09 | Xem Dashboard/Report/Streak/Muscle Balance | User |
| UC-10 | Quản lý reminder | User |
| UC-11 | Quản lý bài mẫu | Admin |

### UC-04 đến UC-07 — luồng trung tâm

- **Tiền điều kiện:** đã đăng nhập; có bài tập hợp lệ.
- **Luồng:** tạo plan → thêm/cấu hình bài → xếp lịch → chọn occurrence → readiness tùy chọn → tự tập → Done → nhập actual results → summary → lưu completion.
- **Ngoại lệ:** plan rỗng; schedule sai; form result không có completed set; mất mạng; duplicate submit.
- **Hậu điều kiện:** completion duy nhất có snapshot; dashboard/report consumers được làm mới; plan gốc không đổi.

## 6. Kiến trúc hệ thống

```text
Flutter Presentation
Screen • Widget • Controller • State
             ↓
Domain
Entity • Repository Contract • Rule • UseCase
             ↓
Data
Model • Repository Implementation • Service
       ↙                         ↘
Firebase Auth/Firestore/Storage   Device Local Notification/Preferences
```

Các feature chính:

```text
authentication, profile, body_metrics,
exercise_library, personal_exercises,
workout_plans, workout_schedules, workout_completion,
dashboard, reports, streaks, reminders,
readiness, muscle_balance, admin_exercises, settings
```

## 7. Database

```text
users/{uid}
users/{uid}/weightEntries/{entryId}
users/{uid}/personalExercises/{exerciseId}
users/{uid}/favorites/{exerciseId}
users/{uid}/workoutPlans/{planId}
users/{uid}/workoutSchedules/{scheduleId}
users/{uid}/workoutCompletions/{completionId}
users/{uid}/reminders/{reminderId}
users/{uid}/activeDays/{yyyy-MM-dd}
users/{uid}/readinessEntries/{entryId}
exercises/{exerciseId}
```

### Entity trọng tâm

```text
WorkoutPlan:
id, userId, name, description?, exercises[], estimatedDuration,
isActive, createdAt, updatedAt

PlanExercise:
exerciseId, exerciseSnapshot, order, targetSets,
minReps, maxReps, targetWeightKg, restSeconds, note?

WorkoutSchedule:
id, userId, planId, type, scheduledDate?, weekdays[],
startDate?, endDate?, hour?, minute?, reminderEnabled, isEnabled

WorkoutCompletion:
id, userId, planId, scheduleId?, occurrenceDate,
planSnapshot, exerciseResults[], status, actualDuration,
totalVolume, perceivedDifficulty?, note?, completedAt

CompletedSet:
setNumber, actualReps, actualWeightKg, isCompleted
```

## 8. API và repository contracts

Không bắt buộc REST API ngoài. Backend dùng Firebase SDK và contracts nội bộ:

```dart
abstract interface class WorkoutPlanRepository {
  Stream<List<WorkoutPlan>> watchPlans();
  Future<WorkoutPlan?> getPlan(String id);
  Future<void> createPlan(WorkoutPlan value);
  Future<void> updatePlan(WorkoutPlan value);
  Future<void> deletePlan(String id);
}

abstract interface class WorkoutScheduleRepository {
  Stream<List<ScheduledOccurrence>> watchOccurrences(DateRange range);
  Future<void> createSchedule(WorkoutSchedule value);
  Future<void> updateSchedule(WorkoutSchedule value);
  Future<void> deleteSchedule(String id);
}

abstract interface class WorkoutCompletionRepository {
  Stream<List<WorkoutCompletion>> watchCompletions(DateRange range);
  Future<void> createCompletion(WorkoutCompletion value);
  Future<void> updateCompletion(WorkoutCompletion value);
  Future<void> deleteCompletion(String id);
}
```

Lỗi Firebase được map thành Auth/Data/Permission/Network/Validation failure; UI không hiển thị stack trace.

## 9. Giao diện

### Design system

- Navy `#071A3D`, `#0A2758`; action `#1557B0`; accent `#2672D9`; background `#F4F7FB`.
- Font Inter/Roboto; radius card 16, input/button 12.
- Bottom navigation: Tổng quan, Kế hoạch, Bài tập, Hồ sơ.

### Màn hình bắt buộc

- Auth: Splash/Login/Register/Forgot Password.
- Profile/Body: Setup/Profile/Edit/BMI/Weight Form.
- Exercise: Library/Detail/Filter/Personal/Form/Progress.
- Plan: List/Detail/Form Content/Form Schedule/Exercise Selection.
- Completion: Result Form/Summary/Success/History/Detail/Edit/Delete.
- Progress: Dashboard/Reports/Streak/Muscle Balance/Muscle Detail.
- Readiness: Wizard/Evaluating/Comparison.
- Reminder: Permission/List/Form.
- Admin: List/Form.

## 10. Phân công nhóm

| Thành viên | Chức năng | CRUD chính |
|---|---|---|
| TV1 | 1, 2, 3, 7, 8, 9 | Profile, WeightEntry |
| TV2 | 4, 5, 12, 13 | TemplateExercise, PersonalExercise |
| TV3 | 6, 10, 11 | WorkoutPlan, WorkoutSchedule, WorkoutCompletion |

TV3 cung cấp completion data cho TV1/TV2; TV2 cung cấp ExerciseSnapshot cho TV3; TV1 cung cấp auth UID/profile.

## 11. Kế hoạch phát triển trong 3 tuần

Kế hoạch áp dụng cho nhóm ba thành viên làm song song. Tuần 1 chỉ dùng để chốt yêu cầu chức năng và giao diện; chưa triển khai mã nguồn nghiệp vụ. Lập trình bắt đầu từ tuần 2.

### Tuần 1 — Chốt chức năng và giao diện

#### Mục tiêu chung

- Chốt chính thức 13 nhóm chức năng và phạm vi MVP.
- Chốt luồng trung tâm `Plan → Schedule → Readiness → Done → Completion`.
- Chốt việc không triển khai Active Workout, Rest Timer, Pause hoặc Resume.
- Hoàn thiện user flow, navigation map và danh sách màn hình.
- Hoàn thiện Figma design system màu xanh dương đậm.
- Thiết kế đủ màn hình chính và các trạng thái loading, empty, error, validation, submitting và success.
- Chốt entity, Firestore schema và repository contracts ở mức thiết kế để tránh thay đổi lớn khi lập trình.
- Chốt phân công TV1, TV2 và TV3; tạo backlog và tiêu chí chấp nhận cho từng chức năng.

#### Phân công

| Thành viên | Công việc tuần 1 |
|---|---|
| TV1 | Chốt luồng Authentication, Profile, Body Metrics, Dashboard, Reports và Streak; thiết kế các frame tương ứng. |
| TV2 | Chốt luồng Exercise Library, Personal Exercises, Muscle Balance và Admin; thiết kế các frame tương ứng. |
| TV3 | Chốt logic Plan, Schedule, Done/Completion, Reminder và Readiness; thiết kế các frame tương ứng. |
| Cả nhóm | Review chéo user flow, component, thuật ngữ, responsive và tính nhất quán giữa các màn hình. |

#### Sản phẩm bàn giao cuối tuần 1

- Danh sách chức năng cuối cùng, không còn yêu cầu mâu thuẫn.
- Figma có design system, component và prototype các luồng chính.
- Danh sách màn hình và trạng thái UI đầy đủ.
- SRS, database schema, architecture blueprint và phân công được duyệt.
- Backlog tuần 2–3 có người phụ trách và Definition of Done.

**Điều kiện chuyển sang tuần 2:** không bắt đầu code một feature khi user flow, dữ liệu đầu vào/đầu ra và acceptance criteria của feature đó chưa được chốt.

### Tuần 2 — Xây dựng chức năng cốt lõi

#### Mục tiêu chung

- Khởi tạo Flutter project, Firebase, theme, router và state management.
- Xây dựng các CRUD chính và luồng Plan–Schedule–Done bằng dữ liệu thật.
- Hoàn thành Security Rules nền và các repository contracts dùng chung.

#### Phân công

| Thành viên | Công việc tuần 2 |
|---|---|
| TV1 | Authentication; Profile CRUD; WeightEntry CRUD; BMI; khung Dashboard/Reports/Streak bằng mock rồi nối dữ liệu sẵn có. |
| TV2 | Exercise Library; tìm kiếm/lọc/yêu thích; PersonalExercise CRUD; Admin CRUD cơ bản; seed bài tập mẫu. |
| TV3 | WorkoutPlan CRUD; WorkoutSchedule once/weekly; occurrence theo ngày; Done form; WorkoutCompletion CRUD và volume. |
| Cả nhóm | Tích hợp auth UID, ExerciseSnapshot và Completion contracts; hoàn thiện loading/empty/error cho luồng cốt lõi. |

#### Sản phẩm bàn giao cuối tuần 2

- Người dùng đăng nhập, quản lý hồ sơ và cân nặng được.
- Người dùng xem/tìm/lọc bài mẫu và quản lý bài cá nhân được.
- Người dùng tạo kế hoạch, xếp lịch, bấm Done, nhập kết quả và lưu completion được.
- Completion lưu snapshot, tính volume đúng và không tạo trùng do double tap.
- Firebase Security Rules bảo vệ dữ liệu theo UID và quyền admin cơ bản.

### Tuần 3 — Tích hợp, chức năng nâng cao và bàn giao

#### Mục tiêu chung

- Nối dữ liệu completion vào Dashboard, Reports, Streak, PR và Muscle Balance.
- Hoàn thiện Reminder và Readiness Adjustment.
- Kiểm thử, sửa lỗi, tối ưu responsive và hoàn thiện tài liệu.

#### Phân công

| Thành viên | Công việc tuần 3 |
|---|---|
| TV1 | Hoàn thiện Dashboard, Reports, Login/Workout Streak và streak reminder; test BMI, report và streak. |
| TV2 | Hoàn thiện PR, Muscle Balance và Admin/Security Rules; test filter, record và muscle workload. |
| TV3 | Hoàn thiện plan reminder, Readiness Wizard, rule engine, adjusted snapshot và luồng Readiness → Done; test plan, schedule, completion và readiness. |
| Cả nhóm | Integration test, Rules test, offline/error states, kiểm tra 360×800 và 412×915, format/analyze/test, README, test matrix, báo cáo và video demo. |

#### Mốc kiểm soát

- **Giữa tuần 3:** feature freeze; không bổ sung chức năng mới.
- **Cuối tuần 3:** có release candidate chạy trên Android, `flutter analyze` sạch và test cốt lõi đạt.

#### Quy tắc cắt giảm khi chậm tiến độ

Giữ bắt buộc: Authentication → Exercise Library → Plan/Schedule → Done/Completion → Dashboard cơ bản → Security Rules và correctness tests.

Cắt giảm theo thứ tự:

1. Animation, dark theme và song ngữ.
2. Upload ảnh nâng cao; dùng ảnh mặc định.
3. Reports chỉ giữ tuần/tháng và KPI chính.
4. Muscle Balance dùng bar chart thay body map.
5. Readiness chỉ giữ giảm sets, loại xung đột sore muscle/dụng cụ và adjusted snapshot.

Không được cắt validation, chống double submit, completion snapshot, phân quyền Firebase hoặc test các quy tắc nghiệp vụ cốt lõi.


## 12. Correctness properties và nghiệm thu

1. Completion không sửa plan gốc.
2. Sửa plan không đổi completion snapshot.
3. Volume chỉ tính completed set và không âm.
4. Một occurrence chỉ có tối đa một completion.
5. Login streak tăng tối đa một lần/ngày.
6. Readiness không tăng sets hoặc sửa plan.
7. Muscle balance chỉ tính completed sets đúng khoảng lọc.
8. User A không truy cập dữ liệu User B; user thường không ghi bài mẫu.

Nghiệm thu khi app chạy Android, luồng Must hoạt động, state lỗi/rỗng/tải đầy đủ, Rules/test đạt, analyze sạch và có README/Figma/schema/test matrix/phân công.
