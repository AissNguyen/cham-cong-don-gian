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
  IncomeCalcMethod.manual => 'Nhập tay mỗi kỳ',
};

/// Khoản thu nhập/khấu trừ tự tạo (phụ cấp, thưởng, tạm ứng...). Cộng/trừ vào tổng thu nhập mỗi kỳ.
class IncomeItemsSection extends StatelessWidget {
  const IncomeItemsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {IncomeItem? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    var type = editing?.type ?? IncomeItemType.income;
    var calc = editing?.calcMethod ?? IncomeCalcMethod.fixed;
    final amountCtrl = TextEditingController(text: (editing?.amount ?? 0).round().toString());

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
                if (calc != IncomeCalcMethod.manual) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: calc == IncomeCalcMethod.perWorkDay ? 'Số tiền mỗi ngày công (đ)' : 'Số tiền (đ)',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Số tiền sẽ nhập riêng cho từng kỳ ở cuối màn chính (mục Thống kê thu nhập theo kỳ).',
                      style: TextStyle(fontSize: 12.5),
                    ),
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
                            amount: calc == IncomeCalcMethod.manual ? 0 : amount,
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

  @override
  Widget build(BuildContext context) {
    final items = store.settings.incomeItems;
    return SettingsCard(
      title: 'Khoản thu nhập / khấu trừ khác',
      subtitle: 'Phụ cấp, thưởng, tạm ứng... cộng/trừ vào tổng thu nhập mỗi kỳ.',
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
                _calcLabel(item.calcMethod) +
                    (item.calcMethod == IncomeCalcMethod.manual ? '' : ' · ${fmtMoney(item.amount)}'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: item),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm khoản'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }
}
