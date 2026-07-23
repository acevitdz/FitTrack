# FitTrack — Ứng dụng quản lý luyện tập

FitTrack là ứng dụng Android được xây dựng bằng Flutter và Dart, giúp người dùng quản lý bài tập, lập lịch luyện tập, ghi nhận kết quả thực tế và theo dõi tiến độ cá nhân. Ứng dụng hướng đến trải nghiệm đơn giản: người dùng chuẩn bị kế hoạch trên app, tự tập bên ngoài app, sau đó bấm **Done** và nhập kết quả thực tế.

Điểm nổi bật của FitTrack là **Readiness Adjustment** — điều chỉnh một bản sao của buổi tập dựa trên năng lượng, đau/mỏi, thời gian và dụng cụ hiện có. Việc điều chỉnh sử dụng quy tắc minh bạch, hiển thị lý do và không làm thay đổi kế hoạch gốc.

## 1. Mục tiêu dự án

- Áp dụng kiến thức Dart, Flutter, Material 3, form, navigation và quản lý trạng thái.
- Xây dựng ứng dụng có xác thực, CRUD, cơ sở dữ liệu và phân quyền người dùng.
- Hỗ trợ người dùng lập kế hoạch và theo dõi kết quả luyện tập thực tế.
- Trực quan hóa tiến độ bằng dashboard, biểu đồ, báo cáo và bản đồ nhóm cơ.
- Tổ chức mã nguồn theo feature-first kết hợp phân tầng để dễ phát triển theo nhóm.

## 2. Đối tượng sử dụng

- **Khách:** đăng ký, đăng nhập và yêu cầu đặt lại mật khẩu.
- **Người dùng:** quản lý hồ sơ, bài tập, kế hoạch, kết quả và tiến độ của chính mình.
- **Quản trị viên:** thêm, sửa, ẩn hoặc hiện bài tập mẫu trong thư viện chung.

## 3. Luồng hoạt động chính

```text
Mở ứng dụng
    ↓
Đăng ký hoặc đăng nhập
    ↓
Cập nhật thông tin ban đầu
(hồ sơ → chỉ số cơ thể → mục tiêu luyện tập)
    ↓
Dashboard
    ↓
Chọn hoặc tạo bài tập
    ↓
Tạo kế hoạch → cấu hình sets/reps/mức tạ/nghỉ → xếp lịch
    ↓
Readiness Adjustment (tùy chọn)
    ↓
Người dùng tự luyện tập bên ngoài ứng dụng
    ↓
Bấm Done → nhập sets/reps/mức tạ/thời gian thực tế → lưu kết quả
    ↓
Cập nhật Dashboard, báo cáo, chuỗi hoạt động, kỷ lục và bản đồ nhóm cơ
```

FitTrack **không triển khai** Active Workout, Rest Timer, Pause hoặc Resume. Trạng thái hoàn thành thuộc một lần xuất hiện của lịch tập theo ngày, không thuộc toàn bộ kế hoạch.

## 4. Chức năng chính

### 4.1. Quản lý tài khoản

- Đăng ký bằng họ tên, email và mật khẩu.
- Đăng nhập và duy trì phiên đăng nhập.
- Gửi email đặt lại mật khẩu.
- Đăng xuất và bảo vệ các màn hình yêu cầu xác thực.

### 4.2. Quản lý hồ sơ

- Xem và cập nhật thông tin cá nhân.
- Cập nhật ảnh đại diện.
- Chọn mục tiêu luyện tập.
- Đặt số buổi tập mục tiêu mỗi tuần.

### 4.3. Theo dõi chỉ số cơ thể

- Cập nhật chiều cao.
- Thêm, sửa và xóa bản ghi cân nặng.
- Tính BMI theo công thức `cân nặng (kg) / chiều cao² (m)`.
- Xem lịch sử và biểu đồ cân nặng.

> BMI chỉ mang tính tham khảo, không thay thế tư vấn y khoa.

### 4.4. Thư viện bài tập mẫu

- Xem danh sách và chi tiết bài tập.
- Tìm kiếm theo tên và lọc theo nhóm cơ.
- Xem nhóm cơ, dụng cụ, độ khó và hướng dẫn thực hiện.
- Đánh dấu hoặc bỏ đánh dấu yêu thích.

