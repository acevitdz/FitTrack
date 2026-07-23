# FITTRACK — ĐẶC TẢ CHỨC NĂNG VÀ QUY TẮC NGHIỆP VỤ

## 1. Phạm vi đã chốt

FitTrack là ứng dụng Android bằng Flutter/Dart hỗ trợ lập kế hoạch, xếp lịch, ghi kết quả sau khi tập và theo dõi tiến độ. Người dùng **không theo dõi trực tiếp trong lúc tập**; hệ thống không có Active Workout, Rest Timer, Pause hoặc Resume.

Luồng trung tâm:

```text
WorkoutPlan → WorkoutSchedule → Readiness (tùy chọn)
→ Người dùng tự tập → Bấm Done → Nhập kết quả thực tế
→ WorkoutCompletion → Dashboard/Báo cáo/Streak/Muscle Balance
```

Ba đối tượng không được trộn lẫn:

- `WorkoutPlan`: nội dung dự kiến có thể tái sử dụng.
- `WorkoutSchedule`: ngày/giờ áp dụng kế hoạch.
- `WorkoutCompletion`: kết quả thực tế và snapshot khi bấm Done.

## 2. Vai trò

- **Khách:** đăng ký, đăng nhập, quên mật khẩu.
- **Người dùng:** quản lý toàn bộ dữ liệu cá nhân của chính mình và đọc bài mẫu đang hoạt động.
- **Admin:** thêm, sửa, ẩn/hiện bài mẫu; không mặc nhiên được đọc dữ liệu sức khỏe của người khác.

## 3. Quy tắc chung

- Dữ liệu cá nhân phải gắn với `FirebaseAuth.currentUser.uid`.
- Mọi màn hình bất đồng bộ có `loading`, `success`, `empty`, `error` và retry phù hợp.
- Form có validation, trạng thái submitting và chống double tap.
- ID ổn định; không dùng vị trí danh sách làm ID.
- Thời gian đồng bộ quan trọng dùng server timestamp.
- Xóa dữ liệu quan trọng phải xác nhận.
- Không truy vấn Firebase trực tiếp trong `build()`.
- Không lưu secret hoặc dữ liệu sức khỏe thật trong repository công khai.

---

# 4. Đặc tả 13 chức năng

## 4.1. Quản lý tài khoản

### Chức năng

- Đăng ký bằng email/mật khẩu.
- Đăng nhập, duy trì phiên và đăng xuất.
- Gửi email đặt lại mật khẩu.

### Quy tắc

- Email được trim và đúng định dạng.
- Mật khẩu tối thiểu 8 ký tự; xác nhận mật khẩu phải trùng.
- Không làm lộ việc một email có tồn tại hay không qua thông báo quá chi tiết.
- Người đã đăng nhập mở lại app được chuyển vào Dashboard.
- Sau đăng xuất không thể quay Back vào route riêng tư.

### Giao diện

- Splash, Login, Register, Forgot Password và trạng thái gửi email thành công.

## 4.2. Quản lý hồ sơ

### Chức năng

- Cập nhật họ tên, ngày sinh, giới tính và avatar.
- Chọn mục tiêu giảm cân/tăng cơ/duy trì.
- Đặt số buổi mục tiêu mỗi tuần.

### Quy tắc

- Họ tên không rỗng; ngày sinh không ở tương lai.
- Mục tiêu tuần là số nguyên 1–7.
- Avatar phải được kiểm tra định dạng/kích thước.
- Thoát form chưa lưu phải xác nhận.

### Giao diện

- Initial Profile Setup, Profile và Edit Profile.

## 4.3. Theo dõi chỉ số cơ thể

### Chức năng

- Cập nhật chiều cao.
- CRUD bản ghi cân nặng.
- Tính BMI và hiển thị biểu đồ cân nặng.

### Quy tắc

- Chiều cao/cân nặng là số dương trong phạm vi cấu hình.
- Ngày cân không ở tương lai.
- `BMI = kg / m²`; chỉ làm tròn khi hiển thị và ghi rõ “mang tính tham khảo”.
- Cân nặng hiện tại là bản ghi có thời điểm mới nhất.
- Biểu đồ sắp xếp tăng dần theo thời gian.

### Giao diện

- Body Metrics, Weight Entry Form, Weight History/Chart và xác nhận xóa.

## 4.4. Thư viện bài tập mẫu

### Chức năng

- Xem danh sách/chi tiết, tìm theo tên, lọc nhóm cơ và yêu thích.

### Quy tắc

