# HANDOFF — 2026-10-19 — cloud

Branch: claude/handoff-2026-10-18-chieu   Repo: AissNguyen/cham-cong-don-gian

## Mục tiêu của phiên
Người dùng muốn tạo một app mới, đơn giản: "pc bỏ túi" (Claude hiểu là **máy tính bỏ túi**, tức app làm phép tính, chưa được xác nhận). Người dùng dặn: "hãy thảo luận trước làm nhé".

## Diễn biến (theo thứ tự)
1. Người dùng: "hãy tạo một ứng dụng mới, đơn giản, là một pc bỏ túi' hãy thảo luận trước làm nhé"
   Claude: chưa viết code, chỉ đưa đề xuất:
   - Hiểu "pc bỏ túi" = máy tính bỏ túi (calculator); nếu ý khác (ví dụ điều khiển PC từ điện thoại) thì người dùng nói lại.
   - Làm app riêng, không gộp vào app Chấm Công: thư mục mới `may-tinh-bo-tui` cạnh thư mục chấm công, repo GitHub riêng.
   - Viết bằng Flutter, như app Chấm Công (PC đã có Flutter, build, cài, deploy như cũ).
   - Bản đầu: số 0–9, dấu phẩy, + − × ÷, %, nút C và ⌫, hiện cả phép tính đang gõ lẫn kết quả, số có dấu chấm ngăn hàng nghìn (1.250.000), lịch sử vài phép tính gần nhất lưu trên máy.
   - Chưa làm: hàm khoa học (sin, cos, căn, lũy thừa), quảng cáo, đăng nhập, Firebase.
   - Ước lượng: Claude làm khoảng 30–45 phút; người dùng cắm điện thoại để cài thử và đồng ý trước khi tạo repo hay bản web (khoảng 5 phút).
   - Hỏi 4 câu (xem mục "Câu hỏi còn mở").
2. Người dùng gọi /handoff, rồi hỏi "sao lâu thế"; Claude viết file này và push ngay.

## Quyết định đã chốt
- Chưa chốt gì. Người dùng chưa trả lời 4 câu hỏi.

## Thay đổi code
- Không có. Chỉ ghi đè `HANDOFF.md`.

## Lệnh đã chạy / cài đặt / cấu hình quan trọng
- Không có.

## Còn dở / bước tiếp theo
- [ ] Chờ người dùng trả lời 4 câu hỏi bên dưới.
- [ ] Khi đã chốt: tạo dự án Flutter mới (ví dụ `flutter create may_tinh_bo_tui` trong thư mục `may-tinh-bo-tui`, đặt cạnh `cham-cong-don-gian`), viết bộ tính biểu thức thuần Dart kèm test, làm giao diện bàn phím.
- [ ] Hỏi người dùng trước khi tạo repo GitHub mới hoặc deploy web.

## Ý tưởng chưa làm, câu hỏi còn mở
1. Có đúng là máy tính bỏ túi không?
2. Chỉ phép tính cơ bản, hay thêm phần khoa học (căn, lũy thừa...)?
3. Chỉ app Android (APK), hay cả bản web như app Chấm Công?
4. Tên app? (tạm gọi "Máy Tính Bỏ Túi")
