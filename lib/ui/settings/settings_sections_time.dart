import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/lunar.dart' as lunar;
import '../../domain/models.dart';
import '../format.dart';
import 'settings_card.dart';

TimeOfDay _toTod(Clock c) => TimeOfDay(hour: c.hour, minute: c.minute);
Clock _toClock(TimeOfDay t) => Clock(t.hour, t.minute);

/// Khung giờ ra vào chuẩn (một khung duy nhất, áp dụng mọi ngày).
class WorkHoursSection extends StatelessWidget {
  const WorkHoursSection({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final s = store.settings;
    return SettingsCard(
      title: 'Khung giờ ra vào',
      subtitle: 'Giờ chuẩn để tính giờ công và tăng ca.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          TimeChip(
            label: 'Vào',
            time: _toTod(s.workStart),
            onPick: (t) => store.updateSettings((s) => s.copyWith(workStart: _toClock(t))),
          ),
          TimeChip(
            label: 'Ra',
            time: _toTod(s.workEnd),
            onPick: (t) => store.updateSettings((s) => s.copyWith(workEnd: _toClock(t))),
          ),
        ],
      ),
    );
  }
}

/// Bảng lương/giờ: nhập thẳng đ/giờ cho 4 loại ngày x (giờ thường, giờ tăng ca).
class WageTableSection extends StatefulWidget {
  const WageTableSection({super.key, required this.store});

  final AppStore store;

  @override
  State<WageTableSection> createState() => _WageTableSectionState();
}

class _WageTableSectionState extends State<WageTableSection> {
  late Map<DayType, TextEditingController> normalCtrls;
  late Map<DayType, TextEditingController> otCtrls;
  late TextEditingController baseSalaryCtrl;

  // Ô nhập theo đơn vị trăm đồng (450 = 45.000đ) cho gõ nhanh, đỡ dài số.
  static int _toDisplay(double amount) => (amount / 100).round();
  static double _fromDisplay(String text) => (double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) * 100;

  @override
  void initState() {
    super.initState();
    final table = widget.store.settings.wageTable;
    normalCtrls = {
      for (final t in DayType.values) t: TextEditingController(text: _toDisplay(table.of(t).normalPerHour).toString()),
    };
    otCtrls = {
      for (final t in DayType.values)
        t: TextEditingController(text: _toDisplay(table.of(t).overtimePerHour).toString()),
    };
    baseSalaryCtrl = TextEditingController(text: widget.store.settings.baseSalary.round().toString());
  }

  @override
  void dispose() {
    for (final c in normalCtrls.values) c.dispose();
    for (final c in otCtrls.values) c.dispose();
    baseSalaryCtrl.dispose();
    super.dispose();
  }

  void _commit(DayType type) {
    final normal = _fromDisplay(normalCtrls[type]!.text);
    final ot = _fromDisplay(otCtrls[type]!.text);
    widget.store.updateSettings((s) {
      final rates = Map<DayType, WageRate>.from(s.wageTable.rates);
      rates[type] = WageRate(normalPerHour: normal, overtimePerHour: ot);
      return s.copyWith(wageTable: WageTable(rates: rates));
    });
  }

  void _commitBaseSalary() {
    final value = double.tryParse(baseSalaryCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    widget.store.updateSettings((s) => s.copyWith(baseSalary: value));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Bảng lương/giờ',
      subtitle: 'Nhập theo đơn vị trăm đồng cho gọn: gõ 450 nghĩa là 45.000đ/giờ, gõ 375 nghĩa là 37.500đ/giờ.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Table(
            columnWidths: const {0: FixedColumnWidth(76)},
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  for (final t in DayType.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Text(t.label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Thường', style: TextStyle(fontSize: 12))),
                  for (final t in DayType.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: TextField(
                        controller: normalCtrls[t],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                        onChanged: (_) => _commit(t),
                      ),
                    ),
                ],
              ),
              TableRow(
                children: [
                  const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Tăng ca', style: TextStyle(fontSize: 12))),
                  for (final t in DayType.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: TextField(
                        controller: otCtrls[t],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                        onChanged: (_) => _commit(t),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          const Text('Lương cơ bản', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            'Dùng làm mốc cho khoản thu nhập/khấu trừ tính theo % (ví dụ bảo hiểm 10%).',
            style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: baseSalaryCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true, suffixText: ' đ', border: OutlineInputBorder()),
            onChanged: (_) => _commitBaseSalary(),
          ),
        ],
      ),
    );
  }
}

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
  String _dedupKey(Holiday h) => h.name.isEmpty ? fmtDM(h.date) : h.name;

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
