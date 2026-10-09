/// Thẻ "Cài đặt tính công" (theo `mockup/luong-va-cai-dat.html`): một khối gộp kỳ lương, giờ làm,
/// bảng lương/giờ và đi muộn; nút "Sửa" riêng, xem / sửa như phiếu lương.
library;

import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import 'number_inputs.dart';
import 'payslip_card.dart';

class WorkConfigCard extends StatefulWidget {
  const WorkConfigCard({super.key, required this.store});

  final AppStore store;

  @override
  State<WorkConfigCard> createState() => _WorkConfigCardState();
}

class _WorkConfigCardState extends State<WorkConfigCard> {
  bool _editing = false;

  AppStore get store => widget.store;
  AppSettings get settings => store.settings;

  Future<void> _period(PayPeriodConfig Function(PayPeriodConfig) update) =>
      store.updateSettings((s) => s.copyWith(payPeriod: update(s.payPeriod)));

  /// Sửa một ô của bảng lương/giờ. Hàng T2–T7 ghi vào cả ngày thường lẫn thứ 7.
  Future<void> _setRate(List<DayType> types, {required bool overtime, required double value}) =>
      store.updateSettings((s) {
        final rates = Map<DayType, WageRate>.from(s.wageTable.rates);
        for (final t in types) {
          final r = s.wageTable.of(t);
          rates[t] = overtime ? r.copyWith(overtimePerHour: value) : r.copyWith(normalPerHour: value);
        }
        return s.copyWith(wageTable: WageTable(rates: rates));
      });

