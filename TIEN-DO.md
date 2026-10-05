# Tổng hợp — Chấm Công Đơn Giản

**Cập nhật lần cuối: 2026-10-05.** Đọc file này trước khi sửa app. Cách làm việc với người dùng nằm ở `CLAUDE.md`.

App chấm công đơn giản cho người làm theo giờ: ghi giờ vào/ra, tăng ca, ngày nghỉ, đi muộn, và ước tính lương theo kỳ. Tách riêng khỏi dự án `so_cong` (bản đầy đủ, đang để đó); chỉ dùng chung `domain/lunar.dart` và font Be Vietnam Pro.

## Đang chạy ở đâu

| Thứ | Ở đâu |
|---|---|
| Mã nguồn | GitHub `AissNguyen/cham-cong-don-gian`, nhánh `master` |
| Bản web | https://cham-cong-don-gian.web.app (Firebase Hosting, deploy lần cuối 2026-10-05) |
| Bản Android | File APK ở GitHub Releases, hiện là `v1.0.0` (bản cũ, chưa có các phần làm từ ngày 2026-10-02 tới nay). Trên điện thoại của người dùng (Realme RMX2021) là bản build trên PC tối 2026-10-05 (code `master` commit `d1d82ad` cộng phần sửa màn Cài đặt cùng ngày), chưa đưa lên Releases. Chưa lên Google Play |
| Firebase | Dự án `cham-cong-don-gian`: Analytics, Crashlytics, Remote Config, Firestore (máy chủ nam5 – Mỹ), Hosting. Gói miễn phí |
| Gói Android | `vn.chamcong.cham_cong_don_gian`, phiên bản trong `pubspec.yaml` vẫn là `1.0.0+1` |

## Đã có

- **Lõi tính toán** (`lib/domain/`, thuần Dart): giờ thường, tăng ca theo khung, đi muộn, cộng trừ giờ theo giờ vào, bảng lương/giờ theo loại ngày, ngày lễ mặc định (tự bù cho năm hiện tại và 2 năm tới), kỳ lương (theo tháng hoặc 2 kỳ/tháng), khoản thu nhập/khấu trừ tự tạo, âm lịch, thu nhập "hôm nay" ước tính theo từng giây.
- **Lưu trữ**: một file JSON trong máy (`lib/data/`), không cần mạng. Bản web lưu trong trình duyệt. Widget và GPS nền đọc/ghi thẳng file này.
- **Màn chính** (`lib/ui/home/`): thẻ thu nhập tạm tính (số hôm nay chạy theo giây), lịch tháng (âm lịch, tiền mỗi ngày, giờ chấm), các nút Chấm vào / Chấm ra / Ngày nghỉ / Đi muộn / Ghi chú, biểu đồ cột giờ công theo ngày trong kỳ, danh sách ghi chú, thống kê thu nhập theo kỳ (có ô nhập tiền ghi đè), băng nhắc cập nhật, băng thông báo của chủ app.
- **Cài đặt** (`lib/ui/settings/`), theo thứ tự trên màn hình: Thông báo, Kỳ lương, Khung giờ ra vào, Bảng lương/giờ, Khoản thu nhập/khấu trừ khác, Ngày lễ, Đi muộn, Cộng trừ giờ theo giờ vào, Tăng ca theo khung, Chấm công GPS, Sao lưu dữ liệu, Sao chép/dán cấu hình, Chia sẻ app, Góp ý (email), Hướng dẫn sử dụng. Bản web có thêm mục Tải bản Android và không có GPS/widget. Từ 2026-10-05 các mục cấu hình (Kỳ lương tới Sao chép/dán cấu hình) mở sẵn nhưng gập được: chạm tiêu đề để gập, mục nào đã gập thì những lần mở Cài đặt sau vẫn gập (`SettingsCard(collapsible: true)`, nhớ trong máy bằng khóa `settings_collapsed`).
- **Đã bỏ mục "Khung nhiều mục (dự phòng)"** (2026-10-05): giờ vào/ra không khớp khung cố định nào thì không tính giờ công trong khoảng nghỉ trưa 11:30–12:30 (chỉ trừ đúng phần giờ làm rơi vào khoảng đó; hằng số `unmatchedBreakFrom`/`unmatchedBreakTo` trong `lib/domain/calc.dart`, áp dụng cho mọi người dùng) và màn chính vẫn hiện cảnh báo đỏ. Chưa cài khung cố định nào thì không trừ, không cảnh báo. Trong lúc ca đang mở (và đã cài khung cố định), số chạy đứng yên suốt 11:30–12:30 rồi chạy tiếp; lúc chấm ra nếu khớp một khung cố định thì chốt theo khung đó, số có thể nhảy nhẹ. Dữ liệu `breakSegments` cũ vẫn được đọc/ghi (file lưu, sao lưu Excel, sao chép cấu hình) nhưng không dùng để tính.
- **Chấm công tự động (chỉ Android)**: GPS chạy nền theo khung giờ (`lib/gps/`: báo thức đánh thức máy, dịch vụ nền có thông báo, tự chấm vào khi vào bán kính và chấm ra khi rời hẳn). Có thêm danh sách "Địa điểm khác" (vị trí, bán kính, "Chấm về"/"Không chấm về") chỉ ảnh hưởng chấm ra: nhà trọ sát công ty thì về tới là chấm ra, xưởng xa máy chấm công thì ở đó không bị chấm ra, widget màn hình chính có 2 nút chấm (`lib/widget/` + `ChamCongWidgetProvider.kt`).
- **Nhắc cập nhật** (`lib/update/`): đổi `latest_version` / `update_url` trên Remote Config là app nhắc; quá 14 ngày không cập nhật thì bắt buộc.
- **Thống kê** (`lib/analytics/`): mỗi máy mỗi ngày ghi tối đa 1 lần các sự kiện mở app, bấm widget, GPS tự chấm, xem thống kê kỳ, mở cài đặt.
- **Dùng thử + mã giới thiệu, đếm lượt dùng, thông báo từ chủ app**: xem ba mục riêng bên dưới.
- **Icon app riêng** (`flutter_launcher_icons.yaml`, `assets/icon/`).
- **Test**: 121 test qua, không lỗi (`flutter test`), `flutter analyze` chỉ còn 2 gợi ý nhỏ về kiểu viết (chạy trên PC ngày 2026-10-05).

## Tham số Remote Config (đổi trên Firebase Console, không cần ra bản mới)

| Tham số | Mặc định khi chưa đặt | Ý nghĩa |
|---|---|---|
| `latest_version`, `update_url` | không nhắc | Phiên bản mới nhất và link tải, để app nhắc cập nhật |
| `share_free_users` | 50 | X: tổng số máy Android vượt số này thì giới hạn GPS/widget mới áp dụng |
| `share_trial_days` | 10 | Y: số ngày dùng thử GPS/widget. Đặt 0 là tắt hẳn tính năng giới hạn |
| `share_entry_hours` | 0 | Thời hạn ô nhập mã tính từ lúc cài (giờ); 0 là không hạn |
| `share_url` | https://cham-cong-don-gian.web.app | Link trong tin nhắn chia sẻ |
| `notice_text`, `notice_title`, `notice_links` (và kiểu cũ `notice_url`, `notice_button`) | không có thông báo | Băng thông báo ở đầu màn chính, xem lại được ở Cài đặt › Thông báo |
| `help_text` | hướng dẫn có sẵn trong app | Nội dung màn "Hướng dẫn sử dụng" |

App tải lại Remote Config tối đa 6 giờ một lần.

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