- Tìm kiếm không phân biệt hoa/thường và trim từ khóa.
- Bộ lọc có thể kết hợp và đặt lại.
- User chỉ đọc bài `isActive == true`.
- Bài bị ẩn không làm mất snapshot trong kế hoạch/kết quả cũ.

### Giao diện

- Exercise Library, Exercise Detail và Filter Bottom Sheet.

## 4.5. Kho bài tập cá nhân

### Chức năng

- CRUD bài tự tạo; xem bài tự tạo/yêu thích/đã dùng.
- Xem số lần tập, lần gần nhất và PR về weight/reps/volume.

### Quy tắc

- Bài cá nhân chỉ thuộc một UID.
- Chỉ completed set trong completion hợp lệ được tính PR.
- Một bài nhiều set trong cùng completion chỉ tăng tần suất buổi một lần.
- Xóa bài không xóa snapshot lịch sử.

### Giao diện

- Personal Exercise Library, Personal Exercise Form và Exercise Progress.

## 4.6. Quản lý kế hoạch luyện tập

### 4.6.1. WorkoutPlan

- CRUD kế hoạch; sao chép phải tạo ID mới.
- Thêm bài mẫu/cá nhân; sắp xếp thứ tự.
- Cấu hình target sets, min/max reps, target weight, rest seconds và note.

Quy tắc:

- Tên không rỗng; có ít nhất một bài.
- Sets/reps dương; `minReps <= maxReps`; weight/rest không âm.
- `WorkoutPlan` không có `isDone`.

### 4.6.2. WorkoutSchedule

Ba lựa chọn:

- Chưa xếp lịch.
- Một ngày cụ thể (`once`).
- Lặp theo các ngày trong tuần (`weekly`).

Quy tắc:

- Once yêu cầu `scheduledDate`.
- Weekly yêu cầu ít nhất một weekday và `startDate`; `endDate >= startDate` nếu có.
- Một plan có thể có nhiều schedule.
- Sửa/xóa schedule tương lai không thay đổi completion cũ.
- Trạng thái occurrence được tính: scheduled, completed, partial, overdue; không lưu `overdue` cố định.

### 4.6.3. Done và WorkoutCompletion

Sau khi tự tập, người dùng bấm Done và nhập:

- Actual sets, reps, weight.
- Completed checkbox cho từng set.
- Set thêm, bài bỏ qua, thời gian, perceived difficulty và note.

Quy tắc:

- Form khởi tạo từ plan hoặc adjusted snapshot.
- Chỉ completed set được tính `reps × weight` vào volume.
- Có ít nhất một completed set mới được lưu.
- Nếu có bài bị bỏ qua: `partiallyCompleted`; nếu mọi bài có completed set: `completed`.
- Completion lưu plan snapshot; không sửa plan gốc.
- Không tạo hai completion cho cùng `userId + scheduleId + occurrenceDate`.
- Sửa/xóa completion phải làm mới report, streak, PR và muscle balance.

### Giao diện

- Plan List theo ngày.
- Plan Detail.
- Plan Form bước nội dung.
- Plan Form bước xếp lịch.
- Exercise Selection.
- Workout Result Form.
- Completion Summary/Success.
- Completion History/Detail/Edit/Delete.

## 4.7. Dashboard và mục tiêu

### Chức năng

- Lịch hôm nay, tiến độ tuần, thời gian, sets, volume, BMI và PR gần nhất.

### Quy tắc

- Chỉ completion completed/partial được tính.
- Tuần mặc định thứ Hai–Chủ Nhật.
- Thanh tiến độ giới hạn hiển thị 100% nhưng số liệu có thể vượt mục tiêu.
- Một card lỗi không làm khóa cả Dashboard.

### Giao diện

- Dashboard với Today Plan, Weekly Goal, Metric Grid, Streak và Muscle Preview.

## 4.8. Báo cáo và thống kê

### Chức năng

- Lọc tuần/tháng; thống kê số buổi, sets, volume, thời gian và bài thường tập.

### Quy tắc

- Dùng dữ liệu từ `WorkoutCompletion`, không dùng plan dự kiến.
- Khoảng bắt đầu không sau kết thúc.
- Không cộng trùng; sửa/xóa completion cập nhật kết quả.
- Không có dữ liệu phải dùng empty state, không vẽ chart gây hiểu nhầm.

### Giao diện

- Report Filter, KPI Cards, Charts, Top Exercises và Workout History.

## 4.9. Chuỗi hoạt động

### Login streak

- Một UID chỉ có một active day/ngày theo `Asia/Ho_Chi_Minh`.
- Ngày kế tiếp tăng; bỏ ngày thì lần sau về 1.
- `longestStreak >= currentStreak` và không giảm.

### Workout streak

