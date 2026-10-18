/// Phiếu lương của một kỳ (thuần Dart, không phụ thuộc Flutter).
///
/// Đây là bộ tính tiền **duy nhất** của app: thẻ thu nhập ở màn chính, số "Hôm nay", tiền từng ngày
/// trên lịch, thống kê theo kỳ và file Excel đều lấy số từ đây. Quy tắc ghi ở mục 3 của
/// `THIET-KE-BAN-MOI.md`. Bên trong luôn tính bằng số lẻ, không làm tròn; chỗ hiển thị mới bỏ phần lẻ.
library;

import 'calc.dart';
import 'leave.dart';
import 'models.dart';
import 'pay_period.dart';

/// Mã dòng "Đi muộn" (đi muộn trừ tiền). Dòng này không nằm trong danh sách khoản của cài đặt.
const payItemLate = 'late';

/// Nghỉ không lương từ ngần này ngày làm việc trở lên trong tháng thì tháng đó không đóng bảo hiểm.
const insuranceSkipUnpaidDays = 14;

/// Một dòng của phiếu lương.
class PayslipLine {
  const PayslipLine({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.how,
    this.item,
  });

  final String id;
  final String name;
  final IncomeItemType type;

  /// Luôn là số không âm; dòng khấu trừ thì trừ đi khi cộng tổng.
  final double amount;

  /// Dòng nhỏ giải thích công thức, ví dụ "4.000.000 ÷ 26 × 24,5 ngày".
  final String how;

  /// Khoản trong cài đặt sinh ra dòng này (null với dòng "Đi muộn").
  final IncomeItem? item;

  double get signed => type == IncomeItemType.income ? amount : -amount;
}

/// Cách tính bù tăng ca: một ngày thiếu giờ (hoặc nghỉ không lương) và số giờ tăng ca đã lấy bù.
class OvertimeOffsetDay {
  const OvertimeOffsetDay({
    required this.date,
    required this.dayOff,
    this.companyOff = false,
    this.late = false,
    required this.shortSeconds,
    required this.coveredSeconds,
  });

  final DateTime date;

  /// Ngày nghỉ không lương (thiếu trọn mốc của ngày); false là ngày có đi làm nhưng thiếu giờ.
  final bool dayOff;

  /// Ngày nghỉ do công ty cho nghỉ (chỉ có nghĩa khi [dayOff]); false là tự nghỉ đã hết phép.
  final bool companyOff;

  /// Ngày thiếu giờ vì tự đi muộn (đã bấm "Đi muộn").
  final bool late;

  /// Số giây thiếu so với mốc đủ công của ngày.
  final int shortSeconds;

  /// Số giây tăng ca đã lấy bù (không quá [shortSeconds]; tăng ca của kỳ hết thì nhỏ hơn).
  final int coveredSeconds;
}

class Payslip {
  const Payslip({
    required this.period,
    required this.kind,
    required this.ended,
    required this.autoStandardDays,
    required this.standardDays,
    required this.standardOverridden,
    required this.workDays,
    required this.normalSeconds,
    required this.overtimeSeconds,
    required this.allNormalSeconds,
    required this.daysOff,
    required this.paidLeaveDays,
    required this.daysLate,
    required this.daysWorked,
    required this.incomes,
    required this.deductions,
    required this.dayAmounts,
    this.overtimeOffset = false,
    this.offsetDays = const [],
    this.autoWorkDays = 0,
    this.autoOvertimeSeconds = 0,
    this.workDaysOverridden = false,
    this.overtimeOverridden = false,
    this.leaveUsedDays = 0,
    this.leaveBalance = 0,
    this.leaveDates = const {},
  });

  final PayPeriod period;
  final WorkerKind kind;

  /// Kỳ đã kết thúc (hôm nay sau ngày cuối kỳ). Chưa kết thúc thì phiếu là "Tạm tính".
  final bool ended;

  /// Công chuẩn app tự đếm: số ngày trong kỳ trừ các chủ nhật.
  final int autoStandardDays;

  /// Công chuẩn đang dùng (số sửa tay của kỳ này nếu có, không thì [autoStandardDays]).
  final double standardDays;
  final bool standardOverridden;

