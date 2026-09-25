import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import 'settings_card.dart';

TimeOfDay _toTod(Clock c) => TimeOfDay(hour: c.hour, minute: c.minute);
Clock _toClock(TimeOfDay t) => Clock(t.hour, t.minute);

/// Cộng/trừ phút theo khung giờ vào (ví dụ vào 07:00-08:59 trừ 15 phút giải lao).
class BreakRulesSection extends StatelessWidget {
  const BreakRulesSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {BreakRule? editing}) async {
    var from = editing?.from ?? const Clock(7, 0);
    var to = editing?.to ?? const Clock(8, 59);
    var isSubtract = (editing?.deltaMinutes ?? -15) <= 0;
    var minutes = (editing?.deltaMinutes ?? -15).abs();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Quy tắc cộng/trừ giờ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Vào lúc từ giờ nào đến giờ nào:'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TimeChip(label: 'Từ', time: _toTod(from), onPick: (t) => setState(() => from = _toClock(t))),
                  TimeChip(label: 'Đến', time: _toTod(to), onPick: (t) => setState(() => to = _toClock(t))),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Trừ')),
                  ButtonSegment(value: false, label: Text('Cộng')),
                ],
                selected: {isSubtract},
                onSelectionChanged: (v) => setState(() => isSubtract = v.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: minutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Số phút', border: OutlineInputBorder()),
                onChanged: (v) => minutes = int.tryParse(v) ?? 0,
              ),
            ],
          ),
          actions: [
            if (editing != null)
              TextButton(
                onPressed: () {
                  store.updateSettings(
                    (s) => s.copyWith(breakRules: s.breakRules.where((r) => r != editing).toList()),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final rule = BreakRule(from: from, to: to, deltaMinutes: isSubtract ? -minutes : minutes);
                store.updateSettings((s) {
                  final list = [...s.breakRules];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = rule;
                  } else {
                    list.add(rule);
                  }
                  return s.copyWith(breakRules: list);
                });
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = store.settings.breakRules;
    return SettingsCard(
      title: 'Cộng trừ giờ theo giờ vào',
      subtitle: 'Ví dụ vào 7:00–11:30 thì trừ 15 phút giải lao, vào 9:00–12:00 thì không trừ.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('Vào ${r.from.formatted}–${r.to.formatted}'),
              subtitle: Text('${r.deltaMinutes < 0 ? 'Trừ' : 'Cộng'} ${r.deltaMinutes.abs()} phút'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: r),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm quy tắc'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }
}

/// Đi muộn: vào sau giờ nào thì đánh dấu, trừ bao nhiêu phút hoặc tiền khi có đánh dấu.
class LateRuleSection extends StatelessWidget {
  const LateRuleSection({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final rule = store.settings.lateRule;
    return SettingsCard(
      title: 'Đi muộn',
      subtitle: 'Số phút/tiền bị trừ được cài ở đây; ở màn chính chỉ cần bấm nút đánh dấu đi muộn.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TimeChip(
            label: 'Vào sau',
            time: _toTod(rule.after),
            onPick: (t) => store.updateSettings((s) => s.copyWith(lateRule: s.lateRule.copyWith(after: _toClock(t)))),
          ),
          const SizedBox(height: 12),
          SegmentedButton<LateUnit>(
            segments: const [
              ButtonSegment(value: LateUnit.minutes, label: Text('Trừ phút')),
              ButtonSegment(value: LateUnit.money, label: Text('Trừ tiền')),
            ],
            selected: {rule.unit},
            onSelectionChanged: (v) => store.updateSettings((s) => s.copyWith(lateRule: s.lateRule.copyWith(unit: v.first))),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(rule.unit),
            initialValue: rule.amount.round().toString(),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: rule.unit == LateUnit.minutes ? 'Số phút bị trừ' : 'Số tiền bị trừ (đ)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              final amount = double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? rule.amount;
              store.updateSettings((s) => s.copyWith(lateRule: s.lateRule.copyWith(amount: amount)));
            },
          ),
        ],
      ),
    );
  }
}

/// Khung giờ tăng ca: mỗi khung trừ số phút nghỉ riêng, hệ số lấy theo bảng lương.
class OvertimeBracketsSection extends StatelessWidget {
  const OvertimeBracketsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {OvertimeBracket? editing}) async {
    var from = editing?.from ?? const Clock(17, 0);
    var to = editing?.to ?? const Clock(22, 0);
    var breakMinutes = editing?.breakMinutes ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Khung giờ tăng ca'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TimeChip(label: 'Từ', time: _toTod(from), onPick: (t) => setState(() => from = _toClock(t))),
                  TimeChip(label: 'Đến', time: _toTod(to), onPick: (t) => setState(() => to = _toClock(t))),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: breakMinutes.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Trừ bao nhiêu phút nghỉ', border: OutlineInputBorder()),
                onChanged: (v) => breakMinutes = int.tryParse(v) ?? 0,
              ),
            ],
          ),
          actions: [
            if (editing != null)
              TextButton(
                onPressed: () {
                  store.updateSettings(
                    (s) => s.copyWith(overtimeBrackets: s.overtimeBrackets.where((b) => b != editing).toList()),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final bracket = OvertimeBracket(from: from, to: to, breakMinutes: breakMinutes);
                store.updateSettings((s) {
                  final list = [...s.overtimeBrackets];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = bracket;
                  } else {
                    list.add(bracket);
                  }
                  return s.copyWith(overtimeBrackets: list);
                });
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brackets = store.settings.overtimeBrackets;
    return SettingsCard(
      title: 'Tăng ca theo khung',
      subtitle: 'Không có hệ số riêng — hệ số tăng ca lấy theo bảng lương/giờ ở trên.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in brackets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${b.from.formatted}–${b.to.formatted}'),
              subtitle: Text('Trừ nghỉ ${b.breakMinutes} phút'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: b),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm khung'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }
}
