# FitTrack — Đặc tả chức năng và giao diện đang có

Tài liệu này mô tả những màn hình và hành vi đã tồn tại trong mã nguồn
FitTrack tại ngày 26/07/2026. Mục đích của tài liệu là giúp các thành viên nối
logic vào giao diện hiện có mà không tự thay đổi luồng sản phẩm hoặc tạo thêm
chức năng chưa được thống nhất.

## 1. Nguyên tắc chung của giao diện

FitTrack dùng Material 3, có theme sáng, theme tối và chế độ theo hệ thống.
Giao diện chính được thiết kế cho điện thoại, đồng thời các danh sách và lưới
có thể thay đổi số cột khi màn hình rộng hơn. Bộ test hiện kiểm tra hai kích
thước 360×800 và 412×915.

Các nguyên tắc đang được áp dụng:

- Tác vụ chính dùng nút rõ ràng và chỉ cần một lần chạm.
- Hành động có thể làm mất dữ liệu như bỏ buổi, đăng xuất hoặc yêu cầu xóa tài
  khoản phải hỏi xác nhận.
- Nội dung chưa có dữ liệu dùng `EmptyState`, không hiển thị một con số giả.
- Lỗi từ thao tác thường được báo bằng `SnackBar` hoặc thông báo ngay trong
  form.
- Khi Firebase không khả dụng, Trang chủ hiển thị banner offline.
- Màu sắc không phải tín hiệu duy nhất; trạng thái còn có nhãn và icon.
- Các cảnh báo sức khỏe luôn nhắc rằng FitTrack không thay thế tư vấn y tế.

## 2. Khởi động và điều hướng theo trạng thái

`main.dart` khởi tạo locale tiếng Việt, Firebase, notification service và
`AppState`. `app.dart` quyết định màn hình đầu tiên dựa trên trạng thái:

```text
Splash
  ├── Chưa đăng nhập → Đăng nhập
  └── Đã đăng nhập
        ├── Chưa onboarding → Onboarding
        └── Đã onboarding → MainShell
```

Splash hiển thị khoảng 900 ms. Sau onboarding, `MainShell` có bốn tab:

1. **Trang chủ**
2. **Chương trình**
3. **Tiến độ**
4. **Hồ sơ**

Ứng dụng giữ các tab trong `IndexedStack`, vì vậy trạng thái cuộn của từng tab
không bị tạo lại mỗi lần chuyển tab.

Notification payload bắt đầu bằng `today:` đưa người dùng về Trang chủ.
Payload bắt đầu bằng `active:` chỉ mở lại Active Workout nếu draft và
occurrence tương ứng vẫn tồn tại.

## 3. Đăng nhập, đăng ký và quên mật khẩu

### Đăng nhập

Màn hình đăng nhập gồm email, mật khẩu, nút hiện/ẩn mật khẩu, nút đăng nhập,
liên kết quên mật khẩu và liên kết chuyển sang đăng ký.

Validation hiện có:

- email phải đúng định dạng cơ bản;
- mật khẩu phải có ít nhất 8 ký tự;
- không gửi form khi AppState đang xử lý.

Khi đăng nhập thất bại, màn hình hiển thị thông báo thân thiện cho mật khẩu
sai, tài khoản bị khóa, lỗi mạng hoặc lỗi chung. Đăng nhập thành công không tự
đẩy route bằng tay; `FitTrackApp` tự chọn onboarding hoặc MainShell theo state.

Hai nút Google và Facebook vẫn xuất hiện trong chế độ đăng nhập nhưng chỉ mở
thông báo rằng phiên bản hiện tại hỗ trợ email/mật khẩu.

### Đăng ký

Khi chuyển sang đăng ký, form bổ sung:

- họ và tên;
- xác nhận mật khẩu;
- checkbox đồng ý điều khoản.

Tên không được để trống, hai mật khẩu phải khớp và checkbox điều khoản phải
được chọn. Tài khoản vừa đăng ký được chuyển vào onboarding.

### Quên mật khẩu

Màn hình quên mật khẩu nhận email đã nhập từ màn hình trước. Sau khi người dùng
gửi form, giao diện luôn dùng thông báo trung tính “nếu email hợp lệ” để tránh
xác nhận email có tồn tại trong hệ thống hay không.

