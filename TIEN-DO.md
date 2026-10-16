# Tổng hợp — Chấm Công Đơn Giản

**Cập nhật lần cuối: 2026-10-10 (PC).** Bản 1.2.0 (phiếu lương chỉ tính khi hết kỳ, phiếu mẫu, GPS kiểu mới ít tốn pin, mặc định mới) đã phát hành và deploy web ngày 2026-10-10; GPS kiểu mới chưa được thử qua một ngày đi làm thật. Đọc file này trước khi sửa app. Cách làm việc với người dùng nằm ở `CLAUDE.md`.

App chấm công đơn giản cho người làm theo giờ: ghi giờ vào/ra, tăng ca, ngày nghỉ, đi muộn, và ước tính lương theo kỳ. Tách riêng khỏi dự án `so_cong` (bản đầy đủ, đang để đó); chỉ dùng chung `domain/lunar.dart` và font Be Vietnam Pro.

## Đang chạy ở đâu

| Thứ | Ở đâu |
|---|---|
| Mã nguồn | GitHub `AissNguyen/cham-cong-don-gian`, nhánh `master` (bản 1.2.0). App trước khi làm lại nằm ở nhánh `cham-cong-don-gian-cu` |
| Bản web | https://cham-cong-don-gian.web.app (Firebase Hosting, deploy lần cuối 2026-10-10, bản 1.2.0) |
| Bản Android | GitHub Releases `v1.2.0` (đưa lên ngày 2026-10-10, file `app-release.apk`; `v1.1.0` cùng ngày vẫn còn đó); nút "Tải bản Android" trên web trỏ tới `releases/latest`. Điện thoại của người dùng (Realme RMX2021) đang chạy bản build cùng mã nguồn nhưng còn ghi số 1.1.0 (lúc phát hành điện thoại không nối với PC nên chưa cài đè bản 1.2.0). Chưa lên Google Play |
| Firebase | Dự án `cham-cong-don-gian`: Analytics, Crashlytics, Remote Config, Firestore (máy chủ nam5 – Mỹ), Hosting. Gói miễn phí |
| Gói Android | `vn.chamcong.cham_cong_don_gian`, phiên bản `1.2.0+3`. Mọi bản phát hành ký bằng khóa ở `C:\Users\Admin\Documents\khoa-ky-cham-cong-don-gian\` trên PC (xem `android/key.properties`, không commit) |

## Bản mới: phiếu lương (nhánh `phieu-luong-moi`, chờ merge)

Làm theo `THIET-KE-BAN-MOI.md` trên cloud ngày 2026-10-09, sửa thêm trên PC ngày 2026-10-10. **Đã merge vào `master`, cài lên điện thoại người dùng, đưa lên Releases (v1.1.0) và deploy web ngày 2026-10-10.** Remote Config chưa đổi: `latest_version` vẫn là `1.0.0` và `update_url` chưa đặt, nên chưa máy nào bị nhắc cập nhật. Muốn nhắc: đặt `update_url` = `https://github.com/AissNguyen/cham-cong-don-gian/releases/latest/download/app-release.apk` trước, rồi mới đổi `latest_version` thành `1.1.0`. Các điểm chính của bản mới:

- **Bộ tính phiếu lương** `lib/domain/payslip.dart` (test `test/domain/payslip_test.dart`): bộ tính tiền duy nhất. Thẻ thu nhập màn chính (số to = Thực nhận), số "Hôm nay", tiền từng ngày trên lịch, "Thống kê thu nhập theo kỳ" và file Excel đều lấy số từ đây. Công nhân: lương cơ bản ÷ công chuẩn × ngày công, khoản căn cứ, Thưởng vượt khoán (tăng ca + chủ nhật + lễ), khoản cố định / % chia theo ngày công (hết kỳ thì khấu trừ tính đủ), cơm trưa theo ngày làm qua 12:30, đi muộn trừ tiền thành một dòng. Công nhật: tổng giờ × bảng lương/giờ (ô 0 = lương ngày ÷ 8). Phần đếm giây của ca đang mở tách thành `liveDayHours` trong `calc.dart`; `computePeriodStats` / `liveItemsEstimate` đã bỏ.
- **Kỳ lương 2 kỳ/tháng** theo ngày tự chọn (kỳ 1 từ A đến B, kỳ 2 từ B+1 tới trước A tháng sau), `pay_period.dart`.
- **Màn Cài đặt mới** theo `mockup/luong-va-cai-dat.html`: Thông báo, Công nhân / Công nhật (đổi thì hỏi lại), Phiếu lương (chuyển kỳ, xem / sửa ngay tại dòng, ✕ luôn hỏi lại, bảng Khoản mới), Cài đặt tính công, Chấm công GPS rút gọn, "Nâng cao và cài đặt khác" (công tắc Hiện thông báo, Dùng chấm công GPS; các màn con Ngày lễ, Tăng ca theo khung, GPS tùy chọn thêm, Sao lưu, Sao chép cấu hình, Chia sẻ, Góp ý, Hướng dẫn). Bỏ các mục "Bảng lương/giờ", "Khoản thu nhập / khấu trừ khác", "Khung giờ ra vào", "Kỳ lương", "Đi muộn" cũ. Code: `lib/ui/settings/payslip_card.dart`, `work_config_card.dart`, `settings_blocks.dart`, `number_inputs.dart`.
- **Sao chép cấu hình** rút gọn một dòng (`CCDG1 {...}`), gồm phần lương, cài đặt tính công và khung tăng ca; máy nhận giữ ngày lễ và GPS của mình. Vẫn đọc chuỗi kiểu cũ.
- **Biểu đồ giờ làm** có lại số ngày dưới cột (chật thì cách ngày).
- **Nhắc cập nhật** thành hộp ba trạng thái (`lib/update/update_policy.dart` + test `test/update_policy_test.dart`), bỏ băng nhắc và màn bắt buộc sau 14 ngày.
- **Chuyển dữ liệu bản cũ**: dữ liệu, file sao lưu Excel và chuỗi cấu hình chưa có `workerKind` thành Công nhân (lương cơ bản = lương giờ ngày thường × 8 × 26, thêm dòng Tiền lương và Tăng ca, giữ khoản cũ). Số tiền gần như không đổi, nhưng khoản cố định cũ nay chia theo ngày công nên giữa kỳ thấp hơn trước.
- **Đã thử**: `flutter analyze` không lỗi, `flutter test` 170 test qua (Flutter 3.47.6 trên cloud). Bản web build release chạy trong Chromium với dữ liệu kiểu cũ: màn chính, phiếu lương, chế độ Sửa, phần Nâng cao hiện đúng. **Chưa thử**: trên điện thoại thật (GPS rút gọn, công tắc tắt GPS, hộp nhắc cập nhật với Remote Config thật, ô nhập tiền trên bàn phím Android), file Excel mới mở bằng Excel thật.
- **Phần lương theo từng kỳ và ngày nghỉ có lương** (làm ngày 2026-10-10 trên PC): sửa phiếu lương ở kỳ nào thì áp dụng cho kỳ đó, các kỳ trước giữ số của chúng (`PayVersion`, `payFor`, `withPayEdit`); nút "Ngày nghỉ" cho chọn nghỉ có lương (tính một ngày lương cơ bản, `DayRecord.paidLeave`) hoặc không lương. Đã thử nghỉ có lương trên điện thoại người dùng; phần lương theo kỳ mới qua test tự động.
- **Quên chấm về thì báo đỏ** (2026-10-10): ngày đã chấm vào mà qua 23:00 (hoặc đã sang ngày khác) vẫn chưa có giờ về thì ô ngày đó trên lịch chuyển đỏ, ghi "Chưa ra", và khi chọn ngày đó màn chính hiện dòng lưu ý đỏ nhắc bấm Chấm ra (`isMissedCheckOut` trong `calc.dart`). Cách tính không đổi: ca của ngày đã qua chưa có giờ về thì chưa tính giờ nào. Mới qua test tự động, chưa xem trên điện thoại.
- **Phiếu lương chỉ tính khi hết kỳ** (2026-10-10, sau bản 1.1.0; đã commit lên `master` (`b672c1a`), cài lên điện thoại người dùng và deploy web cùng ngày; **chưa đưa APK mới lên Releases**, bản trên Releases vẫn là 1.1.0 cũ): ở thẻ Phiếu lương trong Cài đặt, kỳ chưa hết thì không hiện số tiền nào đã tính: nhãn "Chưa chốt", Thực nhận / từng dòng / các tổng hiện "—", dưới mỗi dòng chỉ ghi cách sẽ tính, Căn cứ tính không hiện ngày công và giờ công, có dòng "Phiếu lương chỉ được tính khi hết kỳ, sau ngày dd/MM". Kỳ đã hết thì hiện đủ như trước. Vẫn sửa được các khoản khi chưa chốt. Thống kê nhanh ở màn chính (thẻ thu nhập, "Hôm nay", tiền từng ngày) không đổi công thức, vẫn ước tính từng ngày; hết kỳ thì số của kỳ chính là số phiếu lương. Bộ tính `payslip.dart` không đổi, chỉ đổi phần hiển thị trong `payslip_card.dart`. Lưu ý mục 3 viết lại: việc chia đều khoản cố định là của thống kê nhanh. **Phiếu lương mẫu cho người mới** (cùng ngày, người dùng chốt): khi chưa có kỳ nào được chốt (chưa có ngày chấm đủ vào/ra nào thuộc một kỳ đã hết) thì kỳ đang chạy hiện phiếu lương mẫu thay cho dấu "—": tính bằng đúng các con số đang cài, giả sử 25 ngày công và 95 giờ tăng ca giá ngày thường (kỳ nửa tháng: 12 ngày, 47 giờ), khấu trừ tính đủ (`computeSamplePayslip` trong `payslip.dart`). Ghi rõ là mẫu: nhãn "Phiếu mẫu", khung chữ giải thích, ô "THỰC NHẬN (MẪU)". Có kỳ chốt rồi thì mẫu biến mất, kỳ đang chạy hiện "Chưa chốt". **Bảo hiểm khi nghỉ không lương nhiều** (cùng ngày): bảo hiểm tính trên đủ lương cơ bản (đã đối chiếu với phiếu lương công ty); riêng kỳ theo tháng đã hết mà số ngày nghỉ không lương (công chuẩn − ngày công − ngày nghỉ có lương) từ 14 trở lên thì dòng Bảo hiểm bằng 0 (`insuranceSkipUnpaidDays` trong `payslip.dart`), có thêm một dòng lưu ý. 198 test qua; đã build, cài và mở trên điện thoại người dùng, chưa tự bấm thử trên máy.
- **Chấm công GPS theo mốc giờ cố định** (2026-10-14, người dùng chốt sau khi thử bản 1.2.0 trên máy mình thấy chưa ổn; thay cho cách 2026-10-10). **Chưa commit**; đã build bản `1.2.1+4` và cài lên điện thoại người dùng; chưa phát hành. Quy tắc ghi ở đầu `lib/domain/gps_engine.dart`:
  - *Chấm vào*, từ 7:00 tới 14:00 (`GpsConfig.arriveFrom/arriveTo`, chỉnh được): dò trước ở phút 45 và 15 (có cả 6:45) chỉ để biết điện thoại còn dò ra vị trí; dò chính ở phút 00 và 30: trong phạm vi chỗ làm (`departRadiusMeters`, 200 m; bỏ mốc 30 m) thì chấm vào, giờ vào đúng mốc; ngoài thì chờ mốc sau; không dò ra vị trí thì xem lần dò trước (giờ dò ra vị trí gần nhất `DayRecord.gpsLastFixAt` trong 15 phút trước mốc): có thì chấm vào. Sau 14:00 không tự chấm vào.
  - *Chấm ra*: sau khi vào, dò ở phút 15 và 45 tới 2:30 sáng hôm sau (`departUntil`; dò sau nửa đêm thì làm cho ca hôm trước). Trong 200 m hoặc không dò ra vị trí: vẫn đang làm. Ngoài 200 m: giờ ra x:00 (dò phút 15) hoặc x:30 (dò phút 45), đánh dấu `checkOutByGps`.
  - *Mở lại ca*: giờ ra do GPS chốt thì dò lại 3 lần, cách nhau 1 tiếng; trong 200 m hoặc không dò ra vị trí thì bỏ giờ ra (người dùng chọn vậy, Claude đã nêu rủi ro mất sóng ở nhà; Wi-Fi ngoài giúp chặn trường hợp đó).
  - Mỗi lần không dò ra vị trí: thử lại 2 lần, cách 3 phút (dịch vụ nền "tick" 3 phút một lần, mỗi mốc có 10 phút).
  - *Wi-Fi quen* (`lib/gps/gps_wifi.dart`): app tự học hai danh sách, Wi-Fi thấy khi GPS báo trong phạm vi (chỗ làm) và khi GPS báo ngoài (nhà...), file `gps_wifi.json`. Mất GPS mà chỉ thấy Wi-Fi chỗ làm: coi như ở chỗ làm; chỉ thấy Wi-Fi ngoài: coi như đã đi; mạng có ở cả hai danh sách thì bỏ qua. Chỉ dùng mạng xuất hiện từ 4 lần (mốc dò) trở lên, và mỗi danh sách chỉ lấy 3 mạng xuất hiện nhiều nhất (wifiMinSightings, wifiTopNetworks; đếm theo tên mạng, các thiết bị phát cùng tên tính chung). Mỗi lần dò quét được Wi-Fi thì ghi mốc cho mọi mạng quen đang thấy.
  - *Nhật ký để thử* (`lib/gps/gps_log.dart`, màn `lib/ui/settings/gps_log_view.dart`, mở từ Cài đặt › Nâng cao › GPS: tùy chọn thêm › Nhật ký GPS và Wi-Fi quen): mỗi lần dò (kể cả lần thử lại thứ 2, 3) ghi mốc giờ, lần thứ mấy, dò cho việc gì, GPS có dò ra không, cách bao xa, trong hay ngoài phạm vi, sai số, các mạng Wi-Fi quét được, Wi-Fi quen cho biết gì, kết quả; giữ 1500 dòng. Màn này còn hiện hai danh sách Wi-Fi quen và mục "Tất cả Wi-Fi đã thấy" (mọi mạng quét được ở mọi lần dò, kể cả sóng yếu và lúc mất GPS; theo tên mạng, số lần, số ngày, các mốc theo từng ngày).
  - Báo đỏ quên chấm ra đổi từ 23:00 sang **22:00** (`missedCheckOutHour`). Bỏ ô bán kính 30 m, ô tần suất và danh sách khung giờ trong cài đặt, thay bằng ba ô giờ. Báo thức: một cái cho mỗi mốc trong `gpsProbeTimes`, mã 5200+ (hủy các mã cũ 5000–5199). 196 test qua. **Chưa kiểm chứng trên máy thật.**
  - *Sửa sau khi đọc nhật ký 15–16/10* (bản `1.2.2+5`, cài lên điện thoại người dùng, chưa commit): nhật ký cho thấy GPS luôn dò ra vị trí (ở xưởng cách 14–84 m, ở nhà ~900 m) nhưng bị lỡ khoảng 6/29 mốc và hay trễ tới 7 phút vì máy hoãn báo thức. Đã đổi: báo thức loại "đồng hồ báo thức" (`oneShotAt(alarmClock: true)`, mỗi lần reo tự đặt lại cho hôm sau) cộng một báo thức dự phòng 4 phút sau mỗi mốc; giới hạn trễ: chờ chấm vào 5 phút, dò giờ về/dò lại 20 phút (tới phút 35 hoặc 05), quá thì bỏ mốc đó và ghi nhật ký "Bỏ mốc", mốc kế tiếp vẫn dò; mốc đã làm lưu ở `DayRecord.gpsDoneMarks` để báo thức dự phòng không dò lại (`gpsPendingPlans`, `gpsPlanForMark`). Wi-Fi do điện thoại phát (iPhone, Redmi, OPPO, realme…, `isPhoneHotspot`) không được dùng làm mốc. Sau đó (cùng ngày): chỉ dùng 3 mạng thay vì 5; mạng thấy lần đầu từ 3 ngày trước mà xuất hiện dưới 4 lần thì xóa hẳn khỏi cả ba danh sách (`pruneWifi`, mạng học từ bản 1.2.0 không có mốc nào cũng bị xóa); màn nhật ký gập các mục Wi-Fi và gom các lần dò theo ngày, mỗi ngày một khung gập có dòng tóm tắt. Máy người dùng: app đã được miễn tối ưu pin, được chạy nền; sau khi cài thấy 111 báo thức loại đồng hồ báo thức. 203 test qua.
