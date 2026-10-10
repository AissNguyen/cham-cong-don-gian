/// Phiếu lương của một kỳ (thuần Dart, không phụ thuộc Flutter).
///
/// Đây là bộ tính tiền **duy nhất** của app: thẻ thu nhập ở màn chính, số "Hôm nay", tiền từng ngày
/// trên lịch, thống kê theo kỳ và file Excel đều lấy số từ đây. Quy tắc ghi ở mục 3 của
/// `THIET-KE-BAN-MOI.md`. Bên trong luôn tính bằng số lẻ, không làm tròn; chỗ hiển thị mới bỏ phần lẻ.
library;

import 'calc.dart';
import 'models.dart';
import 'pay_period.dart';

/// Mã dòng "Đi muộn" (đi muộn trừ tiền). Dòng này không nằm trong danh sách khoản của cài đặt.
const payItemLate = 'late';

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
      if (record.paidLeave) paidLeaveDays.add(d);
      continue;
    }
    if (record.isLate) daysLate++;
    final closed = record.checkIn != null && record.checkOut != null;
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

  // --- Lượt 2: lập các dòng của phiếu. ---
  final ended = today.isAfter(period.end);
  final autoStd = autoStandardDaysOf(period);
  final overriddenStd = settings.standardDays[period.key];
  final std = worker ? (overriddenStd ?? autoStd.toDouble()) : 0.0;
  final workDays = dayWork.values.fold(0.0, (s, v) => s + v);
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
        amount = dayOvertime.values.fold(0.0, (s, v) => s + v);
        how = overtimeGroups.isEmpty
            ? 'Chưa có giờ tăng ca, chủ nhật hay ngày lễ'
            : overtimeGroups.entries.map((e) => '${e.key.$1} ${_hours(e.value)} × ${_money(e.key.$2)}').join(' + ');
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
  );
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
