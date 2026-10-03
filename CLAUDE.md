# CLAUDE.md — Chấm Công Đơn Giản

Ghi chú cho Claude Code (trên PC, IDE hay trên cloud) để nắm ngữ cảnh dự án mà không cần hỏi lại.

## Dự án

- App Flutter chấm công đơn giản: ghi giờ vào/ra, tăng ca, ngày nghỉ, đi muộn và ước tính lương theo kỳ.
- Dữ liệu lưu trên máy (một file JSON, `lib/data/store.dart`), không cần mạng.
- Lõi tính toán thuần Dart ở `lib/domain/` (`calc.dart`, `pay_period.dart`, `lunar.dart`...). Test: `flutter test test/domain`.
- Giao diện: `lib/ui/home/` (màn chính), `lib/ui/settings/` (cài đặt). GPS ở `lib/gps/`, widget màn hình chính ở `lib/widget/`.
- Tiến độ chi tiết và hạn chế còn lại: xem `TIEN-DO.md`.

## Cách làm việc với người dùng

- Người dùng viết tiếng Việt: luôn trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu.
- **Hiện tại người dùng muốn thảo luận trước. Không sửa code app cho tới khi người dùng nói rõ là muốn sửa.**
- Quy trình đồng bộ giữa cloud và PC:
  1. Claude trên cloud sửa code, đẩy lên một nhánh mới và mở pull request trên GitHub.
  2. Người dùng bấm merge pull request trên GitHub.
  3. Trên PC chạy `git pull` (hoặc nút Pull/Sync trong IDE) để lấy về.
  - Nên commit và push thay đổi trên PC trước khi nhờ Claude trên cloud sửa, để tránh xung đột.
- Build APK không bắt buộc phải có PC; chỉ cần điện thoại thật (hoặc PC nối điện thoại) để cài thử. Có bản web xem thử trong thư mục dự án chung (`web-preview/cham-cong.html`), hiện còn lỗi khi mở trên điện thoại.

## Ba mặc định đang chờ người dùng chốt

Chưa đổi gì, chờ người dùng quyết định:

1. Ngày nghỉ không tính lương (lương = 0). Nếu muốn đủ lương hoặc một phần thì cần thêm cấu hình.
2. "Thống kê thu nhập theo kỳ" hiện 12 kỳ gần nhất.
3. Hai nút đầu trang (Âm lịch, Lương mỗi ngày) chỉ có icon, không có chữ.

## Cập nhật lần cuối

2026-10-03: ghi lại trao đổi trên project "chấm công" trên claude.ai.