Firebase gửi email đặt lại mật khẩu khi được cấu hình. Trong chế độ local,
service trả về mà không gửi email thật.

## 4. Onboarding

Onboarding có ba bước và không cho quay về màn hình đăng nhập bằng nút Back.

### Bước 1 — Bắt đầu an toàn

Người dùng nhập tên hiển thị và chọn một trong hai nhóm:

- Người trưởng thành khỏe mạnh 18–64.
- Ngoài phạm vi hỗ trợ.

Nếu chọn ngoài phạm vi, màn hình hiển thị cảnh báo rằng FitTrack sẽ không tự kê
chương trình và khuyên người dùng trao đổi với chuyên gia phù hợp.

### Bước 2 — Chỉ số cơ thể

Người dùng chọn `cm/kg` hoặc `in/lb`, sau đó nhập chiều cao và cân nặng.

Quy tắc:

- chiều cao sau quy đổi phải nằm trong 100–250 cm;
- cân nặng sau quy đổi phải lớn hơn 0 và không quá 500 kg;
- khi đổi hệ đơn vị, giá trị đang nhập được chuyển đổi thay vì xóa;
- BMI được tính từ chiều cao và cân nặng, không có ô nhập BMI;
- không có ô cân nặng mục tiêu.

### Bước 3 — Lựa chọn chương trình

Các lựa chọn một chạm gồm:

- mục tiêu;
- 2, 3, 4 hoặc 5 buổi mỗi tuần;
- mới bắt đầu hoặc đã tập;
- không dụng cụ hoặc phòng gym;
- nội dung chung, nam hoặc nữ.

Nút **Chọn chương trình** lưu hồ sơ, preferences, lần đo cơ thể đầu tiên, hệ
đơn vị và hoàn thành onboarding. AppState sau đó chạy `ProgramMatcher`.

## 5. Trang chủ

Phần đầu Trang chủ có avatar, ngày hiện tại và nút mở Chỉ số cơ thể. Avatar
đưa người dùng sang tab Hồ sơ.

Khu vực chính chỉ hiển thị một trong ba trạng thái:

### Có draft đang tập

Thẻ resume cho biết buổi tập, phase và số hiệp đã xử lý. Người dùng có thể:

- tiếp tục buổi tập;
- hoàn tất với các hiệp đã xác nhận;
- bỏ buổi tập và xóa draft.

Chức năng hoàn tất nhanh chỉ khả dụng khi draft đã bắt đầu. Bỏ draft đồng thời
đánh dấu occurrence là skipped.

### Có buổi được đề xuất

Thẻ buổi tập hiển thị tên, tuần, thời lượng dự kiến, số hiệp và số block. Người
dùng chọn readiness:

- **Sung sức** dùng nội dung gốc;
- **Hơi mệt (Giảm tải)** dùng biến thể ít hiệp hơn;
- **Cần nghỉ ngơi** dùng nội dung phục hồi đã cấu hình.

Các hành động gồm bắt đầu với Guided Confirmation, dời lịch và bỏ qua. Dời lịch
chuyển occurrence sang ngày trống tiếp theo. Bỏ qua phải xác nhận.

### Không có buổi

Màn hình giải thích chưa có buổi phù hợp và cung cấp nút mở tab Chương trình.

Phần dưới Trang chủ hiển thị số buổi đã tập trong tuần, workout streak, chuỗi
ngày cập nhật cân nặng và chương trình đang theo. Hai loại streak được trình
bày riêng, không cộng chung.

## 6. Tổng quan chương trình

Nếu chưa có chương trình, màn hình hiển thị empty state và nút thử ghép lại.

Khi đã có chương trình, giao diện trình bày:

- tên và mô tả chương trình;
- version, số tuần, số buổi mỗi tuần và tổng số buổi;
- các tiêu chí đã dùng để ghép;
- cảnh báo khi cadence gần nhất khác số buổi người dùng mong muốn;
- từng tuần, từng buổi, ngày dự kiến và trạng thái occurrence;
- các block và prescription bên trong buổi;
- safety copy và danh sách nguồn tham khảo.

Các trạng thái occurrence gồm sắp tới, đang tập, hoàn thành, đã dời, bỏ qua và
đã hủy. Màn hình này hoàn toàn chỉ đọc; người dùng không chỉnh số hiệp, target
hoặc lịch từ đây.

## 7. Active Workout

