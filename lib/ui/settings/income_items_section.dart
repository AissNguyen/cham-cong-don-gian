import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../format.dart';
import 'settings_card.dart';

const _uuid = Uuid();

String _calcLabel(IncomeCalcMethod m) => switch (m) {
  IncomeCalcMethod.fixed => 'Cố định mỗi kỳ',
  IncomeCalcMethod.perWorkDay => '× số ngày công',
  IncomeCalcMethod.percentOfBaseSalary => '% lương cơ bản',
};

/// Khoản thu nhập/khấu trừ tự tạo (phụ cấp, thưởng, bảo hiểm...). Cộng/trừ vào tổng thu nhập mỗi
/// kỳ khi bật "Cộng thêm vào số ước tính" ở cuối mục này.
class IncomeItemsSection extends StatelessWidget {
  const IncomeItemsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {IncomeItem? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    var type = editing?.type ?? IncomeItemType.income;
    var calc = editing?.calcMethod ?? IncomeCalcMethod.fixed;
    final amountCtrl = TextEditingController(text: (editing?.amount ?? 0).round().toString());
    var activeAfter = editing?.activeAfter;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
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
                Text(editing != null ? 'Sửa khoản' : 'Khoản mới', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên khoản', border: OutlineInputBorder())),
                const SizedBox(height: 14),
                const Text('Loại', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SegmentedButton<IncomeItemType>(
                  segments: const [
                    ButtonSegment(value: IncomeItemType.income, label: Text('Thu nhập')),
                    ButtonSegment(value: IncomeItemType.deduction, label: Text('Khấu trừ')),
                  ],
                  selected: {type},
                  onSelectionChanged: (v) => setState(() => type = v.first),
                ),
                const SizedBox(height: 14),
                const Text('Cách tính', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: IncomeCalcMethod.values
                      .map(
                        (m) => ChoiceChip(
                          label: Text(_calcLabel(m)),
                          selected: calc == m,
                          onSelected: (_) => setState(() => calc = m),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: switch (calc) {
                      IncomeCalcMethod.perWorkDay => 'Số tiền mỗi ngày công (đ)',
                      IncomeCalcMethod.percentOfBaseSalary => 'Phần trăm lương cơ bản (%)',
                      IncomeCalcMethod.fixed => 'Số tiền (đ)',
                    },
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Chỉ tính từ giờ... (ví dụ tiền cơm trưa sau 13:00)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (activeAfter != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Bỏ mốc giờ',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => activeAfter = null),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(activeAfter?.formatted ?? 'Chưa đặt'),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: activeAfter?.hour ?? 13, minute: activeAfter?.minute ?? 0),
                        );
                        if (picked != null) setState(() => activeAfter = Clock(picked.hour, picked.minute));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Chỉ ảnh hưởng tới số tiền chạy sống trong ngày trên màn chính — không đổi tổng chính thức của cả kỳ.',
                  style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (editing != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            store.updateSettings(
                              (s) => s.copyWith(incomeItems: s.incomeItems.where((i) => i.id != editing.id).toList()),
                            );
                            Navigator.pop(context);
                          },
                          child: const Text('Xóa'),
                        ),
                      ),
                    if (editing != null) const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final amount = double.tryParse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          final item = IncomeItem(
                            id: editing?.id ?? _uuid.v4(),
                            name: nameCtrl.text.trim(),
                            type: type,
                            calcMethod: calc,
                            amount: amount,
                            activeAfter: activeAfter,
                          );
                          store.updateSettings((s) {
                            final list = [...s.incomeItems];
                            if (editing != null) {
                              final i = list.indexWhere((e) => e.id == editing.id);
                              if (i >= 0) list[i] = item;
                            } else {
                              list.add(item);
                            }
                            return s.copyWith(incomeItems: list);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Lưu'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Thêm nhanh khoản "Tiền cơm trưa" mẫu — 0đ, chỉ tính sau 13:00 — người dùng tự sửa lại số tiền.
  void _addLunchPreset() {
    store.updateSettings(
      (s) => s.copyWith(
        incomeItems: [
          ...s.incomeItems,
          IncomeItem(
            id: _uuid.v4(),
            name: 'Tiền cơm trưa',
            type: IncomeItemType.income,
            calcMethod: IncomeCalcMethod.fixed,
            amount: 0,
            activeAfter: const Clock(13, 0),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = store.settings.incomeItems;
    return SettingsCard(
      title: 'Khoản thu nhập / khấu trừ khác',
      subtitle: 'Phụ cấp, thưởng, bảo hiểm... cộng/trừ vào tổng thu nhập mỗi kỳ.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.type == IncomeItemType.income ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: item.type == IncomeItemType.income ? Colors.green : Colors.redAccent,
              ),
              title: Text(item.name),
              subtitle: Text(
                '${_calcLabel(item.calcMethod)} · ${item.calcMethod == IncomeCalcMethod.percentOfBaseSalary ? '${fmtN(item.amount)}%' : fmtMoney(item.amount)}'
                '${item.activeAfter != null ? ' · từ ${item.activeAfter!.formatted}' : ''}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: item),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm khoản'),
                onPressed: () => _openForm(context),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.lunch_dining_outlined),
                label: const Text('+ Tiền cơm trưa'),
                onPressed: _addLunchPreset,
              ),
            ],
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Cộng thêm vào số tiền ước tính', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Tắt: số ước tính chỉ theo bảng lương/giờ, các khoản trên chỉ để tham khảo.\n'
              'Bật: cộng/trừ các khoản trên vào cả tổng kỳ lẫn số chạy sống hôm nay.',
              style: TextStyle(fontSize: 11.5),
            ),
            value: store.settings.includeItemsInEstimate,
            onChanged: (v) => store.updateSettings((s) => s.copyWith(includeItemsInEstimate: v)),
          ),
        ],
      ),
    );
  }
}