- **Giá trị mặc định cho máy mới theo điện thoại của người dùng** (2026-10-10): Các khoản trợ cấp 800.000 (trước là 0) và 4 khung tăng ca cài sẵn (16–18h trừ nghỉ 15 phút, 18–19h trừ 30, 19–21h trừ 5, 21–22h trừ 5; `defaultOvertimeBrackets`). Chỉ áp dụng cho máy cài lần đầu hoặc khi đổi Công nhân ↔ Công nhật (khung tăng ca đã có thì giữ); máy đang dùng không đổi gì. Phiếu mẫu mặc định ra Thực nhận 10.093.461 đ.
- **Đo vị trí ngay và còi báo giờ** (2026-10-16, bản `1.2.3+6`, cài lên điện thoại người dùng, chưa commit, chưa phát hành):
  - Wi-Fi quen: cứ 3 ngày hạ số lần xuất hiện của mỗi mạng về tối đa 5 (`resetWifi`, `wifiResetEveryDays`/`wifiResetTo`, mốc lưu ở `resetAt` trong `gps_wifi.json`); mạng có ở cả chỗ làm lẫn ngoài thì xóa hẳn; màn nhật ký ẩn mạng xuất hiện dưới 4 lần (app vẫn đếm ngầm).
  - Nút **Đo vị trí ngay** (Cài đặt › Nâng cao › GPS: tùy chọn thêm, `lib/ui/settings/gps_measure_dialog.dart`, `lib/gps/gps_manual.dart`): ghi tên chỗ đứng (tùy chọn), đo GPS ngay, hiện cách điểm chấm bao xa, trong/ngoài phạm vi, sai số, độ mạnh (theo số vệ tinh dùng được, `AndroidPosition.satellitesUsedInFix`). Mỗi lần đo ghi một dòng (STT, tên, giờ, khoảng cách, sai số, vệ tinh) vào `gps_manual.json`, xem ở màn Nhật ký GPS.
  - **Còi báo giờ** (Cài đặt › Nâng cao › Còi báo giờ, `lib/ui/settings/bell_section.dart`, `lib/bell/`): người dùng thêm các giờ; mỗi giờ có tiếng còi (còi nhà máy, chuông, bíp; app tự tạo file WAV bằng toán, không dùng âm thanh có bản quyền), số lần hú 1–10, độ to; bật/tắt từng giờ; nghe thử. Báo thức loại đồng hồ báo thức mã 6000+, mỗi lần reo tự hẹn lại hôm sau; phát qua âm lượng báo thức nên máy im lặng vẫn hú; ngày đã đánh dấu nghỉ thì không hú; lúc hú có thông báo nút "Tắt còi" (ghi file cờ `bell_stop.flag`). Cài đặt lưu ở `AppSettings.bells`. **Chưa thử hú thật trên máy.** 206 test qua.
- **Số ngày lễ ở dòng "Ngày lễ"** ngoài mục Nâng cao nay đếm giống bên trong (gộp các năm lặp lại): 10 chứ không phải 30.
- **Còn lại ở mục 9 của bản thiết kế**: trợ cấp đang tính theo ngày công (chưa biết công ty trả đủ hay theo ngày công).

## Đã có

