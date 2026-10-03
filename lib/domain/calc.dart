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
    this.breakRuleWarning = false,
    this.breakRuleDeltaMinutes = 0,
  });

  final DayType dayType;
  final int normalMinutes;
  final int overtimeMinutes;
  final double lateDeductionMoney;
  final double pay;

  /// true nếu giờ vào/ra không khớp chính xác khung cộng-trừ giờ nào, phải dùng khung cuối
  /// (dự phòng) để tính tạm — cần cảnh báo người dùng chấm lại cho đúng.
  final bool breakRuleWarning;

  /// Số phút cộng/trừ đã áp dụng (dù khớp đúng khung hay dùng khung dự phòng), để hiện trong cảnh báo.
  final int breakRuleDeltaMinutes;

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

/// Tìm cách cộng-trừ giờ áp dụng cho ca [checkInDt]-[checkOutDt]: khớp khung cố định nào (giờ vào
/// VÀ giờ ra đều nằm trong khoảng đã cài) thì dùng khung đó; không khung nào khớp thì chuyển qua
/// tính theo "khung nhiều mục" (cộng dồn các đoạn mà giờ làm có chạm vào), kèm cảnh báo.
(int deltaMinutes, bool warning) _resolveBreakRule(AppSettings settings, DateTime checkInDt, DateTime checkOutDt) {
  final checkIn = Clock(checkInDt.hour, checkInDt.minute);
  final checkOut = Clock(checkOutDt.hour, checkOutDt.minute);
  for (final r in settings.fixedBreakRules) {
    if (r.matches(checkIn, checkOut, normalEnd: settings.workEnd)) return (r.deltaMinutes, false);
  }
  if (settings.fixedBreakRules.isEmpty && settings.breakSegments.isEmpty) return (0, false);

  var segDelta = 0;
  for (final seg in settings.breakSegments) {
    final (sStart, sEnd) = _span(seg.from, seg.to, dateOnly(checkInDt));
    if (_overlapMinutes(checkInDt, checkOutDt, sStart, sEnd) > 0) segDelta -= seg.breakMinutes;
  }
  return (segDelta, true);
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

  // Khớp khung cố định (giờ vào & giờ ra đều trong khoảng đã cài) thì dùng khung đó; không khớp
  // khung nào thì chuyển qua "khung nhiều mục" làm dự phòng, kèm cảnh báo để chấm lại cho đúng.
  final (breakRuleDelta, breakRuleWarning) = _resolveBreakRule(settings, checkIn, checkOut);
  normalMinutes += breakRuleDelta;

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
    DateTime? lastBracketEnd;
    for (final bracket in settings.overtimeBrackets) {
      final (bStart, bEnd) = _span(bracket.from, bracket.to, dateOnly(windowEnd));
      final overlap = _overlapMinutes(overtimeStart, checkOut, bStart, bEnd);
      overtimeMinutes += overlap > 0 ? (overlap - bracket.breakMinutes).clamp(0, overlap) : 0;
      if (lastBracketEnd == null || bEnd.isAfter(lastBracketEnd)) lastBracketEnd = bEnd;
    }
    // Làm quá khung tăng ca cuối cùng đã cài (vd làm rất khuya): phần dư vẫn tính theo hệ số
    // tăng ca, không bỏ trắng — các khung chỉ định nghĩa chỗ trừ nghỉ, không phải giới hạn trả tiền.
    if (lastBracketEnd != null && checkOut.isAfter(lastBracketEnd)) {
      overtimeMinutes += checkOut.difference(lastBracketEnd).inMinutes;
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
    breakRuleWarning: breakRuleWarning,
    breakRuleDeltaMinutes: breakRuleDelta,
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

  // Ca đang mở, chưa có giờ ra nên chưa thể biết khớp khung cố định nào — tạm tính theo "khung
  // nhiều mục" (nếu có) để số chạy mượt; nếu lúc chấm ra khớp đúng khung cố định, số sẽ chốt lại
  // theo khung đó, có thể nhảy nhẹ đúng lúc đó.
  // Trừ dần theo tỷ lệ đã đi qua đoạn đó (không trừ nguyên cả đoạn ngay khi vừa chạm vào), để số
  // không bị kẹp về 0 đứng yên một lúc rồi mới nhảy — khi đã đi hết đoạn, tỷ lệ = 1 nên trừ đủ
  // nguyên, khớp đúng số chính thức (computeDay) lúc chấm ra.
  for (final seg in settings.breakSegments) {
    final (sStart, sEnd) = _span(seg.from, seg.to, dateOnly(record.date));
    final overlap = _overlapSeconds(checkIn, now, sStart, sEnd);
    if (overlap <= 0) continue;
    final segSeconds = sEnd.difference(sStart).inSeconds;
    if (segSeconds <= 0) continue;
    final fraction = overlap / segSeconds;
    normalSeconds -= (seg.breakMinutes * 60 * fraction).round();
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
    DateTime? lastBracketEnd;
    for (final bracket in settings.overtimeBrackets) {
      final (bStart, bEnd) = _span(bracket.from, bracket.to, dateOnly(windowEnd));
      final overlap = _overlapSeconds(overtimeStart, now, bStart, bEnd);
      overtimeSeconds += overlap > 0 ? (overlap - bracket.breakMinutes * 60).clamp(0, overlap) : 0;
      if (lastBracketEnd == null || bEnd.isAfter(lastBracketEnd)) lastBracketEnd = bEnd;
    }
    // Quá khung tăng ca cuối cùng (vd còn đang làm rất khuya) — số vẫn chạy tiếp theo hệ số tăng
    // ca, khớp với computeDay, không đứng yên.
    if (lastBracketEnd != null && now.isAfter(lastBracketEnd)) {
      overtimeSeconds += now.difference(lastBracketEnd).inSeconds;
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

/// Phần thu nhập/khấu trừ tự tạo tính cho riêng hôm nay, chạy mượt theo giây — chỉ dùng để cộng
/// thêm vào số "hôm nay"/số chạy sống trên màn chính (không đụng tới tổng chính thức của cả kỳ,
/// vốn đã cộng trọn phần của mỗi khoản qua [computePeriodStats]).
///
/// Mỗi khoản được chia đều cho [workDayCountInPeriod] ngày công của kỳ để ra "phần của hôm nay",
/// rồi phần đó chạy dần từ lúc chấm vào (hoặc từ [IncomeItem.activeAfter] nếu khoản có mốc giờ,
/// ví dụ tiền cơm trưa chỉ tính từ 13:00) tới giờ ra chuẩn — chạm mốc giờ ra là nhận đủ, không chờ
/// qua kỳ mới thấy.
double liveItemsEstimate(DayRecord record, AppSettings settings, DateTime now, int workDayCountInPeriod) {
  if (!settings.includeItemsInEstimate) return 0;
  if (record.isDayOff || record.checkIn == null || workDayCountInPeriod <= 0) return 0;

  final (windowStart, windowEnd) = _span(settings.workStart, settings.workEnd, dateOnly(record.date));
  final checkIn = record.checkIn!;
  final shiftStart = checkIn.isBefore(windowStart) ? windowStart : checkIn;
  if (!windowEnd.isAfter(shiftStart)) return 0;
  final nowCapped = record.checkOut ?? now;

  var total = 0.0;
  for (final item in settings.incomeItems) {
    final sign = item.type == IncomeItemType.income ? 1 : -1;
    double periodAmount;
    switch (item.calcMethod) {
      case IncomeCalcMethod.fixed:
        periodAmount = item.amount;
      case IncomeCalcMethod.perWorkDay:
        periodAmount = item.amount * workDayCountInPeriod;
      case IncomeCalcMethod.percentOfBaseSalary:
        periodAmount = settings.baseSalary * (item.amount / 100);
    }
    final dailyShare = periodAmount / workDayCountInPeriod;

    var itemStart = shiftStart;
    if (item.activeAfter != null) {
      final gate = _anchor(item.activeAfter!, dateOnly(record.date));
      if (gate.isAfter(itemStart)) itemStart = gate;
    }
    // Mẫu số là khoảng hoạt động CỦA RIÊNG khoản này (không phải cả ca) — để khoản có mốc giờ
    // (vd tiền cơm sau 13h) vẫn nhận đủ phần của ngày đúng lúc tới giờ ra chuẩn, không bị "ăn non"
    // vì mốc giờ bắt đầu muộn hơn đầu ca.
    final itemWindowSeconds = windowEnd.difference(itemStart).inSeconds;
    if (itemWindowSeconds <= 0) continue;
    var itemEnd = nowCapped.isBefore(itemStart) ? itemStart : nowCapped;
    if (itemEnd.isAfter(windowEnd)) itemEnd = windowEnd;
    final elapsed = itemEnd.difference(itemStart).inSeconds;
    final fraction = (elapsed <= 0 ? 0.0 : elapsed / itemWindowSeconds).clamp(0.0, 1.0);
    total += sign * dailyShare * fraction;
  }
  return total;
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
PeriodStats computePeriodStats(PayPeriod period, Iterable<DayRecord> recordsInPeriod, AppSettings settings) {
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

  // Khoản thu nhập/khấu trừ tự tạo chỉ cộng vào số ước tính khi người dùng bật "cộng thêm thu
  // nhập/khấu trừ" trong Cài đặt — tắt thì các khoản này chỉ để tham khảo.
  var itemsIncome = 0.0;
  if (settings.includeItemsInEstimate) {
    for (final item in settings.incomeItems) {
      final sign = item.type == IncomeItemType.income ? 1 : -1;
      double amount;
      switch (item.calcMethod) {
        case IncomeCalcMethod.fixed:
          amount = item.amount;
        case IncomeCalcMethod.perWorkDay:
          amount = item.amount * workDayCount;
        case IncomeCalcMethod.percentOfBaseSalary:
          amount = settings.baseSalary * (item.amount / 100);
      }
      itemsIncome += sign * amount;
    }
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
