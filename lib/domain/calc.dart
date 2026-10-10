/// Công thức tính giờ công, tăng ca, đi muộn của một ngày. Tiền lương tính ở `payslip.dart`.
library;

import 'models.dart';

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

  /// Tiền theo đúng bảng lương/giờ (cách tính của bản cũ). Phiếu lương (`payslip.dart`) không dùng
  /// số này; chỉ còn để đối chiếu khi chuyển dữ liệu của bản cũ.
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

/// Từ giờ này trở đi mà ca của hôm nay vẫn chưa có giờ về thì coi là quên chấm về.
const missedCheckOutHour = 23;

/// Ngày đã chấm vào nhưng không có giờ về: ca của một ngày đã qua, hoặc ca hôm nay khi đã qua
/// [missedCheckOutHour] giờ. Ngày như vậy được báo đỏ trên lịch để người dùng chấm lại giờ về; ca
/// của ngày đã qua không được tính giờ nào cho tới khi có giờ về.
bool isMissedCheckOut(DayRecord record, DateTime now) {
  if (record.isDayOff || record.checkIn == null || record.checkOut != null) return false;
  // GPS thấy đã rời hẳn mà không xác định được giờ về: báo đỏ ngay, không chờ tới 23:00.
  if (record.gpsLeftUnknown) return true;
  final day = dateOnly(record.date);
  final today = dateOnly(now);
  return day.isBefore(today) || (day == today && now.hour >= missedCheckOutHour);
}

/// Giờ nghỉ trưa: khoảng này không được tính giờ công (áp dụng mọi ngày, mọi người dùng).
const lunchBreakFrom = Clock(11, 30);
const lunchBreakTo = Clock(12, 30);

/// Số phút giờ công bị trừ vì giờ nghỉ trưa: phần giờ làm (trong khung chuẩn [windowStart]-
/// [windowEnd]) rơi vào [lunchBreakFrom]-[lunchBreakTo]. Ngoại lệ: chấm ra trước khi hết giờ nghỉ
/// (ví dụ về lúc 12:00) thì phần nằm trong giờ nghỉ vẫn được tính, không trừ.
int _lunchBreakMinutes(DateTime checkIn, DateTime checkOut, DateTime windowStart, DateTime windowEnd) {
  final (breakStart, breakEnd) = _span(lunchBreakFrom, lunchBreakTo, dateOnly(windowStart));
  if (checkOut.isBefore(breakEnd)) return 0;
  final from = checkIn.isAfter(windowStart) ? checkIn : windowStart;
  final to = checkOut.isBefore(windowEnd) ? checkOut : windowEnd;
  return _overlapMinutes(from, to, breakStart, breakEnd);
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

  normalMinutes -= _lunchBreakMinutes(checkIn, checkOut, windowStart, windowEnd);

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
  );
}

/// Số giây giờ thường / tăng ca của một ca **đang mở** tính tới [now], chính xác theo giây — để số
/// trên màn chính chạy mượt. Áp dụng giờ nghỉ trưa, đi muộn và tăng ca theo khung như [computeDay];
/// lúc chấm ra, số giây khớp với số phút của [computeDay] (trừ phần lẻ giây).
class LiveDayHours {
  const LiveDayHours({required this.normalSeconds, required this.overtimeSeconds, required this.lateDeductionMoney});

  final int normalSeconds;
  final int overtimeSeconds;
  final double lateDeductionMoney;

  static const zero = LiveDayHours(normalSeconds: 0, overtimeSeconds: 0, lateDeductionMoney: 0);
}

/// Đã chấm ra thì lấy đúng số của [computeDay]; ca đang mở thì đếm tới [now].
LiveDayHours liveDayHours(DayRecord record, AppSettings settings, DateTime now) {
  if (record.isDayOff || record.checkIn == null) return LiveDayHours.zero;
  if (record.checkOut != null) {
    final r = computeDay(record, settings);
    return LiveDayHours(
      normalSeconds: r.normalMinutes * 60,
      overtimeSeconds: r.overtimeMinutes * 60,
      lateDeductionMoney: r.lateDeductionMoney,
    );
  }

  final (windowStart, windowEnd) = _span(settings.workStart, settings.workEnd, dateOnly(record.date));
  final checkIn = record.checkIn!;

  final normalStart = checkIn.isBefore(windowStart) ? windowStart : checkIn;
  final normalEnd = now.isBefore(windowEnd) ? now : windowEnd;
  var normalSeconds = normalEnd.isAfter(normalStart) ? normalEnd.difference(normalStart).inSeconds : 0;

  // Số đứng yên suốt giờ nghỉ trưa. Nếu chấm ra ngay trong giờ nghỉ (về sớm, ví dụ 12:00) thì
  // phần giờ nghỉ đã qua vẫn được tính, nên lúc chấm ra số nhảy lên đúng phần đó.
  final (breakStart, breakEnd) = _span(lunchBreakFrom, lunchBreakTo, dateOnly(windowStart));
  normalSeconds -= _overlapSeconds(normalStart, normalEnd, breakStart, breakEnd);

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

  return LiveDayHours(normalSeconds: normalSeconds, overtimeSeconds: overtimeSeconds, lateDeductionMoney: lateDeductionMoney);
}

/// Tiền theo đúng bảng lương/giờ (cách tính của bản cũ, trước khi có phiếu lương) tính tới [now].
/// Phiếu lương không dùng hàm này; chỉ còn để đối chiếu (test chuyển dữ liệu của bản cũ).
double liveEstimatedPay(DayRecord record, AppSettings settings, DateTime now) {
  if (record.isDayOff || record.checkIn == null) return 0;
  if (record.checkOut != null) return computeDay(record, settings).pay;
  final wage = settings.wageTable.of(dayTypeOf(record.date, settings.holidays));
  final live = liveDayHours(record, settings, now);
  final pay =
      (live.normalSeconds / 3600) * wage.normalPerHour +
      (live.overtimeSeconds / 3600) * wage.overtimePerHour -
      live.lateDeductionMoney;
  return pay < 0 ? 0 : pay;
}