### Màn hình chuẩn bị

Trước khi bắt đầu, người dùng thấy tổng số hiệp, danh sách bài tập và target.
Người dùng chọn **Hướng dẫn** hoặc **AI Camera**. Nếu thiết bị, bài tập hoặc
pose rule không phù hợp, ứng dụng tự chuyển về chế độ Hướng dẫn.

Giao diện luôn hiển thị giải thích:

- camera chỉ xử lý frame tạm thời;
- FitTrack không lưu video;
- AI có thể sai;
- người dùng phải ưu tiên cảm nhận an toàn.

### Phase working

Màn hình working hiển thị:

- tiến độ toàn buổi;
- chế độ xác nhận hiện tại;
- thời gian hoạt động;
- media hoặc placeholder của bài;
- tên bài, hiệp hiện tại và target;
- tối đa ba cue kỹ thuật;
- nút hoàn thành, làm lại, bỏ qua và tạm dừng.

Trong Guided Confirmation, nút **Đã hoàn thành hiệp** chỉ tạo một `SetEvent`
đã xác nhận. Ứng dụng không hỏi actual reps, mức tạ hoặc thời lượng. Nếu bài
Squat và thiết bị đủ điều kiện, người dùng có thể bật AI cho hiệp hiện tại.

Nút **Làm lại** ghi một event `redone` nhưng giữ nguyên bài và hiệp. Nút
**Bỏ qua** mở bottom sheet để chọn lý do; lý do rỗng không được chấp nhận.

### Phase resting

Màn hình nghỉ hiển thị thời gian còn lại và bài tiếp theo. Người dùng có thể:

- cộng 15 giây;
- tập tiếp ngay;
- tạm dừng.

Nguồn thời gian thật là `restEndsAt`. Khi quay lại ứng dụng, controller so sánh
timestamp hiện tại thay vì tin vào số tick đã chạy trên UI.

### Phase paused

Khi tạm dừng, active duration và thời gian nghỉ còn lại được đóng băng. Người
dùng có thể tiếp tục, kết thúc với tiến độ hiện tại hoặc bỏ và xóa buổi tập.

### Phase finishing và summary

Khi hết các hiệp hoặc người dùng kết thúc sớm, ứng dụng lưu completion. Nếu lưu
lỗi, màn hình giữ phase finishing và cung cấp nút thử lại.

Summary hiển thị:

- trạng thái hoàn thành toàn bộ hoặc một phần;
- số hiệp hoàn tất, bỏ qua và làm lại;
- thời lượng;
- Guided Confirmation, AI Camera Coach hoặc cả hai;
- chi tiết event theo bài;
- version và nguồn nội dung.

Người dùng có thể mở tab Tiến độ hoặc trở về Trang chủ.

### Rời màn hình

Nếu dùng nút Back trong khi buổi tập đang chạy hoặc đang nghỉ, controller tạm
dừng, lưu checkpoint và trở về Trang chủ. Việc rời màn hình không tự đánh dấu
completion.

## 8. AI Camera Coach

Camera panel chỉ hỗ trợ các ID Squat đã định nghĩa và chỉ khởi tạo trên
Android. Panel ưu tiên camera trước, cho phép đổi camera và tắt camera.

Trình tự giao diện:

1. Hiển thị trạng thái đang chuẩn bị camera.
2. Camera preview có khung gợi ý đặt toàn thân.
3. Hiển thị trạng thái định vị, tốt, cần điều chỉnh, chưa thấy rõ hoặc không
   chắc chắn.
4. Hiển thị số lần hiện tại trên target.
5. Khi đạt target, hiệp được hoàn tất kèm rep count và confidence.

`PoseRuleEngine` cần một chuỗi phase ổn định:

```text
standing → descending → bottom → ascending → standing
```

Một lần đi xuống chưa đủ sâu không được tính rep và có thể đưa ra cue hạ thấp
thêm. Landmark thiếu, visibility thấp, confidence thấp, frame cũ hoặc frame
đến sai thứ tự không được làm tăng rep.

Khi camera không khả dụng, panel hiển thị lý do và nút tiếp tục không dùng
camera. Fallback cũng được kích hoạt tự động sau các lỗi liên tiếp hoặc trạng
thái không chắc chắn kéo dài.

## 9. Tiến độ và lịch sử

