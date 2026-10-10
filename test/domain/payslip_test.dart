import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:cham_cong_don_gian/domain/payslip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tạo dữ liệu chấm công giả: mỗi ngày một ca, giờ vào/ra theo [shift].
Map<String, DayRecord> _records(Iterable<DayRecord> list) => {for (final r in list) dateKey(r.date): r};

DayRecord _shift(DateTime day, int inH, int inM, int outH, int outM, {bool late = false}) => DayRecord(
  date: day,
  checkIn: DateTime(day.year, day.month, day.day, inH, inM),
  checkOut: DateTime(day.year, day.month, day.day, outH, outM),
  isLate: late,
);

Payslip _slip(AppSettings s, Map<String, DayRecord> recs, DateTime now, {PayPeriod? period}) => computePayslip(
  settings: s,
  period: period ?? periodContaining(now, s.payPeriod),
  recordOf: (d) => recs[dateKey(d)] ?? DayRecord(date: dateOnly(d)),
  now: now,
);

/// Các ngày T2–T7 trong khoảng [from, to].
Iterable<DateTime> _workdays(DateTime from, DateTime to) sync* {
  for (var d = from; !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday != DateTime.sunday) yield d;
  }
}

void main() {
  final worker = AppSettings.defaultsFor(WorkerKind.worker);
  final daily = AppSettings.defaultsFor(WorkerKind.daily);

  group('công chuẩn', () {
    test('kỳ 21/07–20/08/2026 ra 27 ngày', () {
      expect(autoStandardDaysOf(PayPeriod(DateTime(2026, 7, 21), DateTime(2026, 8, 20))), 27);
    });

    test('số sửa tay chỉ áp dụng cho đúng kỳ đó', () {
      final p = periodContaining(DateTime(2026, 9, 25), worker.payPeriod);
      final s = worker.copyWith(standardDays: {p.key: 24});
      expect(_slip(s, {}, DateTime(2026, 9, 25)).standardDays, 24);
      expect(_slip(s, {}, DateTime(2026, 9, 25)).standardOverridden, isTrue);
      final other = _slip(s, {}, DateTime(2026, 11, 1));
      expect(other.standardOverridden, isFalse);
      expect(other.standardDays, other.autoStandardDays);
    });
  });

  group('công nhân', () {
    // Kỳ 21/09–20/10/2026: 30 ngày, 4 chủ nhật -> công chuẩn 26.
    final period = PayPeriod(DateTime(2026, 9, 21), DateTime(2026, 10, 20));

    test('đủ 26 ngày công, kỳ đã kết thúc -> lương, thưởng, bảo hiểm, công đoàn đúng mức tháng', () {
      final recs = _records(_workdays(period.start, period.end).map((d) => _shift(d, 7, 0, 16, 0)));
      final slip = _slip(worker, recs, DateTime(2026, 10, 25), period: period);
      expect(slip.standardDays, 26);
      expect(slip.workDays, 26);
      expect(slip.ended, isTrue);
      double line(String id) => [...slip.incomes, ...slip.deductions].firstWhere((l) => l.id == id).amount;
      expect(line(payItemSalary), closeTo(4000000, 0.001));
      expect(line(payItemPerformance), closeTo(2000000, 0.001));
      expect(line(payItemOvertime), 0);
      expect(line(payItemInsurance), closeTo(420000, 0.001));
      expect(line(payItemUnion), closeTo(50000, 0.001));
      expect(line(payItemLunch), 26 * 10000);
      expect(slip.net, closeTo(4000000 + 2000000 - 420000 - 50000 - 260000, 0.001));
    });

    test('giữa kỳ: khoản cố định và bảo hiểm chia đều theo ngày công', () {
      // 10 ngày công đầu kỳ, hôm nay 02/10 (chưa hết kỳ).
      final days = _workdays(period.start, DateTime(2026, 10, 1)).take(10).toList();
      final recs = _records(days.map((d) => _shift(d, 7, 0, 16, 0)));
      final slip = _slip(worker, recs, DateTime(2026, 10, 2, 6, 0), period: period);
      expect(slip.ended, isFalse);
      expect(slip.workDays, 10);
      double line(String id) => [...slip.incomes, ...slip.deductions].firstWhere((l) => l.id == id).amount;
      expect(line(payItemSalary), closeTo(4000000 / 26 * 10, 0.001));
      expect(line(payItemInsurance), closeTo(420000 / 26 * 10, 0.001));
      expect(line(payItemUnion), closeTo(50000 / 26 * 10, 0.001));
      expect(slip.incomes.firstWhere((l) => l.id == payItemSalary).how, '4.000.000 ÷ 26 × 10 ngày');
    });

    test('hết kỳ: khấu trừ cố định và % tính đủ, thu nhập cố định (trợ cấp) vẫn theo ngày công', () {
      final s = worker.copyWith(
        incomeItems: [
          for (final i in worker.incomeItems) i.id == payItemAllowance ? i.copyWith(amount: 520000) : i,
        ],
      );
      final days = _workdays(period.start, period.end).take(13).toList();
      final recs = _records(days.map((d) => _shift(d, 7, 0, 16, 0)));
      final slip = _slip(s, recs, DateTime(2026, 10, 21), period: period);
      double line(String id) => [...slip.incomes, ...slip.deductions].firstWhere((l) => l.id == id).amount;
      expect(line(payItemInsurance), closeTo(420000, 0.001));
      expect(line(payItemUnion), closeTo(50000, 0.001));
      expect(line(payItemAllowance), closeTo(260000, 0.001));
    });

    test('kỳ chưa có ngày công nào -> không trừ gì kể cả khi đã hết kỳ', () {
      final slip = _slip(worker, {}, DateTime(2026, 10, 25), period: period);
      expect(slip.totalDeduction, 0);
      expect(slip.net, 0);
    });

    test('làm hơn công chuẩn -> khoản cố định không vượt quá 100%', () {
      final p = period;
      final s = worker.copyWith(standardDays: {p.key: 20});
      final recs = _records(_workdays(p.start, p.end).take(24).map((d) => _shift(d, 7, 0, 16, 0)));
      final slip = _slip(s, recs, DateTime(2026, 10, 18), period: p);
      expect(slip.deductions.firstWhere((l) => l.id == payItemUnion).amount, closeTo(50000, 0.001));
      // Lương thì không chặn: 4.000.000 ÷ 20 × 24.
      expect(slip.incomes.firstWhere((l) => l.id == payItemSalary).amount, closeTo(4800000, 0.001));
    });

    test('tăng ca T2–T7, chủ nhật và ngày lễ vào dòng Thưởng vượt khoán, không tính ngày công', () {
      final holiday = DateTime(2026, 9, 2 + 28); // 30/09 (thứ Tư) đặt làm ngày lễ
      final s = worker.copyWith(holidays: [Holiday(date: holiday, name: 'Lễ thử')]);
      final recs = _records([
        _shift(DateTime(2026, 9, 21), 7, 0, 18, 0), // T2: 8h + 2h tăng ca
        _shift(DateTime(2026, 9, 27), 7, 0, 16, 0), // CN: 8h
        _shift(holiday, 7, 0, 16, 0), // lễ: 8h
      ]);
      final slip = _slip(s, recs, DateTime(2026, 10, 1), period: period);
      expect(slip.workDays, 1);
      expect(slip.normalMinutes, 8 * 60);
      expect(slip.overtimeMinutes, (2 + 8 + 8) * 60);
      final ot = slip.incomes.firstWhere((l) => l.id == payItemOvertime);
      expect(ot.amount, closeTo(2 * 45000 + 8 * 45000 + 8 * 63000, 0.001));
      expect(ot.how, 'Tăng ca 2h × 45.000 + chủ nhật 8h × 45.000 + lễ 8h × 63.000');
    });

    test('cơm trưa chỉ đếm ngày làm qua 12:30', () {
      final recs = _records([
        _shift(DateTime(2026, 9, 21), 7, 0, 16, 0),
        _shift(DateTime(2026, 9, 22), 7, 0, 12, 0), // về trước 12:30
        _shift(DateTime(2026, 9, 23), 7, 0, 12, 30), // ra đúng 12:30
      ]);
      final slip = _slip(worker, recs, DateTime(2026, 9, 24), period: period);
      final lunch = slip.deductions.firstWhere((l) => l.id == payItemLunch);
      expect(lunch.amount, 20000);
      expect(lunch.how, '10.000 × 2 ngày làm qua 12:30');
    });

    test('đi muộn trừ phút -> nằm trong giờ công; trừ tiền -> thành dòng Đi muộn', () {
      final recs = _records([_shift(DateTime(2026, 9, 21), 7, 0, 16, 0, late: true)]);
      final byMinutes = _slip(worker, recs, DateTime(2026, 9, 22), period: period);
      expect(byMinutes.normalMinutes, 8 * 60 - 30);
      expect(byMinutes.deductions.where((l) => l.id == payItemLate), isEmpty);

      final s = worker.copyWith(lateRule: worker.lateRule.copyWith(unit: LateUnit.money, amount: 20000));
      final byMoney = _slip(s, recs, DateTime(2026, 9, 22), period: period);
      expect(byMoney.normalMinutes, 8 * 60);
      final late = byMoney.deductions.firstWhere((l) => l.id == payItemLate);
      expect(late.amount, 20000);
      expect(late.how, '1 lần × 20.000');
    });

    test('ca đang mở của hôm nay tính theo giây; ca mở của ngày cũ coi như chưa có giờ', () {
      final recs = _records([
        DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)), // quên chấm ra
        DayRecord(date: DateTime(2026, 9, 22), checkIn: DateTime(2026, 9, 22, 7, 0)),
      ]);
      final a = _slip(worker, recs, DateTime(2026, 9, 22, 9, 0, 0), period: period);
      final b = _slip(worker, recs, DateTime(2026, 9, 22, 9, 0, 1), period: period);
      expect(a.normalSeconds, 2 * 3600);
      expect(b.net, greaterThan(a.net));
      expect(a.amountOn(DateTime(2026, 9, 21)), 0);
    });

    test('số đứng yên trong giờ nghỉ trưa, và cơm trưa chỉ trừ khi đã qua 12:30', () {
      final recs = _records([DayRecord(date: DateTime(2026, 9, 22), checkIn: DateTime(2026, 9, 22, 7, 0))]);
      final at1140 = _slip(worker, recs, DateTime(2026, 9, 22, 11, 40), period: period);
      final at1220 = _slip(worker, recs, DateTime(2026, 9, 22, 12, 20), period: period);
      final at1230 = _slip(worker, recs, DateTime(2026, 9, 22, 12, 30), period: period);
      expect(at1220.net, at1140.net);
      expect(at1140.deductions.firstWhere((l) => l.id == payItemLunch).amount, 0);
      expect(at1230.deductions.firstWhere((l) => l.id == payItemLunch).amount, 10000);
    });

    test('tổng tiền các ngày bằng đúng Thực nhận (giữa kỳ, hết kỳ)', () {
      final recs = _records([
        for (final d in _workdays(period.start, period.end).take(15)) _shift(d, 7, 0, 17, 0, late: d.day == 23),
        _shift(DateTime(2026, 9, 27), 7, 0, 11, 0),
      ]);
      for (final now in [DateTime(2026, 10, 9, 10, 0), DateTime(2026, 10, 25)]) {
        final slip = _slip(worker, recs, now, period: period);
        final sum = slip.dayAmounts.values.fold(0.0, (s, v) => s + v);
        expect(sum, closeTo(slip.net, 0.0001));
      }
    });

    test('kỳ chia 2 kỳ/tháng: lương cơ bản và mức tháng tính nửa', () {
      final s = worker.copyWith(payPeriod: const PayPeriodConfig(type: PayPeriodType.semiMonthly));
      final p = PayPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 15)); // 15 ngày, 2 chủ nhật -> 13
      final recs = _records(_workdays(p.start, p.end).map((d) => _shift(d, 7, 0, 16, 0)));
      final slip = _slip(s, recs, DateTime(2026, 9, 20), period: p);
      expect(slip.standardDays, 13);
      expect(slip.incomes.firstWhere((l) => l.id == payItemSalary).amount, closeTo(2000000, 0.001));
    });
  });

  group('công nhật', () {
    final period = PayPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 15));

    test('tiền lương = tổng giờ × lương ngày ÷ 8, dòng giải thích gọn', () {
      final recs = _records([
        _shift(DateTime(2026, 10, 1), 7, 0, 16, 0), // 8h
        _shift(DateTime(2026, 10, 2), 7, 0, 18, 0), // 8h + 2h
        _shift(DateTime(2026, 10, 4), 7, 0, 16, 0), // CN 8h
      ]);
      final slip = _slip(daily, recs, DateTime(2026, 10, 5), period: period);
      final salary = slip.incomes.firstWhere((l) => l.id == payItemSalary);
      expect(salary.amount, closeTo(26 * 43750, 0.001));
      expect(salary.how, '350.000 ÷ 8 × 26 giờ');
      expect(slip.deductions.firstWhere((l) => l.id == payItemLunch).amount, 30000);
      expect(slip.net, closeTo(26 * 43750 - 30000, 0.001));
    });

    test('ô bảng lương/giờ đã sửa thì giữ số người dùng nhập', () {
      final s = daily.copyWith(
        wageTable: WageTable(rates: {...daily.wageTable.rates, DayType.sunday: const WageRate(normalPerHour: 60000)}),
      );
      final recs = _records([
        _shift(DateTime(2026, 10, 1), 7, 0, 16, 0),
        _shift(DateTime(2026, 10, 4), 7, 0, 16, 0), // CN
      ]);
      final slip = _slip(s, recs, DateTime(2026, 10, 5), period: period);
      final salary = slip.incomes.firstWhere((l) => l.id == payItemSalary);
      expect(salary.amount, closeTo(8 * 43750 + 8 * 60000, 0.001));
      expect(salary.how, '8h × 43.750 + 8h × 60.000');
    });

    test('khoản cố định tự thêm tính đủ, không có công chuẩn', () {
      final s = daily.copyWith(
        incomeItems: [...daily.incomeItems, const IncomeItem(id: 'x', name: 'Xăng xe', amount: 100000)],
      );
      final recs = _records([_shift(DateTime(2026, 10, 1), 7, 0, 16, 0)]);
      final slip = _slip(s, recs, DateTime(2026, 10, 2), period: period);
      expect(slip.incomes.firstWhere((l) => l.id == 'x').amount, 100000);
      expect(slip.standardDays, 0);
    });
  });

  group('chuyển dữ liệu bản cũ (chưa có workerKind)', () {
    // Dữ liệu kiểu bản cũ: bảng lương/giờ, không có lương cơ bản, không có khoản nào.
    Map<String, dynamic> legacyJson({List<Map<String, dynamic>> items = const []}) {
      final json = AppSettings(
        wageTable: WageTable(
          rates: {
            DayType.weekday: const WageRate(normalPerHour: 30000, overtimePerHour: 45000),
            DayType.saturday: const WageRate(normalPerHour: 30000, overtimePerHour: 45000),
            DayType.sunday: const WageRate(normalPerHour: 45000, overtimePerHour: 45000),
            DayType.holiday: const WageRate(normalPerHour: 90000, overtimePerHour: 90000),
          },
        ),
        payPeriod: const PayPeriodConfig(monthlyStartDay: 21),
        lateRule: const LateRule(after: Clock(7, 0), unit: LateUnit.money, amount: 20000),
      ).toJson();
      json.remove('workerKind');
      json.remove('dailyWage');
      json.remove('standardDays');
      json.remove('showNotice');
      json.remove('showGps');
      json['incomeItems'] = items;
      return json;
    }

    test('thành Công nhân, lương cơ bản = lương giờ × 8 × 26, có Tiền lương và Tăng ca', () {
      final s = AppSettings.fromJson(legacyJson());
      expect(s.workerKind, WorkerKind.worker);
      expect(s.baseSalary, 30000 * 8 * 26);
      expect(s.incomeItems.map((i) => i.id), [payItemSalary, payItemOvertime]);
      expect(s.payPeriod.monthlyStartDay, 21);
      expect(s.incomeItems.where((i) => i.id == payItemInsurance || i.id == payItemUnion), isEmpty);
    });

    test('số tiền một kỳ gần như không đổi (lệch dưới 5%)', () {
      final legacy = AppSettings.fromJson(legacyJson());
      final oldStyle = AppSettings.fromJson({...legacyJson(), 'workerKind': 'worker'});
      final period = PayPeriod(DateTime(2026, 9, 21), DateTime(2026, 10, 20));
      final recs = _records([
        for (final d in _workdays(period.start, period.end).take(24)) _shift(d, 7, 0, 18, 0, late: d.day == 24),
        _shift(DateTime(2026, 9, 27), 7, 0, 16, 0),
      ]);
      // Cách tính cũ: cộng thẳng tiền theo bảng lương/giờ của từng ngày.
      final oldTotal = recs.values.fold(0.0, (s, r) => s + computeDay(r, oldStyle).pay);
      final slip = _slip(legacy, recs, DateTime(2026, 10, 25), period: period);
      expect((slip.net - oldTotal).abs() / oldTotal, lessThan(0.05));
    });

    test('khoản tự tạo cũ được giữ nguyên', () {
      final s = AppSettings.fromJson(
        legacyJson(items: [const IncomeItem(id: 'a', name: 'Phụ cấp', amount: 300000).toJson()]),
      );
      expect(s.incomeItems.last.name, 'Phụ cấp');
      expect(s.incomeItems.last.amount, 300000);
    });

    test('đọc lại dữ liệu đã chuyển thì không chuyển lần nữa', () {
      final once = AppSettings.fromJson(legacyJson());
      final twice = AppSettings.fromJson(once.toJson());
      expect(twice.incomeItems.length, once.incomeItems.length);
      expect(twice.baseSalary, once.baseSalary);
    });
  });
}
