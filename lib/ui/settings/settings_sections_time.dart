import 'package:flutter/material.dart';

import '../../data/store.dart';
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
  }

  @override
  void dispose() {
    for (final c in normalCtrls.values) c.dispose();
    for (final c in otCtrls.values) c.dispose();
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

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: 'Bảng lương/giờ',
      subtitle: 'Nhập theo đơn vị trăm đồng cho gọn: gõ 450 nghĩa là 45.000đ/giờ, gõ 375 nghĩa là 37.500đ/giờ.',
      child: Table(
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
    );
  }
}

/// Danh sách ngày lễ tự thêm/xóa, dùng cho cột "Ngày lễ" của bảng lương.
class HolidaysSection extends StatelessWidget {
  const HolidaysSection({super.key, required this.store});

  final AppStore store;

  Future<void> _addHoliday(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null || !context.mounted) return;
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tên ngày lễ ${fmtDMY(picked)}'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ví dụ: Quốc khánh'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, nameCtrl.text.trim()), child: const Text('Thêm')),
        ],
      ),
    );
    if (name == null) return;
    final holiday = Holiday(date: dateOnly(picked), name: name);
    store.updateSettings((s) => s.copyWith(holidays: [...s.holidays, holiday]));
  }

  @override
  Widget build(BuildContext context) {
    final holidays = [...store.settings.holidays]..sort((a, b) => a.date.compareTo(b.date));
    return SettingsCard(
      title: 'Ngày lễ',
      subtitle: 'Những ngày được tính theo hệ số "Ngày lễ" ở bảng lương.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (holidays.isEmpty) Text('Chưa có ngày lễ nào.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in holidays)
                Chip(
                  label: Text(h.name.isEmpty ? fmtDMY(h.date) : '${h.name} · ${fmtDMY(h.date)}'),
                  onDeleted: () =>
                      store.updateSettings((s) => s.copyWith(holidays: s.holidays.where((x) => x != h).toList())),
                ),
            ],
          ),
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
