import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/store.dart';
import '../../domain/calc.dart';
import '../format.dart';

/// Giờ gõ bằng bàn phím số: "9" là 9h, "0730" (hoặc "730") là 7h30, "1630" là 16h30. Trả về (giờ,
/// phút), sai thì null. [maxHour]: giờ lớn nhất được nhận (23 với giờ vào/ra, 24 với số giờ làm).
(int, int)? parseHourDigits(String text, {int maxHour = 23}) {
  final t = text.trim();
  if (t.isEmpty || !RegExp(r'^\d{1,4}$').hasMatch(t)) return null;
  final h = t.length <= 2 ? int.parse(t) : int.parse(t.substring(0, t.length - 2));
  final m = t.length <= 2 ? 0 : int.parse(t.substring(t.length - 2));
  if (h > maxHour || m > 59 || (h == maxHour && maxHour == 24 && m > 0)) return null;
  return (h, m);
}

/// "07:30" thành "0730" để điền sẵn vào ô.
String _digits(DateTime? t) => t == null ? '' : '${p2(t.hour)}${p2(t.minute)}';

/// Số phút thành chữ số kiểu "0730" (để trống nếu null).
String _minutesDigits(int? minutes) => minutes == null ? '' : '${p2(minutes ~/ 60)}${p2(minutes % 60)}';

/// Một nút "Vào/Ra": nhập giờ vào, giờ ra bằng bàn phím số; bên dưới sửa tay giờ công / giờ tăng ca
/// của ngày (để trống thì app tự tính từ giờ vào/ra).
Future<void> showPunchDialog(BuildContext context, {required AppStore store, required DateTime date}) async {
  final record = store.recordFor(date);
  final auto = computeDay(record.copyWith(clearManualHours: true), store.settings);
  final inCtl = TextEditingController(text: _digits(record.checkIn));
  final outCtl = TextEditingController(text: _digits(record.checkOut));
  final normalCtl = TextEditingController(text: _minutesDigits(record.manualNormalMinutes));
  final overtimeCtl = TextEditingController(text: _minutesDigits(record.manualOvertimeMinutes));
  String? error;

  Widget field(String label, TextEditingController c, {String? hint, Key? key, VoidCallback? onNow}) => TextField(
    key: key,
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      suffixIcon: onNow == null
          ? null
          : IconButton(icon: const Icon(Icons.schedule, size: 20), tooltip: 'Giờ hiện tại', onPressed: onNow),
    ),
  );

  void now(TextEditingController c) {
    final t = DateTime.now();
    c.text = '${p2(t.hour)}${p2(t.minute)}';
  }

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> save() async {
          final inText = inCtl.text.trim();
          final outText = outCtl.text.trim();
          final cin = parseHourDigits(inText);
          final cout = parseHourDigits(outText);
          final normal = parseHourDigits(normalCtl.text, maxHour: 24);
          final overtime = parseHourDigits(overtimeCtl.text, maxHour: 24);
          if ((inText.isNotEmpty && cin == null) ||
              (outText.isNotEmpty && cout == null) ||
              (normalCtl.text.trim().isNotEmpty && normal == null) ||
              (overtimeCtl.text.trim().isNotEmpty && overtime == null)) {
            setState(() => error = 'Giờ chưa đúng. Ví dụ 7h30 ghi 0730, 9h ghi 9.');
            return;
          }
          if (outText.isNotEmpty && inText.isEmpty) {
            setState(() => error = 'Nhập giờ vào trước rồi mới nhập giờ ra.');
            return;
          }
          DateTime at((int, int) hm) => DateTime(date.year, date.month, date.day, hm.$1, hm.$2);
          if (cin == null) {
            if (record.checkIn != null) await store.clearCheckIn(date);
          } else {
            await store.punchIn(date, at(cin));
            if (cout == null) {
              if (record.checkOut != null) await store.clearCheckOut(date);
            } else {
              await store.punchOut(date, at(cout));
            }
          }
          if (normal == null && overtime == null) {
            if (record.hasManualHours) await store.setManualHours(date);
          } else {
            await store.setManualHours(
              date,
              normalMinutes: normal == null ? null : normal.$1 * 60 + normal.$2,
              overtimeMinutes: overtime == null ? null : overtime.$1 * 60 + overtime.$2,
            );
          }
          if (context.mounted) Navigator.pop(context);
        }

        final ink = Theme.of(context).colorScheme.onSurfaceVariant;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Giờ vào/ra — ${fmtDM(date)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Gõ số: 7h30 ghi 0730, 9h ghi 9, 16h30 ghi 1630.', style: TextStyle(fontSize: 12.5, color: ink)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: field('Giờ vào', inCtl, key: const ValueKey('punch-in'), onNow: () => now(inCtl)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field('Giờ ra', outCtl, key: const ValueKey('punch-out'), onNow: () => now(outCtl)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Sửa giờ công, giờ tăng ca', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Để trống thì app tự tính (giờ công ${fmtHours(auto.normalMinutes)}, '
                  'tăng ca ${fmtHours(auto.overtimeMinutes)}).',
                  style: TextStyle(fontSize: 12.5, color: ink),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: field('Giờ công', normalCtl, key: const ValueKey('manual-normal'), hint: 'vd 8')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: field('Giờ tăng ca', overtimeCtl, key: const ValueKey('manual-overtime'), hint: 'vd 0230'),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (record.checkIn != null || record.hasManualHours)
                      TextButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Xóa hết'),
                        onPressed: () async {
                          await store.clearCheckIn(date);
                          if (record.hasManualHours) await store.setManualHours(date);
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                    const Spacer(),
                    FilledButton(key: const ValueKey('punch-save'), onPressed: save, child: const Text('Lưu')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
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
