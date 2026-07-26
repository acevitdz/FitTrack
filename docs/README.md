# FitTrack

Project Flutter khung dùng chung cho nhóm FitTrack. Project hiện chỉ chứa cấu
trúc thư mục và màn hình khởi động tối thiểu, chưa có chức năng nghiệp vụ.

## Cấu trúc thư mục

```text
FitTrack/
├── android/                 # Cấu hình và mã native Android
├── ios/                     # Cấu hình và mã native iOS
├── lib/
│   ├── data/                # Dữ liệu mẫu và nguồn dữ liệu cục bộ
│   ├── models/              # Các lớp dữ liệu của ứng dụng
│   ├── screens/             # Các màn hình giao diện
│   ├── services/            # API, Firebase và các dịch vụ dùng chung
│   ├── state/               # Quản lý trạng thái ứng dụng
│   ├── theme/               # Màu sắc, font chữ và giao diện chung
│   ├── widgets/             # Widget tái sử dụng
│   └── main.dart            # Điểm khởi chạy ứng dụng
├── test/                    # Unit test và widget test
├── analysis_options.yaml    # Quy tắc phân tích mã Dart
├── pubspec.yaml             # Cấu hình project và dependencies
├── README.md
└── .gitignore
```

## Quy ước làm việc

- Đặt tên file và thư mục theo `snake_case`.
- Chia màn hình theo chức năng, ví dụ `screens/auth/` và `screens/workout/`.
- Chỉ đưa widget được tái sử dụng vào `widgets/`.
- Không đặt mã giao diện trong `services/`, `models/` hoặc `data/`.
- Không thêm package mới vào `pubspec.yaml` trước khi nhóm thống nhất.
- Không commit các thư mục sinh tự động như `.dart_tool/` và `build/`.

## Chạy project

```bash
flutter pub get
flutter analyze
flutter run
```
