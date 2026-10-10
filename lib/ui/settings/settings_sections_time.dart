import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/lunar.dart' as lunar;
import '../../domain/models.dart';
import '../format.dart';
import 'settings_card.dart';

String _holidayDedupKey(Holiday h) => h.name.isEmpty ? fmtDM(h.date) : h.name;

/// Số ngày lễ sau khi gộp các năm lặp lại, đúng bằng số dòng hiện trong danh sách ngày lễ.
int holidayDisplayCount(List<Holiday> holidays) => holidays.map(_holidayDedupKey).toSet().length;

/// Danh sách ngày lễ tự thêm/xóa, dùng cho cột "Ngày lễ" của bảng lương. Thu gọn mặc định (chỉ
/// hiện số lượng), bấm vào mới xổ ra danh sách — vì cộng cả ngày lễ mặc định lẫn tự thêm có thể
/// khá dài.
class HolidaysSection extends StatefulWidget {
  const HolidaysSection({super.key, required this.store});

  final AppStore store;

  @override
  State<HolidaysSection> createState() => _HolidaysSectionState();
}

class _HolidaysSectionState extends State<HolidaysSection> {
  bool _expanded = false;

  AppStore get store => widget.store;

  Future<void> _addHoliday(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final dayCtrl = TextEditingController();
    final monthCtrl = TextEditingController();
    var isLunar = false;
    final result = await showDialog<(String, int, int, bool)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Thêm ngày lễ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Ví dụ: Quốc khánh, Giỗ tổ nghề'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: dayCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Ngày', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: monthCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tháng', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Dương lịch')),
                    ButtonSegment(value: true, label: Text('Âm lịch')),
                  ],
                  selected: {isLunar},
                  onSelectionChanged: (s) => setState(() => isLunar = s.first),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lặp lại hằng năm theo đúng lịch đã chọn — không cần nhập lại năm sau.',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final day = int.tryParse(dayCtrl.text);
                final month = int.tryParse(monthCtrl.text);
                if (day == null || month == null || day < 1 || day > 31 || month < 1 || month > 12) return;
                Navigator.pop(context, (nameCtrl.text.trim(), day, month, isLunar));
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final (name, day, month, lunarChosen) = result;
    final year = DateTime.now().year;
    Holiday holiday;
    if (lunarChosen) {
      final solar = lunar.lunarToSolar(day, month, year) ?? lunar.lunarToSolar(day, month, year + 1);
      if (solar == null) return; // ngày âm không tồn tại (vd 30 ở tháng âm thiếu) cả 2 năm gần nhất.
      holiday = Holiday(date: solar, name: name, recurrence: HolidayRecurrence.lunarYearly);
    } else {
      holiday = Holiday(date: DateTime(year, month, day), name: name, recurrence: HolidayRecurrence.solarYearly);
    }
    store.updateSettings((s) => s.copyWith(holidays: [...s.holidays, holiday]));
  }

  String _recurrenceBadge(HolidayRecurrence r) => switch (r) {
    HolidayRecurrence.once => '',
    HolidayRecurrence.solarYearly => ' · ↻ dương lịch',
    HolidayRecurrence.lunarYearly => ' · ↻ âm lịch',
  };

  /// Khóa gộp các bản ghi của cùng một ngày lễ lặp lại (mỗi năm tự sinh 1 bản riêng ở dưới) thành
  /// 1 dòng duy nhất để hiện cho người dùng — không ai cần thấy "Quốc khánh" lặp lại 3 lần cho 3
  /// năm tới. Gộp theo tên (ngày nào trùng tên thì coi là cùng 1 ngày lễ lặp lại).
  String _dedupKey(Holiday h) => _holidayDedupKey(h);

  @override
  Widget build(BuildContext context) {
    final all = [...store.settings.holidays]..sort((a, b) => a.date.compareTo(b.date));
    final holidays = <Holiday>[];
    final seenKeys = <String>{};
    for (final h in all) {
      if (seenKeys.add(_dedupKey(h))) holidays.add(h);
    }
    return SettingsCard(
      title: 'Ngày lễ',
      subtitle: 'Những ngày được tính theo hệ số "Ngày lễ" ở bảng lương.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      holidays.isEmpty ? 'Chưa có ngày lễ nào' : '${holidays.length} ngày lễ đã thêm',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in holidays)
                  Chip(
                    label: Text(
                      // Chỉ hiện ngày/tháng, không hiện năm — ngày lễ nào cũng lặp lại mỗi năm,
                      // năm cụ thể không có ý nghĩa gì ở đây.
                      '${h.name.isEmpty ? fmtDM(h.date) : '${h.name} · ${fmtDM(h.date)}'}${_recurrenceBadge(h.recurrence)}',
                    ),
                    // Xóa cả các bản đã tự sinh cho năm khác của cùng ngày lễ này, không chỉ bản
                    // đang hiện — không thì năm sau mở lại app, bản vừa xóa lại tự mọc lại.
                    onDeleted: () => store.updateSettings(
                      (s) => s.copyWith(holidays: s.holidays.where((x) => _dedupKey(x) != _dedupKey(h)).toList()),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm ngày lễ'),
            onPressed: () => _addHoliday(context),
          ),
        ],
      ),
    );
  }
}
