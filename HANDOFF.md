# HANDOFF — 2026-10-18 17:37 UTC — cloud

Branch: `claude/handoff-goi-y-cai-tien`   Repo: `AissNguyen/cham-cong-don-gian`

## Mục tiêu của phiên

Người dùng hỏi: "chào bạn b nghĩ cần cải tiến gì ở app này k". Đây là câu hỏi để thảo luận, chưa yêu cầu sửa code.

## Diễn biến (theo thứ tự)

1. Người dùng: "chào bạn b nghĩ cần cải tiến gì ở app này k"
   Claude: đọc `TIEN-DO.md` (phần hiện trạng, "Mặc định Claude tự chọn", "Việc còn lại") và `git log` gần đây (mới nhất trên `master`: `9ffe493` merge PR #10 thêm skill /handoff và /resume-work; trước đó PR #9 thử đồng bộ, `416a622` ghi ý tưởng lấy tăng ca bù giờ thiếu, PR #7 khung giới thiệu và hướng dẫn). Không sửa file nào. Trả lời rằng **lúc này không nên thêm tính năng mới**, và đề xuất theo thứ tự ưu tiên:
   1. **Thử cho chắc rồi phát hành** (quan trọng nhất):
      - GPS kiểu mới (theo mốc giờ, Wi-Fi quen) mới qua test tự động, chưa thử qua nhiều ngày đi làm thật.
      - Còi báo giờ chưa hú thật; khung giới thiệu và hướng dẫn cho người mới chưa mở trên điện thoại.
      - Bản 1.2.3 trên điện thoại người dùng chưa lên Releases; Remote Config `latest_version` vẫn là `1.0.0` nên chưa máy nào được nhắc cập nhật.
      - Đề nghị: người dùng đi làm vài ngày với bản hiện tại, đọc nhật ký GPS cùng Claude, ổn thì phát hành.
   2. **Tự động sao lưu dữ liệu**: dữ liệu chỉ nằm trong máy, sao lưu Excel phải tự bấm; mất máy hay gỡ app là mất hết. Đề xuất app tự lưu một bản sao mỗi tuần hoặc ít nhất nhắc sao lưu.
   3. **Việc dở chờ người dùng quyết**: ý tưởng lấy tăng ca bù giờ thiếu (đã ghi, chưa làm); ba mặc định chờ chốt (ngày nghỉ không lương, thống kê 12 kỳ, hai nút đầu trang chỉ có icon); trợ cấp tính theo ngày công hay trả đủ (cần hỏi công ty).
   4. **Dọn `TIEN-DO.md`**: mục "Việc còn lại" lỗi thời (vẫn ghi ký bằng khóa debug, bản 1.0.0, trong khi đã có khóa phát hành và bản 1.2.x). Ước lượng khoảng 10 phút.
   - Về lâu dài: lên Google Play (cần trang chính sách quyền riêng tư, khai báo Data safety).
   - Claude nghiêng về làm **số 2 (tự sao lưu)** trước, ước lượng khoảng 1 tiếng trên cloud, không đụng phần GPS đang thử; song song người dùng dùng app đi làm để thử số 1. Hỏi người dùng muốn bắt đầu từ việc nào.
2. Người dùng: gõ `/handoff` (chưa trả lời câu hỏi chọn việc).
   Claude: tạo nhánh `claude/handoff-goi-y-cai-tien` từ `master` (`9ffe493`), viết file này, commit và push.

## Quyết định đã chốt

- Chưa có. Người dùng chưa chọn việc nào trong các đề xuất.

## Thay đổi code

- Không có. Chỉ thêm `HANDOFF.md`.

## Lệnh đã chạy / cài đặt / cấu hình quan trọng

- Chỉ đọc file và `git log`. Không chạy `flutter analyze` / `flutter test`, không build, không deploy, không đổi Remote Config.

## Còn dở / bước tiếp theo

- [ ] Hỏi lại người dùng chọn việc nào để bắt đầu (đề xuất của Claude: tự sao lưu dữ liệu).
- [ ] Nếu làm tự sao lưu: thảo luận với người dùng trước (lưu ở đâu trong máy, bao lâu một lần, giữ mấy bản, có nhắc không) rồi mới sửa code. Phần sao lưu Excel hiện có xem mục "Sao lưu dữ liệu ra file Excel" trong `TIEN-DO.md`.
- [ ] Nếu dọn `TIEN-DO.md`: sửa mục "Việc còn lại" cho khớp hiện trạng (khóa phát hành đã có, bản 1.2.x, những gì đã/chưa commit).
- [ ] Lưu ý theo `TIEN-DO.md`: các thay đổi GPS 1.2.1–1.2.3 và còi báo giờ ghi là "chưa commit" ở thời điểm viết, nhưng commit `2463f79` trên `master` đã có "GPS theo mốc, Wi-Fi quen, nhật ký, đo vị trí, còi báo giờ". Nên kiểm tra lại trên PC xem còn gì chưa commit không.

## Ý tưởng chưa làm, câu hỏi còn mở

- Lấy tăng ca bù giờ thiếu (commit `416a622`, chỉ ghi ý tưởng).
- Ba mặc định chờ chốt (mục "Mặc định Claude tự chọn, chờ người dùng xác nhận" trong `TIEN-DO.md`).
- Trợ cấp tính theo ngày công hay trả đủ.
- Lên Google Play; thông báo đẩy, Firebase App Check (chưa có).
