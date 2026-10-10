/// Thẻ "Phiếu lương" ở đầu màn Cài đặt (theo `mockup/luong-va-cai-dat.html`): xem phiếu lương của
/// từng kỳ, bấm "Sửa" để sửa con số ngay tại dòng, thêm hoặc xóa khoản. Số liệu lấy từ
/// `domain/payslip.dart`, cùng bộ tính với màn chính.
library;

import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../domain/pay_period.dart';
import '../../domain/payslip.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import 'number_inputs.dart';

/// Màu chung của phiếu lương (thu nhập xanh, khấu trừ đỏ, ô Thực nhận xanh dương).
class PayslipColors {
  PayslipColors.of(BuildContext context)
    : plus = context.appColors.gradientStart,
      minus = context.appColors.lateMark,
      netInk = Theme.of(context).brightness == Brightness.light ? const Color(0xFF2A56C6) : const Color(0xFF8FB0F5);

  final Color plus;
  final Color minus;
  final Color netInk;
}

/// Nút viền tròn "✎ Sửa" / "✓ Xong" ở góc mỗi khối.
class EditToggleButton extends StatelessWidget {
  const EditToggleButton({super.key, required this.editing, required this.onPressed});

  final bool editing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: const StadiumBorder(),
    );
    return editing
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Xong'),
            onPressed: onPressed,
          )
        : OutlinedButton.icon(
            style: style,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Sửa'),
            onPressed: onPressed,
          );
  }
}

/// Khung thẻ trắng bo góc giống [SettingsCard] nhưng tiêu đề có nút ở bên phải.
class TitledCard extends StatelessWidget {
  const TitledCard({super.key, required this.title, this.trailing, required this.child});

  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: context.appColors.line.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                ?trailing,
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// Mục của phiếu lương mà người dùng bấm "Thêm khoản": căn cứ, thu nhập hay khấu trừ.
enum PayslipSection { basis, income, deduction }

class PayslipCard extends StatefulWidget {
  const PayslipCard({super.key, required this.store, this.now});

  final AppStore store;

  /// Chỉ dùng trong test; bình thường là giờ hiện tại.
  final DateTime? now;

  @override
  State<PayslipCard> createState() => _PayslipCardState();
}

class _PayslipCardState extends State<PayslipCard> {
  /// 0 là kỳ hiện tại, -1 là kỳ trước...
  int _offset = 0;
  bool _editing = false;

  AppStore get store => widget.store;

  DateTime get _today => dateOnly(widget.now ?? DateTime.now());

  /// Kỳ đang xem.
  PayPeriod get _period => _periodAt(_today);

  /// Cài đặt với phần lương của đúng kỳ đang xem (mỗi kỳ giữ số riêng của nó).
  AppSettings get settings => store.settings.payFor(_period.start);

  PayPeriod _periodAt(DateTime today) {
    final cfg = store.settings.payPeriod;
    var p = periodContaining(today, cfg);
    for (var i = 0; i > _offset; i--) {
      p = periodContaining(p.start.subtract(const Duration(days: 1)), cfg);
    }
    return p;
  }

  /// Sửa phần lương của kỳ đang xem. Kỳ đã qua thì chỉ kỳ đó đổi; kỳ hiện tại thì các kỳ sau cũng
  /// theo số mới. Các kỳ trước không bị đổi.
  Future<void> _editPay({
    double? baseSalary,
    double? dailyWage,
    List<IncomeItem> Function(List<IncomeItem>)? items,
  }) {
    final period = _period;
    final next = DateTime(period.end.year, period.end.month, period.end.day + 1);
    final ended = _today.isAfter(period.end);
    return store.updateSettings(
      (s) => s.withPayEdit(
        periodStart: period.start,
        nextPeriodStart: next,
        periodEnded: ended,
        baseSalary: baseSalary,
        dailyWage: dailyWage,
        incomeItems: items?.call([...s.payFor(period.start).incomeItems]),
      ),
    );
  }