Màn hình Tiến độ có bộ chọn 7 ngày, 30 ngày hoặc tất cả. Các số liệu gồm:

- số buổi trong kỳ;
- tổng thời gian;
- hiệp hoàn tất;
- workout streak;
- streak cập nhật cân nặng và streak dài nhất;
- độ chuyên cần dựa trên lịch chương trình;
- activity heatmap của hai loại hoạt động;
- bài tập xuất hiện thường xuyên;
- phân bổ nhóm cơ.

Danh sách completion ở cuối màn hình chỉ dùng schema workout mới. Mỗi thẻ có
thể mở rộng để xem hiệp hoàn tất/bỏ qua, confirmation mode, ProgramVersion và
nguồn.

Nếu còn dữ liệu kế hoạch hoặc kết quả cũ, màn hình cung cấp liên kết riêng tới
Dữ liệu phiên bản cũ; các số liệu legacy không được trộn vào báo cáo mới.

## 10. Chỉ số cơ thể

Màn hình hiển thị chiều cao, cân nặng hiện tại, streak nhập cân, streak dài
nhất và BMI tham khảo. Biểu đồ có hai khoảng thời gian: tuần và tháng. Cần ít
nhất hai lần đo trong khoảng đã chọn mới vẽ đường.

Nút **Cập nhật** mở form tạo lần đo mới. Validation giống onboarding. Lần đo
lưu snapshot chiều cao để BMI lịch sử không thay đổi khi người dùng cập nhật
chiều cao sau này.

Lịch sử đo chỉ đọc trong UI hiện tại. Người dùng không sửa hoặc xóa một lần đo
cũ; họ tạo lần đo mới.

## 11. Thư viện bài tập

Màn hình thư viện:

- debounce ô tìm kiếm 250 ms;
- tìm theo tên tiếng Việt hoặc tiếng Anh;
- lọc bằng chip nhóm cơ;
- thay đổi bố cục 1, 2 hoặc 3 cột theo chiều rộng;
- cho phép yêu thích hoặc bỏ yêu thích;
- mở trang chi tiết.

Trang chi tiết hiển thị ảnh/placeholder, tên, tên tiếng Anh, nhóm cơ, độ khó,
dụng cụ, mô tả, từng bước thực hiện và lỗi thường gặp. Không có nút thêm vào
plan hoặc tạo bài cá nhân.

File `exercise_filter_sheet.dart` có component lọc độ khó, dụng cụ và yêu
thích, nhưng component này chưa được nối vào `ExerciseLibraryScreen`; vì vậy
không được mô tả là chức năng đang sử dụng.

## 12. Hồ sơ và các màn hình phụ

### Hồ sơ

Hồ sơ hiển thị avatar, tên, email và nhãn người dùng. Người dùng có thể sửa tên
hoặc chọn ảnh đại diện tối đa 5 MB.

Các mục điều hướng gồm lựa chọn chương trình, thư viện, chỉ số cơ thể, thành
tích, thông báo, quyền riêng tư và dữ liệu cũ.

### Lựa chọn chương trình

Người dùng chỉnh số buổi, mục tiêu, kinh nghiệm, dụng cụ và ưu tiên nội dung,
sau đó bấm **Lưu và chọn lại**. Không cho đổi chương trình khi còn draft buổi
tập đang dở. Khi lưu thành công, các occurrence mở của enrollment cũ bị hủy và
ứng dụng ghép chương trình lại.

### Thành tích

Màn hình hiển thị các mốc buổi tập đầu tiên, 5 buổi, 10 buổi và streak 3, 7,
30 ngày. Thành tích được mở khi completion hoặc streak thỏa điều kiện.

### Thông báo và nhắc lịch

Người dùng bật nhắc lịch, cấp quyền Android, chọn giờ mặc định và chọn nhắc
đúng giờ hoặc trước 15, 30, 60 phút. Màn hình hiển thị tối đa năm occurrence
sắp tới. Nếu quyền bị từ chối, người dùng có thể mở cài đặt notification của
Android.

Nhắc lịch được sinh từ occurrence; màn hình không tạo lịch tập mới.

### Cài đặt

Các tùy chọn gồm Voice Coach, rung, theme và hệ đơn vị. Theme và đơn vị được
lưu trong snapshot người dùng. Hệ đơn vị chỉ thay cách hiển thị/nhập; dữ liệu
canonical vẫn là cm/kg.