  /// Ngày công thực tế (công nhân) = tổng giờ thường các ngày T2–T7 không phải lễ ÷ 8.
  final double workDays;

  /// Giờ công: giờ thường của các ngày T2–T7 không phải lễ (giây).
  final int normalSeconds;

  /// Tăng ca: giờ tăng ca T2–T7 cộng toàn bộ giờ làm chủ nhật và ngày lễ (giây).
  final int overtimeSeconds;

  /// Giờ thường của mọi ngày, kể cả chủ nhật và lễ (giây). Dùng cho dòng giải thích của công nhật.
  final int allNormalSeconds;

  final int daysOff;

  /// Số ngày nghỉ có lương trong kỳ (nằm trong [daysOff]); mỗi ngày tính một ngày lương cơ bản.
  final int paidLeaveDays;
  final int daysLate;

  /// Số ngày có đi làm (ca đã chấm ra, hoặc ca đang mở của hôm nay).
  final int daysWorked;

  final List<PayslipLine> incomes;
  final List<PayslipLine> deductions;

  /// Phần đóng góp của từng ngày vào Thực nhận (khóa là ngày, 00:00). Tổng các ngày bằng Thực nhận,
  /// trừ khoản cố định của công nhật (không chia theo ngày).
  final Map<DateTime, double> dayAmounts;

  /// Kỳ này tính theo cách bù tăng ca (công nhân bật công tắc ở Cài đặt).
  final bool overtimeOffset;

  /// Các ngày thiếu giờ được lấy tăng ca bù, theo thứ tự ngày.
  final List<OvertimeOffsetDay> offsetDays;

  /// Ngày công thực tế và giờ tăng ca app tự tính (trước khi người dùng sửa tay số của kỳ).
  final double autoWorkDays;
  final int autoOvertimeSeconds;
  final bool workDaysOverridden;
  final bool overtimeOverridden;

  /// Số ngày tự nghỉ trong kỳ được tính là nghỉ phép (nằm trong [paidLeaveDays]).
  final int leaveUsedDays;

  /// Số ngày phép còn lại sau kỳ này (bật bù tăng ca).
  final double leaveBalance;

  /// Các ngày tự nghỉ trong kỳ được tính là nghỉ phép.
  final Set<DateTime> leaveDates;

  /// Ngày [date] có thiếu giờ được tính bù không (null là không).
  OvertimeOffsetDay? offsetOn(DateTime date) {
    final d = dateOnly(date);
    for (final o in offsetDays) {
      if (o.date == d) return o;
    }
    return null;
  }

  /// Tổng giờ tăng ca bị trừ để bù (giây). [overtimeSeconds] là số còn lại sau khi trừ.
  int get offsetTakenSeconds => offsetDays.fold(0, (s, d) => s + d.coveredSeconds);

  /// Giờ còn thiếu vì tăng ca của kỳ không đủ bù (giây).
  int get offsetUncoveredSeconds => offsetDays.fold(0, (s, d) => s + d.shortSeconds - d.coveredSeconds);

  double get totalIncome => incomes.fold(0.0, (s, l) => s + l.amount);
  double get totalDeduction => deductions.fold(0.0, (s, l) => s + l.amount);

  /// Thực nhận.
  double get net => totalIncome - totalDeduction;

  int get normalMinutes => normalSeconds ~/ 60;
  int get overtimeMinutes => overtimeSeconds ~/ 60;

  double amountOn(DateTime date) => dayAmounts[dateOnly(date)] ?? 0;
}

/// Công chuẩn app tự đếm của một kỳ: số ngày trong kỳ trừ các chủ nhật.
int autoStandardDaysOf(PayPeriod period) {
  var count = 0;
  for (var d = period.start; !d.isAfter(period.end); d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday != DateTime.sunday) count++;
  }
  return count;
}

/// Lương cơ bản và các mức theo tháng của công nhân được nhân với hệ số này để ra mức của một kỳ:
/// kỳ theo tháng là 1, chia 2 kỳ một tháng là ½.
double monthFractionOf(PayPeriodConfig cfg) => cfg.type == PayPeriodType.monthly ? 1 : 0.5;

