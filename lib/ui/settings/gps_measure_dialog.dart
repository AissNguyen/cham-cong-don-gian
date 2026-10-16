/// Bảng "Đo vị trí ngay": người dùng ghi tên chỗ đứng (tùy chọn), bấm Đo, xem cách điểm chấm bao xa, GPS
/// mạnh hay yếu, sai số bao nhiêu. Kết quả được ghi vào nhật ký đo thủ công.
library;

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../gps/gps_manual.dart';

/// Một dòng mô tả lần đo, dùng chung cho bảng đo và màn nhật ký.
String describeManualCheck(ManualGpsCheck c) {
  final sats = c.satellites > 0 ? ' (${c.satellitesUsed}/${c.satellites} vệ tinh)' : '';
  return 'Cách điểm chấm ${c.distance.round()} m · sai số ${c.accuracy.round()} m · GPS ${c.strength}$sats';
}

Future<void> showMeasureDialog(BuildContext context, GpsConfig gps) async {
  final nameCtrl = TextEditingController();
  ManualGpsCheck? result;
  var measuring = false;
  var failed = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Đo vị trí ngay'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Tên chỗ đứng (không bắt buộc)',
                hintText: 'Ví dụ: cổng, kho B',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (measuring) const Row(children: [SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Đang đo, chờ tối đa 30 giây...')]),
            if (failed) const Text('Không dò ra vị trí. Thử ra chỗ thoáng hơn hoặc bật định vị.'),
            if (result != null) ...[
              Text('Cách điểm chấm ${result!.distance.round()} m', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                result!.distance <= gps.departRadiusMeters
                    ? 'Trong phạm vi chỗ làm (${gps.departRadiusMeters.round()} m)'
                    : 'Ngoài phạm vi chỗ làm (${gps.departRadiusMeters.round()} m)',
              ),
              Text('Sai số: ${result!.accuracy.round()} m'),
              Text(
                'GPS: ${result!.strength}'
                '${result!.satellites > 0 ? ' · dùng ${result!.satellitesUsed} trên ${result!.satellites} vệ tinh' : ''}',
              ),
              const SizedBox(height: 6),
              const Text('Đã ghi vào nhật ký.', style: TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          FilledButton(
            onPressed: measuring
                ? null
                : () async {
                    setState(() {
                      measuring = true;
                      failed = false;
                      result = null;
                    });
                    final r = await measureNow(gps, name: nameCtrl.text);
                    if (!context.mounted) return;
                    setState(() {
                      measuring = false;
                      result = r;
                      failed = r == null;
                    });
                  },
            child: Text(result == null ? 'Đo' : 'Đo lại'),
          ),
        ],
      ),
    ),
  );
}
