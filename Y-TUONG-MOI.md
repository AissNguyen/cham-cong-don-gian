# Ý tưởng mới: lấy tăng ca bù giờ thiếu

Ghi lại từ buổi trao đổi trên cloud ngày 2026-10-18. **Chưa sửa code.** Chỉ sửa khi người dùng nói "sửa code".

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

## Câu hỏi còn mở

Bên dưới mỗi câu là đề xuất của Claude, người dùng chưa trả lời.

1. ~~Lấy tăng ca từ đâu để bù?~~ **Đã chốt:** lấy từ tổng giờ tăng ca.
   - Chưa rõ "tổng" là tổng **trong kỳ lương** hay tổng **mọi thời gian**. Đề xuất: trong kỳ lương, không chuyển sang kỳ sau; tăng ca không đủ bù thì phần thiếu chịu như hiện nay.
2. **Ngày nghỉ nào phải bù, mỗi ngày bao nhiêu?** Đề xuất:
   - Nghỉ không lương và ngày công ty cho nghỉ (không trả lương): bù 8 tiếng mỗi ngày.
   - Nghỉ có lương: không bù, vì đã được trả lương.
   - Chủ nhật và ngày lễ: không bù.
3. **Đi muộn:** hiện app trừ theo luật đi muộn đã cài (trừ phút hoặc trừ tiền). Đề xuất: khi bật bù thì bỏ luật này và lấy tăng ca bù đúng số giờ đã thiếu, để không bị trừ hai lần.
4. **Một ngày đủ công là 7 hay 8 tiếng?** Khung 8h–16h, nếu trừ 1 tiếng nghỉ trưa thì chỉ còn 7 tiếng. Cần hỏi công ty tính nghỉ trưa có được tính công không. Đề xuất: app tự tính mốc này từ giờ làm đã cài, không cố định số 8.
5. **1 giờ tăng ca bù 1 giờ thường**, tính theo giờ chứ không theo tiền? Đề xuất: ưu tiên lấy tăng ca ngày thường bù trước, vì tăng ca ngày lễ và Chủ nhật lương cao hơn.
6. **"Công ty yêu cầu làm vào lúc 8h, 13h" nghĩa là gì?** Có phải những ngày làm nửa buổi (vào lúc 13h) và ngày đó cũng phải bù?

## Chỗ code liên quan (cho Claude trên PC)

- Tính giờ thường và tăng ca của một ngày: `computeDay` và `liveDayHours` trong `lib/domain/calc.dart`. Hiện tăng ca tính từ giờ ra của khung (`workEnd`), có khung tăng ca và luật đi muộn.
- Tính lương theo kỳ, ngày nghỉ có lương và không lương: `lib/domain/payslip.dart`. Việc bù theo kỳ nên đặt ở đây, vì cần nhìn cả kỳ.
- Cài đặt tăng ca: `lib/ui/settings/`. Thống kê: `lib/ui/home/`.
- Nhớ viết test ở `test/domain`.
