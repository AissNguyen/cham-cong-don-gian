/// Tính khoảng ngày của kỳ lương (theo tháng chọn ngày bắt đầu, hoặc 2 kỳ mỗi tháng).
library;

import 'models.dart';

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Ép ngày về trong khoảng hợp lệ của tháng (vd ngày 31 ở tháng 2 -> ngày cuối tháng 2).
DateTime _clampToMonth(int year, int month, int day) {
  final last = _daysInMonth(year, month);
  return DateTime(year, month, day > last ? last : day);
}

class PayPeriod {
  const PayPeriod(this.start, this.end);

  /// Ngày đầu kỳ (00:00).
  final DateTime start;

  /// Ngày cuối kỳ (00:00, bao gồm cả ngày này).
  final DateTime end;

  bool contains(DateTime date) {
    final d = dateOnly(date);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  String get key => '${dateKey(start)}_${dateKey(end)}';

  @override
  bool operator ==(Object other) => other is PayPeriod && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Ngày đầu (a) và ngày cuối (b) của kỳ 1 khi chia 2 kỳ một tháng, đã ép về khoảng an toàn: a từ
/// 1 tới 28, b từ a tới min(28, a + 26), để tháng nào (kể cả tháng 2) cũng có đủ hai kỳ, mỗi kỳ ít
/// nhất một ngày.
(int, int) semiMonthlyBounds(PayPeriodConfig cfg) {
  final a = cfg.semiFirstStart.clamp(1, 28);
  final maxB = a + 26 < 28 ? a + 26 : 28;
  final b = cfg.semiFirstEnd.clamp(a, maxB);
  return (a, b);
}

/// Kỳ lương chứa [date].
PayPeriod periodContaining(DateTime date, PayPeriodConfig cfg) {
  final d = dateOnly(date);
  if (cfg.type == PayPeriodType.semiMonthly) {
    final (a, b) = semiMonthlyBounds(cfg);
    if (d.day >= a && d.day <= b) {
      return PayPeriod(DateTime(d.year, d.month, a), DateTime(d.year, d.month, b));
    }
    // Kỳ 2: từ ngày b+1 tới trước ngày đầu kỳ 1 (ngày a) của tháng sau.
    final startMonth = d.day > b ? DateTime(d.year, d.month) : DateTime(d.year, d.month - 1);
    final start = DateTime(startMonth.year, startMonth.month, b + 1);
    final end = DateTime(startMonth.year, startMonth.month + 1, a).subtract(const Duration(days: 1));
    return PayPeriod(start, end);
  }

  // Theo tháng, ngày bắt đầu tự chọn.
  final startDay = cfg.monthlyStartDay;
  final thisMonthStart = _clampToMonth(d.year, d.month, startDay);
  DateTime start;
  if (!d.isBefore(thisMonthStart)) {
    start = thisMonthStart;
  } else {
    final prevMonth = d.month == 1 ? 12 : d.month - 1;
    final prevYear = d.month == 1 ? d.year - 1 : d.year;
    start = _clampToMonth(prevYear, prevMonth, startDay);
  }
  final nextMonth = start.month == 12 ? 1 : start.month + 1;
  final nextYear = start.month == 12 ? start.year + 1 : start.year;
  final nextStart = _clampToMonth(nextYear, nextMonth, startDay);
  final end = nextStart.subtract(const Duration(days: 1));
  return PayPeriod(start, end);
}

/// [count] kỳ gần nhất tính đến kỳ chứa [today], mới nhất trước.
List<PayPeriod> recentPeriods(DateTime today, PayPeriodConfig cfg, {int count = 12}) {
  final result = <PayPeriod>[];
  var cursor = periodContaining(today, cfg);
  for (var i = 0; i < count; i++) {
    result.add(cursor);
    final dayBeforeStart = cursor.start.subtract(const Duration(days: 1));
    cursor = periodContaining(dayBeforeStart, cfg);
  }
  return result;
}