### 4.5. Kho bài tập cá nhân

- Tạo, xem, sửa và xóa bài tập cá nhân.
- Quản lý bài tự tạo, bài yêu thích và bài đã sử dụng.
- Xem số lần thực hiện và kỷ lục về mức tạ, reps hoặc volume.

### 4.6. Quản lý kế hoạch luyện tập

- Tạo, xem, sửa, sao chép và xóa kế hoạch.
- Thêm bài mẫu hoặc bài cá nhân vào kế hoạch và thay đổi thứ tự.
- Cấu hình sets, khoảng reps, mức tạ dự kiến, thời gian nghỉ và ghi chú.
- Xếp lịch một lần hoặc lặp theo các ngày trong tuần.
- Chọn ngày, giờ, thời gian bắt đầu/kết thúc và bật nhắc lịch.
- Xem lịch theo ngày với trạng thái `scheduled`, `completed`, `partial` hoặc `overdue`.
- Sau khi tập, nhập sets, reps, mức tạ, thời gian và ghi chú thực tế.
- Xem, sửa hoặc xóa kết quả của buổi đã hoàn thành.

### 4.7. Dashboard và mục tiêu

- Xem lịch tập hôm nay và tiến độ mục tiêu tuần.
- Xem tổng thời gian, tổng sets, volume và BMI gần nhất.
- Xem kỷ lục mới nhất và thông tin phục hồi/cân bằng nhóm cơ.

### 4.8. Báo cáo và thống kê

- Thống kê số buổi, sets, volume và thời gian thực tế.
- Xem các bài tập được thực hiện thường xuyên.
- Lọc dữ liệu theo tuần, tháng hoặc khoảng ngày.
- Tự cập nhật khi kết quả buổi tập được sửa hoặc xóa.

### 4.9. Chuỗi hoạt động

- Theo dõi riêng chuỗi đăng nhập và chuỗi ngày hoàn thành luyện tập.
- Hiển thị chuỗi hiện tại, chuỗi dài nhất và lịch ngày hoạt động.
- Mỗi chuỗi chỉ tăng tối đa một lần mỗi ngày.

### 4.10. Nhắc lịch tập

- Tạo local notification từ lịch tập đã cấu hình.
- Nhắc người dùng mở ứng dụng để duy trì chuỗi hoạt động.
- Hủy hoặc cập nhật thông báo khi lịch tập thay đổi.
- Nhấn thông báo để mở đúng kế hoạch liên quan.

### 4.11. Readiness Adjustment

- Thu thập mức năng lượng, mức đau/mỏi, nhóm cơ đau, thời gian và dụng cụ hiện có.
- Phân loại mức điều chỉnh: giữ nguyên, nhẹ, vừa hoặc phục hồi.
- Có thể giảm sets, bỏ bài xung đột hoặc thay bằng bài phù hợp.
- Hiển thị kế hoạch trước/sau điều chỉnh và lý do của từng thay đổi.
- Cho phép giữ kế hoạch gốc hoặc dùng snapshot đã điều chỉnh cho buổi hiện tại.
- Không sửa dữ liệu của kế hoạch gốc.

### 4.12. Bản đồ cân bằng nhóm cơ

- Tổng hợp working sets theo nhóm cơ trong tuần hoặc tháng.
- Phân biệt nhóm cơ chính và nhóm cơ phụ.
- Phân loại: chưa có dữ liệu, tập ít, cân bằng hoặc tập nhiều.
- Xem các bài tập và kết quả đóng góp cho từng nhóm cơ.

### 4.13. Quản trị bài tập mẫu

- Admin thêm và sửa bài tập mẫu.
- Cấu hình ảnh, nhóm cơ, dụng cụ, độ khó và hướng dẫn.
- Ẩn hoặc hiện bài tập trong thư viện chung.
- Phân quyền bằng Firebase Authentication và Firebase Security Rules.

## 5. Công nghệ sử dụng