- **Lõi tính toán** (`lib/domain/`, thuần Dart): giờ thường, tăng ca theo khung, đi muộn, cộng trừ giờ theo giờ vào, bảng lương/giờ theo loại ngày, ngày lễ mặc định (tự bù cho năm hiện tại và 2 năm tới), kỳ lương (theo tháng hoặc 2 kỳ/tháng), khoản thu nhập/khấu trừ tự tạo, âm lịch, thu nhập "hôm nay" ước tính theo từng giây.
- **Lưu trữ**: một file JSON trong máy (`lib/data/`), không cần mạng. Bản web lưu trong trình duyệt. Widget và GPS nền đọc/ghi thẳng file này.
- **Màn chính** (`lib/ui/home/`): thẻ thu nhập tạm tính (số hôm nay chạy theo giây), lịch tháng (âm lịch, tiền mỗi ngày, giờ chấm), các nút Chấm vào / Chấm ra (chạm: mở bảng chọn giờ; giữ: chấm ngay giờ hiện tại — đổi ngược từ 2026-10-06) / Ngày nghỉ / Đi muộn / Ghi chú, biểu đồ cột giờ công theo ngày trong kỳ (từ 2026-10-06: phần "đi giờ khác" nằm phía trên cột, chỉ có viền cùng màu cột vẽ gọn trong bề ngang cột, bên trong để trống; bỏ chú thích, số giờ bên trái, số ngày bên dưới và chữ "8h · ngày thường" (vẫn giữ đường gạch 8h) — chạm vào cột để xem ngày và số giờ), danh sách ghi chú, thống kê thu nhập theo kỳ (có ô nhập tiền ghi đè), băng nhắc cập nhật, băng thông báo của chủ app.
- **Cài đặt** (`lib/ui/settings/`), theo thứ tự trên màn hình: Thông báo, Kỳ lương, Khung giờ ra vào, Bảng lương/giờ, Khoản thu nhập/khấu trừ khác, Ngày lễ, Đi muộn, Tăng ca theo khung, Chấm công GPS, Sao lưu dữ liệu, Sao chép/dán cấu hình, Chia sẻ app, Góp ý (email), Hướng dẫn sử dụng. Bản web có thêm mục Tải bản Android và không có GPS/widget. Từ 2026-10-05 các mục cấu hình (Kỳ lương tới Sao chép/dán cấu hình) mở sẵn nhưng gập được: chạm tiêu đề để gập, mục nào đã gập thì những lần mở Cài đặt sau vẫn gập (`SettingsCard(collapsible: true)`, nhớ trong máy bằng khóa `settings_collapsed`).
- **Giờ nghỉ trưa cố định 11:30–12:30** (2026-10-06, thay cho mục "Cộng trừ giờ theo giờ vào (khung cố định)" và "Khung nhiều mục (dự phòng)" đã bỏ): với mọi người dùng, phần giờ làm rơi vào 11:30–12:30 không tính công. Ngoại lệ: chấm ra trước 12:30 (ví dụ về lúc 12:00) thì phần trong giờ nghỉ vẫn tính (7:00–12:00 = 5 giờ); ra đúng 12:30 trở đi thì trừ. Vào giữa giờ nghỉ (ví dụ 12:00) thì tính từ 12:30. Hết cảnh báo đỏ ở màn chính và ô lịch. Lúc ca đang mở, số chạy đứng yên suốt 11:30–12:30; nếu chấm ra trong giờ nghỉ thì số nhảy lên đúng phần đó. Hằng số `lunchBreakFrom`/`lunchBreakTo` trong `lib/domain/calc.dart`. Dữ liệu `fixedBreakRules`/`breakSegments` cũ vẫn được đọc/ghi nhưng không dùng để tính. **Lưu ý**: người chưa từng cài khung cố định trước đây không bị trừ giờ trưa, nay bị trừ 1 giờ mỗi ngày làm qua trưa (kể cả các ngày cũ khi xem lại).
- **Sửa thêm ngày 2026-10-10 trên PC** (sau khi người dùng thử bản mới trên điện thoại): nút Công nhân / Công nhật đang chọn tô đậm; thẻ Thông báo ở Cài đặt hiện đầy đủ khi là thông báo mới, thu gọn được (1 hàng rõ, 1 hàng mờ) và app nhớ, bỏ công tắc "Hiện thông báo"; phần Lưu ý của phiếu lương mở đầu bằng câu "đây là phiếu lương tham khảo…"; sao chép cấu hình kèm khung tăng ca; **khung giờ GPS cài sẵn** gồm hai khung lặp mỗi giờ (06:50–12:40: phút 50→05 và 25→35; 13:30–23:00: phút 00→10 và 30→40) và khung lẻ 12:50–13:10, tổng 32 khung một ngày, xóa được nhưng phải hỏi lại (`GpsRepeatRule`, `GpsConfig.allWindows`; số báo thức tối đa nâng từ 20 lên 64). Dữ liệu của bản cũ (kể cả khung người dùng đã tự đặt trước đây) được đặt lại một lần về các khung cài sẵn này; từ đó về sau sửa gì thì giữ nguyên, và có nút "Đặt lại khung cài sẵn". Biểu đồ giờ làm hiện đủ số của mọi ngày dưới cột, xếp so le hai hàng khi chật. Khung GPS mới chỉ qua test tự động, chưa thử tự chấm thật ngoài hiện trường.
- **Chấm công tự động (chỉ Android)**: GPS chạy nền theo khung giờ (`lib/gps/`: báo thức đánh thức máy, dịch vụ nền có thông báo, tự chấm vào khi vào bán kính và chấm ra khi rời hẳn). Có thêm danh sách "Địa điểm khác" (vị trí, bán kính, "Chấm về"/"Không chấm về") chỉ ảnh hưởng chấm ra: nhà trọ sát công ty thì về tới là chấm ra, xưởng xa máy chấm công thì ở đó không bị chấm ra, widget màn hình chính có 2 nút chấm (`lib/widget/` + `ChamCongWidgetProvider.kt`).
- **Nhắc cập nhật** (`lib/update/`): đổi `latest_version` / `update_url` trên Remote Config là app nhắc; quá 14 ngày không cập nhật thì bắt buộc.
- **Thống kê** (`lib/analytics/`): mỗi máy mỗi ngày ghi tối đa 1 lần các sự kiện mở app, bấm widget, GPS tự chấm, xem thống kê kỳ, mở cài đặt.
- **Dùng thử + mã giới thiệu, đếm lượt dùng, thông báo từ chủ app**: xem ba mục riêng bên dưới.
- **Icon app riêng** (`flutter_launcher_icons.yaml`, `assets/icon/`).
- **Biểu đồ giờ làm không còn nhấp nháy** (2026-10-08): màn chính vẽ lại mỗi giây nên biểu đồ chạy lại hiệu ứng chuyển mỗi giây, khúc viền "đi giờ khác" ở đầu cột bị nhòe rồi nét lại. Đã tắt hiệu ứng chuyển của biểu đồ (`duration: Duration.zero`) và tách các mốc màu của dải viền cho khỏi trùng nhau (`lib/ui/home/period_day_chart.dart`). Đã thử trên điện thoại của người dùng: 14 ảnh chụp liên tiếp giống hệt nhau. Bản này đã cài trên điện thoại và đã deploy web cùng ngày.
- **Test**: 117 test qua (chạy trên cloud ngày 2026-10-06 bằng Flutter 3.47.6, `flutter analyze` còn 2 gợi ý nhỏ như cũ). Trước đó: 121 test qua, không lỗi (`flutter test`), `flutter analyze` chỉ còn 2 gợi ý nhỏ về kiểu viết (chạy trên PC ngày 2026-10-05).

## Tham số Remote Config (đổi trên Firebase Console, không cần ra bản mới)