  Future<void> _updateItems(List<IncomeItem> Function(List<IncomeItem>) update) => _editPay(items: update);

  Future<void> _setItemAmount(IncomeItem item, double amount) => _updateItems(
    (list) => [for (final i in list) i.id == item.id ? i.copyWith(amount: amount) : i],
  );

  Future<void> _askDelete(IncomeItem item) async {
    final ok = await confirmAsk(
      context,
      title: 'Xóa khoản này?',
      text: 'Bạn chắc chắn muốn xóa "${item.name}" không?',
      yes: 'Xóa',
    );
    if (ok) await _updateItems((list) => list.where((i) => i.id != item.id).toList());
  }

  Future<void> _askClearBaseSalary() async {
    final ok = await confirmAsk(
      context,
      title: 'Xóa lương cơ bản?',
      text: 'Bạn chắc chắn muốn xóa "Lương cơ bản" không? Lương cơ bản sẽ về 0.',
      yes: 'Xóa',
    );
    if (ok) await _editPay(baseSalary: 0);
  }

  Future<void> _askClearStandard(PayPeriod period, int auto) async {
    final ok = await confirmAsk(
      context,
      title: 'Bỏ số công chuẩn đã sửa?',
      text: 'Bạn chắc chắn muốn xóa số công chuẩn đã sửa của kỳ này không? App sẽ tự đếm lại ($auto ngày).',
      yes: 'Xóa',
    );
    if (ok) {
      await store.updateSettings((s) => s.copyWith(standardDays: {...s.standardDays}..remove(period.key)));
    }
  }

  Future<void> _setStandard(PayPeriod period, double value) => store.updateSettings(
    (s) => s.copyWith(
      standardDays: value > 0 ? {...s.standardDays, period.key: value} : ({...s.standardDays}..remove(period.key)),
    ),
  );

  Future<void> _addItem(PayslipSection section) async {
    final item = await showNewPayItemDialog(context, section: section);
    if (item != null) await _updateItems((list) => [...list, item]);
  }

  /// Đã có phiếu lương nào được chốt chưa: có ngày chấm đủ vào/ra thuộc một kỳ đã hết.
  bool _hasSettledPayslip(DateTime today) {
    final currentStart = periodContaining(today, store.settings.payPeriod).start;
    return store.records.values.any(
      (r) => r.checkIn != null && r.checkOut != null && dateOnly(r.date).isBefore(currentStart),
    );
  }

