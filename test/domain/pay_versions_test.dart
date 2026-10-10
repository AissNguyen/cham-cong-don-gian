import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:cham_cong_don_gian/domain/payslip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Công nhân mặc định: kỳ theo tháng, bắt đầu ngày 21. "Hôm nay" là 10/10/2026.
  final today = DateTime(2026, 10, 10);
  final defaults = AppSettings.defaultsFor(WorkerKind.worker);
  final current = periodContaining(today, defaults.payPeriod); // 21/09 - 20/10
  final previous = periodContaining(DateTime(2026, 9, 1), defaults.payPeriod); // 21/08 - 20/09
  final older = periodContaining(DateTime(2026, 8, 1), defaults.payPeriod); // 21/07 - 20/08
  final next = periodContaining(DateTime(2026, 11, 1), defaults.payPeriod); // 21/10 - 20/11

  List<IncomeItem> withAllowance(List<IncomeItem> items, double amount) => [
    for (final i in items) i.id == payItemAllowance ? i.copyWith(amount: amount) : i,
  ];
  double allowanceOf(AppSettings s) => s.incomeItems.firstWhere((i) => i.id == payItemAllowance).amount;

  // Trước giờ trợ cấp là 700.000.
  final before = defaults.copyWith(incomeItems: withAllowance(defaults.incomeItems, 700000));

  test('sửa ở kỳ hiện tại: kỳ này và kỳ sau theo số mới, kỳ trước giữ số cũ', () {
    final s = before.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      incomeItems: withAllowance(before.incomeItems, 500000),
    );
    expect(allowanceOf(s.payFor(previous.start)), 700000);
    expect(allowanceOf(s.payFor(older.start)), 700000);
    expect(allowanceOf(s.payFor(current.start)), 500000);
    expect(allowanceOf(s.payFor(next.start)), 500000);
  });

  test('sửa ở một kỳ đã qua: chỉ kỳ đó đổi, kỳ trước và kỳ sau giữ nguyên', () {
    final s = before.withPayEdit(
      periodStart: previous.start,
      nextPeriodStart: current.start,
      periodEnded: true,
      baseSalary: 5000000,
    );
    expect(s.payFor(previous.start).baseSalary, 5000000);
    expect(s.payFor(older.start).baseSalary, 4000000);
    expect(s.payFor(current.start).baseSalary, 4000000);
    expect(s.payFor(next.start).baseSalary, 4000000);
  });

  test('sửa kỳ hiện tại rồi sửa kỳ trước: hai kỳ giữ số riêng', () {
    var s = before.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      incomeItems: withAllowance(before.incomeItems, 500000),
    );
    s = s.withPayEdit(
      periodStart: previous.start,
      nextPeriodStart: current.start,
      periodEnded: true,
      incomeItems: withAllowance(s.payFor(previous.start).incomeItems, 650000),
    );
    expect(allowanceOf(s.payFor(older.start)), 700000);
    expect(allowanceOf(s.payFor(previous.start)), 650000);
    expect(allowanceOf(s.payFor(current.start)), 500000);
    // Sửa lại lần nữa trong cùng một kỳ thì ghi đè, không sinh thêm bản ghi.
    final again = s.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      incomeItems: withAllowance(s.payFor(current.start).incomeItems, 450000),
    );
    expect(again.payVersions.length, s.payVersions.length);
    expect(allowanceOf(again.payFor(current.start)), 450000);
  });

  test('lưu rồi đọc lại vẫn giữ số của từng kỳ', () {
    final s = before.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      baseSalary: 4500000,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.payFor(previous.start).baseSalary, 4000000);
    expect(back.payFor(current.start).baseSalary, 4500000);
  });

  test('phiếu lương của mỗi kỳ lấy đúng số của kỳ đó', () {
    final s = before.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      incomeItems: withAllowance(before.incomeItems, 500000),
    );
    Payslip slip(PayPeriod p) =>
        computePayslip(settings: s, period: p, recordOf: (d) => DayRecord(date: d), now: today);
    double allowanceLine(Payslip p) => p.incomes.firstWhere((l) => l.id == payItemAllowance).item!.amount;
    expect(allowanceLine(slip(previous)), 700000);
    expect(allowanceLine(slip(current)), 500000);
  });

  test('đổi Công nhân / Công nhật thì bỏ hết số riêng theo kỳ', () {
    final s = before.withPayEdit(
      periodStart: current.start,
      nextPeriodStart: next.start,
      periodEnded: false,
      baseSalary: 4500000,
    );
    expect(AppSettings.defaultsFor(WorkerKind.daily, keep: s).payVersions, isEmpty);
  });

  group('ngày nghỉ có lương', () {
    final leaveDay = DateTime(2026, 10, 5); // thứ Hai
    Payslip slipWith(AppSettings s, DayRecord leave) => computePayslip(
      settings: s,
      period: periodContaining(today, s.payPeriod),
      recordOf: (d) => d == leaveDay ? leave : DayRecord(date: d),
      now: today,
    );
    double salaryOf(Payslip p) => p.incomes.firstWhere((l) => l.id == payItemSalary).amount;

    test('công nhân: tính một ngày lương cơ bản, không tính vào ngày công', () {
      final paid = slipWith(defaults, DayRecord(date: leaveDay, isDayOff: true, paidLeave: true));
      // Kỳ 21/09-20/10/2026 có 26 ngày công chuẩn.
      expect(paid.standardDays, 26);
      expect(salaryOf(paid), closeTo(4000000 / 26, 0.01));
      expect(paid.amountOn(leaveDay), closeTo(4000000 / 26, 0.01));
      expect(paid.workDays, 0);
      expect(paid.daysOff, 1);
      // Thưởng thành tích và các khoản khác không tính cho ngày nghỉ.
      expect(paid.incomes.firstWhere((l) => l.id == payItemPerformance).amount, 0);
    });

    test('công nhân: nghỉ không lương thì không có tiền', () {
      final unpaid = slipWith(defaults, DayRecord(date: leaveDay, isDayOff: true));
      expect(salaryOf(unpaid), 0);
      expect(unpaid.amountOn(leaveDay), 0);
      expect(unpaid.daysOff, 1);
    });

    test('công nhật: tính một ngày lương', () {
      final daily = AppSettings.defaultsFor(WorkerKind.daily);
      final paid = slipWith(daily, DayRecord(date: leaveDay, isDayOff: true, paidLeave: true));
      expect(salaryOf(paid), 350000);
      expect(paid.amountOn(leaveDay), 350000);
    });

    test('bỏ đánh dấu nghỉ thì cũng hết là nghỉ có lương; lưu rồi đọc lại vẫn đúng', () {
      final leave = DayRecord(date: leaveDay, isDayOff: true, paidLeave: true);
      expect(DayRecord.fromJson(leave.toJson()).paidLeave, isTrue);
      expect(leave.copyWith(isDayOff: false).paidLeave, isFalse);
      // Dữ liệu cũ chưa có trường này: ngày nghỉ là nghỉ không lương.
      final old = leave.toJson()..remove('paidLeave');
      expect(DayRecord.fromJson(old).paidLeave, isFalse);
    });
  });
}