| Tham số | Mặc định khi chưa đặt | Ý nghĩa |
|---|---|---|
| `latest_version`, `update_url` | không nhắc | Phiên bản mới nhất và link tải, để app nhắc cập nhật |
| `update_max_skips` | 3 | (bản mới) Số lần được bấm "Để sau"; 0 là bắt buộc ngay |
| `update_remind_hours` | 24 | (bản mới) Khoảng cách giữa hai lần nhắc (giờ) |
| `update_offline_days` | 10 | (bản mới) Số ngày không kết nối được thì nhắc bật mạng; tắt được, không chặn chấm công |
| `share_free_users` | 50 | X: tổng số máy Android vượt số này thì giới hạn GPS/widget mới áp dụng |
| `share_trial_days` | 10 | Y: số ngày dùng thử GPS/widget. Đặt 0 là tắt hẳn tính năng giới hạn |
| `share_entry_hours` | 0 | Thời hạn ô nhập mã tính từ lúc cài (giờ); 0 là không hạn |
| `share_url` | https://cham-cong-don-gian.web.app | Link trong tin nhắn chia sẻ |
| `notice_text`, `notice_title`, `notice_links` (và kiểu cũ `notice_url`, `notice_button`) | không có thông báo | Băng thông báo ở đầu màn chính, xem lại được ở Cài đặt › Thông báo |
| `help_text` | hướng dẫn có sẵn trong app | Nội dung màn "Hướng dẫn sử dụng" |

App tải lại Remote Config tối đa 6 giờ một lần.

## Khung giới thiệu và chuyến hướng dẫn làm thử (2026-10-16)

**Đã làm trên cloud (nhánh `claude/huong-dan-tung-buoc`, PR vào `master`), chờ người dùng thử trên điện thoại.** Mới qua `flutter analyze` và 219 test tự động (13 test mới ở `test/onboarding/tour_test.dart`); chưa chạy trên điện thoại thật. Code: `lib/onboarding/` (`tour_controller.dart`, `tour_overlay.dart`, `intro_dialog.dart`), `AppStore.restoreRecord`, `HomeScreen(showOnboarding)`, `SettingsScreen(scrollToGps)`, nút "Xem lại hướng dẫn làm thử" ở Hướng dẫn sử dụng. Phần đặc tả dưới đây giữ nguyên để đối chiếu.


Người dùng đã chốt thiết kế, **chỉ còn viết code Flutter**. Không bàn lại thiết kế; chỗ nào lệch thì ghi vào mô tả PR. Mẫu hình ảnh: `mockup/gioi-thieu.html` (khung giới thiệu) và `mockup/huong-dan-tung-buoc.html` (các bước hướng dẫn); chữ trong hai mẫu là chữ người dùng chốt, dùng đúng như vậy (các chỗ đã sửa bên dưới ghi rõ).

**Mục tiêu:** người mới mở app lần đầu thấy khung giới thiệu rồi được dắt làm thử từng chức năng ngay trên màn chính. Mức 2 (phiếu lương, số tiền) để làm sau, **không** nằm trong việc này.

### 1. Khung giới thiệu (hiện một lần)
Hộp thoại giữa màn hình, tiêu đề "Tính năng cơ bản", không icon, không đường kẻ, bốn đoạn chữ, cụm chính in đậm màu xanh (màu chính của app):
1. App **tự động ghi lại giờ đi làm và giờ về** của bạn, mà bạn không cần phải nhập tay.
2. Tính ra **số giờ tăng ca** mỗi ngày.
3. Tính ra **số ngày công**, tổng số giờ tăng ca.
4. (chữ nhạt hơn) **Ước tính số tiền lương** nhận được, dựa trên phiếu lương thật. Dòng nhỏ bên dưới: "Lưu ý, đây là số tiền ước tính, mang tính chất tham khảo, đây là tính năng phụ, bạn có thể bỏ qua."

Nút "Bắt đầu" (vào chuyến hướng dẫn, bỏ qua màn lời mở) và chữ "Để sau" (đóng). Hiện khi: máy chưa từng thấy khung này (SharedPreferences `tour_seen_v1`) **và** chưa có ngày chấm công nào. Đánh dấu đã thấy ngay khi hiện. Nếu đang có hộp "Ai giới thiệu bạn?" (`shouldPromptReferral`) thì chờ hộp đó xong.

### 2. Chuyến hướng dẫn (lớp phủ trên màn chính)
Mỗi bước phủ mờ cả màn hình, **khoét sáng đúng một chỗ**; chỉ chỗ sáng bấm được (các vùng quanh là lớp chặn chạm trong suốt). Chỗ sáng có vòng trắng nhấp nháy, nhãn nhỏ "Bấm vào đây" có icon bàn tay nằm phía đối diện hộp chỉ dẫn. Hộp chỉ dẫn trắng bo tròn: dòng "Bước x/8", chữ chỉ dẫn, chữ "Bỏ qua" nhỏ bên trái, bên phải là "Chạm vào chỗ sáng để thử" (bước chờ thao tác) hoặc nút "Tiếp" (bước chỉ giải thích). Nếu chỗ sáng nằm ngoài màn hình thì tự cuộn tới (`Scrollable.ensureVisible`).

| Bước | Chỗ sáng | Chữ | Sang bước sau khi |
|---|---|---|---|
| lời mở (chỉ khi mở từ "Xem lại hướng dẫn") | hộp thoại | Hướng dẫn cách dùng: "Mình sẽ hướng dẫn bạn cách dùng, hãy làm theo chỉ dẫn nhé." Nút Bắt đầu, Bỏ qua | bấm Bắt đầu |
| nhập tay | hộp thoại | Nhập tay: "Chức năng nhập tay này được dùng khi bạn không muốn dùng tự động chấm công hoặc muốn sửa lại." Nút Tiếp | bấm Tiếp |
| 1 | nút Chấm vào | "Đây là nút chấm giờ vào. Bạn hãy thử nhập giờ vào của bạn nhé." | hôm nay có giờ vào (chạm chọn giờ hoặc giữ đều được) |
| 2 | nút Chấm ra | "Đây là nút chấm giờ ra. Bạn hãy thử nhập giờ ra của bạn nhé." | hôm nay có giờ ra |
| 3a | ô lịch "hôm qua" | "Giả sử hôm qua (ngày N) bạn nghỉ. Hãy chọn ngày N." Nếu hôm nay là mùng 1 thì dùng "ngày mai (ngày 2)" | ô đó được chọn (`_selectedDate`) |
| 3b | nút Ngày nghỉ | "Bấm nút Ngày nghỉ, rồi chọn nghỉ có lương hay không lương." | ngày đó thành ngày nghỉ. Sau đó tự chọn lại ngày hôm nay |
| 4 | nút Đi muộn | "Nếu đi muộn, hãy chọn vào nút Đi muộn." | hôm nay `isLate` |
| 5 | nút Ghi chú | "Bạn muốn ghi nhớ điều gì hôm nay thì có thể ghi lại ở đây, như bị ốm chẳng hạn." | hôm nay có ghi chú hoặc thẻ |
| 6 | cả lịch | "Số trong ô là giờ làm trong ngày. Số màu đỏ ở góc ô là giờ tăng ca. Chữ "Chưa" nghĩa là ngày đó chưa chấm." | bấm Tiếp |
| 7 | thẻ thống kê (xanh) | "Đây là khung thống kê nhanh: số giờ công, số giờ tăng ca, tổng giờ và số ngày nghỉ của kỳ này." | bấm Tiếp |
| 8 | hai nút Âm lịch và Giờ vào/ra | "Hai nút này: biểu tượng mặt trăng bật ngày âm lịch, biểu tượng đồng hồ hiện giờ vào và giờ ra trong từng ô lịch." | bấm Tiếp |
| xong | hộp thoại | "Vậy là cơ bản đã xong" / "Nếu bạn muốn chấm công tự động thì bấm Tiếp theo nhé." / chữ nhạt: "Để dùng chức năng này, bây giờ bạn hãy đến chỗ nơi bạn hay chấm công nhé, hoặc chờ lúc về, cài đặt sau." Nút Tiếp theo, Để sau | Tiếp theo: dọn dữ liệu tập rồi mở Cài đặt, tự cuộn tới thẻ "Chấm công GPS" (`GpsQuickCard`). Để sau: dọn rồi đóng |

