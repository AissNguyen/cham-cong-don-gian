# Thiết kế bản mới — phiếu lương, Cài đặt gộp, nhắc cập nhật

**Chốt với người dùng ngày 2026-10-10.** File này là bản ghi đầy đủ các quyết định để viết code; người viết code (kể cả Claude trên cloud) không có cuộc trò chuyện gốc nên phải dựa vào đây. Đọc `CLAUDE.md` và `TIEN-DO.md` trước.

Bản mẫu HTML đã được người dùng duyệt, mở bằng trình duyệt để xem (bấm được):

- `mockup/luong-va-cai-dat.html` — màn Cài đặt mới. Đuôi địa chỉ `#sua`, `#nhat`, `#nhatsua`, `#mo` mở thẳng từng trạng thái.
- `mockup/nhac-cap-nhat.html` — ba trạng thái hộp nhắc cập nhật và bảng tham số Remote Config.
- `mockup/phieu-luong.html`, `mockup/cai-dat-nang-cao.html` — hai bản đầu, đã bị thay thế, chỉ để đối chiếu.

App cũ (trước thay đổi này) được giữ ở nhánh `cham-cong-don-gian-cu`. Bản mới làm trên `master` (qua pull request). Vẫn là **cùng một app** (cùng mã gói, cài đè giữ dữ liệu), không tách app riêng.

## 1. Vì sao làm

Người dùng thử (công nhân cùng bộ phận) thấy phần Cài đặt quá nhiều mục, không biết điền gì. Hướng giải quyết: mọi thứ cài sẵn theo cách tính của bộ phận, người dùng chỉ thấy **một phiếu lương** giống phiếu công ty phát và sửa vài con số của riêng mình.

## 2. Hai loại người dùng

Trên cùng màn Cài đặt có hai nút nhỏ, chỉ chọn một: **Công nhân** (đứng trước, mặc định khi mới cài) và **Công nhật**.

- Bấm đổi loại thì hỏi lại: "Nếu bạn đổi thì phần lương và cài đặt tính công cũ sẽ bị mất hết (giờ chấm công từng ngày vẫn giữ nguyên). Bạn chắc chắn đổi không?"
- Đồng ý thì đặt lại phần lương và cài đặt tính công về mặc định của loại mới (`AppSettings.defaultsFor(kind, keep: cài đặt cũ)`): giữ giờ chấm công, GPS, ngày lễ, khung tăng ca, công tắc ẩn/hiện.

### Mặc định Công nhân

| Mục | Giá trị |
|---|---|
| Lương cơ bản | 4.000.000 đ/tháng |
| Thưởng thành tích | 2.000.000 đ/tháng (khoản "căn cứ") |
| Các khoản trợ cấp | 0 (có sẵn dòng, người dùng tự điền) |
| Bảo hiểm | 10,5% lương cơ bản (BHXH 8 + BHYT 1,5 + BHTN 1), gom một dòng |
| Cơm trưa | 10.000 đ × số ngày làm qua 12:30 (khấu trừ) |
| Công đoàn phí | 50.000 đ/kỳ |
| Kỳ lương | theo tháng, bắt đầu ngày 21 |
| Giờ làm | 07:00–16:00, nghỉ trưa 11:30–12:30 (đã có sẵn trong `calc.dart`) |
| Bảng lương/giờ | T2–T7: giờ thường **tự tính** = lương cơ bản ÷ công chuẩn ÷ 8 (không sửa được), tăng ca 45.000. Chủ nhật 45.000 : 45.000. Ngày lễ 63.000 : 63.000 |
| Đi muộn | trừ 30 phút (chọn được trừ phút hoặc trừ tiền) |

### Mặc định Công nhật

| Mục | Giá trị |
|---|---|
| Lương cơ bản | 350.000 đ/ngày |
| Cơm trưa | 10.000 đ × số ngày làm qua 12:30 (khấu trừ) |
| Kỳ lương | 2 kỳ một tháng: kỳ 1 từ ngày A đến ngày B (mặc định 1–15), kỳ 2 từ B+1 đến **trước ngày đầu kỳ 1** của tháng sau |
| Bảng lương/giờ | cả 6 ô tự điền = lương ngày ÷ 8 (43.750). Sửa ô nào thì ô đó giữ số người dùng nhập (trong dữ liệu: ô bằng 0 nghĩa là tự tính) |
| Giờ làm, đi muộn | như Công nhân |

