# FITTRACK — NHIỆM VỤ THÀNH VIÊN 2 (TV2)

> Tài liệu tổng hợp chức năng, nhiệm vụ và checklist kỹ thuật của Thành viên 2.
> Chủ đề phụ trách: **Bài tập & Phân tích nhóm cơ**
> CRUD chính: `TemplateExercise`, `PersonalExercise`

---

## 1. Phạm vi chức năng phụ trách

| Mã | Chức năng | Mô tả |
|---|---|---|
| 4.4 | Thư viện bài tập mẫu | Xem, tìm kiếm, lọc theo nhóm cơ, đánh dấu yêu thích |
| 4.5 | Kho bài tập cá nhân | CRUD bài tự tạo; xem PR, tần suất, tiến độ |
| 4.12 | Bản đồ cân bằng nhóm cơ | Tổng hợp working sets theo nhóm cơ; phân loại; cảnh báo mất cân bằng |
| 4.13 | Quản trị bài tập mẫu | Admin thêm/sửa/ẩn-hiện bài mẫu, upload ảnh |

---

## 2. Schema dữ liệu (Firestore)

### 2.1 Collection `exercises` (Template Exercise — dùng chung, chỉ Admin ghi)

```
exercises/{exerciseId}
├─ name: string                          // tên bài tập
├─ primaryMuscle: string                 // nhóm cơ chính (enum chuẩn, xem mục 3)
├─ secondaryMuscles: string[]            // nhóm cơ phụ (có thể rỗng)
├─ equipment: string[]                   // dụng cụ cần dùng
├─ difficulty: "beginner" | "intermediate" | "advanced"
├─ instructions: string[]                // hướng dẫn từng bước
├─ commonMistakes: string[]              // lỗi thường gặp
├─ quickTip: string                      // 1 câu lưu ý ngắn, hiển thị nhanh lúc tập
├─ suggestedRestSeconds: number          // thời gian nghỉ gợi ý giữa các set
├─ imageUrl: string                      // ảnh minh họa (bắt buộc, không để trống)
├─ isActive: boolean                     // soft delete — user chỉ đọc khi true
├─ createdAt: timestamp (server)
└─ updatedAt: timestamp (server)
```

### 2.2 Sub-collection `users/{uid}/personalExercises` (Personal Exercise — riêng từng user)

```
users/{uid}/personalExercises/{exerciseId}
├─ name: string
├─ primaryMuscle: string
├─ secondaryMuscles: string[]
├─ equipment: string[]
├─ difficulty: "beginner" | "intermediate" | "advanced"
├─ instructions: string[]
├─ personalNote: string                  // ghi chú riêng, tùy chọn
├─ isFavorite: boolean
├─ createdAt: timestamp (server)
└─ updatedAt: timestamp (server)
```

### 2.3 ExerciseSnapshot (embedded trong WorkoutPlan / WorkoutCompletion — TV3 sở hữu object cha, TV2 định nghĩa format)

```
ExerciseSnapshot {
  exerciseId: string          // tham chiếu ngược tới bản gốc (chỉ để hiển thị, không dùng để đọc lại)
  name: string
  primaryMuscle: string
  secondaryMuscles: string[]
  equipment: string[]
  imageUrl: string
  suggestedRestSeconds: number
  quickTip: string
}
```
> **Lưu ý bắt buộc:** Snapshot được copy tại thời điểm thêm vào Plan — không bao giờ query lại bản gốc để cập nhật. Nếu bản gốc bị sửa/ẩn sau này, snapshot cũ vẫn giữ nguyên.

---

## 3. Enum chuẩn hóa (PHẢI thống nhất với TV3 trước khi code)

### Nhóm cơ (`muscle`)
```
nguc, lung_tren, lung_duoi, vai_truoc, vai_giua, vai_sau,
tay_truoc, tay_sau, dui_truoc, dui_sau, mong, bap_chan, bung
```

### Dụng cụ (`equipment`)
```
khong_dung_cu, ta_don, ta_doi, day_khang_luc, ghe_tap,
may_tap_nguc, may_keo_xo, may_tap_chan, xa_ngang
```

### Độ khó (`difficulty`)
```
beginner, intermediate, advanced
```

> Tên hiển thị tiếng Việt map từ các key trên — giữ key tiếng Anh/không dấu trong DB để tránh lỗi so khớp chuỗi có dấu.

