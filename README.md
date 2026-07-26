# FitTrack

FitTrack là ứng dụng Flutter hỗ trợ người dùng luyện tập theo chương trình có
sẵn. Thay vì yêu cầu người dùng tự tạo kế hoạch, tự xếp lịch và nhập lại kết
quả bằng nhiều biểu mẫu, ứng dụng chọn một chương trình phù hợp, tạo lịch tập,
hướng dẫn từng hiệp và tự tổng hợp những gì người dùng đã xác nhận trong buổi
tập.

Tài liệu này mô tả đúng trạng thái mã nguồn hiện có tại ngày 26/07/2026. Những
phần còn cần kiểm thử trên thiết bị hoặc cần backend xử lý được ghi rõ ở phần
giới hạn, không được xem là chức năng đã sẵn sàng để phát hành.

## 1. Người dùng có thể làm gì?

### Tài khoản

Người dùng có thể đăng ký bằng họ tên, email và mật khẩu; đăng nhập; đăng xuất;
và yêu cầu gửi email đặt lại mật khẩu. Màn hình đăng ký yêu cầu xác nhận mật
khẩu và đồng ý với điều khoản. Hai nút Google và Facebook hiện chỉ hiển thị
thông báo chưa hỗ trợ, chưa có đăng nhập mạng xã hội.

Khi Firebase hoạt động, phiên đăng nhập sử dụng Firebase Authentication và dữ
liệu riêng được phân tách theo UID. Nếu Firebase không khởi tạo được, ứng dụng
chuyển sang chế độ dữ liệu cục bộ để nhóm có thể chạy thử giao diện và luồng
nghiệp vụ; chế độ này không thay thế cơ chế xác thực thật.

### Thiết lập ban đầu

Người đăng ký mới đi qua ba bước:

1. Nhập tên hiển thị và xác nhận nhóm người dùng được hỗ trợ.
2. Nhập chiều cao, cân nặng và chọn hệ đơn vị `cm/kg` hoặc `in/lb`.
3. Chọn mục tiêu, số buổi mỗi tuần, kinh nghiệm, dụng cụ và ưu tiên nội dung.

Chiều cao và cân nặng được chuẩn hóa về `cm/kg`. BMI được tính tự động và chỉ
được trình bày như một chỉ số tham khảo. Nếu người dùng chọn nhóm nằm ngoài
phạm vi người trưởng thành khỏe mạnh 18–64 tuổi, bộ ghép chương trình sẽ không
tự gán chương trình không phù hợp.

### Chương trình và lịch tập

`ProgramMatcher` chỉ xét những phiên bản chương trình đang ở trạng thái
`published`. Việc ghép chương trình dựa trên nhóm người dùng, mục tiêu, kinh
nghiệm và dụng cụ; ưu tiên nội dung và số buổi mỗi tuần được dùng để xếp hạng.
Fallback được phép nới mục tiêu nhưng vẫn phải giữ các điều kiện an toàn,
kinh nghiệm và dụng cụ.

Khi tìm được chương trình, ứng dụng tạo `ProgramEnrollment` và danh sách
`WorkoutOccurrence` theo cadence của phiên bản đó. Enrollment được ghim vào
một `ProgramVersion`, vì vậy lịch sử không bị thay đổi khi catalog có phiên bản
mới. Người dùng có thể:

- xem toàn bộ tuần, buổi, block và prescription ở chế độ chỉ đọc;
- xem phiên bản, nội dung an toàn và nguồn tham khảo;
- dời một buổi sang ngày trống tiếp theo;
- bỏ qua một buổi sau khi xác nhận;
- chọn mức sẵn sàng cho buổi hôm nay.

Ba lựa chọn readiness hiện có là **Sung sức**, **Hơi mệt (Giảm tải)** và
**Cần nghỉ ngơi**. Mỗi lựa chọn dùng một biến thể nội dung đã có trong phiên
bản chương trình; ứng dụng không tự sinh prescription mới.

### Active Workout

Buổi tập được thực hiện bằng một state machine rõ ràng:

```text
preparing → working ↔ resting → finishing → completed
                 ↘ paused ↗
preparing/working/resting/paused → discarded
```

Trong một buổi tập, người dùng có thể:

- xem bài hiện tại, mục tiêu, số hiệp, gợi ý kỹ thuật và thời gian đã tập;
- xác nhận hoàn thành hiệp;
- làm lại một hiệp mà không di chuyển con trỏ;
- bỏ qua hiệp với một lý do được chọn;
- nghỉ theo thời gian đã cấu hình, cộng thêm 15 giây hoặc kết thúc nghỉ sớm;
- tạm dừng rồi tiếp tục;
- kết thúc sớm và lưu phần đã thực hiện;
- bỏ buổi tập và xóa bản nháp.

Sau mỗi chuyển trạng thái quan trọng, draft được lưu theo UID trong
`SharedPreferences`. Nếu ứng dụng bị đóng khi buổi tập chưa kết thúc, thẻ
**Tiếp tục buổi tập** xuất hiện ở Trang chủ. Completion dùng idempotency key
để thao tác lưu lại không tạo bản ghi trùng.

### Guided Confirmation và AI Camera Coach

Guided Confirmation là chế độ mặc định và hoạt động trên cả Android lẫn Web.
Người dùng xác nhận hiệp bằng nút; chế độ này không tự suy ra số lần lặp,
confidence hoặc mức tạ.

AI Camera Coach hiện là MVP dành cho bài **Squat trên Android**. Camera gửi
khung hình tạm thời tới Google ML Kit Pose Detection, sau đó `PoseRuleEngine`
đánh giá các mốc vai, hông, gối và cổ chân để nhận biết chu kỳ squat. Giao diện
hiển thị số lần lặp, trạng thái nhìn thấy cơ thể và các gợi ý như đứng thẳng,
hạ thấp thêm hoặc cải thiện ánh sáng.

AI Camera Coach sẽ chuyển về Guided Confirmation khi:

- chạy trên Web hoặc nền tảng chưa hỗ trợ;
- bài tập không phải Squat hoặc không có rule `squat_pose_v1`;
- người dùng từ chối quyền camera;
- không có camera, model lỗi hoặc kết quả không chắc chắn kéo dài;
- người dùng chủ động tắt camera.

Khung hình, video và landmark không được lưu trong state hoặc tải lên Firebase.
Dữ liệu đếm lần và confidence chỉ được gắn vào sự kiện của hiệp khi chế độ AI
thực sự hoàn thành hiệp đó.

### Tiến độ và chỉ số cơ thể

Khu vực **Tiến độ** cho phép chọn báo cáo 7 ngày, 30 ngày hoặc toàn bộ thời
gian. Màn hình tổng hợp số buổi, thời gian, số hiệp hoàn tất, độ chuyên cần,
bài tập xuất hiện nhiều nhất, phân bổ nhóm cơ và chi tiết từng completion.
Completion lưu snapshot của buổi tập, phiên bản nội dung, nguồn tham khảo và
chế độ xác nhận.

Khu vực **Chỉ số cơ thể** cho phép tạo lần đo mới với chiều cao và cân nặng,
hiển thị BMI, biểu đồ cân nặng trong 7 hoặc 30 ngày và lịch sử đo. Ứng dụng theo
dõi riêng hai loại chuỗi:

- chuỗi ngày cập nhật chỉ số cơ thể;
- chuỗi ngày hoàn thành buổi tập.

Nhiều lần cập nhật trong cùng một ngày chỉ được tính là một ngày hoạt động.

### Thư viện bài tập

Người dùng có thể tìm bài tập theo tên tiếng Việt hoặc tiếng Anh, lọc theo
nhóm cơ, mở trang chi tiết và đánh dấu yêu thích. Trang chi tiết trình bày mô
tả, dụng cụ, độ khó, các bước thực hiện và lỗi thường gặp.

Thư viện của người dùng là nội dung chỉ đọc. Người dùng không có nút tạo bài
tập cá nhân, thêm bài vào kế hoạch hoặc sửa prescription.

### Hồ sơ và cài đặt

Người dùng có thể:

- đổi tên hiển thị và ảnh đại diện;
- thay đổi lựa chọn chương trình rồi yêu cầu ghép lại;
- chọn giao diện hệ thống, sáng hoặc tối;
- chọn hệ đơn vị;
- bật hoặc tắt Voice Coach và phản hồi rung;
- bật nhắc lịch, chọn giờ nhắc và chọn trước 0, 15, 30 hoặc 60 phút;
- xem thành tích;
- gửi yêu cầu xuất dữ liệu;
- gửi yêu cầu xóa tài khoản và đăng xuất;
- xem giải thích về quyền riêng tư, camera và giới hạn sức khỏe.