## 3. Quy tắc tính phiếu lương

Một bộ tính duy nhất (đề xuất `lib/domain/payslip.dart`, thuần Dart, có test). **Thẻ thu nhập ở màn chính, số "Hôm nay", tiền từng ngày trên lịch, thống kê theo kỳ và file Excel đều phải lấy số từ bộ tính này**, không tự tính riêng. Cần test khẳng định "số trên thẻ màn chính = Thực nhận của phiếu lương" ở các tình huống: giữa ca, giữa kỳ, ngày chốt kỳ, có tăng ca, có chủ nhật và lễ, có đi muộn.

Số giờ từng ngày dùng lại `computeDay` (giờ thường, giờ tăng ca, nghỉ trưa, đi muộn, khung tăng ca). Ca đang mở của hôm nay tính theo giây như `liveEstimatedPay` (cần tách phần đếm giây ra để dùng lại). Ca mở của ngày cũ (quên chấm ra) coi như chưa có giờ.

### Công nhân

- **Công chuẩn của kỳ** = số ngày trong kỳ trừ các chủ nhật (kỳ 21/07–20/08/2026 ra 27). Người dùng sửa tay được trong phiếu lương; số sửa tay chỉ áp dụng cho đúng kỳ đó (`AppSettings.standardDays`, khóa là `PayPeriod.key`). Bấm ✕ ở dòng Công chuẩn là bỏ số sửa tay, quay về tự đếm.
- **Ngày công thực tế** = tổng giờ thường của các ngày T2–T7 không phải lễ ÷ 8.
- **Chủ nhật và ngày lễ không tính ngày công**: toàn bộ giờ làm những ngày đó tính tiền theo bảng lương/giờ và cộng vào dòng tăng ca.
- **Tiền lương** = lương cơ bản ÷ công chuẩn × ngày công.
- **Khoản căn cứ** (thưởng thành tích và khoản người dùng thêm ở mục Căn cứ): mức tháng ÷ công chuẩn × ngày công, hiện thành một dòng ở Thu nhập.
- **Thưởng vượt khoán** (chính là tiền tăng ca): giờ tăng ca T2–T7 × giá tăng ca + giờ chủ nhật × giá chủ nhật + giờ lễ × giá lễ, theo bảng lương/giờ. Dòng giải thích tách rõ từng loại, ví dụ "Tăng ca 12h × 45.000 + chủ nhật 8h × 45.000".
- **Khoản cố định mỗi kỳ** (trợ cấp, công đoàn phí) và **khoản % lương cơ bản** (bảo hiểm): trong kỳ được **chia đều cho công chuẩn**, tức nhân với tỉ lệ ngày công ÷ công chuẩn, không vượt quá 100%.
- **Khi kỳ đã kết thúc** (hôm nay sau ngày cuối kỳ) và kỳ đó có ngày công: các khoản **khấu trừ** cố định và theo % được **tính đủ**. Khoản thu nhập cố định (trợ cấp) vẫn theo ngày công.
- **Khoản "× số ngày công"** có mốc giờ (cơm trưa, mốc 12:30): số tiền × số ngày có đi làm và làm qua mốc giờ (ca đã chấm ra sau mốc giờ, hoặc ca đang mở mà bây giờ đã qua mốc). Không có mốc giờ thì đếm mọi ngày có đi làm.
- **Đi muộn trừ tiền**: thành một dòng khấu trừ "Đi muộn". Đi muộn trừ phút thì đã nằm trong giờ công.

### Công nhật

- **Tiền lương** = tổng giờ làm × giá giờ theo bảng lương/giờ (mặc định mọi ô = lương ngày ÷ 8). Khi mọi ô còn mặc định, dòng giải thích ghi "350.000 ÷ 8 × 89 giờ".
- Không có công chuẩn; khoản cố định (nếu người dùng tự thêm) tính đủ.
- Cơm trưa như Công nhân.

