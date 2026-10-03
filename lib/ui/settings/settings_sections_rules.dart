import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import 'settings_card.dart';

TimeOfDay _toTod(Clock c) => TimeOfDay(hour: c.hour, minute: c.minute);
Clock _toClock(TimeOfDay t) => Clock(t.hour, t.minute);

/// Khung cố định: giờ vào nằm trong 1 khoảng VÀ giờ ra nằm trong 1 khoảng khác thì áp dụng số
/// phút cộng/trừ đã cài (ví dụ vào trong khoảng 7:00-8:00, ra trong khoảng 11:00-12:00, trừ 15p).
/// Mỗi khoảng có thể chỉ là 1 giờ duy nhất (nhập từ = đến).
class BreakRulesSection extends StatelessWidget {
  const BreakRulesSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {FixedBreakRule? editing}) async {
    var checkInFrom = editing?.checkInFrom ?? const Clock(7, 0);
    var checkInTo = editing?.checkInTo ?? const Clock(7, 0);
    var checkOutFrom = editing?.checkOutFrom ?? const Clock(12, 0);
    var checkOutTo = editing?.checkOutTo ?? const Clock(12, 0);
    var isSubtract = (editing?.deltaMinutes ?? -15) <= 0;
    var minutes = (editing?.deltaMinutes ?? -15).abs();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Khung cố định'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Giờ vào nằm trong khoảng (nhập 1 giờ nếu không cần khoảng):'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    TimeChip(
                      label: 'Từ',
                      time: _toTod(checkInFrom),
                      onPick: (t) => setState(() => checkInFrom = _toClock(t)),
                    ),
                    TimeChip(
                      label: 'Đến',
                      time: _toTod(checkInTo),
                      onPick: (t) => setState(() => checkInTo = _toClock(t)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Giờ ra nằm trong khoảng:'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    TimeChip(
                      label: 'Từ',
                      time: _toTod(checkOutFrom),
                      onPick: (t) => setState(() => checkOutFrom = _toClock(t)),
                    ),
                    TimeChip(
                      label: 'Đến',
                      time: _toTod(checkOutTo),
                      onPick: (t) => setState(() => checkOutTo = _toClock(t)),
                    ),
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
          ),
          actions: [
            if (editing != null)
              TextButton(
                onPressed: () {
                  store.updateSettings(
                    (s) => s.copyWith(fixedBreakRules: s.fixedBreakRules.where((r) => r != editing).toList()),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final rule = FixedBreakRule(
                  checkInFrom: checkInFrom,
                  checkInTo: checkInTo,
                  checkOutFrom: checkOutFrom,
                  checkOutTo: checkOutTo,
                  deltaMinutes: isSubtract ? -minutes : minutes,
                );
                store.updateSettings((s) {
                  final list = [...s.fixedBreakRules];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = rule;
                  } else {
                    list.add(rule);
                  }
                  return s.copyWith(fixedBreakRules: list);
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

  String _rangeLabel(Clock from, Clock to) => from == to ? from.formatted : '${from.formatted}–${to.formatted}';

  @override
  Widget build(BuildContext context) {
    final rules = store.settings.fixedBreakRules;
    return SettingsCard(
      title: 'Cộng trừ giờ theo giờ vào (khung cố định)',
      subtitle:
          'Giờ vào và giờ ra đều nằm trong khoảng đã cài thì tính theo khung đó. Không khung nào '
          'khớp thì hệ thống chuyển qua tính theo "Khung nhiều mục" ở dưới (kèm cảnh báo đỏ). Ra '
          'muộn hơn giờ ra chuẩn do tăng ca vẫn tính là khớp, không bị đẩy xuống dự phòng.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rules)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('Vào ${_rangeLabel(r.checkInFrom, r.checkInTo)} · Ra ${_rangeLabel(r.checkOutFrom, r.checkOutTo)}'),
              subtitle: Text('${r.deltaMinutes < 0 ? 'Trừ' : 'Cộng'} ${r.deltaMinutes.abs()} phút'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: r),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm khung cố định'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }
}

/// Khung nhiều mục: danh sách các đoạn nối tiếp nhau (từ giờ nào tới giờ nào thì nghỉ mấy phút),
/// dùng làm dự phòng khi không khung cố định nào khớp — cộng dồn các đoạn mà giờ làm có chạm vào.
class BreakSegmentsSection extends StatelessWidget {
  const BreakSegmentsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _openForm(BuildContext context, {BreakSegment? editing}) async {
    // Thêm đoạn mới thì gợi ý nối tiếp ngay sau đoạn cuối cùng đã có, đỡ phải tự gõ lại giờ bắt đầu.
    final segments = store.settings.breakSegments;
    final suggestedFrom = segments.isNotEmpty ? segments.last.to : const Clock(7, 0);
    var from = editing?.from ?? suggestedFrom;
    var to = editing?.to ?? suggestedFrom;
    var breakMinutes = editing?.breakMinutes ?? 15;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Đoạn giờ nghỉ'),
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
                decoration: const InputDecoration(labelText: 'Nghỉ bao nhiêu phút', border: OutlineInputBorder()),
                onChanged: (v) => breakMinutes = int.tryParse(v) ?? 0,
              ),
            ],
          ),
          actions: [
            if (editing != null)
              TextButton(
                onPressed: () {
                  store.updateSettings(
                    (s) => s.copyWith(breakSegments: s.breakSegments.where((r) => r != editing).toList()),
                  );
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final segment = BreakSegment(from: from, to: to, breakMinutes: breakMinutes);
                store.updateSettings((s) {
                  final list = [...s.breakSegments];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = segment;
                  } else {
                    list.add(segment);
                  }
                  return s.copyWith(breakSegments: list);
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
    final segments = store.settings.breakSegments;
    return SettingsCard(
      title: 'Khung nhiều mục (dự phòng)',
      subtitle:
          'Ví dụ 7:00–11:30 nghỉ 15p, 11:30–12:30 nghỉ 30p, 12:30–16:00 nghỉ 15p... Chỉ dùng khi giờ '
          'vào/ra không khớp khung cố định nào ở trên.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seg in segments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('${seg.from.formatted}–${seg.to.formatted}'),
              subtitle: Text('Nghỉ ${seg.breakMinutes} phút'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openForm(context, editing: seg),
            ),
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm đoạn'),
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