- Chỉ ngày có completion hợp lệ mới tính.
- Nhiều completion cùng ngày chỉ đóng góp một ngày.
- Xóa completion phải tính lại.

### Giao diện

- Streak Detail với hai section/tab và heatmap có legend.

## 4.10. Nhắc lịch tập

### Nhắc kế hoạch

- Đăng ký local notification từ schedule; sửa/xóa lịch phải hủy notification cũ.
- Nhấn notification mở đúng plan.

### Nhắc duy trì streak

- Lên lịch nhắc local nếu người dùng chưa mở app trong ngày; hủy khi đã check-in trên thiết bị.
- Đây là reminder cục bộ, không cam kết đồng bộ tuyệt đối đa thiết bị.

### Giao diện

- Permission Card, Reminder List/Form, trạng thái denied và nút mở Settings.

## 4.11. Điều chỉnh theo mức sẵn sàng

### Đầu vào

- Energy 1–5, soreness 1–5, sore muscles, available minutes và equipment.

### Quy tắc MVP

- Energy 4–5 và soreness 1–2: giữ nguyên.
- Energy 3 hoặc soreness 3: giảm nhẹ sets.
- Energy 2 hoặc soreness 4: giảm vừa.
- Energy 1 hoặc soreness 5: đề xuất recovery/nghỉ.
- Loại bài có primary muscle xung đột soreness cao.
- Loại bài cần dụng cụ không có.
- Giảm bài phụ/sets để khớp thời gian.
- Tạo `AdjustedPlanSnapshot`, không sửa `WorkoutPlan`.
- Hiển thị thay đổi và lý do; người dùng được giữ plan gốc.

### Giao diện

- Readiness Wizard, Evaluating và Adjustment Comparison.

## 4.12. Bản đồ cân bằng nhóm cơ

### Chức năng

- Tổng hợp working sets theo tuần/tháng; xem chi tiết nhóm cơ.

### Quy tắc

- Chỉ completed set trong completion hợp lệ được tính.
- Primary muscle nhận 1 set; secondary có thể nhận 0,5 nếu bật trọng số.
- Phân loại bằng ngưỡng cấu hình: chưa tập, ít, cân bằng, nhiều.
- Không có dữ liệu thì hiển thị neutral, không kết luận mất cân bằng.
- Chỉ mang tính tham khảo.

### Giao diện

- Muscle Balance dạng bar/card ưu tiên; Muscle Detail và legend không chỉ dựa vào màu.

## 4.13. Quản trị bài tập mẫu

### Chức năng

- Admin thêm, sửa, upload ảnh và ẩn/hiện bài mẫu.

### Quy tắc

- Quyền admin được kiểm tra trong Security Rules, không chỉ ẩn nút UI.
- User thường không thể ghi collection bài mẫu.
- Dùng soft delete/`isActive`, giữ snapshot lịch sử.

### Giao diện

- Admin Exercise List và Admin Exercise Form.

---

# 5. Phân công nhóm đã chốt

## Thành viên 1 — chức năng 1, 2, 3, 7, 8, 9

- Authentication, Profile, Body Metrics, Dashboard, Reports và Streaks.
- CRUD chính: Profile và WeightEntry.

## Thành viên 2 — chức năng 4, 5, 12, 13

- Exercise Library, Personal Exercises, Muscle Balance và Admin Exercises.
- CRUD chính: TemplateExercise và PersonalExercise.

## Thành viên 3 — chức năng 6, 10, 11

- Plan, Schedule, Done/Completion, Reminder infrastructure và Readiness.
- CRUD chính: WorkoutPlan, WorkoutSchedule và WorkoutCompletion.

## Điểm tích hợp

- TV3 cung cấp completion cho Dashboard/Reports/Streak của TV1.
- TV3 cung cấp completed sets cho PR/Muscle Balance của TV2.
- TV2 cung cấp ExerciseSnapshot cho Plan/Readiness của TV3.
- TV1 cung cấp auth UID/profile cho toàn hệ thống.

# 6. Correctness properties tối thiểu

1. Completion không thay đổi plan gốc.
2. Sửa plan không thay đổi completion snapshot.
3. Volume chỉ tính completed set và không âm.
4. Một schedule occurrence chỉ có tối đa một completion.
5. Login streak tăng tối đa một lần/ngày.
6. Readiness không tăng sets và không sửa plan.
7. Bài xung đột sore muscle cao không xuất hiện trong adjusted snapshot.
8. Người dùng A không đọc/sửa dữ liệu riêng của B.
9. User thường không ghi được bài mẫu.
10. Muscle balance chỉ dùng completed sets trong khoảng lọc.

