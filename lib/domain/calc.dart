/// Công thức tính giờ công, tăng ca, đi muộn và tiền lương một ngày.
library;

import 'models.dart';
import 'pay_period.dart';

DayType dayTypeOf(DateTime date, List<Holiday> holidays) {
  final d = dateOnly(date);
  if (holidays.any((h) => dateOnly(h.date) == d)) return DayType.holiday;
  switch (d.weekday) {
    case DateTime.saturday:
      return DayType.saturday;
    case DateTime.sunday:
      return DayType.sunday;
    default:
      return DayType.weekday;
  }
}

DateTime _anchor(Clock c, DateTime baseDate) => DateTime(baseDate.year, baseDate.month, baseDate.day, c.hour, c.minute);

/// [start, end) của một khung giờ, tự đẩy sang hôm sau nếu end <= start (qua đêm).
(DateTime, DateTime) _span(Clock start, Clock end, DateTime baseDate) {
  final s = _anchor(start, baseDate);
  var e = _anchor(end, baseDate);
  if (!e.isAfter(s)) e = e.add(const Duration(days: 1));
  return (s, e);
}

int _overlapMinutes(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  final diff = end.difference(start).inMinutes;
  return diff > 0 ? diff : 0;
}

int _overlapSeconds(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  final diff = end.difference(start).inSeconds;
  return diff > 0 ? diff : 0;
}

class DayCalcResult {
  const DayCalcResult({
    required this.dayType,
    required this.normalMinutes,
    required this.overtimeMinutes,
    required this.lateDeductionMoney,
    required this.pay,
  });

  final DayType dayType;
  final int normalMinutes;
  final int overtimeMinutes;
  final double lateDeductionMoney;
  final double pay;

  double get normalHours => normalMinutes / 60;
  double get overtimeHours => overtimeMinutes / 60;

  static const zero = DayCalcResult(
    dayType: DayType.weekday,
    normalMinutes: 0,
    overtimeMinutes: 0,
    lateDeductionMoney: 0,
    pay: 0,
  );
}

DayCalcResult computeDay(DayRecord record, AppSettings settings) {
  final dayType = dayTypeOf(record.date, settings.holidays);
  // Chưa chấm, nghỉ, hoặc mới chấm vào (chưa chấm ra — ca đang mở) thì chưa tính giờ/tiền.
  if (record.isDayOff || record.checkIn == null || record.checkOut == null) {
    return DayCalcResult(dayType: dayType, normalMinutes: 0, overtimeMinutes: 0, lateDeductionMoney: 0, pay: 0);
  }

  final checkIn = record.checkIn!;
  final checkOut = record.checkOut!;
  final (windowStart, windowEnd) = _span(settings.workStart, settings.workEnd, dateOnly(record.date));

  var normalMinutes = _overlapMinutes(checkIn, checkOut, windowStart, windowEnd);

  // Chỉ một khung khớp giờ vào được áp dụng (không cộng dồn nhiều khung).
  final checkInClock = Clock(checkIn.hour, checkIn.minute);
  final matchingRules = settings.breakRules.where((r) => r.matches(checkInClock));
  if (matchingRules.isNotEmpty) {
    normalMinutes += matchingRules.first.deltaMinutes;
  }

  var lateDeductionMoney = 0.0;
  if (record.isLate) {
    if (settings.lateRule.unit == LateUnit.minutes) {
      normalMinutes -= settings.lateRule.amount.round();
    } else {
      lateDeductionMoney = settings.lateRule.amount;
    }
  }
  if (normalMinutes < 0) normalMinutes = 0;

  // Tăng ca chỉ tính phần thật sự đã làm sau giờ ra: nếu chấm vào đã muộn hơn giờ ra
  // (ca ngắn nằm ngoài khung chuẩn) thì mốc bắt đầu tăng ca là giờ vào, không phải giờ ra.
  final overtimeStart = checkIn.isAfter(windowEnd) ? checkIn : windowEnd;
  int overtimeMinutes;
  if (checkOut.isAfter(overtimeStart) && settings.overtimeBrackets.isNotEmpty) {
    overtimeMinutes = 0;
    for (final bracket in settings.overtimeBrackets) {
      final (bStart, bEnd) = _span(bracket.from, bracket.to, dateOnly(windowEnd));
      final overlap = _overlapMinutes(overtimeStart, checkOut, bStart, bEnd);
      overtimeMinutes += overlap > 0 ? (overlap - bracket.breakMinutes).clamp(0, overlap) : 0;
    }
  } else if (checkOut.isAfter(overtimeStart)) {
    overtimeMinutes = checkOut.difference(overtimeStart).inMinutes;
  } else {
    overtimeMinutes = 0;
  }
  if (overtimeMinutes < 0) overtimeMinutes = 0;

  final wage = settings.wageTable.of(dayType);
  var pay = (normalMinutes / 60) * wage.normalPerHour + (overtimeMinutes / 60) * wage.overtimePerHour;
  pay -= lateDeductionMoney;
  if (pay < 0) pay = 0;

  return DayCalcResult(
    dayType: dayType,
    normalMinutes: normalMinutes,
    overtimeMinutes: overtimeMinutes,
    lateDeductionMoney: lateDeductionMoney,
    pay: pay,
  );
}

