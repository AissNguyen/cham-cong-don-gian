/// Ngày phép của công nhân (thuần Dart, không phụ thuộc bù tăng ca): mỗi kỳ lương được cộng 1 ngày phép, không
/// dùng thì dồn sang kỳ sau. Ngày tự nghỉ (T2–T7, không phải lễ) trừ vào phép trước — tính như nghỉ có
/// lương; hết phép mới là nghỉ không lương. Ngày công ty cho nghỉ không trừ phép.
library;

import 'calc.dart';
import 'models.dart';
import 'pay_period.dart';

/// Ngày tự nghỉ: đánh dấu nghỉ, không phải nghỉ có lương cũ, không phải công ty cho nghỉ.
bool isSelfDayOff(DayRecord r) => r.isDayOff && !r.paidLeave && !r.companyOff;

class LeaveState {
  const LeaveState({required this.used, required this.balance});

  /// Các ngày tự nghỉ được tính là nghỉ phép.
  final Set<DateTime> used;

  /// Số ngày phép còn lại sau ngày cuối cùng đã xét.
  final double balance;
}

/// Đi qua từng ngày từ mốc phép đầu tiên tới [until]. [includeUntil] = false thì không trừ phép của
/// chính ngày [until] (để biết "còn bao nhiêu phép" khi đang chọn ngày đó).
LeaveState leaveState(
  AppSettings settings,
  DayRecord Function(DateTime date) recordOf,
  DateTime until, {
  bool includeUntil = true,
}) {
  final anchors = [...settings.leaveAnchors]..sort((a, b) => a.date.compareTo(b.date));
  final end = dateOnly(until);
  final used = <DateTime>{};
  if (settings.workerKind != WorkerKind.worker || anchors.isEmpty || anchors.first.date.isAfter(end)) {
    return LeaveState(used: used, balance: 0);
  }
  var balance = 0.0;
  var next = 0;
  for (var d = dateOnly(anchors.first.date); !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    var anchored = false;
    while (next < anchors.length && !dateOnly(anchors[next].date).isAfter(d)) {
      balance = anchors[next].days;
      next++;
      anchored = true;
    }
    // Đầu mỗi kỳ lương mới được cộng 1 ngày phép (ngày có mốc thì số của mốc đã gồm phép kỳ đó).
    if (!anchored && periodContaining(d, settings.payPeriod).start == d) balance += 1;
    if (d == end && !includeUntil) break;
    final type = dayTypeOf(d, settings.holidays);
    final workday = type == DayType.weekday || type == DayType.saturday;
    if (workday && balance >= 1 && isSelfDayOff(recordOf(d))) {
      used.add(d);
      balance -= 1;
    }
  }
  return LeaveState(used: used, balance: balance);
}

/// Số ngày phép còn lại để dùng cho ngày [date] (chưa trừ phép của chính ngày đó).
double leaveBalanceFor(AppSettings settings, DayRecord Function(DateTime date) recordOf, DateTime date) =>
    leaveState(settings, recordOf, date, includeUntil: false).balance;
