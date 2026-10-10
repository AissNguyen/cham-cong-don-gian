/// Ô nhập số dùng trong phiếu lương và Cài đặt tính công: ô tiền tự thêm dấu chấm ngăn hàng
/// nghìn khi gõ, ô phần trăm nhận được dấu phẩy (ví dụ 1,5). Kèm hộp hỏi lại dùng chung.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';

/// "4000000" -> "4.000.000" ngay khi gõ. Giữ con trỏ đứng sau đúng chữ số người dùng vừa gõ.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cursor = newValue.selection.baseOffset < 0 ? newValue.text.length : newValue.selection.baseOffset;
    final digitsBeforeCursor = newValue.text.substring(0, cursor.clamp(0, newValue.text.length)).replaceAll(RegExp(r'\D'), '').length;
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final removedZeros = digits.length - trimmed.length;
    digits = trimmed;
    final text = groupThousands(digits);
    // Đặt con trỏ sau chữ số thứ [want] (tính trên chuỗi đã có dấu chấm).
    final want = (digitsBeforeCursor - removedZeros).clamp(0, digits.length);
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < want) {
      if (text[offset] != '.') seen++;
      offset++;
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: offset));
  }
}

/// Phần trăm: chỉ nhận chữ số và một dấu phẩy; gõ dấu chấm cũng thành dấu phẩy.
class PercentInputFormatter extends TextInputFormatter {
  const PercentInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var v = newValue.text.replaceAll('.', ',').replaceAll(RegExp(r'[^\d,]'), '');
    final i = v.indexOf(',');
    if (i >= 0) v = v.substring(0, i + 1) + v.substring(i + 1).replaceAll(',', '');
    return TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
  }
}

/// "4000000" -> "4.000.000".
String groupThousands(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Số tiền đang hiện trong ô (bỏ dấu chấm). Ô trống là 0.
double parseMoney(String text) => double.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

/// "1,5" -> 1.5. Ô trống là 0.
double parsePercent(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0;

/// Chữ ban đầu của ô tiền: "4.000.000" (bỏ phần lẻ).
String moneyText(double v) => fmtMoney(v, unit: false).replaceAll('−', '');

/// Hộp hỏi lại dùng chung (đổi Công nhân / Công nhật, mọi dấu ✕). Trả về true khi bấm đồng ý.
Future<bool> confirmAsk(BuildContext context, {required String title, required String text, required String yes}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(yes)),
      ],
    ),
  );
  return ok == true;
}

/// Ô nhập số nằm ngay tại dòng (phiếu lương, bảng lương/giờ). Mỗi lần gõ là lưu luôn qua
/// [onChanged]; khi số bên ngoài đổi mà người dùng không đang gõ thì ô tự cập nhật theo.
class InlineNumberField extends StatefulWidget {
  const InlineNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.percent = false,
    this.width = 112,
    this.integerOnly = false,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// true: ô phần trăm hoặc số có phần lẻ (nhận dấu phẩy). false: ô tiền (tự thêm dấu chấm).
  final bool percent;

  /// Ô số ngày, số phút: chỉ nhận chữ số, không thêm dấu chấm.
  final bool integerOnly;
  final double width;

  @override
  State<InlineNumberField> createState() => _InlineNumberFieldState();
}

class _InlineNumberFieldState extends State<InlineNumberField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  String _textOf(double v) {
    if (widget.percent || widget.integerOnly) return fmtPercent(v);
    return moneyText(v);
  }

  double _parse(String text) {
    if (widget.percent || widget.integerOnly) return parsePercent(text);
    return parseMoney(text);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _textOf(widget.value));
  }

  @override
  void didUpdateWidget(covariant InlineNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus && _parse(_controller.text) != widget.value) {
      _controller.text = _textOf(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.right,
        keyboardType: widget.percent ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
        inputFormatters: [
          if (widget.integerOnly)
            FilteringTextInputFormatter.digitsOnly
          else if (widget.percent)
            const PercentInputFormatter()
          else
            const MoneyInputFormatter(),
        ],
        style: const TextStyle(fontSize: 14, fontFeatures: [FontFeature.tabularFigures()]),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          border: OutlineInputBorder(),
        ),
        onChanged: (text) => widget.onChanged(_parse(text)),
      ),
    );
  }
}
