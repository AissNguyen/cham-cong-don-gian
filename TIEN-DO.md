# Tổng hợp — Chấm Công Đơn Giản

**Cập nhật lần cuối: 2026-10-05.** Đọc file này trước khi sửa app. Cách làm việc với người dùng nằm ở `CLAUDE.md`.

App chấm công đơn giản cho người làm theo giờ: ghi giờ vào/ra, tăng ca, ngày nghỉ, đi muộn, và ước tính lương theo kỳ. Tách riêng khỏi dự án `so_cong` (bản đầy đủ, đang để đó); chỉ dùng chung `domain/lunar.dart` và font Be Vietnam Pro.

## Đang chạy ở đâu

| Thứ | Ở đâu |
|---|---|
| Mã nguồn | GitHub `AissNguyen/cham-cong-don-gian`, nhánh `master` |
| Bản web | https://cham-cong-don-gian.web.app (Firebase Hosting, deploy lần cuối 2026-10-03) |
| Bản Android | File APK ở GitHub Releases, hiện là `v1.0.0` (bản cũ, chưa có các phần làm ngày 2026-10-02 và 03). Chưa lên Google Play |
| Firebase | Dự án `cham-cong-don-gian`: Analytics, Crashlytics, Remote Config, Firestore (máy chủ nam5 – Mỹ), Hosting. Gói miễn phí |
| Gói Android | `vn.chamcong.cham_cong_don_gian`, phiên bản trong `pubspec.yaml` vẫn là `1.0.0+1` |

## Đã có

- **Lõi tính toán** (`lib/domain/`, thuần Dart): giờ thường, tăng ca theo khung, đi muộn, cộng trừ giờ theo giờ vào, bảng lương/giờ theo loại ngày, ngày lễ mặc định (tự bù cho năm hiện tại và 2 năm tới), kỳ lương (theo tháng hoặc 2 kỳ/tháng), khoản thu nhập/khấu trừ tự tạo, âm lịch, thu nhập "hôm nay" ước tính theo từng giây.
- **Lưu trữ**: một file JSON trong máy (`lib/data/`), không cần mạng. Bản web lưu trong trình duyệt. Widget và GPS nền đọc/ghi thẳng file này.
- **Màn chính** (`lib/ui/home/`): thẻ thu nhập tạm tính (số hôm nay chạy theo giây), lịch tháng (âm lịch, tiền mỗi ngày, giờ chấm), các nút Chấm vào / Chấm ra / Ngày nghỉ / Đi muộn / Ghi chú, biểu đồ cột giờ công theo ngày trong kỳ, danh sách ghi chú, thống kê thu nhập theo kỳ (có ô nhập tiền ghi đè), băng nhắc cập nhật, băng thông báo của chủ app.
- **Cài đặt** (`lib/ui/settings/`): Chia sẻ app, Sao chép/dán cấu hình, Kỳ lương, Khung giờ ra vào, Bảng lương/giờ, Khoản thu nhập/khấu trừ khác, Ngày lễ, Cộng trừ giờ theo giờ vào, Khung nhiều mục, Tăng ca theo khung, Đi muộn, Chấm công GPS, Góp ý (email), Hướng dẫn sử dụng. Bản web có thêm mục Tải bản Android và không có GPS/widget.
- **Chấm công tự động (chỉ Android)**: GPS chạy nền theo khung giờ (`lib/gps/`: báo thức đánh thức máy, dịch vụ nền có thông báo, tự chấm vào khi vào bán kính và chấm ra khi rời hẳn). Có thêm danh sách "Địa điểm khác" (vị trí, bán kính, "Chấm về"/"Không chấm về") chỉ ảnh hưởng chấm ra: nhà trọ sát công ty thì về tới là chấm ra, xưởng xa máy chấm công thì ở đó không bị chấm ra, widget màn hình chính có 2 nút chấm (`lib/widget/` + `ChamCongWidgetProvider.kt`).
- **Nhắc cập nhật** (`lib/update/`): đổi `latest_version` / `update_url` trên Remote Config là app nhắc; quá 14 ngày không cập nhật thì bắt buộc.
- **Thống kê** (`lib/analytics/`): mỗi máy mỗi ngày ghi tối đa 1 lần các sự kiện mở app, bấm widget, GPS tự chấm, xem thống kê kỳ, mở cài đặt.
- **Dùng thử + mã giới thiệu, đếm lượt dùng, thông báo từ chủ app**: xem ba mục riêng bên dưới.
- **Icon app riêng** (`flutter_launcher_icons.yaml`, `assets/icon/`).
- **Test**: 89 test qua (`flutter test`), `flutter analyze` chỉ còn 2 gợi ý nhỏ về kiểu viết.

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

