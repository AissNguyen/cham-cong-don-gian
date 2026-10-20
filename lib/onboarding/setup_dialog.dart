/// Câu hỏi lần đầu mở app (và đầu "Hướng dẫn lương"): Công nhân hay Công nhật, kỳ lương; công nhân
/// hỏi thêm lấy tăng ca bù và số ngày phép. Trả lời bước nào thì lưu ngay bước đó.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../domain/leave.dart';
import '../domain/models.dart';
import '../domain/pay_period.dart';
import '../ui/format.dart';

enum _SetupStep { kind, period, offset, leave }

Future<void> showSetupDialog(BuildContext context, AppStore store) =>
    showDialog(context: context, barrierDismissible: false, builder: (_) => _SetupDialog(store: store));

class _SetupDialog extends StatefulWidget {
  const _SetupDialog({required this.store});

  final AppStore store;

  @override
  State<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends State<_SetupDialog> {
  _SetupStep _step = _SetupStep.kind;
  late WorkerKind _kind = widget.store.settings.workerKind;
  late PayPeriodConfig _period = widget.store.settings.payPeriod;
  late OvertimeOffsetMode _mode = widget.store.settings.offsetMode;
  late final _monthlyStart = TextEditingController(text: '${_period.monthlyStartDay}');
  late final _semiStart = TextEditingController(text: '${_period.semiFirstStart}');
  late final _semiEnd = TextEditingController(text: '${_period.semiFirstEnd}');
  late final _leave = TextEditingController(
    text: widget.store.settings.leaveAnchors.isEmpty
        ? '1'
        : fmtN(leaveBalanceFor(widget.store.settings, widget.store.recordFor, DateTime.now())),
  );

  AppStore get store => widget.store;
  bool get _worker => _kind == WorkerKind.worker;

  List<_SetupStep> get _steps => [
    _SetupStep.kind,
    _SetupStep.period,
    if (_worker) ...[_SetupStep.offset, _SetupStep.leave],
  ];

  @override
  void dispose() {
    for (final c in [_monthlyStart, _semiStart, _semiEnd, _leave]) {
      c.dispose();
    }
    super.dispose();
  }

  int _day(TextEditingController c, int fallback, int max) => (int.tryParse(c.text.trim()) ?? fallback).clamp(1, max);

  /// Lưu câu trả lời của bước đang xem.
  Future<void> _save() async {
    switch (_step) {
      case _SetupStep.kind:
        if (_kind != store.settings.workerKind) {
          await store.replaceSettings(AppSettings.defaultsFor(_kind, keep: store.settings));
          _period = store.settings.payPeriod;
          _mode = store.settings.offsetMode;
          _monthlyStart.text = '${_period.monthlyStartDay}';
          _semiStart.text = '${_period.semiFirstStart}';
          _semiEnd.text = '${_period.semiFirstEnd}';
        }
      case _SetupStep.period:
        final cfg = _period.type == PayPeriodType.monthly
            ? _period.copyWith(monthlyStartDay: _day(_monthlyStart, _period.monthlyStartDay, 31))
            : _period.copyWith(
                semiFirstStart: _day(_semiStart, _period.semiFirstStart, 28),
                semiFirstEnd: _day(_semiEnd, _period.semiFirstEnd, 28),
              );
        await store.updateSettings((s) => s.copyWith(payPeriod: cfg));
      case _SetupStep.offset:
        await store.updateSettings((s) => s.copyWith(offsetMode: _mode));
      case _SetupStep.leave:
        final days = double.tryParse(_leave.text.trim().replaceAll(',', '.')) ?? 1;
        await store.updateSettings((s) {
          // Lần đầu: số phép tính từ đầu kỳ đang chạy; đã có thì ghi mốc hôm nay.
          if (s.leaveAnchors.isEmpty) {
            final start = periodContaining(DateTime.now(), s.payPeriod).start;
            return s.copyWith(leaveAnchors: [LeaveAnchor(date: start, days: days < 0 ? 0 : days)]);
          }
          return s.withLeaveBalance(days, DateTime.now());
        });
    }
  }

  Future<void> _next() async {
    await _save();
    if (!mounted) return;
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i + 1 >= steps.length) {
      Navigator.pop(context);
    } else {
      setState(() => _step = steps[i + 1]);
    }
  }