/// Ước tính lương đang kiếm được tính tới [now], chính xác theo **giây** — chỉ để hiện số chạy
/// mượt trên màn chính (khi ca đang mở). Áp dụng đúng các khoản cộng/trừ như [computeDay] (cộng
/// trừ giờ vào, đi muộn, tăng ca theo khung) để không bị tụt đột ngột lúc chấm ra và chuyển sang
/// số chính thức (tính theo phút).
double liveEstimatedPay(DayRecord record, AppSettings settings, DateTime now) {
  if (record.isDayOff || record.checkIn == null) return 0;
  if (record.checkOut != null) return computeDay(record, settings).pay;

  final dayType = dayTypeOf(record.date, settings.holidays);
  final wage = settings.wageTable.of(dayType);
  final (windowStart, windowEnd) = _span(settings.workStart, settings.workEnd, dateOnly(record.date));
  final checkIn = record.checkIn!;

  final normalStart = checkIn.isBefore(windowStart) ? windowStart : checkIn;
  final normalEnd = now.isBefore(windowEnd) ? now : windowEnd;
  var normalSeconds = normalEnd.isAfter(normalStart) ? normalEnd.difference(normalStart).inSeconds : 0;

  // Đúng 1 khung cộng trừ giờ khớp giờ vào — giống computeDay.
  final checkInClock = Clock(checkIn.hour, checkIn.minute);
  final matchingRules = settings.breakRules.where((r) => r.matches(checkInClock));
  if (matchingRules.isNotEmpty) {
    normalSeconds += matchingRules.first.deltaMinutes * 60;
  }

  var lateDeductionMoney = 0.0;
  if (record.isLate) {
    if (settings.lateRule.unit == LateUnit.minutes) {
      normalSeconds -= (settings.lateRule.amount * 60).round();
    } else {
      lateDeductionMoney = settings.lateRule.amount;
    }
  }
  if (normalSeconds < 0) normalSeconds = 0;

  final overtimeStart = checkIn.isAfter(windowEnd) ? checkIn : windowEnd;
  int overtimeSeconds;
  if (now.isAfter(overtimeStart) && settings.overtimeBrackets.isNotEmpty) {
    overtimeSeconds = 0;
    for (final bracket in settings.overtimeBrackets) {
      final (bStart, bEnd) = _span(bracket.from, bracket.to, dateOnly(windowEnd));
      final overlap = _overlapSeconds(overtimeStart, now, bStart, bEnd);
      overtimeSeconds += overlap > 0 ? (overlap - bracket.breakMinutes * 60).clamp(0, overlap) : 0;
    }
  } else if (now.isAfter(overtimeStart)) {
    overtimeSeconds = now.difference(overtimeStart).inSeconds;
  } else {
    overtimeSeconds = 0;
  }
  if (overtimeSeconds < 0) overtimeSeconds = 0;

  var pay = (normalSeconds / 3600) * wage.normalPerHour + (overtimeSeconds / 3600) * wage.overtimePerHour;
  pay -= lateDeductionMoney;
  return pay < 0 ? 0 : pay;
}

class PeriodStats {
  const PeriodStats({
    required this.period,
    required this.normalMinutes,
    required this.overtimeMinutes,
    required this.daysOff,
    required this.daysLate,
    required this.workDayCount,
    required this.attendanceIncome,
    required this.itemsIncome,
  });

  final PayPeriod period;
  final int normalMinutes;
  final int overtimeMinutes;
  final int daysOff;
  final int daysLate;
  final int workDayCount;
  final double attendanceIncome;
  final double itemsIncome;

  double get normalHours => normalMinutes / 60;
  double get overtimeHours => overtimeMinutes / 60;
  double get totalIncome => attendanceIncome + itemsIncome;
}

/// [recordsInPeriod] chỉ cần chứa các bản ghi có trong khoảng [period]; ngày không có bản ghi coi như chưa chấm.
/// [manualItemAmount] trả về số tiền đã nhập tay cho khoản có calcMethod = manual trong kỳ này (null nếu chưa nhập).
PeriodStats computePeriodStats(
  PayPeriod period,
  Iterable<DayRecord> recordsInPeriod,
  AppSettings settings, {
  double? Function(IncomeItem item)? manualItemAmount,
}) {
  var normalMinutes = 0;
  var overtimeMinutes = 0;
  var daysOff = 0;
  var daysLate = 0;
  var workDayCount = 0;
  var attendanceIncome = 0.0;

  for (final record in recordsInPeriod) {
    if (record.isDayOff) {
      daysOff++;
      continue;
    }
    if (record.isLate) daysLate++;
    if (record.hasAttendance) workDayCount++;
    final result = computeDay(record, settings);
    normalMinutes += result.normalMinutes;
    overtimeMinutes += result.overtimeMinutes;
    attendanceIncome += result.pay;
  }

  var itemsIncome = 0.0;
  for (final item in settings.incomeItems) {
    final sign = item.type == IncomeItemType.income ? 1 : -1;
    double amount;
    switch (item.calcMethod) {
      case IncomeCalcMethod.fixed:
        amount = item.amount;
      case IncomeCalcMethod.perWorkDay:
        amount = item.amount * workDayCount;
      case IncomeCalcMethod.manual:
        amount = manualItemAmount?.call(item) ?? 0;
    }
    itemsIncome += sign * amount;
  }

  return PeriodStats(
    period: period,
    normalMinutes: normalMinutes,
    overtimeMinutes: overtimeMinutes,
    daysOff: daysOff,
    daysLate: daysLate,
    workDayCount: workDayCount,
    attendanceIncome: attendanceIncome,
    itemsIncome: itemsIncome,
  );
}