  String _title(PayPeriod p) {
    final cfg = settings.payPeriod;
    if (cfg.type == PayPeriodType.semiMonthly) {
      final first = p.start.day == semiMonthlyBounds(cfg).$1 && p.start.month == p.end.month;
      return 'Kỳ ${first ? 1 : 2} · tháng ${p.start.month}/${p.start.year}';
    }
    return 'Tháng ${p.end.month}/${p.end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now();
    final period = _periodAt(dateOnly(now));
    final real = computePayslip(settings: store.settings, period: period, recordOf: store.recordFor, now: now);
    // Người chưa có phiếu lương nào được chốt thì kỳ đang chạy hiện phiếu lương mẫu thay cho dấu "—".
    final sample = !real.ended && !_hasSettledPayslip(dateOnly(now))
        ? computeSamplePayslip(settings: store.settings, period: period)
        : null;
    final slip = sample?.slip ?? real;
    final colors = context.appColors;
    final pc = PayslipColors.of(context);
    final worker = settings.workerKind == WorkerKind.worker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Chuyển kỳ.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Kỳ trước',
                onPressed: _offset > -24 ? () => setState(() => _offset--) : null,
              ),
              Text(
                'Kỳ ${fmtDM(period.start)} – ${fmtDMY(period.end)}',
                style: TextStyle(fontSize: 13, color: colors.ink2),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Kỳ sau',
                onPressed: _offset < 0 ? () => setState(() => _offset++) : null,
              ),
            ],
          ),
        ),
        TitledCard(
          title: 'Phiếu lương',
          trailing: EditToggleButton(editing: _editing, onPressed: () => setState(() => _editing = !_editing)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Text(_title(period), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (!real.ended)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: colors.warnSoft, borderRadius: BorderRadius.circular(99)),
                            child: Text(
                              sample != null ? 'Phiếu mẫu' : 'Chưa chốt',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: colors.warn),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    slip.ended ? fmtMoney(slip.net) : _pendingMark,
                    key: const ValueKey('payslip-net'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pc.plus),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                slip.ended
                    ? 'Thu nhập ${fmtMoney(slip.totalIncome, unit: false)} · trừ ${fmtMoney(slip.totalDeduction, unit: false)}'
                    : 'Phiếu lương chỉ được tính khi hết kỳ, sau ngày ${fmtDM(period.end)}.',
                style: TextStyle(fontSize: 12.5, color: colors.ink3),
              ),
              if (sample != null)
                Container(
                  key: const ValueKey('payslip-sample-note'),
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: colors.warnSoft, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    'Đây là phiếu lương MẪU để bạn xem cách tính, không phải lương của bạn. Mẫu giả sử bạn làm '
                    '${sample.days} ngày công và ${sample.overtimeHours} giờ tăng ca ngày thường. Sửa các khoản '
                    'cho đúng bảng lương của mình thì số mẫu đổi theo. Phiếu lương thật có sau khi hết kỳ, sau ngày '
                    '${fmtDM(period.end)}.',
                    style: TextStyle(fontSize: 12, color: colors.warn, height: 1.45),
                  ),
                ),
              Divider(height: 28, color: context.appColors.line),
              _basisBlock(context, slip, period, worker),
              _sectionLabel('THU NHẬP', pc.plus),
              for (final line in slip.incomes) _lineRow(context, line, worker, pending: !slip.ended),
              if (_editing) _addButton('Thêm khoản thu nhập', PayslipSection.income),
              _totalRow(
                'Tổng thu nhập',
                slip.ended ? fmtMoney(slip.totalIncome, unit: false) : _pendingMark,
                pc.plus,
              ),
              _sectionLabel('KHẤU TRỪ', pc.minus),
              // Kỳ chưa chốt thì chưa có dòng tự sinh (Đi muộn), chỉ hiện các khoản đã cài.
              for (final line in slip.deductions)
                if (slip.ended || line.item != null) _lineRow(context, line, worker, pending: !slip.ended),
              if (_editing) _addButton('Thêm khoản khấu trừ', PayslipSection.deduction),
              _totalRow(
                'Tổng khấu trừ',
                !slip.ended
                    ? _pendingMark
                    : (slip.totalDeduction > 0 ? '−${fmtMoney(slip.totalDeduction, unit: false)}' : '0'),
                pc.minus,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pc.netInk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sample != null ? 'THỰC NHẬN (MẪU)' : 'THỰC NHẬN',
                        style: TextStyle(fontSize: 12.5, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: pc.netInk),
                      ),
                    ),
                    Text(
                      slip.ended ? fmtMoney(slip.net) : _pendingMark,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: pc.netInk),
                    ),
                  ],
                ),
              ),
              if (!slip.ended)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Kỳ này chưa chốt nên phiếu lương chưa tính. Số ước tính đang chạy xem ở thẻ thu nhập ngoài '
                    'màn chính.',
                    style: TextStyle(fontSize: 12, color: colors.ink3, height: 1.45),
                  ),
                ),
              if (worker) const _CalcNotes(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _basisBlock(BuildContext context, Payslip slip, PayPeriod period, bool worker) {
    final colors = context.appColors;
    final bodyStyle = TextStyle(fontSize: 13, color: colors.ink2, height: 1.75);
    final bold = TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface);
    final basisItems = settings.incomeItems.where((i) => i.inBasis).toList();
    final hours = slip.normalMinutes + slip.overtimeMinutes;

    TextSpan b(String t) => TextSpan(text: t, style: bold);

    final List<Widget> content;
    if (!_editing) {
      content = [
        Text.rich(
          TextSpan(
            style: bodyStyle,
            children: worker
                ? [
                    const TextSpan(text: 'Lương cơ bản '),
                    b(fmtMoney(settings.baseSalary)),
                    const TextSpan(text: '/tháng'),
                    for (final i in basisItems) ...[
                      TextSpan(text: '\n${i.name} '),
                      b(fmtMoney(i.amount)),
                      const TextSpan(text: '/tháng'),
                    ],
                    const TextSpan(text: '\nCông chuẩn '),
                    b(fmtN(slip.standardDays)),
                    // Ngày công, giờ công chỉ hiện khi kỳ đã chốt.
                    if (!slip.ended)
                      const TextSpan(text: ' ngày')
                    else ...[
                      const TextSpan(text: ' · thực tế '),
                      b(fmtN(slip.workDays)),
                      const TextSpan(text: ' ngày'),
                      if (slip.paidLeaveDays > 0) ...[
                        const TextSpan(text: ' · nghỉ có lương '),
                        b('${slip.paidLeaveDays}'),
                        const TextSpan(text: ' ngày'),
                      ],
                      const TextSpan(text: '\nGiờ công '),
                      b(fmtHours(slip.normalMinutes)),
                      const TextSpan(text: ' · tăng ca '),
                      b(fmtHours(slip.overtimeMinutes)),
                    ],
                  ]
                : [
                    const TextSpan(text: 'Lương cơ bản '),
                    b(fmtMoney(settings.dailyWage)),
                    const TextSpan(text: '/ngày'),
                    if (slip.ended) ...[const TextSpan(text: '\nTổng giờ công '), b(fmtHours(hours))],
                  ],
          ),
        ),
      ];
    } else {
      content = [
        if (worker) ...[
          _editRow(
            name: 'Lương cơ bản',
            how: 'đ/tháng',
            field: InlineNumberField(
              value: settings.baseSalary,
              onChanged: (v) => _editPay(baseSalary: v),
            ),
            onDelete: _askClearBaseSalary,
          ),
          for (final i in basisItems)
            _editRow(
              name: i.name,
              how: 'đ/tháng',
              field: InlineNumberField(value: i.amount, onChanged: (v) => _setItemAmount(i, v)),
              onDelete: () => _askDelete(i),
            ),
          _editRow(
            name: 'Công chuẩn',
            how: 'ngày · app tự đếm kỳ này là ${slip.autoStandardDays}',
            field: InlineNumberField(
              key: ValueKey('std-${period.key}'),
              value: slip.standardDays,
              percent: true,
              width: 70,
              onChanged: (v) => _setStandard(period, v),
            ),
            onDelete: slip.standardOverridden ? () => _askClearStandard(period, slip.autoStandardDays) : null,
          ),
          _addButton('Thêm khoản căn cứ', PayslipSection.basis),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: bodyStyle.copyWith(fontSize: 12.5, height: 1.6),
              children: [
                const TextSpan(text: 'Tự tính từ chấm công, không sửa ở đây:\nthực tế '),
                b(fmtN(slip.workDays)),
                const TextSpan(text: ' ngày · giờ công '),
                b(fmtHours(slip.normalMinutes)),
                const TextSpan(text: ' · tăng ca '),
                b(fmtHours(slip.overtimeMinutes)),
              ],
            ),
          ),
        ] else ...[
          _editRow(
            name: 'Lương cơ bản',
            how: 'đ/ngày',
            field: InlineNumberField(
              value: settings.dailyWage,
              onChanged: (v) => _editPay(dailyWage: v),
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: bodyStyle.copyWith(fontSize: 12.5, height: 1.6),
              children: [const TextSpan(text: 'Tự tính từ chấm công, không sửa ở đây: tổng giờ công '), b(fmtHours(hours))],
            ),
          ),
        ],
      ];
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CĂN CỨ TÍNH',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: colors.ink3),
          ),
          ...content,
        ],
      ),
    );
  }

  /// Giải thích dưới tên khoản khi đang sửa (đơn vị và cách tính).
  String _editHow(IncomeItem item, bool worker) {
    switch (item.calcMethod) {
      case IncomeCalcMethod.perWorkDay:
        final gate = item.activeAfter;
        return gate == null ? 'đ × số ngày đi làm' : 'đ × số ngày làm qua ${gate.formatted}';
      case IncomeCalcMethod.percentOfBaseSalary:
        final insurance = item.id == payItemInsurance ? ' · gồm BHXH 8 + BHYT 1,5 + BHTN 1' : '';
        return worker ? '% lương cơ bản$insurance' : '% tiền lương';
      case IncomeCalcMethod.fixed:
        return worker ? 'đ/kỳ · tính dần theo ngày công' : 'đ/kỳ';
      case IncomeCalcMethod.salary:
      case IncomeCalcMethod.overtime:
        return '';
    }
  }

  /// Chỗ của số tiền khi kỳ chưa chốt.
  static const _pendingMark = '—';

  /// Dòng nhỏ dưới tên khoản khi kỳ chưa chốt: nói cách sẽ tính, không tính ra số.
  String _pendingHow(PayslipLine line, bool worker) {
    final item = line.item;
    if (item == null) return '';
    switch (item.calcMethod) {
      case IncomeCalcMethod.salary:
        return worker ? 'Lương cơ bản ÷ công chuẩn × ngày công' : 'Lương ngày ÷ 8 × số giờ làm';
      case IncomeCalcMethod.overtime:
        return 'Giờ tăng ca, chủ nhật, ngày lễ × giá trong bảng lương/giờ';
      case IncomeCalcMethod.perWorkDay:
        final gate = item.activeAfter;
        return '${fmtMoney(item.amount, unit: false)} × số ngày ${gate == null ? 'đi làm' : 'làm qua ${gate.formatted}'}';
      case IncomeCalcMethod.percentOfBaseSalary:
        return worker ? '${fmtPercent(item.amount)}% lương cơ bản' : '${fmtPercent(item.amount)}% tiền lương';
      case IncomeCalcMethod.fixed:
        if (item.inBasis && worker) return '${fmtMoney(item.amount, unit: false)} ÷ công chuẩn × ngày công';
        return '${fmtMoney(item.amount, unit: false)} mỗi kỳ';
    }
  }

  /// [pending]: kỳ chưa chốt, không hiện số tiền đã tính.
  Widget _lineRow(BuildContext context, PayslipLine line, bool worker, {bool pending = false}) {
    final colors = context.appColors;
    final pc = PayslipColors.of(context);
    final item = line.item;
    final minus = line.type == IncomeItemType.deduction;
    final percent = item?.calcMethod == IncomeCalcMethod.percentOfBaseSalary;
    final name = percent ? '${line.name} (${fmtPercent(item!.amount)}%)' : line.name;
    // Dòng tự tính: Tiền lương, Thưởng vượt khoán, dòng thu nhập của khoản căn cứ, Đi muộn.
    final auto =
        item == null ||
        item.calcMethod == IncomeCalcMethod.salary ||
        item.calcMethod == IncomeCalcMethod.overtime ||
        (item.inBasis && worker);
    final editInline = _editing && !auto;
    // Công nhật: dòng Tiền lương là cách tính chính, không xóa được.
    final deletable = _editing && item != null && !(item.calcMethod == IncomeCalcMethod.salary && !worker);
    final how = editInline ? _editHow(item, worker) : (pending ? _pendingHow(line, worker) : line.how);
    final amountText = pending
        ? _pendingMark
        : (minus ? '−${fmtMoney(line.amount, unit: false)}' : fmtMoney(line.amount, unit: false));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: _editing ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 14)),
                if (how.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(how, style: TextStyle(fontSize: 11.5, color: colors.ink3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (editInline && percent) ...[
            InlineNumberField(value: item.amount, percent: true, width: 70, onChanged: (v) => _setItemAmount(item, v)),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('%', style: TextStyle(fontSize: 13, color: colors.ink2)),
            ),
          ] else if (editInline)
            InlineNumberField(value: item.amount, onChanged: (v) => _setItemAmount(item, v))
          else
            Text(
              amountText,
              style: TextStyle(
                fontSize: 14,
                color: minus ? pc.minus : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          if (deletable) _deleteButton(() => _askDelete(item)),
        ],
      ),
    );
  }

  Widget _deleteButton(VoidCallback? onPressed) => SizedBox(
    width: 36,
    child: onPressed == null
        ? null
        : IconButton(
            icon: Icon(Icons.close, size: 17, color: context.appColors.lateMark),
            tooltip: 'Xóa',
            visualDensity: VisualDensity.compact,
            onPressed: onPressed,
          ),
  );

  Widget _editRow({required String name, required String how, required Widget field, VoidCallback? onDelete}) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
                Text(how, style: TextStyle(fontSize: 11.5, color: colors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          field,
          if (settings.workerKind == WorkerKind.worker) _deleteButton(onDelete),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 4),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: color),
    ),
  );

  Widget _addButton(String label, PayslipSection section) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(shape: const StadiumBorder(), visualDensity: VisualDensity.compact),
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        onPressed: () => _addItem(section),
      ),
    ),
  );

  Widget _totalRow(String label, String value, Color color) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.only(top: 10),
    decoration: BoxDecoration(border: Border(top: BorderSide(color: context.appColors.line))),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color))),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
      ],
    ),
  );
}

