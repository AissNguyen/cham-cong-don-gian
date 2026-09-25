import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../format.dart';

/// Chỉnh giờ vào/ra thực tế: lấy giờ hiện tại, tự sửa bằng số, hoặc xóa.
Future<void> showPunchEditSheet(
  BuildContext context, {
  required AppStore store,
  required DateTime date,
  required bool isCheckIn,
}) async {
  final record = store.recordFor(date);
  final current = isCheckIn ? record.checkIn : record.checkOut;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCheckIn ? 'Chấm vào — ${fmtDM(date)}' : 'Chấm ra — ${fmtDM(date)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                current != null ? 'Đang ghi nhận lúc ${fmtTime(current)}' : 'Chưa chấm',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.schedule),
                label: const Text('Lấy giờ hiện tại'),
                onPressed: () async {
                  final now = DateTime.now();
                  final time = DateTime(date.year, date.month, date.day, now.hour, now.minute);
                  if (isCheckIn) {
                    await store.punchIn(date, time);
                  } else {
                    await store.punchOut(date, time);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              Text('Giờ hay dùng', style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hour in const [6, 7, 8, 9, 12, 13, 17, 18, 22])
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final time = DateTime(date.year, date.month, date.day, hour);
                        if (isCheckIn) {
                          await store.punchIn(date, time);
                        } else {
                          await store.punchOut(date, time);
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text('${hour}h'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Tự sửa giờ'),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: current != null
                        ? TimeOfDay(hour: current.hour, minute: current.minute)
                        : TimeOfDay.now(),
                  );
                  if (picked == null) return;
                  final time = DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
                  if (isCheckIn) {
                    await store.punchIn(date, time);
                  } else {
                    await store.punchOut(date, time);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (current != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Xóa giờ đã chấm'),
                  onPressed: () async {
                    if (isCheckIn) {
                      await store.clearCheckIn(date);
                    } else {
                      await store.clearCheckOut(date);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

const noteSuggestions = ['Đi muộn', 'Đi muộn xin phép', 'Ốm', 'Nghỉ không phép', 'Có phép'];

/// Ghi chú cho một ngày: nội dung tự do + thẻ gợi ý. Không ảnh hưởng đến tính giờ/lương.
Future<void> showNoteSheet(BuildContext context, {required AppStore store, required DateTime date}) async {
  final record = store.recordFor(date);
  final controller = TextEditingController(text: record.note ?? '');
  final tags = {...record.tags};

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 4,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ghi chú — ${fmtDM(date)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: noteSuggestions
                        .map(
                          (tag) => FilterChip(
                            label: Text(tag),
                            selected: tags.contains(tag),
                            onSelected: (v) => setSheetState(() => v ? tags.add(tag) : tags.remove(tag)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 4,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nội dung ghi chú...'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        await store.setNote(date, note: controller.text.trim(), tags: tags.toList());
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Lưu ghi chú'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