Ghi chú: thẻ thống kê giữ nguyên như app hiện tại (Giờ công, Tăng ca, Tổng giờ, Ngày nghỉ); phần số tiền trên thẻ và nút "Lương mỗi ngày" ở mức 2 sẽ ẩn sau, chưa làm ở đây. Ngày nghỉ ở bước 3: nếu người dùng chọn lại ngày hôm nay thì bước đó chỉ cần ô ngày sáng.

### 3. Dữ liệu làm thử tự xóa
Người dùng thử thật nên app ghi giờ vào/ra, ngày nghỉ, đi muộn, ghi chú **thật** vào lịch. Khi bắt đầu chuyến: lưu bản chụp bản ghi của hai ngày tập (hôm nay và ngày nghỉ giả định) vào SharedPreferences (`tour_snapshot_v1`), rồi xóa trắng hai ngày đó. Khi **kết thúc, bấm Bỏ qua, hoặc sang Cài đặt**: trả hai ngày về đúng như bản chụp (không có bản ghi thì xóa). Lần mở app sau, nếu còn bản chụp mà chuyến không chạy (app bị tắt giữa chừng) thì trả luôn. Cần thêm `AppStore.restoreRecord(DateTime, DayRecord?)` (giống `_putRecord`: cập nhật bộ nhớ, `notifyListeners`, `_save`, cập nhật widget nếu là hôm nay).

### 4. Gợi ý cấu trúc code (làm khác đi nếu có lý do)
- `lib/onboarding/tour_controller.dart`: `enum TourStep`, `TourController extends ChangeNotifier` (bước hiện tại, bản chụp, `start`, `next`, `end`, `update(store, selectedDate)` tự chuyển bước theo bảng trên, `shouldAutoStart`, `restoreIfInterrupted`), và một `tourController` toàn cục như `shareController`.
- `lib/onboarding/tour_overlay.dart`: lớp phủ. Mỗi chỗ sáng có một `GlobalKey` do `HomeScreen` giữ (nút Chấm vào, Chấm ra, Ngày nghỉ, Đi muộn, Ghi chú, `CalendarGrid`, thẻ thống kê, hai nút đầu thanh trên, và ô ngày của bước 3a: thêm tham số `keyFor` cho `CalendarGrid`). Vẽ lớp mờ bằng `CustomPaint` khoét lỗ bo góc, lớp chặn chạm là bốn hình chữ nhật quanh lỗ.
- `HomeScreen`: thêm tham số `showOnboarding` (mặc định `false` để test cũ không bị hộp thoại chặn; `main.dart` truyền `true`); bọc thân màn trong `Stack` để đặt lớp phủ lên trên; gọi `tourController.update` sau mỗi lần dựng khi đang chạy; chọn lại hôm nay và về đúng tháng khi bắt đầu.
- Màn Hướng dẫn dùng (`help_screen.dart`) thêm nút "Xem lại hướng dẫn làm thử": `tourController.requestReplay()` rồi `popUntil` về màn chính; màn chính nghe và khởi động chuyến (bắt đầu từ bước lời mở). Người dùng cũ (đã có dữ liệu) không bị hiện tự động.
- `SettingsScreen` thêm tham số `scrollToGps` và `GlobalKey` cho thẻ GPS.
- Bảng chọn giờ, bảng Ngày nghỉ, bảng Ghi chú là các bottom sheet có sẵn (`edit_dialogs.dart`, `_chooseDayOff`): không sửa, chúng nằm trên lớp phủ nên người dùng dùng bình thường.

### 5. Ngoài phạm vi (đừng làm trong PR này)
Ẩn số tiền ở mức 1, thẻ "Bắt đầu" tích dần, dấu "?" giải thích từng con số, hướng dẫn phần lương, đổi bất cứ quy tắc tính công nào, đụng vào GPS và còi.

### 6. Yêu cầu khi làm
- `flutter analyze` sạch và `flutter test` qua hết (206 test hiện có không được hỏng). Thêm test: bộ điều khiển chuyển bước đúng theo từng thao tác trên một `AppStore` giả (ghi đè `_save`/`restoreRecord` theo kiểu `_MemoryStore` trong `test/ui/settings_screen_test.dart`), trả dữ liệu tập về đúng bản chụp, và một test widget: người mới thấy khung giới thiệu, người đã có dữ liệu thì không.
- Làm trên nhánh mới từ nhánh này, mở pull request vào `master`. **Không** deploy web, **không** phát hành, **không** đổi Remote Config, **không** động tới khóa ký hay `key.properties`. Không cài lên điện thoại được (không có adb trên cloud); trong PR ghi rõ phần nào mới qua test, phần nào chưa thử trên máy.
- Viết Dart theo phong cách file xung quanh (chú thích tiếng Việt, tên rõ). Cuối PR cập nhật mục này trong `TIEN-DO.md` thành "đã làm, chờ người dùng thử trên điện thoại".
## Mặc định Claude tự chọn, chờ người dùng xác nhận

1. **Ngày nghỉ không tính lương** (lương = 0). Muốn đủ lương hoặc một phần thì cần thêm cấu hình.
2. "Thống kê thu nhập theo kỳ" hiện 12 kỳ gần nhất.
3. Hai nút đầu trang (Âm lịch, Lương mỗi ngày) chỉ có icon, không có chữ.

## Việc còn lại

- **Bản Android mới chưa tới tay ai**: ngày 2026-10-05 bản build từ `master` commit `d1d82ad` (có sao lưu Excel và thông báo nhiều link) đã được build trên PC và cài đè lên điện thoại của người dùng (Realme RMX2021); mới cài và mở, chưa thử tính năng nào trên máy. Tối cùng ngày cài đè thêm bản có phần sửa màn Cài đặt (mục gập được và nhớ trạng thái gập, đổi thứ tự, bỏ Khung nhiều mục, chấm khác khung thì không tính giờ nghỉ 11:30–12:30), build bằng Flutter 3.47.6; cũng mới cài và mở. Bản này chưa đưa lên GitHub Releases, số phiên bản trong `pubspec.yaml` vẫn là `1.0.0+1` và chưa đổi `latest_version`. Nút "Tải bản Android" trên web vẫn trỏ tới APK `v1.0.0`.
- **Chưa thử trên máy thật**: luồng lấy mã / nhập mã / mở khóa (cần 2 máy), băng thông báo, việc gửi số lượt dùng lên máy chủ. Mới xác nhận được là máy đầu tiên đã đăng ký với máy chủ (`meta/counter` = 1).
- **Khóa ký app**: bản release đang ký bằng khóa debug. Phải tạo khóa phát hành thật trước khi có nhiều người dùng hoặc lên Google Play; đổi khóa thì các máy bị coi là máy mới (mất số thứ tự và trạng thái mở khóa).
- **Lên Google Play**: cần khóa ký, trang chính sách quyền riêng tư và khai báo Data safety (app có gửi số liệu sử dụng theo máy).
- Chưa có: thông báo đẩy, Firebase App Check, bản iOS.