/// "Lưu ý về cách tính": rút gọn sẵn, bấm mới mở.
class _CalcNotes extends StatefulWidget {
  const _CalcNotes();

  @override
  State<_CalcNotes> createState() => _CalcNotesState();
}

class _CalcNotesState extends State<_CalcNotes> {
  bool _open = false;

  static const _notes = [
    'Đây là phiếu lương tham khảo, hãy chỉnh sửa lại các mục cho phù hợp bảng lương của mình. Sửa ở kỳ nào '
        'thì áp dụng cho kỳ đó, các kỳ trước giữ nguyên số của chúng.',
    'Phiếu lương mang tính chất ước lượng. Mức lương nhận được phụ thuộc vào người tính lương cho bạn, nên '
        'khi nhận được lương thật, hãy nhập lại số tiền ở mục "Thống kê thu nhập theo kỳ" bên lịch chấm công '
        'để tính tổng chính xác hơn.',
    'Ở phần thống kê nhanh (thẻ thu nhập ngoài màn chính), các khoản cố định như công đoàn phí, trợ cấp, bảo '
        'hiểm được chia đều cho số ngày công chuẩn để ước tính sát theo từng ngày bạn đi làm. Phiếu lương thì '
        'chỉ tính khi hết kỳ; lúc đó các khoản khấu trừ cố định (bảo hiểm, công đoàn phí) được tính đủ và tổng '
        'của kỳ lấy theo phiếu lương.',
    'Bảo hiểm tính trên đủ lương cơ bản dù không đủ ngày công. Riêng tháng nào nghỉ không lương từ 14 ngày làm '
        'việc trở lên thì tháng đó không trừ bảo hiểm.',
    'Chủ nhật và ngày lễ không tính các khoản cố định. Làm những ngày đó chỉ được tính tiền tăng ca.',
    'Ngày nghỉ có lương được tính một ngày lương cơ bản.',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = Theme.of(context).brightness == Brightness.light ? const Color(0xFF7A4A0A) : colors.warn;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(color: colors.warnSoft, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_open ? Icons.expand_more : Icons.chevron_right, size: 18, color: ink),
                  const SizedBox(width: 4),
                  Text('Lưu ý về cách tính', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink)),
                ],
              ),
              if (_open)
                for (final note in _notes)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text('•  $note', style: TextStyle(fontSize: 12, height: 1.5, color: ink)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng "Khoản mới" (chỉ hiện khi thêm). Không có mục "Loại": app tự hiểu theo nút được bấm. Khoản
/// thêm ở mục Căn cứ chỉ có tên và số tiền/tháng.
Future<IncomeItem?> showNewPayItemDialog(BuildContext context, {required PayslipSection section}) {
  return showDialog<IncomeItem>(context: context, builder: (_) => _NewPayItemDialog(section: section));
}

class _NewPayItemDialog extends StatefulWidget {
  const _NewPayItemDialog({required this.section});

  final PayslipSection section;

  @override
  State<_NewPayItemDialog> createState() => _NewPayItemDialogState();
}

class _NewPayItemDialogState extends State<_NewPayItemDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController(text: '0');
  var _method = IncomeCalcMethod.fixed;
  Clock? _after;

  bool get _basis => widget.section == PayslipSection.basis;
  bool get _percent => _method == IncomeCalcMethod.percentOfBaseSalary;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _setMethod(IncomeCalcMethod m) {
    setState(() {
      _method = m;
      _amount.text = '0';
      if (m != IncomeCalcMethod.perWorkDay) _after = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final amount = _percent ? parsePercent(_amount.text) : parseMoney(_amount.text);
    Navigator.pop(
      context,
      IncomeItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        type: widget.section == PayslipSection.deduction ? IncomeItemType.deduction : IncomeItemType.income,
        calcMethod: _basis ? IncomeCalcMethod.fixed : _method,
        amount: amount,
        activeAfter: _after,
        inBasis: _basis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final kindName = switch (widget.section) {
      PayslipSection.basis => 'căn cứ',
      PayslipSection.income => 'thu nhập',
      PayslipSection.deduction => 'khấu trừ',
    };
    final amountLabel = _basis
        ? 'Số tiền (đ/tháng)'
        : switch (_method) {
            IncomeCalcMethod.perWorkDay => 'Số tiền mỗi ngày công (đ)',
            IncomeCalcMethod.percentOfBaseSalary => 'Phần trăm (%), ví dụ 1,5',
            _ => 'Số tiền (đ)',
          };

    return AlertDialog(
      title: Text('Khoản $kindName mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tên khoản',
                hintText: 'Ví dụ: Chuyên cần',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (!_basis) ...[
              const SizedBox(height: 18),
              const Text('Cách tính', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (m, label) in const [
                    (IncomeCalcMethod.fixed, 'Cố định mỗi kỳ'),
                    (IncomeCalcMethod.perWorkDay, '× số ngày công'),
                    (IncomeCalcMethod.percentOfBaseSalary, '% lương cơ bản'),
                  ])
                    ChoiceChip(label: Text(label), selected: _method == m, onSelected: (_) => _setMethod(m)),
                ],
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              key: ValueKey(_percent),
              controller: _amount,
              keyboardType: _percent ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
              inputFormatters: [if (_percent) const PercentInputFormatter() else const MoneyInputFormatter()],
              decoration: InputDecoration(labelText: amountLabel, border: const OutlineInputBorder()),
            ),
            if (_basis)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Khoản căn cứ là mức theo tháng, giống Thưởng thành tích: app tự thêm một dòng ở Thu nhập '
                  'bằng mức này ÷ công chuẩn × ngày công thực tế.',
                  style: TextStyle(fontSize: 11.5, color: colors.ink2),
                ),
              ),
            if (_method == IncomeCalcMethod.perWorkDay && !_basis) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Chỉ tính từ giờ... (ví dụ tiền cơm trưa sau 12:30)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(_after?.formatted ?? 'Chưa đặt'),
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: _after?.hour ?? 12, minute: _after?.minute ?? 30),
                      );
                      if (picked != null) setState(() => _after = Clock(picked.hour, picked.minute));
                    },
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Chỉ đếm những ngày làm qua giờ này. Để trống thì đếm mọi ngày có đi làm.',
                  style: TextStyle(fontSize: 11.5, color: colors.ink2),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _name.text.trim().isEmpty ? null : _save, child: const Text('Lưu')),
      ],
    );
  }
}
