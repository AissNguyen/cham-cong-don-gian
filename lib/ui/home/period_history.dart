import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../format.dart';
import '../settings/number_inputs.dart';
import '../../theme/app_theme.dart';

/// Thống kê thu nhập từng kỳ lương (Thực nhận của phiếu lương), mỗi kỳ nhập tay được số tiền thực
/// nhận (ghi đè số tự tính).
class PeriodHistorySection extends StatelessWidget {
  const PeriodHistorySection({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periods = recentPeriods(dateOnly(now), store.settings.payPeriod, count: 12);

    // Số tự tính là Thực nhận của phiếu lương từng kỳ; người dùng vẫn nhập tay được số thật nhận.
    final rows = periods.map((p) {
      final slip = computePayslip(settings: store.settings, period: p, recordOf: store.recordFor, now: now);
      final override = store.periodOverrides[p.key];
      return (period: p, stats: slip, amount: override ?? slip.net, isOverridden: override != null);
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
  final Payslip stats;
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
    controller = TextEditingController(text: _text(widget.amount));
    focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant _PeriodRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!focusNode.hasFocus && oldWidget.amount != widget.amount) {
      controller.text = _text(widget.amount);
    }
  }

  /// "2.363.293": có dấu chấm ngăn hàng nghìn, bỏ phần lẻ.
  String _text(double amount) => fmtMoney(amount, unit: false);

  void _commit() {
    final value = parseMoney(controller.text);
    controller.text = _text(value);
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
              inputFormatters: const [MoneyInputFormatter()],
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
