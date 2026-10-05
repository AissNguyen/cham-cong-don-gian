# CLAUDE.md — Chấm Công Đơn Giản

Ghi chú cho Claude Code (trên PC, IDE hay trên cloud) để nắm ngữ cảnh dự án mà không cần hỏi lại.

## Dự án

- App Flutter chấm công đơn giản: ghi giờ vào/ra, tăng ca, ngày nghỉ, đi muộn và ước tính lương theo kỳ. Chạy trên Android (APK) và web (https://cham-cong-don-gian.web.app).
- **Đọc `TIEN-DO.md` trước khi làm**: đó là bản tổng hợp hiện trạng (đã có gì, đang chạy ở đâu, tham số Remote Config, việc còn lại, lệnh build và deploy).
- Dữ liệu chấm công lưu trên máy (một file JSON, `lib/data/`), không cần mạng. Firebase (dự án `cham-cong-don-gian`) chỉ dùng cho thống kê, nhắc cập nhật, thông báo, mã giới thiệu và bản web.
- Lõi tính toán thuần Dart ở `lib/domain/` (`calc.dart`, `pay_period.dart`, `share_gate.dart`, `lunar.dart`...), có test ở `test/domain`.
- Giao diện: `lib/ui/home/` (màn chính), `lib/ui/settings/` (cài đặt). GPS ở `lib/gps/`, widget màn hình chính ở `lib/widget/`, mã giới thiệu và đếm lượt dùng ở `lib/share/`, thông báo của chủ app ở `lib/notice/`, nhắc cập nhật ở `lib/update/`.
- Widget và GPS chạy ở tiến trình nền riêng, không có sẵn Firebase và không chung bộ nhớ với app: chúng chỉ đọc/ghi file. Sửa phần này phải giữ nguyên tắc đó.
- Luật bảo mật Firestore ở `firestore.rules`; sửa xong phải deploy thì mới có hiệu lực.

## Cách làm việc với người dùng

- Người dùng viết tiếng Việt và không rành kỹ thuật: luôn trả lời bằng tiếng Việt, ngắn gọn, dễ hiểu, giải thích thuật ngữ khi cần.
- **Thảo luận trước, sửa sau.** Khi người dùng nêu ý tưởng mới: nói lại cách hiểu, góp ý, hỏi chỗ chưa rõ. Chỉ sửa code khi người dùng đã chốt hoặc nói rõ là muốn sửa. Không đưa ra danh sách lựa chọn A/B dài; nêu đề xuất của mình kèm lý do.
- Trước khi bắt đầu một việc, báo ước lượng thời gian ngắn gọn: phần Claude tự làm và phần cần người dùng.
- Báo kết quả trung thực: nói rõ cái gì đã chạy thử thật, cái gì mới chỉ qua test, cái gì chưa thử.
- Các con số người dùng muốn tự điều chỉnh (số ngày dùng thử, số máy miễn phí, link...) để ở Firebase Remote Config, không cố định trong code.
- Mọi thứ ảnh hưởng tới người dùng thật (deploy web, deploy luật Firestore, đưa APK lên Releases, đổi `latest_version`) phải được người dùng đồng ý trước.

## Đồng bộ giữa PC và cloud

- Nhánh chính là `master`. Trên PC, người dùng nhờ Claude commit và push thẳng lên `master`.
- Claude trên cloud (dùng từ điện thoại): sửa code trên một nhánh mới, mở pull request; người dùng bấm merge trên GitHub; sau đó trên PC chạy `git pull`.
- Trước khi nhờ Claude trên cloud sửa, PC phải commit và push hết để tránh xung đột. Trước khi sửa trên PC, `git pull` trước.
- Trên cloud thường không có điện thoại nối vào và có thể không có Flutter: nếu không chạy được `flutter analyze` / `flutter test` thì nói rõ là chưa chạy. Cài APK lên điện thoại, deploy web và deploy luật Firestore làm ở PC (đã đăng nhập Firebase và có adb).
- Repo này công khai. Không commit khóa ký (`*.jks`, `key.properties`) hay bất kỳ mật khẩu nào. `google-services.json` và `lib/firebase_options.dart` là cấu hình phía máy khách của Firebase (vốn có sẵn trong app phát hành), được commit để build được ở nơi khác.

## Ba mặc định đang chờ người dùng chốt

Chưa đổi gì, chờ người dùng quyết định. Danh sách nằm ở `TIEN-DO.md`, mục "Mặc định Claude tự chọn, chờ người dùng xác nhận".

## Cập nhật lần cuối

2026-10-05: sao lưu/khôi phục dữ liệu bằng file Excel (Cài đặt › Sao lưu dữ liệu); thông báo nhiều link + mục Cài đặt › Thông báo, hướng dẫn soạn trên Firebase (`help_text`), bản web mở nhanh và chạy offline (xem `TIEN-DO.md`). Cùng ngày: build trên PC từ `master` commit `d1d82ad` và cài đè lên điện thoại của người dùng (mới cài và mở, chưa thử tính năng); chưa đưa lên GitHub Releases. Cũng ngày này trên PC: bỏ các thư mục `ios`, `macos`, `windows`, `linux`, nâng Flutter lên 3.47.6, màn Cài đặt gập được và đổi thứ tự, bỏ mục "Khung nhiều mục (dự phòng)" (xem `TIEN-DO.md`).

2026-10-03: đồng bộ toàn bộ code trên PC lên `master` (Firebase, GPS/widget, mã giới thiệu, đếm lượt dùng, thông báo, bản web) và viết lại `TIEN-DO.md` thành bản tổng hợp.
