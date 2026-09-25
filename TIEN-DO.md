# Tiến độ — Chấm Công Đơn Giản

Project mới, tách riêng khỏi `so_cong` (bản đầy đủ, để chỉnh sau). Chỉ tham khảo logic tính giờ/lương/âm lịch từ `so_cong`, không dùng chung code trừ `domain/lunar.dart` (copy nguyên, đã kiểm chứng) và font Be Vietnam Pro.

## Đã xong (2026-09-22)

- **Lõi tính toán** (`lib/domain/`): model dữ liệu thuần Dart, công thức tính giờ thường/tăng ca/đi muộn/lương (`calc.dart`), tính kỳ lương (`pay_period.dart`), âm lịch, xuất/nhập cấu hình JSON. 16 test qua (`flutter test test/domain`).
- **Lưu trữ**: một file JSON trong thư mục dữ liệu app (`lib/data/store.dart`), không cần mạng, không dùng SQL vì dữ liệu ít.
- **Màn chính** (`lib/ui/home/`): nút Cài đặt góc trái, đổi tháng, nút Âm lịch/Lương mỗi ngày, thẻ Thu nhập tạm tính (Giờ công/Tăng ca/Ngày nghỉ từ đầu kỳ), lịch tháng, 5 nút (Chấm vào, Chấm ra, Tăng ca, Ngày nghỉ, Đi muộn), nút Ghi chú (gợi ý thẻ), thống kê thu nhập theo kỳ ở cuối trang (tổng cộng ở đầu, mỗi kỳ có ô nhập tiền ghi đè + số ngày nghỉ/đi muộn + khoản "nhập tay mỗi kỳ" nếu có).
- **Cài đặt** (`lib/ui/settings/`): khung giờ ra/vào, bảng lương/giờ (8 ô, nhập thẳng đ/giờ), ngày lễ, cộng trừ giờ theo giờ vào, đi muộn (mốc giờ + trừ phút/tiền), tăng ca theo khung, GPS (bật/tắt, lấy tọa độ, bán kính, khung giờ, tần suất), kỳ lương (theo tháng chọn ngày bắt đầu / 2 kỳ mỗi tháng), khoản thu nhập-khấu trừ tự tạo, sao chép/dán cấu hình (JSON qua clipboard).
- Build thử `flutter build apk --debug` qua, không lỗi Gradle/manifest.

## Mặc định mình tự chọn — cần bạn xác nhận lại

1. **Ngày nghỉ không tính lương** (pay = 0). Nếu muốn có lựa chọn đủ lương/một phần thì phải hỏi lại và thêm cấu hình.
2. Danh sách "Thống kê thu nhập theo kỳ" hiện 12 kỳ gần nhất — số này chỉnh được nếu cần nhiều/ít hơn.
3. Icon 2 nút đầu trang (Âm lịch = icon trăng, Lương mỗi ngày = icon tiền) chỉ có icon, không có chữ, để đỡ chật.

## Chưa làm / còn hạn chế

- **GPS mới dừng ở phần cài đặt** (lưu vị trí, bán kính, khung giờ, tần suất) và nút "Lấy vị trí hiện tại". Chưa chạy nền để tự động chấm công theo GPS — phần này phức tạp (cần dịch vụ chạy nền có thông báo trên Android, iOS hạn chế hơn), để sau nếu bạn cần.
- Icon app vẫn là icon Flutter mặc định, chưa đổi icon riêng.
- Chưa test bằng tay thật trên điện thoại — nhờ bạn cài bản debug rồi báo lại bố cục/màu sắc có ổn không.

## Cách cài thử

```
cd C:\Users\Admin\Documents\PlatformIO\Projects\cham_cong_don_gian
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Hoặc `flutter run` khi điện thoại nối máy qua USB (bật gỡ lỗi USB).