### Số chạy trên màn chính

- Chấm vào là số bắt đầu chạy ngay, theo giây.
- Số **đứng yên** trong giờ nghỉ trưa 11:30–12:30 và trong giờ nghỉ của khung tăng ca. Chấm ra ngay trong giờ nghỉ trưa thì phần giờ nghỉ đã qua vẫn được tính (đã có sẵn trong `computeDay`).
- Số "Hôm nay" = phần đóng góp của hôm nay vào Thực nhận (lương theo ngày công + phần khoản cố định của ngày + tăng ca − cơm trưa nếu đã qua 12:30).

### Hiển thị số

- Bên trong luôn tính bằng số lẻ, **không làm tròn**, để tổng chính xác.
- Hiển thị ở mọi nơi là **số nguyên** (bỏ phần lẻ), có dấu chấm ngăn hàng nghìn.

## 4. Màn Cài đặt mới

Theo đúng `mockup/luong-va-cai-dat.html`, từ trên xuống:

1. **Thông báo** (nếu có): thông báo mới thì hiện đầy đủ; bấm "Thu gọn" thì còn 1 hàng rõ và 1 hàng mờ dần, bấm "Xem thêm" để mở lại. App nhớ thông báo đã thu gọn; đổi nội dung là thành thông báo mới và lại hiện đầy đủ. **Không có nút xóa và không có công tắc tắt thông báo** (sửa ngày 2026-10-10).
2. **Hai nút nhỏ** Công nhân / Công nhật.
3. **Thẻ Phiếu lương**: mũi tên chuyển kỳ, nút "Sửa" riêng.
   - *Xem*: đầu phiếu (tháng, nhãn "Tạm tính" khi kỳ chưa kết thúc, Thực nhận, dòng "Thu nhập … · trừ …"); khối **Căn cứ tính**; **Thu nhập** và tổng; **Khấu trừ** và tổng; ô **Thực nhận**; dòng rút gọn **"Lưu ý về cách tính"** bấm mới mở (nội dung trong bản mẫu). Mỗi dòng có một dòng nhỏ giải thích công thức.
   - *Sửa*: khoản đã có (cài sẵn hay tự thêm) thì **sửa con số ngay tại dòng** và có dấu ✕; **không mở bảng**. Dòng tự tính (Tiền lương, dòng thu nhập của khoản căn cứ, Thưởng vượt khoán) không có ô nhập, chỉ có ✕. Bảo hiểm sửa theo %. Cuối mỗi mục (Căn cứ, Thu nhập, Khấu trừ) có nút "Thêm khoản".
   - **Bảng "Khoản mới"** chỉ hiện khi thêm: tên, cách tính (Cố định mỗi kỳ / × số ngày công / % lương cơ bản), số, "Chỉ tính từ giờ…". **Không có mục "Loại"**: app tự hiểu theo nút được bấm. Khoản thêm ở mục Căn cứ chỉ có tên và số tiền/tháng.
   - **Mọi dấu ✕ đều hỏi lại** "Bạn chắc chắn muốn xóa … không?" trước khi xóa, kể cả khoản cài sẵn. ✕ ở Lương cơ bản thì đặt về 0.
4. **Thẻ "Cài đặt tính công"**: một khối gộp, nút "Sửa" riêng, xem / sửa như phiếu lương: kỳ lương, giờ làm, bảng lương/giờ (3 hàng: T2–T7, Chủ nhật, Ngày lễ × 2 cột), đi muộn.
5. **Thẻ Chấm công GPS** (ẩn trên web): chỉ có nút "Lấy tọa độ", nút "Cấp quyền chấm công" và một dòng trạng thái. Bấm Lấy tọa độ thì bật GPS luôn.
6. **Thẻ "Nâng cao và cài đặt khác"**: bình thường chỉ là một dòng gợi ý, bấm mới xổ. Bên trong: công tắc **Dùng chấm công GPS** (tắt thì ẩn thẻ GPS và GPS ngừng tự chấm); rồi các dòng mở sang màn con dùng lại các mục đã có: Ngày lễ, Tăng ca theo khung, GPS tùy chọn thêm (mục GPS đầy đủ hiện có), Sao lưu dữ liệu, Sao chép / dán cấu hình, Chia sẻ app, Góp ý, Hướng dẫn dùng (web có thêm Tải bản Android).

