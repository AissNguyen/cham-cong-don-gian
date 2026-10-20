# Ý tưởng mới: lấy tăng ca bù giờ thiếu

Ghi lại từ buổi trao đổi trên cloud ngày 2026-10-18. **Đã code trên PC ngày 2026-10-18** (người dùng nói "code luôn", bỏ qua bước mockup HTML): test ở `test/domain/overtime_offset_test.dart`. Lần 2 (cùng ngày) làm thêm ba mức bù, hai loại ngày nghỉ, ngày phép, sửa tay; đã cài lên điện thoại và mở được app, chưa thử tính năng trên máy.

## Lý do

Công ty của người dùng lấy giờ ngoài giờ (tăng ca) để bù vào:
- ngày nghỉ (công ty cho nghỉ, hoặc người dùng tự xin nghỉ);
- những ngày đi làm thiếu giờ (đi muộn, về sớm);
- (chưa rõ) những ngày công ty yêu cầu làm vào lúc 8h, 13h. Xem câu 6 bên dưới.

Người dùng muốn app tính lương giống cách công ty tính.

## Cách tính mới (khi bật công tắc)

Khung giờ thường hiện tại của người dùng kết thúc lúc **16h**, sau 16h là tăng ca. App luôn trừ 1 tiếng nghỉ trưa (11h30–12h30).

1. **Trong một ngày:** lấy tổng giờ làm của ngày đó (đã trừ nghỉ trưa).
   - Trong mốc một ngày đủ công (8 tiếng, xem câu 4) thì tính lương giờ thường.
   - Phần vượt mốc mới tính lương tăng ca.

   Ví dụ vào 9h, về 18h:

   | | Giờ thường | Tăng ca |
   |---|---|---|
   | Hiện tại | 9h–16h trừ nghỉ trưa = 6 tiếng | 16h–18h = 2 tiếng |
   | Khi bật bù | 9h–18h trừ nghỉ trưa = 8 tiếng (đủ ngày) | 0 tiếng |

2. **Ngày thiếu giờ** (ví dụ về lúc 16h, hoặc nghỉ): phần thiếu được bù bằng giờ tăng ca.
   - **Đã chốt (câu 1):** lấy từ **tổng giờ tăng ca** để trừ vào (không chỉ tăng ca của riêng ngày đó).

## Giao diện

- **Cài đặt:** chung chỗ cài giờ tăng ca, thêm công tắc **"Lấy tăng ca bù vào ngày nghỉ, ngày đi muộn"**.
- **Thống kê:** thêm một số **"Giờ tăng ca bị trừ"**. Bấm vào thì hiện chi tiết: trừ để bù cho ngày nào, bao nhiêu giờ.

## Đã chốt (người dùng trả lời trên PC ngày 2026-10-18)

- **Chỉ áp dụng cho Công nhân.** Khi chọn Công nhật thì không hiện công tắc, cách tính giữ như cũ.
- Mọi điều bên dưới chỉ dùng khi **bật công tắc**. Tắt công tắc thì app tính như hiện nay.

1. **Lấy tăng ca từ đâu:** từ tổng giờ tăng ca **trong kỳ lương**, không chuyển sang kỳ sau. Tăng ca không đủ bù thì phần còn thiếu chịu như hiện nay.
2. **Ngày nghỉ nào phải bù:**
   - Nghỉ không lương và ngày công ty cho nghỉ (không trả lương): bù 8 tiếng mỗi ngày.
   - Nghỉ có lương: không bù.
   - Chủ nhật và ngày lễ: không bù.
   - **Thứ 7:** chỉ làm buổi sáng **7h–11h30 = 4,5 tiếng giờ thường** (đủ công thứ 7). 11h30–12h30 là nghỉ trưa, không tính. **Từ 12h30 trở đi là tăng ca.**
   - Thứ 7 về trước 11h30, hoặc nghỉ thứ 7 không lương: bù cho đủ 4,5 tiếng (7h–11h30), không phải 8 tiếng.
3. **Đi muộn:** bỏ luật đi muộn đã cài (trừ phút hoặc trừ tiền), thay bằng lấy tăng ca bù đúng số giờ thiếu, để không bị trừ hai lần.
4. **Một ngày đủ công = 8 tiếng** (T2–T6).
5. **1 giờ tăng ca bù 1 giờ thường.** Lấy tăng ca ngày thường bù trước, sau đó mới đến tăng ca Chủ nhật và ngày lễ (lương cao hơn).
6. **"Công ty yêu cầu vào lúc 8h, 13h"** là những ngày ít việc hoặc đang chờ hàng, công ty cho vào muộn hơn. Giờ thiếu của những ngày này **cũng lấy tăng ca bù**, coi như ngày thiếu giờ.

