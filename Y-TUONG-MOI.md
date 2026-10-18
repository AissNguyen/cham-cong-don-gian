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
- Chưa làm: file Excel sao lưu chưa ghi "công ty cho nghỉ" và giờ sửa tay (sao lưu JSON thì có).

## Chỗ code liên quan (cho Claude trên PC)

- Tính giờ thường và tăng ca của một ngày: `computeDay` và `liveDayHours` trong `lib/domain/calc.dart`. Hiện tăng ca tính từ giờ ra của khung (`workEnd`), có khung tăng ca và luật đi muộn.
- Tính lương theo kỳ, ngày nghỉ có lương và không lương: `lib/domain/payslip.dart`. Việc bù theo kỳ nên đặt ở đây, vì cần nhìn cả kỳ.
- Cài đặt tăng ca: `lib/ui/settings/`. Thống kê: `lib/ui/home/`.
- Nhớ viết test ở `test/domain`.
