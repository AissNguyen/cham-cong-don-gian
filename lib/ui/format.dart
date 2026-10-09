const weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const weekdayLong = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
const monthNames = [
  'Tháng 1',
  'Tháng 2',
  'Tháng 3',
  'Tháng 4',
  'Tháng 5',
  'Tháng 6',
  'Tháng 7',
  'Tháng 8',
  'Tháng 9',
  'Tháng 10',
  'Tháng 11',
  'Tháng 12',
];

String p2(int n) => n.toString().padLeft(2, '0');

/// "3", "8,3": một chữ số thập phân, bỏ ",0", dấu phẩy kiểu Việt Nam.
String fmtN(num v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString().replaceAll('.', ',');
}

/// "1.234.567 đ" (âm thì có dấu "−"). Bỏ phần lẻ (không làm tròn lên), như mọi chỗ hiện tiền.
String fmtMoney(num v, {bool unit = true}) {
  final n = v.truncate();
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '−' : ''}$buf${unit ? ' đ' : ''}';
}

/// Số phút thành "10h30" (tròn giờ thì chỉ "10h", không có "h00").
String fmtHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${p2(m)}';
}

/// "20/09".
String fmtDM(DateTime d) => '${p2(d.day)}/${p2(d.month)}';

/// "20/09/2026".
String fmtDMY(DateTime d) => '${p2(d.day)}/${p2(d.month)}/${d.year}';

/// "Thứ Tư, 16/09".
String fmtDayLong(DateTime d) => '${weekdayLong[d.weekday - 1]}, ${fmtDM(d)}';

/// "07:30".
String fmtTime(DateTime d) => '${p2(d.hour)}:${p2(d.minute)}';

/// "10,5": phần trăm, tối đa hai chữ số lẻ, dấu phẩy.
String fmtPercent(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString().replaceAll('.', ',');
}