Không còn câu hỏi mở.

## Đã làm trong code (lần 1; lần 2 xem mục "Đã làm lần 2" bên dưới)

- Cài đặt: công tắc `overtimeOffset` (lưu trong cài đặt, đi kèm khi sao chép cấu hình), nằm trong thẻ "Cài đặt tính công" dưới bảng lương/giờ, chỉ hiện với Công nhân.
- `calc.dart`: bật bù thì mỗi ngày T2–T7 gộp giờ thường + tăng ca rồi chia lại theo mốc 8h (thứ 7: 4,5h), và bỏ luật đi muộn. Lịch, biểu đồ, Excel đều theo cách chia này.
- `payslip.dart`: gom các ngày thiếu giờ (ngày đã chấm ra, và ngày nghỉ không lương T2–T7) rồi lấy tăng ca trong kỳ bù vào; tăng ca T2–T7 trước, sau đó mới tới chủ nhật và ngày lễ. Giờ được bù cộng vào ngày công của ngày thiếu, bớt khỏi tiền tăng ca. Phiếu lương có `offsetDays`, `offsetTakenSeconds`.
- Màn chính: thẻ thu nhập có dòng "Giờ tăng ca bị trừ", bấm vào mở chi tiết theo ngày (`lib/ui/home/overtime_offset_sheet.dart`). Thống kê theo kỳ: mỗi kỳ có dòng "Tăng ca bị trừ …", bấm vào cũng mở chi tiết.
- Chỉ bù cho ngày đã đánh dấu nghỉ không lương; ngày bỏ trống (không chấm, không đánh dấu nghỉ) thì không bù.

## Góp ý sau khi thử trên điện thoại (2026-10-18)

1. **Lịch hiện giờ thiếu bằng huy hiệu cùng màu với huy hiệu tăng ca:** ngày nghỉ hiện "−8h", ngày làm thiếu hiện số thiếu (ví dụ ngày 9 vào 9:00 về 16:00 hiện "−2h").
2. Bật bù thì ngày nào cũng ~8h, nên **số giờ công trong ô lịch không cần nữa**.
3. **Chia hai loại ngày thiếu giờ:**
   - Do công ty: công ty cho nghỉ, công ty yêu cầu vào lúc 8h, 9h...
   - Do công nhân tự nghỉ: mất công luôn.
   - Công tắc thành hai mức: mức 1 chỉ lấy tăng ca bù cho ngày thiếu do công ty; mức 2 bù cả ngày công nhân tự nghỉ.
4. **Nút sửa tay:** sửa ngày công và giờ tăng ca ở phiếu lương; sửa giờ của từng ngày.

### Đã chốt thêm (2026-10-18)

- Ngày nghỉ khi bật bù: hai loại **Tự nghỉ** / **Công ty cho nghỉ** (tắt bù thì giữ có lương / không lương như cũ).
- Công tắc ba mức: Tắt / Chỉ bù ngày do công ty / Bù cả ngày tự nghỉ.
- Đi muộn: mức "bù cả ngày tự nghỉ" thì lấy tăng ca bù; mức "chỉ ngày do công ty" thì trừ phút theo luật đi muộn.
- Lịch: ngày được bù hiện huy hiệu cam "−8h", "−2h"; ngày tự nghỉ không được bù vẫn hiện "Nghỉ".
- Thứ 7 giữ như hiện giờ.

### Ngày phép (đã chốt)

- Mỗi kỳ lương được cộng 1 ngày phép; không dùng thì dồn sang kỳ sau.
- Tự nghỉ thì trừ vào ngày phép trước (tính như nghỉ có lương), hết phép mới là nghỉ không lương.
- Ban đầu cho 1 ngày phép (từ đầu kỳ bật bù). Số phép hiện ở nút Ngày nghỉ (dòng nhỏ dưới "Tự nghỉ") và ở phiếu lương; sửa tay ở phiếu lương (khi sửa thì cộng dồn hay xóa phép cuối năm là việc người dùng tự chỉnh).
- Trên lịch: nghỉ phép tô đậm (chữ "Phép"), tự nghỉ hết phép tô nhạt.
- Tự nghỉ hết phép ở mức "bù cả ngày tự nghỉ" thì lấy tăng ca bù.

### Đã làm lần 2 (2026-10-18)