- **Bản Android mới chưa tới tay ai**: bản build ngày 2026-10-03 đã cài lên điện thoại của người dùng (22:48) nhưng chưa đưa lên GitHub Releases, chưa tăng số phiên bản và chưa đổi `latest_version`. Nút "Tải bản Android" trên web vẫn trỏ tới APK `v1.0.0`.
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
- Bản build 2026-10-03 (luật lấy mã thì mất ô nhập) đã cài lên điện thoại của người dùng tối 2026-10-03; mới cài và mở, chưa bấm thử luồng nào.
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
- Bản web đã deploy ngày 2026-10-03 (`flutter build web --release` rồi `firebase deploy --only hosting`), gồm băng thông báo và mục "Chia sẻ app" (trên web là nút sao chép link). Bản Android mới đã cài lên điện thoại của người dùng, chưa đưa lên GitHub releases.

## Hướng dẫn sử dụng soạn trên Firebase (2026-10-05)

Tham số `help_text`: để trống thì màn "Hướng dẫn sử dụng" dùng nội dung có sẵn trong app (`lib/ui/settings/help_screen.dart`); có nội dung thì **thay toàn bộ** nội dung có sẵn. Mỗi mục một dòng dạng `Tiêu đề | Nội dung` (ô nhập một dòng thì gõ `\n` giữa các mục); dòng không có `|` được nối vào nội dung mục ngay trên. Các mục soạn trên Firebase dùng chung một icon. Code và test: `lib/notice/help_text.dart`, `test/help_text_test.dart`.

## Bản web mở nhanh và dùng được khi mất mạng (2026-10-05)

- `web/sw.js`: service worker tự viết, lưu sẵn mọi file của app trong máy; lần sau mở ngay từ bản đã lưu (kể cả mất mạng) và tải bản mới ngầm, bản deploy mới có hiệu lực ở lần mở kế tiếp. Lần đầu tiên vẫn cần mạng. (Service worker mặc định của Flutter đã bị bỏ, chỉ còn file tự gỡ `flutter_service_worker.js` không được dùng.)
- `web/flutter_bootstrap.js`: lấy CanvasKit (phần vẽ giao diện) từ chính trang web thay vì `gstatic.com`, để lưu sẵn được.
- `web/index.html`: màn chờ có logo trong lúc tải; tên app "Chấm Công Đơn Giản" (cả `manifest.json`).
- `lib/main.dart`: trên web app hiện lên ngay, không chờ Firebase (trước đây chờ tối đa 5 giây); thống kê/thông báo/mã giới thiệu chạy sau khi Firebase sẵn sàng. Android giữ như cũ.
- Đã thử trên cloud bằng Chromium (bản build release, chạy ở localhost): lần đầu app hiện sau ~1,2 giây, mở lại ~0,9 giây, **ngắt mạng rồi mở lại vẫn hiện app** (~0,5 giây). Chưa thử trên điện thoại thật và trên tên miền thật.

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
- `flutter pub get` báo lỗi "symlink support / Developer Mode" trên PC này; không ảnh hưởng build Android và web.
- Bản debug rất nặng trên máy ít RAM; thử trên điện thoại thì luôn dùng bản release.
- Người dùng web có thể phải tải lại trang một lần sau mỗi lần deploy.
