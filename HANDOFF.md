# HANDOFF — 2026-10-20 — PC

Branch: pc/bu-tang-ca-2026-10-18   Repo: AissNguyen/cham-cong-don-gian

Phiên này chạy trên PC từ 2026-10-18 tới 2026-10-20 (VS Code mở thư mục `Projects\test`, làm việc trong `Projects\cham_cong_don_gian`). Chi tiết từng lần sửa còn ghi trong `Y-TUONG-MOI.md` (mục "Đã làm…", "Lần 2" … "Lần 11", và ghi chú GPS 2026-10-19).

## Mục tiêu của phiên
Người dùng: "đọc Y-TUONG-MOI.md" → chốt và làm tính năng **lấy tăng ca bù giờ thiếu** (công ty lấy giờ tăng ca bù cho ngày nghỉ, ngày đi muộn), rồi theo góp ý khi thử trên điện thoại: ngày phép, sửa tay giờ, gộp nút chấm công, lịch mới, hướng dẫn mới (lần đầu mở app, hướng dẫn cơ bản, hướng dẫn lương), nhập tọa độ GPS, và cuối cùng kiểm tra lỗi GPS.

## Diễn biến (theo thứ tự)
1. Người dùng: "git pull, đọc Y-TUONG-MOI.md". Claude: remote của `Projects\test` (`platform-io-timesheet`) không còn trên GitHub; pull ở `cham_cong_don_gian`, đọc ý tưởng, tóm tắt 6 câu hỏi mở.
2. Người dùng trả lời: tổng tăng ca trong kỳ; nghỉ không lương/công ty cho nghỉ bù 8h, nghỉ có lương/CN/lễ không bù; **thứ 7 làm 7h–11h30 (4,5h) là đủ công, 11h30–12h30 nghỉ trưa, từ 12h30 là tăng ca**; đi muộn: khi bù thì bỏ luật đi muộn; **một ngày đủ công 8 tiếng**; 1h tăng ca bù 1h, ưu tiên tăng ca ngày thường; ngày công ty cho vào lúc 8h/13h (ít việc, chờ hàng) cũng được bù; chỉ áp dụng **Công nhân**. Claude ghi vào md.
3. Người dùng: "code luôn". Claude làm bản 1 (công tắc bật/tắt, chia lại giờ trong ngày, bù theo kỳ, dòng "Giờ tăng ca bị trừ" + màn chi tiết). Cài lên điện thoại.
4. Góp ý sau khi thử: lịch hiện giờ thiếu "−8h", "−2h" màu cam như huy hiệu tăng ca; bỏ số giờ trong ô; chia hai loại nghỉ; nút sửa tay giờ (phiếu lương và từng ngày). Chốt: **hai loại nghỉ Tự nghỉ / Công ty cho nghỉ**; công tắc 3 mức; đi muộn: mức "bù cả ngày tự nghỉ" thì lấy tăng ca bù, còn không thì trừ phút như cũ; thứ 7 giữ như cũ (0,56 công).
5. Người dùng thêm **ngày phép**: mỗi kỳ +1 phép, dồn sang kỳ sau; tự nghỉ trừ phép trước rồi mới không lương; ban đầu 1 phép; hiện ở nút Ngày nghỉ (dòng nhỏ "Bạn còn … ngày phép") và phiếu lương; nghỉ phép tô đậm, hết phép tô nhạt; xóa phép cuối năm thì người dùng tự sửa tay.
6. Góp ý tiếp: 3 nút mức bù → **2 ô tròn** "Công ty cho nghỉ" / "Tự nghỉ" (chọn Tự nghỉ thì cũng bù ngày công ty); ngày phép sửa được ở Cài đặt tính công; chữ giải thích chỉ hiện khi bấm Sửa; **bỏ phiếu lương mẫu, mọi số tiền về 0** (máy mới cài); bảo hiểm ghi rõ "BHXH 8% + BHYT 1,5% + BHTN 1%"; "Lưu ý về cách tính" bỏ câu đầu và mục 4, 5, 6.
7. Thống kê nhanh: "Giờ công" → **"Ngày công"**; "Tổng giờ" → **"Trừ tăng ca"** (luôn hiện với công nhân, bấm xem chi tiết). **Gộp nút Chấm vào/Chấm ra thành một nút "Vào/Ra"**: nhập giờ bằng bàn phím số (7h30 ghi 0730, 9h ghi 9), chung chỗ sửa tay giờ công/tăng ca.
8. Lịch: **luôn hiện giờ vào, giờ ra**; dòng thứ ba là **tiền của ngày** (chỉ khi đã cài lương; chưa cài thì ô thấp lại). Bỏ hai nút "tiền" và "giờ" trên cùng, chỉ còn nút âm lịch. Công nhật: thẻ thống kê Giờ công / Tăng ca / Ngày nghỉ.
9. Ngày phép **độc lập với bù tăng ca**. Chỗ "0 đ" khi chưa cài lương → nút **"Hướng dẫn tính lương"** + chữ nhỏ "Đây là chức năng ước tính lương, nếu bạn không cần thì bỏ qua nhé." Claude làm `mockup/huong-dan-moi.html` (artifact https://claude.ai/artifact/WCLM1TsYsxDR3m3P1sFGEx), người dùng góp ý 2 lần rồi chốt: lần đầu mở app = khung "Tính năng cơ bản" → hỏi **Công nhân/Công nhật → kỳ lương → (công nhân) lấy tăng ca bù, ngày phép** → hướng dẫn cơ bản **10 bước có GPS (bước 9–10)**; màn Hướng dẫn chia **Cơ bản / Lương / Nâng cao (trang chữ)**; bước 5 bỏ câu "công ty cho vào muộn thì không cần bấm".
10. Người dùng chỉ `mockup/huong-dan-phieu-luong.html` làm mẫu: hướng dẫn lương **phủ mờ, sáng từng chỗ trong Cài đặt**, có ngón tay "Nhập vào đây" nhấp nháy. Câu hỏi kỳ lương theo loại người dùng (công nhân chỉ hỏi ngày bắt đầu, công nhật chỉ hỏi kỳ 1), bỏ chọn 1/2 kỳ.
11. Người dùng: "xóa hết dữ liệu để trải nghiệm từ đầu" → đồng ý ("oki"). `pm clear` bị ColorOS chặn → **gỡ app và cài lại** (mất toàn bộ dữ liệu trên máy người dùng, kể cả cài đặt chạy nền của ColorOS — xem mục 15).
12. Nút "Hướng dẫn tính lương" không hỏi lại câu ban đầu; **ngón tay nhấp nháy đè lên mép nút, viền nút sáng lên tắt xuống** (bỏ nhãn "Hãy ấn vào đây" vì gây hiểu nhầm). Thêm nút **"Nhập tọa độ"** ở thẻ Chấm công GPS; nhập tọa độ chỗ làm của người dùng.
13. Bàn trước khi code: nhắc cài GPS lần sau (dòng **"Chưa cài chấm công tự động · Cài ngay"** trên màn chính, ✕ tắt hẳn; bước 9 hướng dẫn 2 cách: tới chỗ làm bấm Lấy tọa độ, hoặc chép từ Google Maps rồi Nhập tọa độ); lời mở hướng dẫn lương có **"Đồng nghiệp đã cài sẵn? Dán cấu hình"**, dán xong chỉ hỏi lại lương cơ bản/lương ngày. Người dùng "ok" → làm.
14. Google Maps tiếng Việt cho tọa độ dạng **"10,7724983, 106,6980146"** (dấu phẩy thập phân) → ô Nhập tọa độ nhận cả kiểu này. Tọa độ chỗ làm hiện lưu: **10,7724983, 106,6980146**.
15. Người dùng (19/10 tối): "GPS lại lỗi". Kiểm tra: nhật ký chỉ có lần dò 07:34–07:51, sau đó cả ngày không dò. Quyền vị trí "Luôn cho phép", định vị bật, miễn tối ưu pin, báo thức có đặt. Nguyên nhân: ColorOS 7.2 (Realme RMX2021, Android 10) — trong Cài đặt › Ứng dụng › Chấm Công › **Mức sử dụng pin**, "Cho phép hoạt động dưới nền" và "Cho phép tự động khởi chạy" đang **tắt** (bị đặt lại khi gỡ cài lại ở bước 11). Claude mở sẵn trang đó, nhờ người dùng bật cả hai. Thêm nhật ký cho các lần báo thức reo mà không dò (trước đây dừng im lặng).
16. Người dùng: "tóm tắt lại all ý chính và lưu vào md, sau đó chuyển sang phiên mới" → file này.

## Quyết định đã chốt
- Bù tăng ca chỉ cho **Công nhân**; mức bù: tắt / chỉ ngày do công ty / cả ngày tự nghỉ (giao diện là 2 ô tròn).
- Ngày đủ công T2–T6 = 8h; thứ 7 = 7h–11h30 (4,5h), từ 12h30 là tăng ca; thứ 7 vẫn tính ngày công = giờ ÷ 8 (người dùng chọn "như hiện giờ").
- Bù trong cùng kỳ lương, 1h tăng ca bù 1h, lấy tăng ca T2–T7 trước rồi mới CN, lễ; không đủ bù thì phần thiếu mất.
- Ngày thiếu giờ không bấm "Đi muộn" = do công ty (luôn được bù khi bật bù).
- Ngày phép: mỗi kỳ +1, dồn sang kỳ sau, tự nghỉ trừ phép trước; độc lập với bù tăng ca; chỉ công nhân.
- Máy mới cài: mọi số tiền = 0; không còn phiếu lương mẫu; phiếu kỳ chưa chốt hiện 0.
- Một nút Vào/Ra, nhập giờ bằng chữ số; lịch luôn hiện giờ vào/ra, tiền ngày chỉ khi đã cài lương.
- Hướng dẫn: lần đầu mở app hỏi loại người dùng, kỳ lương (+ bù tăng ca, ngày phép) rồi mới hướng dẫn cơ bản 10 bước; hướng dẫn lương là lớp phủ sáng từng chỗ; màn Hướng dẫn 3 mục.

## Thay đổi code (đã commit trong `49df007`)
- `lib/domain/models.dart` — `OvertimeOffsetMode` (thay công tắc bật/tắt; dữ liệu cũ `overtimeOffset: true` → `all`), `LeaveAnchor`/`leaveAnchors`, `workDaysOverride`, `overtimeHoursOverride`, `gpsReminderOff`, `hasPayConfigured`, `withLeaveBalance`; `DayRecord.companyOff`, `manualNormalMinutes`, `manualOvertimeMinutes`; mặc định máy mới: tiền = 0.
- `lib/domain/calc.dart` — chia lại giờ theo mốc 8h/4,5h khi bật bù (`offsetFullDaySeconds`, `_offsetSplit`), `lateRuleApplies` (luật đi muộn theo mức, trừ sau khi chia), giờ sửa tay của ngày.
- `lib/domain/leave.dart` (mới) — tính ngày phép theo mốc, cộng 1 mỗi kỳ, trừ khi tự nghỉ.
- `lib/domain/payslip.dart` — bù theo kỳ (`OvertimeOffsetDay`, `offsetDays`, ưu tiên tăng ca T2–T7), ngày phép tính như nghỉ có lương, số sửa tay của kỳ (co giãn tiền từng ngày); bỏ `computeSamplePayslip`.
- `lib/domain/config_share.dart` — sao chép/dán cấu hình kèm mức bù (`ob`: 1 company, 2 all).
- `lib/ui/home/home_screen.dart` — thẻ thu nhập (Ngày công, Tăng ca, Trừ tăng ca bấm được, Ngày nghỉ; nút `PayGuideCta` khi chưa cài lương), nút Vào/Ra, nút Ngày nghỉ (Tự nghỉ/Công ty cho nghỉ + số phép), dòng nhắc cài GPS, lần đầu mở app gọi `showSetupDialog` trước chuyến.
- `lib/ui/home/calendar_grid.dart` — giờ vào/ra + tiền ngày, huy hiệu "−", Phép đậm/nhạt, ô thấp khi chưa cài lương.
- `lib/ui/home/edit_dialogs.dart` — `showPunchDialog` (giờ vào/ra + sửa tay giờ công/tăng ca, `parseHourDigits`); bỏ `day_hours_dialog.dart`.
- `lib/ui/home/overtime_offset_sheet.dart` (mới) — chi tiết "Trừ tăng ca".
- `lib/ui/settings/work_config_card.dart` — dòng Ngày phép còn, 2 ô tròn bù tăng ca, chữ giải thích chỉ khi Sửa.
- `lib/ui/settings/payslip_card.dart` — sửa tay ngày công/giờ tăng ca/ngày phép, bảo hiểm ghi rõ các loại, bỏ phiếu mẫu, kỳ chưa chốt hiện 0, bớt mục lưu ý, mốc cho hướng dẫn lương.
- `lib/ui/settings/settings_blocks.dart` — thẻ GPS: lời hướng dẫn bước 9–10 (2 cách), nút Nhập tọa độ (`parseLatLng`, nhận dấu phẩy thập phân).
- `lib/ui/settings/settings_screen.dart` — `payGuide` (lớp phủ hướng dẫn lương), `scrollToGps` hiện gợi ý bước 9–10.
- `lib/ui/settings/help_screen.dart` — 3 mục Cơ bản / Lương / Nâng cao.
- `lib/onboarding/setup_dialog.dart` (mới) — câu hỏi lần đầu. `lib/onboarding/pay_guide.dart` (mới) — hướng dẫn lương, `BlinkingHand`, `PayGuideCta`, dán cấu hình đồng nghiệp. `tour_controller.dart`, `tour_overlay.dart` — 10 bước, câu chữ mới.
- `lib/gps/gps_scheduler.dart`, `lib/gps/gps_task_handler.dart` — ghi nhật ký khi báo thức reo mà bị khóa / dịch vụ còn chạy / máy không cho bật dịch vụ / lỗi khi dò.
- Test: `test/domain/overtime_offset_test.dart`, `test/onboarding/setup_and_pay_guide_test.dart`, `test/ui/punch_digits_test.dart` (mới), `test/sample_settings.dart` (bộ số mẫu cũ cho test, vì máy mới để tiền = 0); sửa các test cũ theo giao diện mới. **247 test qua, analyze sạch.**
- Mockup: `mockup/huong-dan-moi.html` (mới), `mockup/huong-dan-phieu-luong.html` (có sẵn, trước đây chưa commit).

## Lệnh đã chạy / cài đặt / cấu hình quan trọng
- Build và cài: `flutter build apk --release`, rồi `adb -s 5SRONVQKHUZH9H8L install -r build/app/outputs/flutter-apk/app-release.apk` (adb ở `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`). Bản trên điện thoại là bản mới nhất của phiên này (version 1.2.4+7).
- 2026-10-18 23:51: đã **gỡ app và cài lại** trên điện thoại người dùng (người dùng đồng ý xóa dữ liệu). Hệ quả: mất dữ liệu chấm công cũ, cài đặt chạy nền ColorOS bị đặt lại.
- Chụp màn hình điện thoại để kiểm tra: dùng bash `adb exec-out screencap -p > file.png` (PowerShell làm hỏng ảnh). `uiautomator dump` cần `MSYS_NO_PATHCONV=1` trong Git Bash.
- Artifact mockup: https://claude.ai/artifact/WCLM1TsYsxDR3m3P1sFGEx

## Còn dở / bước tiếp theo
- [ ] Người dùng bật "Cho phép hoạt động dưới nền" và "Cho phép tự động khởi chạy" (Cài đặt › Ứng dụng › Chấm Công Đơn Giản › Mức sử dụng pin), rồi sáng hôm sau xem Nhật ký GPS từ 6:45. Nếu vẫn không dò, nhật ký giờ ghi lý do.
- [ ] Người dùng bấm "Cấp quyền chấm công" nếu thẻ GPS còn báo "chưa cấp quyền".
- [ ] Người dùng thử toàn bộ luồng mới trên máy; khi người dùng thấy ổn: merge nhánh này vào `master` (theo `CLAUDE.md`, PC commit/push thẳng `master` khi người dùng đồng ý), cập nhật `TIEN-DO.md`, `CLAUDE.md`.
- [ ] Chưa deploy web, chưa phát hành APK lên Releases.

## Phiên 2026-10-20 (PC): hình động lấy tọa độ từ Google Maps
- Người dùng muốn "video ngắn về lấy GPS bằng cách nhập" → chọn **dựng hình động** (không quay video). Mockup `mockup/gps-nhap-toa-do.html` (artifact https://claude.ai/artifact/BLHRLSSe53Np7bgSPwgaDx), người dùng thêm bước **phóng to bản đồ, giữ đúng chỗ chấm công** rồi chốt.
- Code (chưa commit): `lib/ui/widgets/gps_coords_demo.dart` (mới) — hình động 7 bước vẽ bằng widget (~24 giây, lặp, tạm dừng/xem lại), `openGoogleMaps()`, `gpsExampleCoords` = 10,7724983, 106,6980146. Gắn vào: hộp Nhập tọa độ (nút "Xem cách làm", "Mở Google Maps" — đã có tọa độ thì mở đúng chỗ đó), lời hướng dẫn bước 9 (nút "Xem cách lấy tọa độ từ Google Maps"), màn Hướng dẫn (mục "Lấy tọa độ từ Google Maps"). Lời trong app bỏ tọa độ chỗ làm thật của người dùng, thay bằng tọa độ ví dụ, thêm ý phóng to bản đồ.
- Test `test/ui/gps_coords_demo_test.dart`; **251 test qua, analyze sạch**. Đã build, cài lên điện thoại và mở app; chưa thử hình động trên máy.
- Việc tiếp (Claude đề xuất 2026-10-21, chờ người dùng trả lời, rồi người dùng bảo tắt PC):
  1. Đối chiếu cách chép tọa độ trên Google Maps thật (có thể chỉ cần bấm vào dãy số ở khung dưới là chép), sửa hình động cho đúng.
  2. Mở hình động trên máy, chụp màn hình xem ngón tay có chạm đúng nút không.
  3. Repo công khai: thay tọa độ chỗ làm thật của người dùng ở `HANDOFF.md` (mục 14), `Y-TUONG-MOI.md` (lần 11), `test/ui/punch_digits_test.dart` bằng tọa độ ví dụ trước lần commit tới.
  4. Hỏi người dùng GPS sáng 21/10 có tự dò không (đã bật 2 công tắc chạy nền chưa).
  5. Commit phần hình động khi người dùng thấy ổn (hiện chưa commit, file vẫn nằm trên máy).

## Ý tưởng chưa làm, câu hỏi còn mở
- Gợi ý (chờ người dùng đồng ý): trên máy Realme/OPPO, nút "Cấp quyền chấm công" mở luôn trang pin của app và nhắc bật 2 công tắc chạy nền.
- Phần B của `mockup/huong-dan-phieu-luong.html` (đối chiếu với phiếu lương thật khi hết kỳ) chưa làm.
- File Excel sao lưu chưa ghi "Công ty cho nghỉ", giờ sửa tay, ngày phép (sao lưu JSON thì có).
- Lớp phủ hướng dẫn lương chưa phủ thanh tiêu đề "Cài đặt" (không ảnh hưởng dùng).