## Dùng thử chấm công tự động + mã giới thiệu (cập nhật 2026-10-03)

Quy tắc đã chốt với bạn (X và Y chỉnh từ Remote Config, không cố định trong code):

- **Tổng số máy Android chưa vượt X** (`share_free_users`, mặc định 50): không giới hạn gì, không hiện mã, ô nhập hay lời báo trước; mục "Chia sẻ app" trong Cài đặt chỉ có nút gửi link. App trông hoàn toàn miễn phí. Số "ngày dùng" (ngày có ít nhất 1 lần GPS tự chấm hoặc bấm widget) vẫn được đếm âm thầm từ đầu.
- **Vượt X** (máy thứ X+1 cài app): áp dụng cho mọi máy, kể cả X máy đầu. Máy nào đã dùng GPS/widget quá Y ngày (`share_trial_days`, mặc định 10) thì GPS/widget tạm dừng ngay, chấm tay vẫn bình thường. `share_trial_days` = 0 là tắt hẳn tính năng.
- Khi đã vượt X, mỗi máy có ô nhập mã "Ai giới thiệu bạn?" và nút "Lấy mã giới thiệu" trong Cài đặt › Chia sẻ app. **Lấy mã rồi thì mất ô nhập** (có hộp hỏi lại trước khi cấp), nên không thể có hai hay một vòng nhiều máy mở khóa lẫn nhau. Nhập mã trước rồi lấy mã sau thì được. Máy chủ cũng từ chối việc nhập mã từ máy đã có mã.
- Có 1 máy nhập đúng mã là chủ mã được mở lâu dài (qua các bản cập nhật vẫn giữ); mở rồi thì phần mã ẩn đi, chỉ còn nút gửi link. Máy nhập mã không được thưởng gì.
- Ô nhập mã không có thời hạn (`share_entry_hours` mặc định 0 = không hạn; đặt 24 nếu sau này muốn giới hạn lại). Hộp hỏi "Ai giới thiệu bạn?" chỉ tự bật 1 lần cho máy cài sau khi đã đủ X máy; máy cũ thì ô nhập nằm sẵn trong Cài đặt.
- Thời gian mở khóa sau khi máy kia nhập mã: app đang mở thì vài giây (nghe trực tiếp từ máy chủ); app đóng thì ngay lần mở kế tiếp, hoặc tới khung giờ GPS dịch vụ nền tự hỏi máy chủ (`lib/share/background_unlock.dart`). Không dùng thông báo đẩy (cần gói trả phí).
- Tham số khác: `share_url` (mặc định `https://cham-cong-don-gian.web.app`). App tải lại Remote Config tối đa 6 giờ một lần.
- Mở khóa tay cho một máy: Firestore › `codes` › mã của máy đó, đổi `redeemed` thành `true`.

- **Đếm lượt dùng theo từng máy (2026-10-03):** `devices/{id}` có thêm `appOpens` (mở app, hai lần cách nhau dưới 30 phút tính 1), `widgetUses`, `gpsUses`, `lastSeen`, `appVersion`. Widget/GPS nền cộng dồn vào `usage_pending.json`, app gửi lên ở lần mở kế tiếp (tối đa 10 phút một lần). Tổng số máy: `meta/counter.count`. Analytics dùng số thứ tự máy (`seq`) làm mã người dùng.

Code: quy tắc thuần ở `lib/domain/share_gate.dart` (test `test/domain/share_gate_test.dart`), file trạng thái `share_state.json` ở `lib/share/share_state_file.dart` (tiến trình nền widget/GPS đọc được), Firestore ở `lib/share/share_service.dart`, giao diện ở `lib/ui/settings/share_section.dart`, luật bảo mật ở `firestore.rules`.

Còn lại:

- Firestore đã bật và luật đã đưa lên ngày 2026-10-02 (`firebase deploy --only firestore:rules`). Lệnh deploy tự tạo cơ sở dữ liệu ở **nam5 (Mỹ)**, không phải Singapore như dự định; vị trí không đổi được, muốn đổi phải xóa cơ sở dữ liệu `(default)` trong Firebase Console rồi tạo lại ở `asia-southeast1` và deploy lại luật.
- Chưa thử trên máy thật luồng lấy mã / nhập mã / mở khóa (cần 2 máy, và đặt tạm `share_free_users` = 0 hoặc 1 để giới hạn áp dụng ngay).
- Bản build 2026-10-03 (luật lấy mã thì mất ô nhập) đã cài lên điện thoại của người dùng tối 2026-10-03, rồi ngày 2026-10-05 được cài đè bằng bản build từ `master` commit `d1d82ad`; cả hai lần mới cài và mở, chưa bấm thử luồng nào.
- Máy được nhận diện bằng mã thiết bị Android, mã này phụ thuộc khóa ký app. Bản release đang ký bằng khóa debug; đổi sang khóa phát hành thật thì các máy đã mở khóa sẽ bị coi là máy mới. Nên chốt khóa ký trước khi có nhiều người dùng.
- App không đăng nhập nên người rành kỹ thuật có thể gọi thẳng máy chủ để tự mở khóa. Muốn chặn thì thêm Firebase App Check sau.

## Thông báo từ chủ app tới người dùng (2026-10-03)

Băng thông báo ở đầu màn chính (cả Android lẫn web), soạn trên Firebase Remote Config, không cần ra bản mới. Code và test: `lib/notice/notice.dart`, `test/notice_test.dart`.

- `notice_text`: nội dung; để trống là không có thông báo. Gõ `\n` để xuống dòng.
- `notice_title`: tiêu đề in đậm (không bắt buộc).
- `notice_links`: nhiều link, mỗi link một nút. Mỗi dòng một link dạng `Nhóm Zalo | https://zalo.me/g/...` (ô nhập một dòng thì gõ `\n` giữa các link). Không có chữ trước `|` thì nút ghi "Mở link"; link phải bắt đầu bằng `https://`.
- Kiểu cũ `notice_url` + `notice_button` (một link) vẫn dùng được, nút này đứng trước các nút của `notice_links`.
- Băng chỉ hiện 3 dòng đầu của nội dung; dài hơn thì có nút "Xem thêm" mở toàn bộ.
- Người dùng bấm × thì băng ẩn hẳn trên máy họ và app nhắc "xem lại trong Cài đặt › Thông báo". Mục **Cài đặt › Thông báo** luôn hiện đủ thông báo đang đặt (kể cả đã tắt băng); để trống `notice_text` thì mục này ẩn. Đổi nội dung, tiêu đề hoặc link là thành thông báo mới và băng hiện lại cho mọi người.
- App tải lại Remote Config tối đa 6 giờ một lần, nên thông báo tới dần trong ngày. Chỉ người mở app mới thấy (chưa có thông báo đẩy).
- Bản web đã deploy ngày 2026-10-03 (`flutter build web --release` rồi `firebase deploy --only hosting`), gồm băng thông báo và mục "Chia sẻ app" (trên web là nút sao chép link). Bản Android trên điện thoại của người dùng (Realme RMX2021) hiện là bản build từ `master` commit `d1d82ad`, cài đè ngày 2026-10-05 (có thông báo nhiều link); mới cài và mở, chưa thử tính năng nào trên máy, chưa đưa lên GitHub Releases.