Voice Coach dùng Text-to-Speech tiếng Việt qua Android MethodChannel. Thông báo
cục bộ nhắc buổi tập và báo hết giờ nghỉ cũng đang được triển khai cho Android.
Nếu người dùng không cấp quyền, buổi tập vẫn hoạt động bình thường.

### Dữ liệu phiên bản cũ

Model kế hoạch thủ công, lịch thủ công và completion cũ vẫn được giữ để đọc dữ
liệu đã có. Màn hình **Dữ liệu phiên bản cũ** chỉ cho xem; các hàm tạo, sửa,
xóa hoặc sao chép dữ liệu legacy đều bị chặn trong AppState.

## 2. Điều hướng hiện tại

Sau khi đăng nhập và hoàn thành onboarding, thanh điều hướng có bốn khu vực:

| Khu vực | Nội dung |
|---|---|
| Trang chủ | Buổi hôm nay, readiness, resume, tiến độ tuần và cảnh báo offline |
| Chương trình | Phiên bản đang theo, các tuần, buổi, block và nguồn |
| Tiến độ | Báo cáo, streak, heatmap, Body Metrics và lịch sử completion |
| Hồ sơ | Thư viện, tùy chọn chương trình, cài đặt và quyền riêng tư |

Splash screen, đăng nhập và onboarding nằm ngoài thanh điều hướng này.

## 3. Nền tảng và mức hỗ trợ

| Khả năng | Android | Web |
|---|---:|---:|
| Luồng tài khoản và dữ liệu Firebase | Có | Có |
| Guided Confirmation | Có | Có |
| AI Camera Coach Squat | Có code path, cần QA thiết bị | Không, tự fallback |
| Voice Coach | Có code path, cần QA thiết bị | Không |
| Local notification và rest notification | Có code path, cần QA thiết bị | Không |
| Theme, chương trình, tiến độ và Body Metrics | Có | Có |

Repository hiện có thư mục nền tảng `android/` và `web/`. iOS chưa được cấu
hình trong project và `firebase_options.dart` cũng chưa có cấu hình iOS.

## 4. Công nghệ chính

- Flutter, Dart và Material 3.
- Firebase Authentication, Cloud Firestore, Firebase Storage và Firebase
  Messaging.
- `shared_preferences` cho snapshot cục bộ và draft buổi tập.
- `camera` và Google ML Kit Pose Detection cho Camera Coach Android.
- `flutter_local_notifications` và `timezone` cho lịch nhắc.
- Android Text-to-Speech qua MethodChannel cho Voice Coach.
- `fl_chart` cho biểu đồ.
- `intl` cho định dạng ngày tiếng Việt.

## 5. Cấu trúc mã nguồn

Project đang dùng cấu trúc phân tầng trực tiếp:

```text
FitTrack/
├── android/                 # Cấu hình và mã native Android
├── web/                     # Bootstrap Flutter Web
├── lib/
│   ├── data/                # Catalog và dữ liệu seed
│   ├── models/              # Model chương trình, workout, hồ sơ và sức khỏe
│   ├── screens/             # Các màn hình theo nhóm chức năng
│   ├── services/            # Firebase, local store, notification, pose, TTS
│   ├── state/               # AppState và nghiệp vụ điều phối toàn ứng dụng
│   ├── theme/               # Màu sắc và theme sáng/tối
│   ├── widgets/             # Widget dùng lại và Camera Coach panel
│   ├── app.dart             # Chọn màn hình theo auth/onboarding state
│   ├── firebase_options.dart
│   └── main.dart            # Khởi tạo Firebase, locale, notification và state
├── test/
├── firestore.rules
├── storage.rules
└── pubspec.yaml
```

`AppState` là `ChangeNotifier` trung tâm, vừa giữ state vừa điều phối các
service. Những luật cần kiểm thử độc lập được tách riêng, gồm
`ProgramMatcher`, `ActiveWorkoutController` và `PoseRuleEngine`.

## 6. Dữ liệu và đồng bộ

Khi Firebase khả dụng, snapshot tài khoản được lưu tại:

```text
users/{uid}/appState/current
```