---

## 4. Danh sách màn hình cần có

### Đã có trong Figma (thiết kế hoàn chỉnh)
- [x] Exercise Library
- [x] Exercise Detail
- [x] Filter Bottom Sheet
- [x] Personal Exercise Library (tab: Tất cả / Đã tạo / Yêu thích / Lịch sử tập)
- [x] Personal Exercise Form (tạo mới)
- [x] Exercise Progress (PR, biểu đồ tiến độ)
- [x] Muscle Balance (tổng quan)
- [x] Admin Exercise List (tab: Tất cả / Hoạt động / Đã ẩn)
- [x] Admin Exercise Form

### Còn thiếu — cần bổ sung
- [ ] **Muscle Detail** — chi tiết 1 nhóm cơ khi bấm vào từ Muscle Balance (biểu đồ theo buổi, danh sách bài đã dùng nhóm cơ đó, legend rõ màu + chữ)
- [ ] **Edit Personal Exercise** — màn sửa riêng (hoặc rõ trạng thái edit trong form hiện có)
- [ ] Dialog xác nhận xóa Personal Exercise
- [ ] Dialog xác nhận ẩn/xóa Admin Exercise
- [ ] Empty state khi tìm kiếm không có kết quả (Library)
- [ ] Loading state cho các danh sách
- [ ] Bộ lọc tuần/tháng trên Muscle Balance (hiện đang cứng "7 ngày")
- [ ] Nút yêu thích hiển thị ngay trên card trong danh sách Library (không chỉ trong Detail)

---

## 5. Quy tắc nghiệp vụ bắt buộc

- User chỉ đọc bài mẫu có `isActive == true`.
- Bài bị ẩn/xóa **không** làm mất snapshot đã lưu trong Plan/Completion cũ.
- Bài cá nhân chỉ thuộc đúng 1 UID (`users/{uid}/personalExercises`).
- Chỉ **completed set** trong completion hợp lệ mới được tính vào PR.
- Một bài có nhiều set trong cùng 1 completion chỉ tăng tần suất buổi tập **1 lần**.
- Xóa bài tập (mẫu hoặc cá nhân) **không** xóa snapshot lịch sử — dùng soft delete (`isActive`).
- Muscle Balance: primary muscle = trọng số 1, secondary muscle = trọng số 0.5 (tùy chọn bật).
- Không có dữ liệu → hiển thị `neutral`, **không suy diễn** kết luận mất cân bằng.
- Phân quyền ghi vào `exercises/` (Admin only) **phải** kiểm tra ở Firestore Security Rules, không chỉ ẩn nút UI.
- Mọi màn hình async: có đủ `loading / success / empty / error` + retry.
- Form: validate input, chống double-tap khi submit.
- Xóa dữ liệu quan trọng: bắt buộc có dialog xác nhận.
- Không query Firestore trực tiếp trong hàm `build()` (Flutter).

---

## 6. Chuẩn bị dữ liệu bài tập (seed)

### Quy trình
1. Tham khảo (không copy nguyên) từ API mở `wger.de` để lấy ý tưởng tên bài/cấu trúc.
2. Tự viết lại nội dung bằng tiếng Việt, đúng enum đã chuẩn hóa ở mục 3.
3. Soạn **30–40 bài tập**, phủ đều toàn bộ nhóm cơ ở mục 3 (không dồn hết vào ngực/tay).
4. Mỗi bài **bắt buộc có ảnh** (dùng ảnh free-license, ví dụ Pexels/Unsplash — không lấy ảnh gốc từ API).
5. Đóng gói thành file `exercises_seed.json` theo đúng schema mục 2.1.
6. Viết script 1 lần (Node.js hoặc Python + Firebase Admin SDK) đọc file JSON, ghi vào Firestore.
7. **Không gọi API lúc runtime** — app chỉ đọc dữ liệu từ Firestore.

### Giáo án mẫu (Preset Plan) — hỗ trợ người dùng mới
Soạn thêm 2–3 bộ gợi ý bài tập theo mục tiêu (phối hợp với TV3 vì `WorkoutPlan` do TV3 sở hữu):
- **Giảm cân:** Full-body 3 buổi/tuần, nhiều nhóm cơ mỗi buổi, cường độ vừa.
- **Tăng cơ:** Chia lịch Ngực-Vai-Tay / Lưng-Tay sau / Chân — 3-4 buổi/tuần.
- **Duy trì:** Full-body 2-3 buổi/tuần, cường độ nhẹ-vừa.