| Thành phần | Công nghệ |
|---|---|
| Ngôn ngữ | Dart, null safety |
| Framework | Flutter, Material 3 |
| Thiết kế giao diện | Figma |
| Xác thực | Firebase Authentication |
| Cơ sở dữ liệu | Cloud Firestore |
| Lưu ảnh | Firebase Storage |
| Thông báo | Local Notifications |
| Quản lý trạng thái | Riverpod, Provider hoặc giải pháp thống nhất của nhóm |
| Điều hướng | Router có auth guard và admin guard |
| Biểu đồ | Thư viện biểu đồ tương thích Flutter |
| Kiểm thử | Unit test, widget test và integration test cho luồng chính |
| Nền tảng chính | Android |

## 6. Kiến trúc hệ thống

FitTrack sử dụng kiến trúc **feature-first kết hợp phân tầng**:

```text
Screen/Widget
    ↓
Controller/State
    ↓
Rule hoặc Use Case
    ↓
Repository Contract
    ↓
Repository Implementation
    ↓
Firebase hoặc dịch vụ thiết bị
```

Nguyên tắc chính:

- UI không gọi Firebase trực tiếp.
- Domain không phụ thuộc Flutter hoặc Firebase.
- Business rules được viết bằng Dart thuần để có thể unit test.
- Mỗi feature có thể chứa `data`, `domain` và `presentation`.
- `WorkoutPlan`, `WorkoutSchedule` và `WorkoutCompletion` là ba entity độc lập.
- Completion lưu snapshot để lịch sử không bị thay đổi khi bài tập hoặc kế hoạch gốc được sửa.

Cấu trúc rút gọn:

```text
lib/
├── main.dart
├── bootstrap.dart
├── app.dart
├── core/
│   ├── config/
│   ├── constants/
│   ├── errors/
│   ├── navigation/
│   ├── services/
│   ├── theme/
│   └── widgets/
├── shared/
└── features/
    ├── auth/
    ├── onboarding/
    ├── profile/
    ├── body_metrics/
    ├── exercise_library/
    ├── personal_exercises/
    ├── workout_plan/
    ├── workout_schedule/
    ├── workout_completion/
    ├── readiness/
    ├── dashboard/
    ├── reports/
    ├── streaks/
    ├── reminders/
    ├── muscle_balance/
    └── admin_exercises/
```

## 7. Mô hình dữ liệu chính

Các collection/entity dự kiến:

- `users`: hồ sơ, mục tiêu, vai trò và trạng thái onboarding.
- `weight_records`: lịch sử cân nặng theo người dùng.
- `template_exercises`: bài tập mẫu do admin quản lý.
- `personal_exercises`: bài tập cá nhân.
- `favorites`: liên kết người dùng với bài tập yêu thích.
- `workout_plans`: nội dung kế hoạch gốc.
- `workout_schedules`: quy tắc xếp lịch và nhắc lịch.
- `workout_completions`: snapshot kết quả thực tế theo occurrence/ngày.
- `readiness_snapshots`: đầu vào, kết quả và lý do điều chỉnh.
- `streaks`: chuỗi đăng nhập và chuỗi luyện tập.
- `reminders`: cấu hình local notification.

Mọi dữ liệu cá nhân phải gắn với UID của Firebase Authentication. Người dùng chỉ được đọc và sửa dữ liệu của chính mình; quyền quản trị được kiểm tra bằng role/claim và Firebase Security Rules.

## 8. Cài đặt và chạy dự án

### 8.1. Yêu cầu môi trường

- Flutter SDK phiên bản stable phù hợp với dự án.
- Dart SDK đi kèm Flutter.
- Android Studio hoặc VS Code.
- Android SDK và Android Emulator hoặc thiết bị Android thật.
- Firebase CLI và FlutterFire CLI nếu cần cấu hình lại Firebase.

### 8.2. Các bước chạy

```powershell
git clone <repository-url>
cd fittrack
flutter pub get
flutter run
```

Nếu Firebase chưa được cấu hình:

```powershell
firebase login
flutterfire configure
```

Sau đó bật các dịch vụ cần thiết trong Firebase Console:

1. Authentication với Email/Password.
2. Cloud Firestore.
3. Firebase Storage nếu sử dụng ảnh đại diện hoặc ảnh bài tập.
4. Triển khai `firestore.rules`, `storage.rules` và indexes cần thiết.