Các mục cũ "Bảng lương/giờ" và "Khoản thu nhập / khấu trừ khác" bỏ khỏi Cài đặt (phiếu lương và khối Cài đặt tính công thay thế).

### Ô nhập

- Ô tiền: tự thêm dấu chấm ngăn hàng nghìn khi gõ.
- Ô phần trăm: nhập được dấu phẩy (ví dụ 1,5).

### Sao chép cấu hình

Người dùng thử thấy tin nhắn quá dài nên bị cắt. Làm lại: chỉ gồm các con số của phần lương, cài đặt tính công và khung tăng ca, viết gọn một dòng, **không kèm ngày lễ, GPS và các danh sách cũ**. Máy nhận giữ nguyên ngày lễ và GPS của mình. Vẫn đọc được chuỗi kiểu cũ.

### Khung giờ GPS cài sẵn (thêm ngày 2026-10-10)

Máy mới cài và mọi máy cập nhật từ bản cũ (các khung đã đặt trước đây bị bỏ, đặt lại một lần) có sẵn ba phần, hiện ở Nâng cao › GPS: tùy chọn thêm:

- Khung lặp 06:50–12:40, mỗi giờ: phút 50 → 05 và phút 25 → 35 (12 khung).
- Khung lặp 13:30–23:00, mỗi giờ: phút 00 → 10 và phút 30 → 40 (19 khung).
- Khung lẻ 12:50–13:10.

Cả ba đều xóa được, nhưng phải hỏi lại trước khi xóa. Có nút "Đặt lại khung cài sẵn" (hỏi lại trước khi đặt lại). Trong code: `GpsRepeatRule`, `GpsConfig.repeatRules`, `GpsConfig.allWindows`.

## 5. Màn chính

- Thẻ thu nhập: số to là **Thực nhận** của kỳ hiện tại lấy từ phiếu lương; bấm vào thẻ thì mở Cài đặt (phiếu lương nằm trên cùng).
- Các ô thống kê: Giờ công (giờ thường T2–T7), Tăng ca (gồm cả giờ chủ nhật và lễ), Tổng giờ, Ngày nghỉ.
- Tiền từng ngày trên lịch và "Thống kê thu nhập theo kỳ" lấy từ phiếu lương.
- **Biểu đồ giờ làm theo ngày**: hiện số của mọi ngày dưới cột; chật thì xếp so le thành hai hàng (không bỏ cách ngày).

## 6. Nhắc cập nhật

Theo `mockup/nhac-cap-nhat.html`. Người dùng ra bản mới bằng cách đưa APK lên GitHub Releases rồi đổi `latest_version` trên Remote Config; không cài ngày nào cả.

- Thay băng nhỏ hiện tại bằng **hộp nhắc** "Cần cập nhật lên bản mới", có nút "Cập nhật" và "Để sau (còn N lần)", kèm dòng "Dữ liệu chấm công và cài đặt của bạn được giữ nguyên".
- Mỗi máy tự đếm số lần bấm "Để sau". Hết lượt thì hộp **không tắt được**, chỉ còn "Cập nhật".
- Mỗi `update_remind_hours` giờ nhắc tối đa một lần.
- Nếu `update_offline_days` ngày liền app không kết nối được Remote Config: hiện "Hãy bật mạng để kiểm tra bản mới" (nút "Thử lại" và "Để sau"), **tắt được và không chặn chấm công**, sau đúng số ngày đó nhắc lại. Mất mạng thì dùng giá trị lấy được lần gần nhất.

| Tham số | Mặc định | Ý nghĩa |
|---|---|---|
| `latest_version`, `update_url` | (đã có) | Như hiện tại |
| `update_max_skips` | 3 | Số lần được bấm "Để sau"; 0 là bắt buộc ngay |
| `update_remind_hours` | 24 | Khoảng cách giữa hai lần nhắc |
| `update_offline_days` | 10 | Số ngày mất mạng thì nhắc bật mạng |