- `AppSettings.offsetMode` (off / company / all) thay cho công tắc bật/tắt; dữ liệu bản thử đầu (`overtimeOffset: true`) đọc thành `all`. Chọn mức bằng ba nút ở Cài đặt tính công.
- `DayRecord.companyOff` (công ty cho nghỉ); tự nghỉ = nghỉ, không lương, không phải công ty. Khi bật bù, nút Ngày nghỉ có hai lựa chọn Tự nghỉ / Công ty cho nghỉ.
- Ngày phép: `lib/domain/leave.dart`, các mốc `AppSettings.leaveAnchors` (mốc đầu tạo khi bật bù lần đầu: 1 ngày từ đầu kỳ đang chạy; sửa số phép thì thêm mốc hôm nay). Đầu mỗi kỳ cộng 1. Chỉ ngày T2–T7 không lễ mới trừ phép.
- Đi muộn: `lateRuleApplies` trong `calc.dart`; luật đi muộn trừ sau khi chia lại giờ.
- Ngày vào muộn / về sớm không bấm "Đi muộn" coi là do công ty, luôn được bù.
- Lịch: huy hiệu cam "−8h", "−2h" cho ngày được tính bù; bật bù thì ô ngày đi làm không hiện số giờ nữa.
- Sửa tay: giờ của từng ngày (`DayRecord.manualNormalMinutes/manualOvertimeMinutes`, nút "Sửa giờ" cạnh Ghi chú); ngày công thực tế và giờ tăng ca của kỳ (`AppSettings.workDaysOverride/overtimeHoursOverride`, ở chế độ sửa của phiếu lương). Tiền từng ngày co giãn theo tỷ lệ.
- Lần 3 (theo góp ý): ở Cài đặt tính công thay ba nút bằng hai ô tích "Công ty cho nghỉ" / "Tự nghỉ" (tích "Tự nghỉ" là mức all, chỉ "Công ty cho nghỉ" là mức company, không tích là tắt); thêm dòng "Ngày phép còn" sửa được khi bấm Sửa; chữ giải thích chỉ hiện khi bấm Sửa. Bỏ hẳn phiếu lương mẫu (`computeSamplePayslip`).
- Lần 4: máy mới cài để mọi số tiền bằng 0 (test dùng bộ số mẫu cũ ở `test/sample_settings.dart`). Thẻ thu nhập: "Giờ công" thành "Ngày công" (công nhân), "Tổng giờ" thành "Trừ ngoài giờ" khi bật bù (bấm vào xem chi tiết). Gộp hai nút Chấm vào / Chấm ra thành một nút "Vào/Ra" (`showPunchDialog` trong `edit_dialogs.dart`): gõ bằng bàn phím số (0730 = 7h30, 9 = 9h), chung chỗ sửa tay giờ công / tăng ca; giữ nút thì chấm giờ hiện tại. Bỏ nút "Sửa giờ" cạnh Ghi chú.
- Lần 5: ô "Trừ tăng ca" luôn thay "Tổng giờ" với công nhân (tắt bù thì 0, bấm vào xem chi tiết); hai lựa chọn bù là ô tròn (chọn thì tô kín), sát nhau; phiếu lương kỳ chưa chốt hiện 0 thay cho "—"; bảo hiểm 10,5% ghi rõ "BHXH 8% + BHYT 1,5% + BHTN 1%"; "Lưu ý về cách tính" bỏ câu đầu và các mục bảo hiểm, chủ nhật/lễ, nghỉ có lương.
- Lần 6: ô lịch luôn hiện giờ vào, giờ ra; dòng thứ ba là tiền của ngày, chỉ khi đã cài lương (`AppSettings.hasPayConfigured`), chưa cài thì ô thấp lại. Bỏ hai nút "Giờ vào/ra" và "Lương mỗi ngày" ở đầu màn chính, chỉ còn nút Âm lịch. Công nhật: thẻ thu nhập còn ba ô Giờ công / Tăng ca / Ngày nghỉ (bỏ Tổng giờ).
- Lần 7 (theo `mockup/huong-dan-moi.html`, người dùng chốt): ngày phép độc lập với bù tăng ca (công nhân luôn có phép, nút Ngày nghỉ luôn Tự nghỉ / Công ty cho nghỉ; dòng "Ngày phép còn" ngay dưới Kỳ lương). Lần đầu mở app: bấm Bắt đầu thì hỏi Công nhân/Công nhật, kỳ lương, (công nhân) lấy tăng ca bù, ngày phép (`lib/onboarding/setup_dialog.dart`) rồi mới vào chuyến cơ bản. Chuyến cơ bản 10 bước: 8 bước trên màn chính (bỏ bước riêng nút trên cùng), bước 9–10 GPS hiện trong thẻ Chấm công GPS. Chưa cài lương: thẻ thu nhập hiện nút "Hướng dẫn tính lương" + chữ nhỏ; hướng dẫn lương phủ mờ, sáng từng chỗ trong Cài đặt (`lib/onboarding/pay_guide.dart`, theo kiểu `mockup/huong-dan-phieu-luong.html`; phần đối chiếu khi hết kỳ chưa làm). Màn Hướng dẫn: ba mục Cơ bản / Lương / Nâng cao (trang chữ).
- Lần 8: hướng dẫn lương có nhãn ngón tay "Nhập vào đây"; nút "Hướng dẫn tính lương" cũng hỏi trước loại người dùng, kỳ lương, bù tăng ca, ngày phép; câu hỏi kỳ lương theo loại người dùng (công nhân chỉ hỏi ngày bắt đầu, công nhật chỉ hỏi kỳ 1), bỏ nút chọn 1 kỳ / 2 kỳ. Ngày 2026-10-18 đã gỡ app và cài lại trên điện thoại người dùng (người dùng đồng ý xóa hết dữ liệu) để thử từ đầu.
- Lần 9 (2026-10-19): nút "Hướng dẫn tính lương" không hỏi lại câu ban đầu (chỉ màn Hướng dẫn › Hướng dẫn lương mới hỏi); nhãn ngón tay nhấp nháy `BlinkingHand` ("Hãy ấn vào đây" dưới nút, "Nhập vào đây" trong hướng dẫn lương). Thẻ Chấm công GPS có nút "Nhập tọa độ" (dán "vĩ độ, kinh độ", `parseLatLng`). Đã nhập tọa độ chỗ làm 11.759805, 108.439777 vào máy người dùng.
- Lần 10 (2026-10-19): nút "Hướng dẫn tính lương" thành `PayGuideCta` (viền nút sáng lên tắt xuống, ngón tay nhấp nháy đè mép phải, ấn ngón tay cũng mở), bỏ nhãn "Hãy ấn vào đây". Màn chính nhắc "Chưa cài chấm công tự động · Cài ngay" khi chưa có tọa độ (✕ thì tắt hẳn: `AppSettings.gpsReminderOff`); bước 9 hướng dẫn hai cách lấy tọa độ (tới chỗ làm bấm Lấy tọa độ, hoặc chép từ Google Maps rồi Nhập tọa độ). Lời mở hướng dẫn lương có nút "Đồng nghiệp đã cài sẵn? Dán cấu hình" (theo `huong-dan-phieu-luong.html`): dán xong chỉ hỏi lại lương cơ bản / lương ngày rồi sang lời kết.
- Lần 11: ô "Nhập tọa độ" nhận kiểu Google Maps tiếng Việt (dấu phẩy thập phân, "11,7598094, 108,4397679") lẫn kiểu tiếng Anh; ô điền sẵn cũng hiện theo kiểu tiếng Việt. Đã nhập 11,7598094, 108,4397679 vào máy người dùng.
- 2026-10-19 tối, người dùng báo GPS lỗi: nhật ký chỉ có lần dò 07:34–07:51, sau đó cả ngày không dò. Nguyên nhân: sau khi gỡ app cài lại (để thử từ đầu), ColorOS 7.2 (Realme RMX2021, Android 10) đặt lại "Cho phép hoạt động dưới nền" và "Cho phép tự động khởi chạy" về tắt (Cài đặt › Ứng dụng › Chấm Công › Mức sử dụng pin), nên báo thức không bật được việc dò khi app đang đóng. Quyền vị trí "Luôn cho phép", định vị bật, miễn tối ưu pin đều đã có. Đã thêm nhật ký cho các lần báo thức reo mà không dò (bị khóa dùng thử, lần dò trước còn chạy, máy không cho bật dịch vụ) và lỗi khi dò, trước đây các trường hợp này dừng im lặng. Gợi ý (chưa làm): nút "Cấp quyền chấm công" mở luôn trang pin của app trên máy Realme/OPPO và nhắc bật hai công tắc này.
- Chưa làm: file Excel sao lưu chưa ghi "công ty cho nghỉ" và giờ sửa tay (sao lưu JSON thì có).

## Chỗ code liên quan (cho Claude trên PC)

- Tính giờ thường và tăng ca của một ngày: `computeDay` và `liveDayHours` trong `lib/domain/calc.dart`. Hiện tăng ca tính từ giờ ra của khung (`workEnd`), có khung tăng ca và luật đi muộn.
- Tính lương theo kỳ, ngày nghỉ có lương và không lương: `lib/domain/payslip.dart`. Việc bù theo kỳ nên đặt ở đây, vì cần nhìn cả kỳ.
- Cài đặt tăng ca: `lib/ui/settings/`. Thống kê: `lib/ui/home/`.
- Nhớ viết test ở `test/domain`.
