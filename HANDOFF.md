# HANDOFF — 2026-10-18 (chiều, giờ VN) — PC

Branch: pc/bu-tang-ca-2026-10-18   Repo: AissNguyen/cham-cong-don-gian

## Mục tiêu của phiên
Người dùng gọi `/resume-work` để nhận lại phiên cloud trước, rồi gọi `/handoff` ngay để chuyển đi tiếp. Không có yêu cầu làm việc mới trong phiên này.

## Diễn biến (theo thứ tự)
1. Người dùng: `/resume-work` (không chỉ định branch).
   Claude: thư mục mở trong VS Code là `Projects\test` (remote GitHub `platform-io-timesheet` báo "Repository not found"), không có HANDOFF.md. Theo memory, app đang làm là `cham_cong_don_gian`, nên chuyển sang repo này. `git fetch` thấy HANDOFF.md mới nhất ở `origin/claude/handoff-2026-10-18` (phiên cloud chỉ chào hỏi, không có việc). Đọc bằng `git show`, không checkout nhánh đó.
   - Phát hiện trên PC, nhánh `master`, có **nhiều thay đổi chưa commit** (20 file sửa + 4 file mới, ~830 dòng, sửa khoảng 12:26–12:30 ngày 2026-10-18). Đây là tính năng **lấy tăng ca bù giờ thiếu** do một phiên PC trước làm (xem dòng 2026-10-18 trong `CLAUDE.md` và `Y-TUONG-MOI.md`).
   - `git pull --ff-only` trên master: kéo về PR #9, #10 (skill /handoff, /resume-work, `THU-NGHIEM.md`). Không trùng file đang sửa, không đụng thay đổi dở.
   - Hỏi người dùng: commit / stash / để nguyên phần dở? Người dùng chưa trả lời mà gọi `/handoff`.
2. Người dùng: `/handoff`.
   Claude: để phiên kia làm tiếp được phần tăng ca bù giờ, tạo nhánh `pc/bu-tang-ca-2026-10-18` từ master, commit toàn bộ phần dở + file này, push. **Không đẩy vào master** vì tính năng chưa được người dùng thử trên điện thoại.

## Quyết định đã chốt
- Phần dở đưa lên nhánh riêng, không phải master. Lý do: chưa thử trên máy, người dùng chưa trả lời commit/stash.
- Nội dung tính năng đã chốt với người dùng nằm trong `Y-TUONG-MOI.md` (mục "Đã chốt", "Đã chốt thêm", "Đã làm lần 2"). Tóm tắt: chỉ cho Công nhân; công tắc 3 mức (Tắt / Chỉ bù ngày do công ty / Bù cả ngày tự nghỉ); ngày đủ công 8h T2–T6, thứ 7 là 4,5h (7h–11h30), từ 12h30 là tăng ca; 1h tăng ca bù 1h thường, ưu tiên tăng ca ngày thường rồi mới CN/lễ; chỉ bù trong cùng kỳ lương; ngày nghỉ có hai loại Tự nghỉ / Công ty cho nghỉ; có ngày phép mỗi kỳ; sửa tay giờ từng ngày và số của kỳ.

## Thay đổi code (do phiên PC trước làm, phiên này chỉ commit)
- `lib/domain/models.dart`, `lib/data/store.dart`, `lib/domain/backup.dart`, `lib/domain/config_share.dart`: cài đặt mức bù, loại ngày nghỉ, ngày phép, giờ sửa tay; lưu, sao lưu, chia sẻ cấu hình.
- `lib/domain/calc.dart`: bật bù thì gộp giờ thường + tăng ca, chia lại theo mốc 8h / 4,5h; xử lý luật đi muộn theo mức.
- `lib/domain/payslip.dart`: gom ngày thiếu giờ, lấy tăng ca trong kỳ bù vào; `offsetDays`, `offsetTakenSeconds`.
- `lib/domain/leave.dart` (mới): ngày phép / loại ngày nghỉ.
- `lib/ui/home/home_screen.dart`, `calendar_grid.dart`, `period_history.dart`: dòng "Giờ tăng ca bị trừ", huy hiệu giờ thiếu trên lịch, thống kê theo kỳ.
- `lib/ui/home/overtime_offset_sheet.dart` (mới): chi tiết giờ bị trừ theo ngày.
- `lib/ui/home/day_hours_dialog.dart` (mới): sửa tay giờ từng ngày.
- `lib/ui/settings/work_config_card.dart`, `payslip_card.dart`: công tắc 3 mức, sửa tay số của kỳ.
- `lib/gps/gps_task_handler.dart`, `gps_wifi.dart`, `lib/domain/gps_engine.dart`, `lib/ui/settings/gps_log_view.dart`: có sửa (chưa đọc kỹ trong phiên này; xem diff).
- `test/domain/overtime_offset_test.dart` (mới), `test/domain/gps_engine_test.dart`, `test/onboarding/tour_test.dart`.
- `pubspec.yaml`: 1.2.3+6 → **1.2.4+7**.
- `CLAUDE.md`, `Y-TUONG-MOI.md`: ghi chép tiến độ.

## Lệnh đã chạy / cài đặt / cấu hình quan trọng
- Phiên này: chỉ `git fetch`, `git pull --ff-only` (master), tạo nhánh, commit, push. Không chạy analyze/test.
- Theo `CLAUDE.md` (phiên PC trước): 240 test qua, `flutter analyze` sạch; đã build APK, cài lên điện thoại, mở được app.

## Còn dở / bước tiếp theo
- [ ] Người dùng thử tính năng tăng ca bù giờ trên điện thoại (bản 1.2.4 đã cài), góp ý.
- [ ] Sau khi người dùng đồng ý: merge `pc/bu-tang-ca-2026-10-18` vào master (master đã chứa sẵn `huong-dan-tung-buoc`, nên chỉ thêm phần tăng ca bù giờ).
- [ ] Chưa deploy web, chưa release GitHub. Build/release chỉ làm trên PC (khóa ký ở `C:\Users\Admin\Documents\khoa-ky-cham-cong-don-gian\`).
- [ ] Cập nhật `TIEN-DO.md` khi tính năng chốt xong.

## Ý tưởng chưa làm, câu hỏi còn mở
- Ba mặc định chờ người dùng chốt (`TIEN-DO.md`, mục "Mặc định Claude tự chọn, chờ người dùng xác nhận"): ngày nghỉ không lương = 0; thống kê 12 kỳ; hai nút đầu trang chỉ có icon.
- Hướng dẫn lần đầu mở app (`lib/onboarding/`) chưa thử trên điện thoại thật.
- Thư mục `Projects\test` có remote GitHub không tồn tại (`platform-io-timesheet`); không ảnh hưởng app.