---

## 7. Phối hợp liên nhóm (Data Contract)

| Cung cấp cho | Dữ liệu | Ghi chú |
|---|---|---|
| TV3 (Plan, Readiness, Active Workout) | `ExerciseSnapshot` | Cần tên nhóm cơ khớp 100% enum đã chuẩn hóa (mục 3) |
| TV1 (Report — bài tập thường tập) | Tên/ID exercise từ Completion | Không cần field riêng, TV1 tự truy vấn qua Completion |

| Nhận từ | Dữ liệu | Dùng cho |
|---|---|---|
| TV3 | `WorkoutCompletion` (completed sets) | Tính PR, Muscle Balance |
| TV1 | Auth UID | Toàn bộ query theo `currentUser.uid` |

---

## 8. Test case cần thực hiện

- [ ] Filter kết hợp nhiều điều kiện (nhóm cơ + độ khó + dụng cụ) cho ra đúng kết quả.
- [ ] Reset filter về mặc định hoạt động đúng.
- [ ] PR tính đúng: nhiều set trong 1 completion chỉ tăng tần suất buổi tập 1 lần.
- [ ] Volume chỉ tính từ set có `completed = true`.
- [ ] Muscle Balance: nhập dữ liệu giả lập, đối chiếu kết quả tính tay.
- [ ] Ẩn 1 bài tập mẫu (`isActive = false`) → snapshot cũ trong Plan/Completion vẫn hiển thị đầy đủ, không lỗi.
- [ ] Security Rules: tài khoản user thường **không** ghi được vào `exercises/`.
- [ ] Security Rules: user A không đọc/sửa được `personalExercises` của user B.
- [ ] Không có dữ liệu buổi tập nào → Muscle Balance hiển thị `neutral`, không kết luận sai.

---

## 9. Checklist tiến độ tổng thể

```
[ ] GĐ0 — Họp nhóm chốt schema, enum nhóm cơ, phạm vi real-time (giữ Rest Timer + Active Workout rút gọn + Live Timer, bỏ Pause/Resume)
[ ] GĐ1 — Vẽ bổ sung Muscle Detail, Edit Personal Exercise, các empty/loading/confirm state còn thiếu
[ ] GĐ2 — Soạn 30-40 bài tập + 2-3 giáo án mẫu, seed vào Firestore (deadline: giữa tuần 2)
[ ] GĐ3 — Code Exercise Library, Detail, Personal Exercise CRUD, Admin CRUD + Security Rules
[ ] GĐ4 — Code Exercise Progress/PR, Muscle Balance, Muscle Detail (cần Completion thật từ TV3)
[ ] GĐ5 — Chạy đủ test case ở mục 8
[ ] GĐ6 — Tích hợp với TV1/TV3, rà soát UI theo quy tắc mục 5, feature freeze giữa tuần 3
[ ] GĐ7 — Chuẩn bị tài khoản demo có dữ liệu đầy đủ, hoàn thiện báo cáo
```

---

## 10. Ghi chú kiến trúc (để Claude Code tham chiếu khi sinh code)

- Stack: Flutter/Dart (Android), Firebase (Auth, Firestore, Storage) — không có backend riêng.
- Kiến trúc: `UI (Screen/Widget/Controller) → Domain (Repository interface/UseCase) → Data (Repository impl) → Firebase`.
- Không gọi API bên thứ ba lúc runtime.
- Repository cần định nghĩa dạng interface trước khi implement, ví dụ:

```dart
abstract interface class ExerciseRepository {
  Stream<List<Exercise>> watchExercises({ExerciseFilter? filter});
  Future<Exercise?> getExercise(String id);
  Future<void> createExercise(Exercise value);   // admin only
  Future<void> updateExercise(Exercise value);   // admin only
  Future<void> setActive(String id, bool isActive); // soft delete, admin only
}

abstract interface class PersonalExerciseRepository {
  Stream<List<PersonalExercise>> watchPersonalExercises(String uid);
  Future<void> create(String uid, PersonalExercise value);
  Future<void> update(String uid, PersonalExercise value);
  Future<void> delete(String uid, String id); // cần confirm dialog ở UI trước khi gọi
}
```
