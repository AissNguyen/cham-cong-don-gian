/// Hộp sửa tay giờ công / giờ tăng ca của một ngày (thay cho số app tự tính từ giờ vào/ra).
library;

import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/calc.dart';
import '../format.dart';

/// "8", "7,5", "7.5", "7h30", "7:30" thành số phút; ô trống hoặc sai thì null.
int? parseHoursText(String text) {
  final t = text.trim().toLowerCase();
  if (t.isEmpty) return null;
  final hm = RegExp(r'^(\d+)\s*[h:]\s*(\d{0,2})$').firstMatch(t);
  if (hm != null) {
    final m = hm.group(2)!.isEmpty ? 0 : int.parse(hm.group(2)!);
    return m < 60 ? int.parse(hm.group(1)!) * 60 + m : null;
  }
  final v = double.tryParse(t.replaceAll(',', '.'));
  return v == null || v < 0 ? null : (v * 60).round();
}

Future<void> showDayHoursDialog(BuildContext context, {required AppStore store, required DateTime date}) {
  final record = store.recordFor(date);
  final now = computeDay(record, store.settings);
  final normal = TextEditingController(text: fmtHours(now.normalMinutes));
  final overtime = TextEditingController(text: fmtHours(now.overtimeMinutes));
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Sửa giờ · ${fmtDayLong(date)}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.hasManualHours
                ? 'Ngày này đang dùng số bạn sửa tay.'
                : 'Nhập số giờ công ty tính cho ngày này, ví dụ 8 hoặc 7h30.',
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('manual-normal'),
            controller: normal,
            decoration: const InputDecoration(labelText: 'Giờ công', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('manual-overtime'),
            controller: overtime,
            decoration: const InputDecoration(labelText: 'Giờ tăng ca', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        if (record.hasManualHours)
          TextButton(
            onPressed: () {
              store.setManualHours(date);
              Navigator.pop(context);
            },
            child: const Text('Dùng số tự tính'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            store.setManualHours(
              date,
              normalMinutes: parseHoursText(normal.text) ?? 0,
              overtimeMinutes: parseHoursText(overtime.text) ?? 0,
            );
            Navigator.pop(context);
          },
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
}
