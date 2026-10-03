import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/calc.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../format.dart';
import '../../theme/app_theme.dart';

/// Thống kê thu nhập từng kỳ lương đã qua, mỗi kỳ nhập tay được số tiền thực nhận (ghi đè số tự tính).
class PeriodHistorySection extends StatelessWidget {
  const PeriodHistorySection({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final periods = recentPeriods(today, store.settings.payPeriod, count: 12);

    final rows = periods.map((p) {
      final records = store.records.values.where((r) => p.contains(r.date));
      final stats = computePeriodStats(p, records, store.settings);
      final override = store.periodOverrides[p.key];
      return (period: p, stats: stats, amount: override ?? stats.totalIncome, isOverridden: override != null);
    }).toList();

    final total = rows.fold<double>(0, (sum, r) => sum + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng ${periods.length} kỳ gần đây: ${fmtMoney(total)}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 12),
        for (final row in rows)
          _PeriodRow(
            key: ValueKey(row.period.key),
            period: row.period,
            stats: row.stats,
            amount: row.amount,
            isOverridden: row.isOverridden,
            onChanged: (value) => store.setPeriodOverride(row.period.key, value),
          ),
      ],
    );
  }
}

class _PeriodRow extends StatefulWidget {
  const _PeriodRow({
    super.key,
    required this.period,
    required this.stats,
    required this.amount,
    required this.isOverridden,
    required this.onChanged,
  });

  final PayPeriod period;
  final PeriodStats stats;
  final double amount;
  final bool isOverridden;
  final ValueChanged<double?> onChanged;

  @override
  State<_PeriodRow> createState() => _PeriodRowState();
}

class _PeriodRowState extends State<_PeriodRow> {
  late final TextEditingController controller;
  late final FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.amount.round().toString());
    focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _PeriodRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focusNode.hasFocus && oldWidget.amount != widget.amount) {
      controller.text = widget.amount.round().toString();
    }
  }

  void _commit() {
    final digits = controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = double.tryParse(digits) ?? 0;
    controller.text = value.round().toString();
    widget.onChanged(value);
  }

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final p = widget.period;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${fmtDM(p.start)} – ${fmtDM(p.end)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Nghỉ ${widget.stats.daysOff} ngày · Muộn ${widget.stats.daysLate} ngày',
                  style: TextStyle(fontSize: 12, color: colors.ink2),
                ),
              ],
            ),
          ),
          if (widget.isOverridden)
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 18),
              tooltip: 'Bỏ ghi đè, dùng lại số tự tính',
              visualDensity: VisualDensity.compact,
              onPressed: () => widget.onChanged(null),
            ),
          SizedBox(
            width: 130,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _commit(),
              decoration: InputDecoration(
                isDense: true,
                suffixText: ' đ',
                border: const OutlineInputBorder(),
                filled: widget.isOverridden,
                fillColor: widget.isOverridden ? colors.accentSoft : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
