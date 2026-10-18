---
name: handoff
description: Ghi lại toàn bộ nội dung phiên hiện tại vào HANDOFF.md, commit và push lên GitHub để phiên khác (PC hoặc cloud) đọc và làm tiếp. Chỉ chạy khi người dùng gõ /handoff.
disable-model-invocation: true
---

# /handoff — chuyển phiên sang nơi khác qua GitHub

Người dùng sắp rời phiên này (cloud → PC hoặc PC → cloud). Mục tiêu: phiên khác chỉ cần đọc HANDOFF.md là nắm được toàn bộ những gì đã diễn ra, như thể đã ngồi trong phiên này.

## Bước 1 — Xác định repo
- Chạy `git rev-parse --show-toplevel` và `git branch --show-current`.
- Nếu thư mục hiện tại không phải git repo: hỏi người dùng repo nào, dừng lại.

## Bước 2 — Viết HANDOFF.md ở thư mục gốc repo
KHÔNG tóm tắt. Ghi đầy đủ, theo đúng thứ tự thời gian, đủ chi tiết để người khác dựng lại được mạch suy nghĩ. Ghi đè file cũ (lịch sử đã có trong git).

Cấu trúc:

```markdown
# HANDOFF — <ngày giờ> — <nơi ghi: cloud / PC>

Branch: <tên branch>   Repo: <tên repo>

## Mục tiêu của phiên
<người dùng muốn làm gì, bằng lời của họ>

## Diễn biến (theo thứ tự)
1. Người dùng: <ý/yêu cầu, giữ nguyên cách diễn đạt càng sát càng tốt>
   Claude: <đã làm gì, kết quả, lý do>
2. ...

## Quyết định đã chốt
- <quyết định> — vì <lý do>

## Thay đổi code
- `đường/dẫn/file` — <thay đổi gì, vì sao>

## Lệnh đã chạy / cài đặt / cấu hình quan trọng

## Còn dở / bước tiếp theo
- [ ] <việc cụ thể, đủ để phiên sau bắt tay làm ngay>

## Ý tưởng chưa làm, câu hỏi còn mở
```

Nếu phần đầu phiên đã bị nén (chỉ còn bản tóm tắt), ghi rõ: "Phần đầu phiên chỉ còn bản tóm tắt" rồi ghi những gì còn biết.

## Bước 3 — Commit
- `git status` để xem các thay đổi.
- KHÔNG commit file bí mật (.env, key, token, credentials). Nếu thấy, bỏ ra và báo người dùng.
- `git add` HANDOFF.md và các file code đã sửa trong phiên.
- Commit với message: `handoff: <mô tả ngắn việc đang làm>`.

## Bước 4 — Push
- `git push -u origin <branch hiện tại>`.
- Nếu push lỗi (conflict, chưa có quyền): báo rõ lỗi, không force push.

## Bước 5 — Báo lại (ngắn)
- Branch đã push.
- Nhắc người dùng: sang phiên kia gõ `/resume-work` (hoặc `/teleport` nếu đang ngồi ở PC và đi từ cloud về).