  Future<void> _pickTime(bool start) async {
    final c = start ? settings.workStart : settings.workEnd;
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: c.hour, minute: c.minute));
    if (picked == null) return;
    final clock = Clock(picked.hour, picked.minute);
    await store.updateSettings((s) => start ? s.copyWith(workStart: clock) : s.copyWith(workEnd: clock));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final worker = settings.workerKind == WorkerKind.worker;
    final cfg = settings.payPeriod;
    final (a, b) = semiMonthlyBounds(cfg);
    final std = settings.standardDays[periodContaining(DateTime.now(), cfg).key] ??
        autoStandardDaysOf(periodContaining(DateTime.now(), cfg)).toDouble();
    final autoHourly = workerAutoHourlyRate(settings, std);
    final valueStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]);
    final unitStyle = TextStyle(fontSize: 13, color: colors.ink2);

    Widget line({required Widget label, required List<Widget> trailing}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
      child: Row(
        children: [
          Expanded(child: DefaultTextStyle.merge(style: TextStyle(fontSize: 14, color: colors.ink2), child: label)),
          ...trailing,
        ],
      ),
    );

    Widget smallNumber(int value, ValueChanged<int> onChanged) => InlineNumberField(
      value: value.toDouble(),
      integerOnly: true,
      width: 52,
      onChanged: (v) {
        if (v >= 1) onChanged(v.round());
      },
    );

    // --- Kỳ lương ---
    final Widget periodLine;
    if (cfg.type == PayPeriodType.monthly) {
      periodLine = line(
        label: const Text('Kỳ lương'),
        trailing: _editing
            ? [
                Text('bắt đầu ngày ', style: unitStyle),
                smallNumber(cfg.monthlyStartDay, (d) => _period((p) => p.copyWith(monthlyStartDay: d.clamp(1, 31)))),
              ]
            : [Text('bắt đầu ngày ${cfg.monthlyStartDay}', style: valueStyle)],
      );
    } else {
      periodLine = line(
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kỳ lương'),
            if (!_editing) Text('2 kỳ một tháng', style: TextStyle(fontSize: 11.5, color: colors.ink3)),
          ],
        ),
        trailing: _editing
            ? [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Kỳ 1 từ ', style: unitStyle),
                        smallNumber(a, (d) => _period((p) => p.copyWith(semiFirstStart: d.clamp(1, 28)))),
                        Text(' đến ', style: unitStyle),
                        smallNumber(b, (d) => _period((p) => p.copyWith(semiFirstEnd: d.clamp(1, 28)))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: unitStyle,
                        children: [
                          const TextSpan(text: 'Kỳ 2 từ '),
                          TextSpan(text: '${b + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' đến '),
                          const TextSpan(text: 'trước ngày đầu kỳ 1', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ]
            : [Text('$a–$b · ${b + 1}–trước kỳ 1', style: valueStyle)],
      );
    }

    // --- Giờ làm ---
    Widget timeButton(bool start) => OutlinedButton(
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 12)),
      onPressed: () => _pickTime(start),
      child: Text((start ? settings.workStart : settings.workEnd).formatted),
    );
    final hoursLine = line(
      label: const Text('Giờ làm'),
      trailing: _editing
          ? [timeButton(true), Text('  –  ', style: unitStyle), timeButton(false)]
          : [Text('${settings.workStart.formatted} – ${settings.workEnd.formatted}', style: valueStyle)],
    );

    // --- Bảng lương/giờ ---
    Widget cell(List<DayType> types, {required bool overtime}) {
      final type = types.first;
      if (worker && type == DayType.weekday && !overtime) {
        return Text(fmtMoney(autoHourly, unit: false), style: valueStyle.copyWith(color: colors.ink2));
      }
      final value = tableRate(settings, type, overtime: overtime);
      if (!_editing) return Text(fmtMoney(value, unit: false), style: valueStyle);
      return InlineNumberField(
        value: value,
        width: 96,
        onChanged: (v) => _setRate(types, overtime: overtime, value: v),
      );
    }

    final rows = [
      ('T2–T7', [DayType.weekday, DayType.saturday]),
      ('Chủ nhật', [DayType.sunday]),
      ('Ngày lễ', [DayType.holiday]),
    ];
    final headStyle = TextStyle(fontSize: 11.5, color: colors.ink3);
    final wageBlock = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bảng lương/giờ', style: TextStyle(fontSize: 14, color: colors.ink2)),
          const SizedBox(height: 2),
          Text(
            worker
                ? 'Giờ thường T2–T7 tự tính = lương cơ bản ÷ công chuẩn ÷ 8 '
                      '(${fmtMoney(settings.baseSalary * monthFractionOf(cfg), unit: false)} ÷ ${fmtN(std)} ÷ 8 = '
                      '${fmtMoney(autoHourly, unit: false)}), không sửa ở đây.'
                : 'Mọi ô tự điền = lương ngày ÷ 8 (${fmtMoney(settings.dailyWage, unit: false)} ÷ 8 = '
                      '${fmtMoney(settings.dailyWage / 8, unit: false)}). Sửa ô nào thì ô đó giữ số bạn nhập.',
            style: TextStyle(fontSize: 11.5, color: colors.ink3),
          ),
          const SizedBox(height: 4),
          Table(
            columnWidths: const {0: FlexColumnWidth(1), 1: IntrinsicColumnWidth(), 2: IntrinsicColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                    child: Text('Giờ thường', style: headStyle, textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
                    child: Text('Giờ tăng ca', style: headStyle, textAlign: TextAlign.right),
                  ),
                ],
              ),
              for (final (label, types) in rows)
                TableRow(
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, color: colors.ink2)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                      child: Align(alignment: Alignment.centerRight, child: cell(types, overtime: false)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
                      child: Align(alignment: Alignment.centerRight, child: cell(types, overtime: true)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    // --- Đi muộn ---
    final late = settings.lateRule;
    final lateMinutes = late.unit == LateUnit.minutes;
    final lateLine = Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: _editing
          ? Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('Đi muộn', style: TextStyle(fontSize: 14, color: colors.ink2)),
                SegmentedButton<LateUnit>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: LateUnit.minutes, label: Text('Trừ phút')),
                    ButtonSegment(value: LateUnit.money, label: Text('Trừ tiền')),
                  ],
                  selected: {late.unit},
                  onSelectionChanged: (v) => store.updateSettings(
                    (s) => s.copyWith(
                      lateRule: s.lateRule.copyWith(unit: v.first, amount: v.first == LateUnit.minutes ? 30 : 20000),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InlineNumberField(
                      key: ValueKey(late.unit),
                      value: late.amount,
                      integerOnly: lateMinutes,
                      width: lateMinutes ? 64 : 96,
                      onChanged: (v) => store.updateSettings((s) => s.copyWith(lateRule: s.lateRule.copyWith(amount: v))),
                    ),
                    Text(lateMinutes ? '  phút' : '  đ', style: unitStyle),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text('Đi muộn', style: TextStyle(fontSize: 14, color: colors.ink2))),
                Text(lateMinutes ? 'trừ ${fmtN(late.amount)} phút' : 'trừ ${fmtMoney(late.amount)}', style: valueStyle),
              ],
            ),
    );

    return TitledCard(
      title: 'Cài đặt tính công',
      trailing: EditToggleButton(editing: _editing, onPressed: () => setState(() => _editing = !_editing)),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(children: [periodLine, hoursLine, wageBlock, lateLine]),
      ),
    );
  }
}