## Hướng dẫn sử dụng soạn trên Firebase (2026-10-05)

Tham số `help_text`: để trống thì màn "Hướng dẫn sử dụng" dùng nội dung có sẵn trong app (`lib/ui/settings/help_screen.dart`); có nội dung thì **thay toàn bộ** nội dung có sẵn. Mỗi mục một dòng dạng `Tiêu đề | Nội dung` (ô nhập một dòng thì gõ `\n` giữa các mục); dòng không có `|` được nối vào nội dung mục ngay trên. Các mục soạn trên Firebase dùng chung một icon. Code và test: `lib/notice/help_text.dart`, `test/help_text_test.dart`.

## Bản web mở nhanh và dùng được khi mất mạng (2026-10-05)

- `web/sw.js`: service worker tự viết, lưu sẵn mọi file của app trong máy; lần sau mở ngay từ bản đã lưu (kể cả mất mạng) và tải bản mới ngầm, bản deploy mới có hiệu lực ở lần mở kế tiếp. Lần đầu tiên vẫn cần mạng. (Service worker mặc định của Flutter đã bị bỏ, chỉ còn file tự gỡ `flutter_service_worker.js` không được dùng.)
- `web/flutter_bootstrap.js`: lấy CanvasKit (phần vẽ giao diện) từ chính trang web thay vì `gstatic.com`, để lưu sẵn được.
- `web/index.html`: màn chờ có logo trong lúc tải; tên app "Chấm Công Đơn Giản" (cả `manifest.json`).
- `lib/main.dart`: trên web app hiện lên ngay, không chờ Firebase (trước đây chờ tối đa 5 giây); thống kê/thông báo/mã giới thiệu chạy sau khi Firebase sẵn sàng. Android giữ như cũ.
- Đã thử trên cloud bằng Chromium (bản build release, chạy ở localhost): lần đầu app hiện sau ~1,2 giây, mở lại ~0,9 giây, **ngắt mạng rồi mở lại vẫn hiện app** (~0,5 giây). Đã deploy lên trang thật tối 2026-10-05 (build bằng Flutter 3.47.6, gồm cả phần sửa màn Cài đặt và cách tính chấm khác khung cùng ngày); mới kiểm tra là trang thật đã trả về `sw.js` và các file mới, chưa mở thử bằng trình duyệt, chưa thử mất mạng trên điện thoại thật.

## Sao lưu dữ liệu ra file Excel (2026-10-05)

Cài đặt › **Sao lưu dữ liệu** có 2 nút (cả Android lẫn web):

- **Xuất file Excel**: tạo `ChamCong_yyyy-MM-dd.xlsx`, Android mở hộp chọn chỗ lưu (Download, Google Drive...) rồi hiện đường dẫn và nút "Gửi file đi" (Zalo, email...); web tải về thư mục Tải xuống. Trong file: trang "Chấm công" (mỗi ngày một dòng: giờ vào/ra, giờ thường, tăng ca, nghỉ, đi muộn, **tiền tạm tính**, ghi chú; dòng tổng cuối), "Theo kỳ" (tổng giờ/tiền từng kỳ lương, tiền tự nhập), "Thông tin" (ngày xuất, cách khôi phục) và trang ẩn `DuLieuApp` chứa toàn bộ dữ liệu gốc (JSON chia nhiều ô).
- **Khôi phục từ file**: chỉ đọc trang ẩn, nên người dùng sửa số ở các trang khác không ảnh hưởng. Gộp **theo từng ngày**: ngày có trong file thay ngày đó trong app; ngày chỉ có trong app giữ nguyên; từ ngày xuất file trở về sau, ngày nào app đã có dữ liệu thì giữ bản trong app (đã chấm tiếp sau khi xuất). Tiền tự nhập theo kỳ gộp cùng cách. Hộp hỏi lại có ô "Lấy cả cài đặt theo file" (mặc định tick khi app chưa có dữ liệu); GPS khôi phục nhưng để tắt, bật lại để app xin quyền trên máy mới.
- Code: quy tắc gộp `lib/domain/backup.dart`, tạo/đọc file `lib/data/backup_excel.dart` (thư viện `excel` để tạo; đọc lại bằng cách tự đọc XML để đọc được cả file đã mở và lưu lại bằng chương trình khác), giao diện `lib/ui/settings/backup_section.dart`. Test: `test/domain/backup_test.dart`, `test/data/backup_excel_test.dart`, `test/ui/backup_section_test.dart`.
- Đã thử trên cloud: bản web (Chromium) chấm vào, xuất file tải về, khôi phục file mẫu 40 ngày (thêm 39, giữ ngày hôm nay theo app). File đọc được bằng openpyxl (thư viện bảng tính của Python), trang dữ liệu ẩn đúng, số tiền có dấu phân cách; file đã sửa và lưu lại bằng openpyxl vẫn khôi phục được. **Chưa thử**: bản Android (hộp chọn chỗ lưu, đường dẫn hiện ra, nút gửi file), mở file bằng Excel/Google Sheets/WPS thật.

## Cách build, cài và đưa lên

Chạy trong thư mục dự án (trên PC: `C:\Users\Admin\Documents\PlatformIO\Projects\cham_cong_don_gian`).

```
flutter analyze
flutter test

# Android: build bản release rồi cài lên điện thoại nối USB (bật gỡ lỗi USB). Cài đè giữ nguyên dữ liệu.
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk

# Web: build rồi deploy lên https://cham-cong-don-gian.web.app
flutter build web --release
firebase deploy --only hosting

# Luật bảo mật Firestore (sau khi sửa firestore.rules)
firebase deploy --only firestore:rules
```

- Trên PC này `adb` không có trong PATH, nằm ở `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.
- Ngày 2026-10-05 đã bỏ các thư mục không dùng `ios`, `macos`, `windows`, `linux` (app chỉ chạy Android và web). Nhờ đó hết lỗi "symlink support / Developer Mode" từng chặn `flutter build apk` trên PC này. Sau này muốn làm bản iOS thì tạo lại bằng `flutter create --platforms=ios .`.
- Flutter trên PC đã nâng lên 3.47.6 (Dart 3.13.5) ngày 2026-10-05; `flutter pub get` không còn ghi lại `pubspec.lock`. Flutter mới tự thêm vài dòng vào `analysis_options.yaml` và `android/gradle.properties`, và nhắc nâng Kotlin từ 2.2.20 lên ít nhất 2.3.20 (mới là cảnh báo, build vẫn chạy).
- Bản debug rất nặng trên máy ít RAM; thử trên điện thoại thì luôn dùng bản release.
- Người dùng web có thể phải tải lại trang một lần sau mỗi lần deploy.