  Widget _option({required String title, required String sub, required bool selected, required VoidCallback onTap, Key? key}) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: 1.5),
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(selected ? Icons.circle : Icons.radio_button_unchecked, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayField(TextEditingController c, {Key? key}) => SizedBox(
    width: 56,
    child: TextField(
      key: key,
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final n = steps.indexOf(_step) + 1;
    final muted = TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final String title;
    final List<Widget> body;
    switch (_step) {
      case _SetupStep.kind:
        title = 'Bạn là Công nhân hay Công nhật?';
        body = [
          _option(
            key: const ValueKey('setup-worker'),
            title: 'Công nhân',
            sub: 'Lương tháng, chia theo ngày công. Có thưởng, phụ cấp, bảo hiểm, ngày phép.',
            selected: _worker,
            onTap: () => setState(() => _kind = WorkerKind.worker),
          ),
          const SizedBox(height: 8),
          _option(
            key: const ValueKey('setup-daily'),
            title: 'Công nhật',
            sub: 'Lương trả theo từng ngày làm (lương ngày ÷ 8 × số giờ).',
            selected: !_worker,
            onTap: () => setState(() => _kind = WorkerKind.daily),
          ),
          const SizedBox(height: 8),
          Text(
            _kind != store.settings.workerKind && store.settings.hasPayConfigured
                ? 'Đổi loại thì phần lương đã cài sẽ về mặc định (giờ chấm công vẫn giữ nguyên).'
                : 'Chọn xong app đổi luôn theo loại bạn chọn. Sau này đổi lại ở Cài đặt.',
            style: muted,
          ),
        ];
      case _SetupStep.period:
        final monthly = _period.type == PayPeriodType.monthly;
        title = 'Kỳ lương';
        body = [
          // Công nhân: 1 kỳ một tháng; công nhật: 2 kỳ một tháng (giống Cài đặt tính công).
          Text(
            monthly
                ? 'Công ty tính lương từ ngày nào? Ví dụ từ ngày 21 tháng này tới ngày 20 tháng sau. Không biết thì để '
                      'như cũ, sửa sau ở Cài đặt.'
                : 'Công ty trả lương 2 lần một tháng: kỳ 1 từ ngày nào tới ngày nào? Kỳ 2 là các ngày còn lại. Không biết '
                      'thì để như cũ, sửa sau ở Cài đặt.',
            style: muted,
          ),
          const SizedBox(height: 12),
          if (monthly)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Kỳ bắt đầu ngày'),
                _dayField(_monthlyStart, key: const ValueKey('setup-start-day')),
                const Text('mỗi tháng'),
              ],
            )
          else
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Text('Kỳ 1 từ ngày'),
                _dayField(_semiStart),
                const Text('đến'),
                _dayField(_semiEnd),
                const Text('· kỳ 2 là các ngày còn lại'),
              ],
            ),
        ];
      case _SetupStep.offset:
        title = 'Lấy tăng ca bù';
        body = [
          Text('Công ty có lấy giờ tăng ca để bù cho ngày nghỉ, ngày thiếu giờ không? Không thì bỏ trống cả hai.', style: muted),
          const SizedBox(height: 10),
          _option(
            key: const ValueKey('setup-offset-company'),
            title: 'Công ty cho nghỉ',
            sub: 'Bù ngày công ty cho nghỉ, cho vào muộn, về sớm.',
            selected: _mode != OvertimeOffsetMode.off,
            onTap: () => setState(
              () => _mode = _mode == OvertimeOffsetMode.off ? OvertimeOffsetMode.company : OvertimeOffsetMode.off,
            ),
          ),
          const SizedBox(height: 8),
          _option(
            key: const ValueKey('setup-offset-self'),
            title: 'Tự nghỉ',
            sub: 'Bù cả ngày tự nghỉ (đã hết phép) và ngày tự đi muộn.',
            selected: _mode == OvertimeOffsetMode.all,
            onTap: () => setState(
              () => _mode = _mode == OvertimeOffsetMode.all ? OvertimeOffsetMode.company : OvertimeOffsetMode.all,
            ),
          ),
        ];
      case _SetupStep.leave:
        title = 'Ngày phép';
        body = [
          Text('Bạn đang còn mấy ngày phép? Mỗi kỳ lương app tự cộng 1 ngày. Tự nghỉ thì trừ phép trước.', style: muted),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Còn'),
              const SizedBox(width: 8),
              SizedBox(
                width: 64,
                child: TextField(
                  key: const ValueKey('setup-leave'),
                  controller: _leave,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              const Text('ngày phép'),
            ],
          ),
        ];
    }
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Câu hỏi $n/${steps.length}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 2),
          Text(title),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Để sau')),
        FilledButton(
          key: const ValueKey('setup-next'),
          onPressed: _next,
          child: Text(n == steps.length ? 'Xong' : 'Tiếp'),
        ),
      ],
    );
  }
}