Catalog bài tập, chương trình và phiên bản dùng các collection cấp cao riêng.
Ảnh đại diện nằm dưới đường dẫn Storage của UID; media catalog chỉ được ứng
dụng người dùng đọc.

Ứng dụng đồng thời giữ một cache cục bộ theo UID. Cache giúp mở lại dữ liệu gần
nhất khi mất mạng, nhưng project chưa có hàng đợi đồng bộ bền vững hoặc cơ chế
giải quyết xung đột hai chiều. Khi đồng bộ cloud thất bại, bản cục bộ được giữ
lại và ứng dụng tiếp tục hoạt động.

Firestore Rules hiện kiểm tra UID và chỉ cho ứng dụng đọc catalog đang
active/published. Client không được ghi catalog. Storage Rules giới hạn ảnh
người dùng dưới 5 MB và chỉ cho đọc media gắn với nội dung đã phát hành. Các
rules này vẫn cần được kiểm thử bằng Firebase Emulator trước khi xem là đạt mức
phát hành.

## 7. Cài đặt và chạy

Yêu cầu:

- Flutter SDK tương thích với Dart `^3.12.2`;
- Android SDK và thiết bị/emulator nếu chạy Android;
- Chrome nếu chạy Web;
- quyền truy cập Firebase project nếu kiểm thử dữ liệu thật.

Từ thư mục repository:

```powershell
cd FitTrack
flutter pub get
flutter run -d chrome
```

Chạy Android:

```powershell
flutter devices
flutter run -d <device-id>
```

Nếu Firebase không khởi tạo được, ứng dụng vẫn có thể chạy luồng cục bộ để
phát triển và kiểm tra giao diện.

## 8. Kiểm tra

Trước khi tạo Pull Request:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Test hiện có bao phủ:

- validation đăng nhập và chuyển sang đăng ký;
- ProgramMatcher, fallback và published-version gate;
- enrollment ghim phiên bản và sinh lịch tự động;
- Body Metrics, chuyển đổi dữ liệu và BMI;
- Active Workout, nghỉ, pause/resume, checkpoint và completion idempotent;
- Squat PoseRuleEngine, confidence gate và Web fallback;
- thao tác điều hướng, thư viện read-only và layout 360×800/412×915;
- parser HTTP bài tập và round-trip của các model.

Các test tự động không chứng minh Camera Coach chính xác trên mọi thiết bị,
không thay thế kiểm thử Firebase Rules và không thay thế QA notification/TTS
khi ứng dụng chạy nền.

## 9. Giới hạn hiện tại

- Camera Coach mới hỗ trợ Squat trên Android và chưa có kết quả QA thiết bị
  thật được lưu trong repository.
- Voice Coach, notification, deep link và khôi phục sau process death cần kiểm
  thử trên Android.
- Web luôn dùng Guided Confirmation và không có local notification hoặc TTS.
- Chưa có cấu hình và source platform iOS.
- Chưa có công cụ biên soạn catalog trong ứng dụng người dùng.
- Xuất dữ liệu và xóa tài khoản hiện tạo request trong Firestore; project chưa
  có backend worker để đóng gói hoặc xóa toàn bộ dữ liệu.
- Offline cache chưa có durable sync queue và conflict policy.
- Google/Facebook login chưa được triển khai.
- FitTrack không chẩn đoán, điều trị hoặc thay thế bác sĩ hay huấn luyện viên.

## 10. Phân công hiện tại

| Thành viên | Phạm vi |
|---|---|
| Lê Tiến Hải | Tài khoản, onboarding, hồ sơ, Body Metrics, tiến độ và thành tích |
| Minh Thắng | Thư viện bài tập, catalog nội dung, model chương trình và kiểm tra dữ liệu |
| Võ Việt Anh | Program enrollment, readiness, Active Workout, completion và nhắc lịch |

Khi tích hợp, người phụ trách giao diện review mọi thay đổi trong `screens/`,
`theme/` và `widgets/`. Thành viên làm logic nên ưu tiên thay đổi `models/`,
`services/`, `state/` và test tương ứng, đồng thời tránh sửa cùng một màn hình
trong nhiều branch.

## 11. Tài liệu liên quan

- [Đặc tả chức năng và UI](./FitTrack_Dac_ta_chuc_nang_UI.md)
- [Đặc tả yêu cầu hệ thống](./FitTrack_System_Requirements_Specification.md)