/// Lương giờ thường T2–T7 tự tính của công nhân = lương cơ bản ÷ công chuẩn ÷ 8.
double workerAutoHourlyRate(AppSettings settings, double standardDays) =>
    standardDays > 0 ? settings.baseSalary * monthFractionOf(settings.payPeriod) / standardDays / 8 : 0;

/// Giá một giờ theo bảng lương/giờ. Công nhật: ô nào bằng 0 thì tự lấy lương ngày ÷ 8.
double tableRate(AppSettings settings, DayType type, {required bool overtime}) {
  final rate = settings.wageTable.of(type);
  final value = overtime ? rate.overtimePerHour : rate.normalPerHour;
  if (settings.workerKind == WorkerKind.daily && value <= 0) return settings.dailyWage / 8;
  return value;
}

/// Phiếu lương của [period]. [recordOf] trả về dữ liệu chấm công của một ngày (ngày chưa chấm thì
/// trả về bản ghi trống). [now] là thời điểm hiện tại: ca đang mở của hôm nay tính tới [now] theo
/// giây; ca mở của ngày cũ (quên chấm ra) coi như chưa có giờ.
Payslip computePayslip({
  required AppSettings settings,
  required PayPeriod period,
  required DayRecord Function(DateTime date) recordOf,
  required DateTime now,
}) {
  // Phần lương (lương cơ bản, các khoản) lấy theo đúng kỳ này, không lấy số của kỳ khác.
  settings = settings.payFor(period.start);
  final today = dateOnly(now);
  final worker = settings.workerKind == WorkerKind.worker;
  final items = settings.incomeItems;
  final perDayItems = items.where((i) => i.calcMethod == IncomeCalcMethod.perWorkDay).toList();
  final hasOvertimeLine = items.any((i) => i.calcMethod == IncomeCalcMethod.overtime);

  // --- Lượt 1: đi qua từng ngày trong kỳ, gom giờ và tiền theo ngày. ---
  final dayWork = <DateTime, double>{}; // ngày công của ngày (công nhân)
  final daySalary = <DateTime, double>{}; // tiền lương theo giờ của ngày (công nhật)
  final dayOvertime = <DateTime, double>{}; // tiền tăng ca của ngày
  final dayLate = <DateTime, double>{};
  final paidLeaveDays = <DateTime>[]; // ngày nghỉ có lương: mỗi ngày tính một ngày lương cơ bản
  final dayItemCounts = <String, Set<DateTime>>{for (final i in perDayItems) i.id: {}};
  // Giây làm theo (nhóm, giá) để viết dòng giải thích, ví dụ ('Tăng ca', 45000) -> 12h.
  final overtimeGroups = <(String, double), int>{};
  final salaryGroups = <double, int>{};

  // Bù tăng ca: các ngày thiếu giờ (ngày, nghỉ không lương?, giây thiếu) và các phần giờ tăng ca có
  // thể lấy ra bù (ngày, giây, giá một giờ, nhóm của dòng giải thích).
  final offset = settings.usesOvertimeOffset;
  final offsetAll = offset && settings.offsetMode == OvertimeOffsetMode.all;
  // Ngày tự nghỉ được trừ vào phép (tính như nghỉ có lương).
  final leave = offset ? leaveState(settings, recordOf, period.end) : null;
  var leaveUsedDays = 0;
  final shortages = <({DateTime date, bool dayOff, bool companyOff, bool late, int seconds})>[];
  final pool = <({DateTime date, int seconds, double rate, String group, bool regular})>[];

  var normalSeconds = 0;
  var allNormalSeconds = 0;
  var overtimeSeconds = 0;
  var daysOff = 0;
  var daysLate = 0;
  var daysWorked = 0;
  var lateCount = 0;

  void addGroup<K>(Map<K, int> map, K key, int seconds) {
    if (seconds > 0) map[key] = (map[key] ?? 0) + seconds;
  }

  for (var d = period.start; !d.isAfter(period.end); d = DateTime(d.year, d.month, d.day + 1)) {
    final record = recordOf(d);
    if (record.isDayOff) {
      daysOff++;
      final onLeave = leave?.used.contains(d) ?? false;
      if (onLeave) leaveUsedDays++;
      if (record.paidLeave || onLeave) paidLeaveDays.add(d);
      // Nghỉ không lương: công ty cho nghỉ thì luôn bù; tự nghỉ (đã hết phép) chỉ bù ở mức "bù cả ngày
      // tự nghỉ". Bù đủ mốc của ngày; chủ nhật, lễ thì không.
      final full = offsetFullDaySeconds(dayTypeOf(d, settings.holidays));
      final eligible = !record.paidLeave && !onLeave && (record.companyOff || offsetAll);
      if (offset && eligible && full > 0) {
        shortages.add((date: d, dayOff: true, companyOff: record.companyOff, late: false, seconds: full));
      }
      continue;
    }
    if (record.isLate) daysLate++;
    final closed = (record.checkIn != null && record.checkOut != null) || record.hasManualHours;
    final openToday = record.isOpenShift && dateOnly(record.date) == today;
    if (!closed && !openToday) continue;
    daysWorked++;

    final hours = liveDayHours(record, settings, now);
    final type = dayTypeOf(d, settings.holidays);
    final regularDay = type == DayType.weekday || type == DayType.saturday;
    final nSec = hours.normalSeconds;
    final oSec = hours.overtimeSeconds;
    allNormalSeconds += nSec;

    if (regularDay) {
      normalSeconds += nSec;
      overtimeSeconds += oSec;
    } else {
      overtimeSeconds += nSec + oSec;
    }

    final normalRate = tableRate(settings, type, overtime: false);
    final overtimeRate = tableRate(settings, type, overtime: true);
    final groupName = switch (type) {
      DayType.sunday => 'chủ nhật',
      DayType.holiday => 'lễ',
      _ => 'Tăng ca',
    };

    if (offset) {
      // Ca đang mở của hôm nay chưa tính là thiếu giờ; giờ tăng ca đã làm thì vẫn lấy bù được.
      // Thiếu giờ do công ty (vào muộn, về sớm theo yêu cầu) thì luôn bù; tự đi muộn (đã bấm "Đi muộn")
      // chỉ bù ở mức "bù cả ngày tự nghỉ", còn không thì trừ theo luật đi muộn.
      final short = offsetFullDaySeconds(type) - nSec;
      if (closed && regularDay && short > 0 && (!record.isLate || offsetAll)) {
        shortages.add((date: d, dayOff: false, companyOff: false, late: record.isLate, seconds: short));
      }
      if (regularDay) {
        if (oSec > 0) pool.add((date: d, seconds: oSec, rate: overtimeRate, group: groupName, regular: true));
      } else {
        if (nSec > 0) pool.add((date: d, seconds: nSec, rate: normalRate, group: groupName, regular: false));
        if (oSec > 0) pool.add((date: d, seconds: oSec, rate: overtimeRate, group: groupName, regular: false));
      }
    }

    if (worker) {
      if (regularDay) {
        dayWork[d] = nSec / 3600 / 8;
        dayOvertime[d] = oSec / 3600 * overtimeRate;
        addGroup(overtimeGroups, (groupName, overtimeRate), oSec);
      } else {
        // Chủ nhật và ngày lễ không tính ngày công: mọi giờ làm tính theo bảng lương/giờ.
        dayOvertime[d] = nSec / 3600 * normalRate + oSec / 3600 * overtimeRate;
        addGroup(overtimeGroups, (groupName, normalRate), nSec);
        addGroup(overtimeGroups, (groupName, overtimeRate), oSec);
      }
    } else {
      // Công nhật: giờ thường vào Tiền lương; giờ tăng ca vào dòng tăng ca nếu có dòng đó, không thì
      // cũng vào Tiền lương.
      daySalary[d] = nSec / 3600 * normalRate + (hasOvertimeLine ? 0 : oSec / 3600 * overtimeRate);
      addGroup(salaryGroups, normalRate, nSec);
      if (hasOvertimeLine) {
        dayOvertime[d] = oSec / 3600 * overtimeRate;
        addGroup(overtimeGroups, (groupName, overtimeRate), oSec);
      } else {
        addGroup(salaryGroups, overtimeRate, oSec);
      }
    }

    if (hours.lateDeductionMoney > 0) {
      dayLate[d] = hours.lateDeductionMoney;
      lateCount++;
    }

    final endOfShift = record.checkOut ?? now;
    for (final item in perDayItems) {
      final gate = item.activeAfter;
      final passed =
          gate == null || !endOfShift.isBefore(DateTime(d.year, d.month, d.day, gate.hour, gate.minute));
      if (passed) dayItemCounts[item.id]!.add(d);
    }
  }

  // --- Bù tăng ca: lấy giờ tăng ca trong kỳ bù vào các ngày thiếu giờ, theo thứ tự ngày. Lấy giờ
  // tăng ca T2–T7 trước, rồi mới tới chủ nhật, ngày lễ (cùng nhóm thì giờ rẻ trước, rồi theo ngày);
  // 1 giờ tăng ca bù 1 giờ thường.
  // Giờ đã lấy chuyển thành ngày công của ngày thiếu và bớt khỏi tiền tăng ca của ngày làm thêm.
  final offsetDays = <OvertimeOffsetDay>[];
  if (offset) {
    final order = [for (var i = 0; i < pool.length; i++) i]
      ..sort((a, b) {
        if (pool[a].regular != pool[b].regular) return pool[a].regular ? -1 : 1;
        final byRate = pool[a].rate.compareTo(pool[b].rate);
        return byRate != 0 ? byRate : a.compareTo(b);
      });
    final left = [for (final c in pool) c.seconds];
    var next = 0;
    for (final sh in shortages) {
      final day = sh.date;
      final short = sh.seconds;
      var need = short;
      while (need > 0 && next < order.length) {
        final i = order[next];
        final chunk = pool[i];
        final take = need < left[i] ? need : left[i];
        left[i] -= take;
        need -= take;
        if (left[i] == 0) next++;
        dayWork[day] = (dayWork[day] ?? 0) + take / 3600 / 8;
        dayOvertime[chunk.date] = (dayOvertime[chunk.date] ?? 0) - take / 3600 * chunk.rate;
        final key = (chunk.group, chunk.rate);
        final rest = (overtimeGroups[key] ?? 0) - take;
        if (rest > 0) {
          overtimeGroups[key] = rest;
        } else {
          overtimeGroups.remove(key);
        }
        normalSeconds += take;
        overtimeSeconds -= take;
      }
      offsetDays.add(
        OvertimeOffsetDay(
          date: day,
          dayOff: sh.dayOff,
          companyOff: sh.companyOff,
          late: sh.late,
          shortSeconds: short,
          coveredSeconds: short - need,
        ),
      );
    }
  }
  final offsetTaken = offsetDays.fold(0, (s, d) => s + d.coveredSeconds);

  // --- Số người dùng sửa tay cho kỳ (theo số công ty chốt): ngày công thực tế và giờ tăng ca. Tiền
  // của từng ngày được co giãn theo tỷ lệ để tổng vẫn khớp.
  final autoWorkDays = dayWork.values.fold(0.0, (s, v) => s + v);
  final autoOvertimeSeconds = overtimeSeconds;
  final workDaysOverride = worker ? settings.workDaysOverride[period.key] : null;
  if (workDaysOverride != null && autoWorkDays > 0) {
    final f = workDaysOverride / autoWorkDays;
    dayWork.updateAll((d, w) => w * f);
  }
  final overtimeOverride = worker ? settings.overtimeHoursOverride[period.key] : null;
  var extraOvertimeMoney = 0.0;
  if (overtimeOverride != null) {
    final target = (overtimeOverride * 3600).round();
    if (autoOvertimeSeconds > 0) {
      final f = target / autoOvertimeSeconds;
      dayOvertime.updateAll((d, v) => v * f);
    } else {
      // Chưa có giờ tăng ca nào để chia: tính theo giá tăng ca T2–T7, không chia cho ngày nào.
      extraOvertimeMoney = overtimeOverride * tableRate(settings, DayType.weekday, overtime: true);
    }
    overtimeSeconds = target;
  }

  // --- Lượt 2: lập các dòng của phiếu. ---
  final ended = today.isAfter(period.end);
  final autoStd = autoStandardDaysOf(period);
  final overriddenStd = settings.standardDays[period.key];
  final std = worker ? (overriddenStd ?? autoStd.toDouble()) : 0.0;
  final workDays = workDaysOverride ?? dayWork.values.fold<double>(0.0, (s, v) => s + v);
  final monthFraction = monthFractionOf(settings.payPeriod);
  final base = settings.baseSalary * monthFraction;
  final baseText = monthFraction == 1 ? _money(settings.baseSalary) : '${_money(base)} (nửa tháng)';
  final ratio = std > 0 ? workDays / std : 0.0;
  final cappedRatio = ratio > 1 ? 1.0 : ratio;
  final salaryTotal = daySalary.values.fold(0.0, (s, v) => s + v);

  final incomes = <PayslipLine>[];
  final deductions = <PayslipLine>[];
  final dayAmounts = <DateTime, double>{};

  void addDay(DateTime d, double signed) => dayAmounts[d] = (dayAmounts[d] ?? 0) + signed;

  /// Chia [amount] của một dòng cho các ngày theo ngày công của từng ngày (công nhân).
  void spreadByWorkDays(double signed) {
    if (workDays <= 0) return;
    dayWork.forEach((d, w) => addDay(d, signed * w / workDays));
  }

  String prorateHow(String amountText) => std > 0
      ? '$amountText ÷ ${_num(std)} × ${_num(workDays)} ngày'
      : '$amountText ÷ công chuẩn × ngày công';

  for (final item in items) {
    final sign = item.type == IncomeItemType.income ? 1.0 : -1.0;
    final deduction = item.type == IncomeItemType.deduction;
    double amount;
    String how;

    switch (item.calcMethod) {
      case IncomeCalcMethod.salary:
        // Ngày nghỉ có lương: mỗi ngày tính như một ngày công của lương cơ bản (công nhân) hoặc
        // một ngày lương (công nhật); không tính vào các khoản khác.
        final paid = paidLeaveDays.length;
        if (worker) {
          final perDay = std > 0 ? base / std : 0.0;
          amount = perDay * (workDays + paid);
          how = paid == 0
              ? prorateHow(baseText)
              : std > 0
              ? '$baseText ÷ ${_num(std)} × (${_num(workDays)} ngày công + $paid ngày nghỉ có lương)'
              : '$baseText ÷ công chuẩn × ngày công';
          dayWork.forEach((d, w) => addDay(d, sign * perDay * w));
          for (final d in paidLeaveDays) {
            addDay(d, sign * perDay);
          }
        } else {
          amount = salaryTotal + settings.dailyWage * paid;
          how = _dailySalaryHow(settings, salaryGroups);
          if (paid > 0) how = '$how + $paid ngày nghỉ có lương × ${_money(settings.dailyWage)}';
          daySalary.forEach((d, v) => addDay(d, sign * v));
          for (final d in paidLeaveDays) {
            addDay(d, sign * settings.dailyWage);
          }
        }
      case IncomeCalcMethod.overtime:
        amount = dayOvertime.values.fold(0.0, (s, v) => s + v) + extraOvertimeMoney;
        how = overtimeOverride != null
            ? 'Sửa tay ${_num(overtimeOverride)}h (app tự tính ${_hours(autoOvertimeSeconds)})'
            : overtimeGroups.isEmpty
            ? 'Chưa có giờ tăng ca, chủ nhật hay ngày lễ'
            : overtimeGroups.entries.map((e) => '${e.key.$1} ${_hours(e.value)} × ${_money(e.key.$2)}').join(' + ');
        if (offsetTaken > 0 && overtimeOverride == null) how = '$how (đã lấy ${_hours(offsetTaken)} bù giờ thiếu)';
        dayOvertime.forEach((d, v) => addDay(d, sign * v));
      case IncomeCalcMethod.perWorkDay:
        final days = dayItemCounts[item.id]!;
        amount = item.amount * days.length;
        final gate = item.activeAfter;
        how = '${_money(item.amount)} × ${days.length} ngày ${gate == null ? 'đi làm' : 'làm qua ${gate.formatted}'}';
        for (final d in days) {
          addDay(d, sign * item.amount);
        }
      case IncomeCalcMethod.fixed:
      case IncomeCalcMethod.percentOfBaseSalary:
        final percent = item.calcMethod == IncomeCalcMethod.percentOfBaseSalary;
        if (!worker) {
          // Công nhật không có công chuẩn: khoản cố định tính đủ; khoản % tính trên Tiền lương.
          if (percent) {
            amount = salaryTotal * item.amount / 100;
            how = '${_num(item.amount)}% × tiền lương ${_money(salaryTotal)}';
            daySalary.forEach((d, v) => addDay(d, sign * v * item.amount / 100));
          } else {
            amount = item.amount;
            how = 'cố định mỗi kỳ';
          }
          break;
        }
        if (item.inBasis && !percent) {
          // Khoản căn cứ (thưởng thành tích...): mức tháng ÷ công chuẩn × ngày công, không chặn 100%.
          final monthly = item.amount * monthFraction;
          amount = std > 0 ? monthly / std * workDays : 0;
          how = prorateHow(monthFraction == 1 ? _money(item.amount) : '${_money(monthly)} (nửa tháng)');
          spreadByWorkDays(sign * amount);
          break;
        }
        final periodAmount = percent ? base * item.amount / 100 : item.amount;
        final amountText = percent ? '${_percentHow(item)} × $baseText' : _money(item.amount);
        // Bảo hiểm: tháng nào nghỉ không lương từ 14 ngày làm việc trở lên thì tháng đó không đóng.
        final unpaidDays = std - workDays - paidLeaveDays.length;
        if (item.id == payItemInsurance && ended && monthFraction == 1 && unpaidDays >= insuranceSkipUnpaidDays) {
          amount = 0;
          how = 'Nghỉ không lương từ $insuranceSkipUnpaidDays ngày trở lên nên kỳ này không đóng';
          break;
        }
        // Hết kỳ (và kỳ có ngày công): khoản khấu trừ cố định / theo % tính đủ.
        final full = deduction && ended && workDays > 0;
        if (full || cappedRatio >= 1) {
          amount = periodAmount;
          how = '$amountText (đủ kỳ)';
        } else {
          amount = periodAmount * cappedRatio;
          how = prorateHow(amountText);
        }
        spreadByWorkDays(sign * amount);
    }
    final line = PayslipLine(id: item.id, name: item.name, type: item.type, amount: amount, how: how, item: item);
    (deduction ? deductions : incomes).add(line);
  }

  final lateTotal = dayLate.values.fold(0.0, (s, v) => s + v);
  if (lateTotal > 0) {
    deductions.add(
      PayslipLine(
        id: payItemLate,
        name: 'Đi muộn',
        type: IncomeItemType.deduction,
        amount: lateTotal,
        how: '$lateCount lần × ${_money(settings.lateRule.amount)}',
      ),
    );
    dayLate.forEach((d, v) => addDay(d, -v));
  }

  return Payslip(
    period: period,
    kind: settings.workerKind,
    ended: ended,
    autoStandardDays: autoStd,
    standardDays: std,
    standardOverridden: worker && overriddenStd != null,
    workDays: workDays,
    normalSeconds: normalSeconds,
    overtimeSeconds: overtimeSeconds,
    allNormalSeconds: allNormalSeconds,
    daysOff: daysOff,
    paidLeaveDays: paidLeaveDays.length,
    daysLate: daysLate,
    daysWorked: daysWorked,
    incomes: incomes,
    deductions: deductions,
    dayAmounts: dayAmounts,
    overtimeOffset: offset,
    offsetDays: offsetDays,
    autoWorkDays: autoWorkDays,
    autoOvertimeSeconds: autoOvertimeSeconds,
    workDaysOverridden: workDaysOverride != null,
    overtimeOverridden: overtimeOverride != null,
    leaveUsedDays: leaveUsedDays,
    leaveBalance: leave?.balance ?? 0,
    leaveDates: {...?leave?.used.where((d) => !d.isBefore(period.start) && !d.isAfter(period.end))},
  );
}

