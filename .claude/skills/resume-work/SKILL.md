---
name: resume-work
description: Kéo code mới nhất từ GitHub, mở branch có HANDOFF.md, đọc HANDOFF.md và CLAUDE.md rồi tiếp tục công việc từ phiên trước. Chỉ chạy khi người dùng gõ /resume-work.
disable-model-invocation: true
argument-hint: "[tên branch] (tùy chọn)"
---

# /resume-work — tiếp tục công việc từ phiên khác

Phiên trước (cloud hoặc PC) đã chạy /handoff: ghi HANDOFF.md, commit, push. Giờ nhận lại và làm tiếp.

Branch người dùng chỉ định (nếu có): $ARGUMENTS

## Bước 1 — Xác định repo
- `git rev-parse --show-toplevel`. Nếu không phải git repo: hỏi người dùng repo nào (đường dẫn trên máy), `cd` vào đó.

## Bước 2 — Kiểm tra thay đổi chưa commit
- `git status`. Nếu có thay đổi chưa commit: liệt kê và HỎI người dùng (commit / stash / bỏ qua) trước khi đổi branch. Không tự ý xóa.

## Bước 3 — Lấy code mới
- `git fetch --all --prune`.
- Chọn branch:
  - Có tên branch trong tham số → dùng branch đó.
  - Không có → tìm branch có HANDOFF.md mới nhất: `git log --all -1 --format="%D %ci" -- HANDOFF.md`. Báo người dùng branch tìm được.
- `git checkout <branch>` rồi `git pull`.
- Nếu người dùng yêu cầu merge vào branch khác: merge, gặp conflict thì dừng và báo, không tự giải quyết bừa.

## Bước 4 — Đọc lại
- Đọc toàn bộ HANDOFF.md.
- Đọc CLAUDE.md (nếu có) và các file .md được nhắc trong HANDOFF.md.
- Xem nhanh các file code được liệt kê trong mục "Thay đổi code".

## Bước 5 — Báo lại và hỏi
Trả lời ngắn:
- Đang ở branch nào, commit mới nhất.
- 3–5 dòng: phiên trước làm gì, đang dở chỗ nào.
- Danh sách "Còn dở / bước tiếp theo".
- Hỏi: "Làm tiếp việc đầu tiên luôn không?"