### Quyền riêng tư và tài khoản

Dialog quyền riêng tư giải thích camera xử lý trên thiết bị, dữ liệu sức khỏe
thuộc tài khoản và FitTrack không thay thế tư vấn y tế.

**Yêu cầu xuất dữ liệu** tạo một request Firestore khi Firebase hoạt động.
**Yêu cầu xóa tài khoản và dữ liệu** hiện tạo request rồi đăng xuất; việc xóa
toàn bộ dữ liệu cần backend xử lý, không hoàn thành ngay trong ứng dụng.

## 13. Dữ liệu phiên bản cũ

Màn hình Legacy trình bày kế hoạch và completion cũ dưới nhãn chỉ đọc. Không có
nút tạo, chỉnh sửa, sao chép, xóa hoặc dùng lại dữ liệu. Mục đích của màn hình
là tránh mất khả năng xem dữ liệu đã lưu từ schema trước.

## 14. Trạng thái lỗi và fallback

Các trường hợp đã có xử lý giao diện:

- Firebase không khả dụng: banner offline và cache cục bộ.
- Không có chương trình: empty state và nút ghép lại.
- Không có buổi: điều hướng sang Chương trình.
- Không đủ dữ liệu biểu đồ: empty state có giải thích.
- Không tìm thấy bài tập: gợi ý đổi từ khóa/nhóm cơ.
- Camera hoặc ML Kit lỗi: chuyển Guided Confirmation.
- Notification bị từ chối: hiển thị cảnh báo và nút mở cài đặt.
- Lưu completion lỗi: giữ phase finishing và cho thử lại.
- ProgramVersion bị recall: hủy lịch mở và báo lý do.

Project chưa có một hàng đợi đồng bộ offline bền vững. Khi sync Firebase thất
bại, AppState giữ cache local nhưng không hiển thị tiến độ retry chi tiết.

## 15. Ma trận nền tảng

| Chức năng | Android | Web |
|---|---:|---:|
| Đăng nhập email, onboarding, chương trình | Có | Có |
| Guided Confirmation | Có | Có |
| AI Camera Coach Squat | Có code path | Fallback |
| Text-to-Speech | Có code path | Không |
| Local notification | Có code path | Không |
| Theme, Body Metrics, history | Có | Có |

“Có code path” nghĩa là source đã nối end-to-end nhưng vẫn cần QA trên thiết
bị thật trước khi xem là đạt yêu cầu phát hành.

## 16. Tiêu chí nghiệm thu giao diện hiện tại

1. Người dùng đăng ký mới phải đi vào onboarding.
2. Form không chấp nhận email sai, mật khẩu ngắn hoặc hai mật khẩu khác nhau.
3. Chiều cao/cân nặng sai giới hạn không được lưu.
4. MainShell chỉ có bốn tab đã mô tả.
5. Người dùng không thấy tính năng tạo plan, lịch thủ công hoặc bài cá nhân.
6. Chỉ ProgramVersion published mới được ghép.
7. Readiness chỉ chọn một biến thể đã có trong session.
8. Không được mở hai Active Workout khác nhau cùng lúc.
9. Back khỏi workout phải lưu draft, không tự tạo completion.
10. Guided Confirmation không lưu rep count hoặc confidence suy đoán.
11. AI Camera không hỗ trợ phải fallback mà không chặn buổi tập.
12. Completion retry không tạo bản ghi trùng.
13. Hai loại streak phải được trình bày riêng.
14. Thư viện người dùng phải chỉ đọc.
15. Published version không được sửa nội dung hoặc quay lại draft.
16. Legacy không có mutation route trên UI.
17. Các màn hình chính không overflow ở 360×800 và 412×915.

## 17. Ngoài phạm vi hiện tại

- Đăng nhập Google hoặc Facebook.
- Tạo plan, lịch hoặc bài tập cá nhân bởi người dùng.
- Nhập actual reps, mức tạ hoặc volume bằng form trong luồng mới.
- AI Camera cho bài khác Squat.
- Pose detection trên Web.
- Công cụ biên soạn catalog trong ứng dụng người dùng.
- Backend đóng gói export và xóa toàn bộ dữ liệu.
- iOS.
- Wearable, Health Connect, mạng xã hội, thanh toán hoặc huấn luyện viên trực
  tiếp.