/// Phiếu lương mẫu cho người mới: tính bằng đúng các con số đang cài nhưng với ngày công giả định.
class SamplePayslip {
  const SamplePayslip({required this.slip, required this.days, required this.overtimeHours});

  final Payslip slip;

  /// Số ngày công giả định (mỗi ngày đủ 8 giờ).
  final int days;

  /// Tổng giờ tăng ca giả định, tính theo giá tăng ca ngày thường.
  final int overtimeHours;
}

/// Phiếu lương mẫu của [period]: giả sử làm 25 ngày công và 95 giờ tăng ca ngày thường (kỳ nửa tháng
/// thì 12 ngày, 47 giờ), không đi muộn, không nghỉ, kỳ đã hết nên khấu trừ tính đủ. Chỉ để người mới
/// nhìn cho dễ hiểu; không dùng dữ liệu chấm công thật.
SamplePayslip computeSamplePayslip({required AppSettings settings, required PayPeriod period}) {
  final monthly = settings.payPeriod.type == PayPeriodType.monthly;
  // Ngày làm giả định: các ngày T2–T7 đầu kỳ, 07:00–16:00 (8 giờ công) rồi tăng ca tiếp. Bỏ ngày lễ và
  // khung tăng ca để số giờ ra đúng như giả định.
  final sample = settings.copyWith(
    workStart: const Clock(7, 0),
    workEnd: const Clock(16, 0),
    overtimeBrackets: const [],
    holidays: const [],
  );
  final workDates = <DateTime>[];
  final target = monthly ? 25 : 12;
  for (var d = period.start; !d.isAfter(period.end) && workDates.length < target; d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday != DateTime.sunday) workDates.add(d);
  }
  final overtimeHours = monthly ? 95 : 47;
  final perDay = workDates.isEmpty ? 0 : overtimeHours * 60 ~/ workDates.length;
  final extra = workDates.isEmpty ? 0 : overtimeHours * 60 - perDay * workDates.length;
  final records = <DateTime, DayRecord>{
    for (final (i, d) in workDates.indexed)
      d: DayRecord(
        date: d,
        checkIn: DateTime(d.year, d.month, d.day, 7),
        checkOut: DateTime(d.year, d.month, d.day, 16, perDay + (i == 0 ? extra : 0)),
      ),
  };
  final slip = computePayslip(
    settings: sample,
    period: period,
    recordOf: (date) => records[dateOnly(date)] ?? DayRecord(date: dateOnly(date)),
    now: DateTime(period.end.year, period.end.month, period.end.day + 1, 12),
  );
  return SamplePayslip(slip: slip, days: workDates.length, overtimeHours: overtimeHours);
}