Việc xử lý mã mời/giới thiệu làm sau, sau khi cơ chế cập nhật này chạy.

## 7. Chuyển dữ liệu của bản cũ

Dữ liệu chưa có khóa `workerKind` là của bản cũ (tính tiền thẳng theo bảng lương/giờ). Khi đọc, chuyển thành Công nhân sao cho số tiền gần như không đổi (đã viết trong `AppSettings._migrateLegacy`): lương cơ bản chưa có thì lấy lương giờ ngày thường × 8 × 26; thêm hai dòng "Tiền lương" và "Tăng ca"; khoản tự tạo cũ giữ nguyên; kỳ lương, giờ làm, giá tăng ca, chủ nhật, lễ giữ nguyên. **Không** tự thêm bảo hiểm, công đoàn cho người dùng cũ.

## 8. Việc đã làm và còn lại

Đã có trên nhánh `phieu-luong-moi` (chưa biên dịch được vì các màn cũ chưa sửa theo):

- `lib/domain/models.dart`: `WorkerKind`, các mã `payItem…`, `IncomeCalcMethod.salary` / `overtime`, `IncomeItem.inBasis`, `PayPeriodConfig.semiFirstStart` / `semiFirstEnd`, các trường mới của `AppSettings` (`workerKind`, `dailyWage`, `standardDays`, `showNotice`, `showGps`), `defaultPayItems`, `AppSettings.defaultsFor`, `_migrateLegacy`.

Còn lại, nên làm theo thứ tự:

1. `pay_period.dart`: 2 kỳ/tháng theo `semiFirstStart` / `semiFirstEnd`. `data_file.dart`: dữ liệu trống dùng `AppSettings.defaultsFor(WorkerKind.worker)`.
2. Bộ tính phiếu lương và test.
3. Màn Cài đặt mới, ô nhập, sao chép cấu hình rút gọn.
4. Màn chính, lịch, thống kê theo kỳ, biểu đồ, Excel lấy số từ phiếu lương.
5. Nhắc cập nhật.
6. Sửa các test cũ cho khớp, `flutter analyze`, `flutter test`, cập nhật `TIEN-DO.md` và `CLAUDE.md`.

## 9. Giới hạn và điều chưa chốt

- **Phần lương theo từng kỳ (chốt và làm ngày 2026-10-10).** Sửa phiếu lương (lương cơ bản, lương ngày, các khoản) ở kỳ nào thì áp dụng cho kỳ đó: sửa kỳ hiện tại thì các kỳ sau cũng theo số mới, các kỳ trước giữ nguyên; sửa một kỳ đã qua thì chỉ kỳ đó đổi. Trong code: `PayVersion`, `AppSettings.payVersions`, `payFor`, `withPayEdit`; `computePayslip` tự lấy phần lương của đúng kỳ. Đổi Công nhân / Công nhật hoặc dán cấu hình thì bỏ hết số riêng theo kỳ. Cài đặt tính công (kỳ lương, giờ làm, bảng lương/giờ, đi muộn) vẫn dùng chung cho mọi kỳ.
- **Ngày nghỉ có lương (chốt và làm ngày 2026-10-10).** Bấm nút "Ngày nghỉ" thì chọn "Nghỉ có lương" hoặc "Nghỉ không lương" (đã nghỉ rồi thì có thêm "Bỏ đánh dấu nghỉ"). Nghỉ có lương tính một ngày lương cơ bản (công nhân: lương cơ bản ÷ công chuẩn; công nhật: một ngày lương), chỉ cộng vào dòng Tiền lương, không tính vào ngày công, thưởng thành tích hay các khoản khác. Trên lịch ngày đó ghi "Nghỉ ₫". Trong code: `DayRecord.paidLeave`. App không tự coi ngày lễ là nghỉ có lương; người dùng tự đánh dấu.
- Trợ cấp: chưa biết công ty trả đủ hay theo ngày công; đang tính theo ngày công.
- Khóa ký: mọi bản đã phát hành ký bằng một khóa chỉ có trên PC của người dùng. Bản build trên cloud **không cài đè được** lên app người dùng, nên việc cài lên điện thoại, đưa APK lên Releases và deploy web chỉ làm ở PC.