> Không commit API key bí mật, tài khoản thật, mật khẩu, file service account hoặc dữ liệu sức khỏe thật vào Git.

## 9. Kiểm tra chất lượng

Chạy các lệnh sau trước khi tạo Pull Request:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

Các nhóm test ưu tiên:

- Validation đăng ký, đăng nhập và biểu mẫu.
- Công thức BMI và tổng hợp volume.
- Quy tắc Readiness Adjustment.
- Tạo occurrence từ lịch một lần hoặc lặp hằng tuần.
- Lưu completion và ngăn trùng kết quả cùng occurrence.
- Tính báo cáo, streak, kỷ lục và working sets theo nhóm cơ.
- Widget test cho loading, empty, error và success state.

## 10. Phân công nhóm

| Thành viên | Phạm vi chính | CRUD chính |
|---|---|---|
| Lê Tiến Hải | Tài khoản, hồ sơ, chỉ số cơ thể, dashboard, báo cáo và chuỗi hoạt động | Hồ sơ và bản ghi cân nặng |
| Minh Thắng | Thư viện bài mẫu, kho bài cá nhân, bản đồ nhóm cơ và quản trị bài mẫu | Bài tập mẫu và bài tập cá nhân |
| Võ Việt Anh | Kế hoạch, xếp lịch, kết quả, nhắc lịch và Readiness Adjustment | Kế hoạch, lịch tập và kết quả |

## 11. Quy trình Git

- Nhánh ổn định: `main`.
- Nhánh tích hợp: `develop`.
- Mỗi thành viên làm việc trên feature branch riêng, ví dụ `feature/auth-profile` hoặc `feature/workout-plan`.
- Không code trực tiếp trên `main` và `develop`.
- Mỗi Pull Request cần mô tả thay đổi, ảnh giao diện và kết quả kiểm tra.
- Đồng bộ `develop` thường xuyên để xử lý xung đột sớm.
- Chỉ merge vào `main` khi bản tích hợp đã được kiểm tra.

## 12. Kế hoạch phát triển trong 3 tuần

### Tuần 1 — Chốt chức năng và giao diện

- Thống nhất phạm vi, actor, yêu cầu và tiêu chí nghiệm thu.
- Hoàn thiện user flow, wireframe và giao diện Figma.
- Chốt design system, navigation và trạng thái màn hình.
- Thiết kế entity, Firestore schema và repository contracts ở mức tài liệu.
- Khởi tạo Flutter/Firebase, cấu trúc thư mục và Git workflow.

### Tuần 2 — Xây dựng chức năng cốt lõi

- Thành viên 1: auth, onboarding, profile và body metrics.
- Thành viên 2: thư viện bài tập, yêu thích và bài cá nhân.
- Thành viên 3: kế hoạch, xếp lịch, Done và lưu completion.
- Tích hợp Firestore, Storage, Security Rules và kiểm tra CRUD.

### Tuần 3 — Tích hợp, chức năng nâng cao và hoàn thiện

- Hoàn thiện dashboard, báo cáo, streak, reminder, Readiness và muscle balance.
- Tích hợp các feature qua `develop` và xử lý xung đột.
- Chạy format, analyze, test và kiểm thử luồng đầu-cuối.
- Sửa lỗi, tối ưu giao diện, bổ sung trạng thái rỗng/lỗi/loading.
- Chuẩn bị dữ liệu demo, tài khoản demo, video và tài liệu thuyết trình.

## 13. Tài liệu liên quan

- [Đặc tả yêu cầu hệ thống](./FitTrack_System_Requirements_Specification.md)
- [Đặc tả chức năng và UI](./FitTrack_Dac_ta_chuc_nang_UI.md)


## 14. Trạng thái dự án

Dự án đang ở giai đoạn thiết kế và chuẩn bị triển khai. README này là tài liệu tổng quan; khi code được hoàn thiện, nhóm cần cập nhật thêm:

- Link repository và bản thiết kế Figma.
- Phiên bản Flutter/Dart chính xác.
- Danh sách dependency thực tế.
- Ảnh chụp màn hình hoặc video demo.
- Tài khoản demo và hướng dẫn build APK.
- Các giới hạn hoặc lỗi đã biết.