/// Dòng giải thích Tiền lương của công nhật. Mọi giờ cùng giá lương ngày ÷ 8 thì ghi gọn
/// "350.000 ÷ 8 × 89 giờ"; có giá khác thì liệt kê từng giá.
String _dailySalaryHow(AppSettings settings, Map<double, int> groups) {
  final defaultRate = settings.dailyWage / 8;
  if (groups.isEmpty) return '${_money(settings.dailyWage)} ÷ 8 × 0 giờ';
  if (groups.length == 1 && groups.keys.first == defaultRate) {
    return '${_money(settings.dailyWage)} ÷ 8 × ${_num(groups.values.first / 3600)} giờ';
  }
  return groups.entries.map((e) => '${_hours(e.value)} × ${_money(e.key)}').join(' + ');
}

/// "10,5%"; riêng bảo hiểm cài sẵn đúng 10,5% thì ghi rõ "BHXH 8% + BHYT 1,5% + BHTN 1%".
String _percentHow(IncomeItem item) =>
    item.id == payItemInsurance && item.amount == 10.5 ? 'BHXH 8% + BHYT 1,5% + BHTN 1%' : '${_num(item.amount)}%';

/// Số tiền bỏ phần lẻ, có dấu chấm ngăn hàng nghìn: "4.000.000".
String _money(double v) {
  final n = v.truncate();
  final digits = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '-' : ''}$buf';
}

/// Số có tối đa một chữ số lẻ, dấu phẩy kiểu Việt Nam: "24,5", "26".
String _num(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString().replaceAll('.', ',');
}

String _hours(int seconds) => '${_num(seconds / 3600)}h';
