import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:flutter_test/flutter_test.dart';

AppSettings baseSettings() {
  final wage = WageTable(
    rates: {
      DayType.weekday: const WageRate(normalPerHour: 30000, overtimePerHour: 45000),
      DayType.saturday: const WageRate(normalPerHour: 40000, overtimePerHour: 60000),
      DayType.sunday: const WageRate(normalPerHour: 40000, overtimePerHour: 60000),
      DayType.holiday: const WageRate(normalPerHour: 90000, overtimePerHour: 135000),
    },
  );
  return AppSettings(
    workStart: const Clock(7, 0),
    workEnd: const Clock(16, 0),
    wageTable: wage,
    lateRule: const LateRule(after: Clock(7, 0), unit: LateUnit.minutes, amount: 30),
  );
}

void main() {
  test('ngày nghỉ -> không tính giờ, không tính tiền', () {
    final settings = baseSettings();
    final record = DayRecord(date: DateTime(2026, 9, 21), isDayOff: true);
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 0);
    expect(result.pay, 0);
  });

  test('chưa chấm (không có checkIn) -> không tính', () {
    final settings = baseSettings();
    final record = DayRecord(date: DateTime(2026, 9, 21));
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 0);
    expect(result.pay, 0);
  });

  test('đã chấm vào nhưng chưa chấm ra (ca đang mở) -> chưa tính giờ/tiền, kể cả chấm vào giờ muộn', () {
    final settings = baseSettings().copyWith(
      overtimeBrackets: [const OvertimeBracket(from: Clock(17, 0), to: Clock(22, 0), breakMinutes: 0)],
    );
    // Chấm vào lúc 18:00 (sau giờ ra 16:00, rơi vào khung tăng ca) nhưng chưa chấm ra.
    final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 18, 0));
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 0);
    expect(result.overtimeMinutes, 0);
    expect(result.pay, 0);
  });

  test('chấm đủ ca thứ Hai 07:00-16:00 -> 8 giờ thường (trừ nghỉ trưa), đúng lương', () {
    final settings = baseSettings();
    final record = DayRecord(
      date: DateTime(2026, 9, 21), // Thứ Hai
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 8 * 60);
    expect(result.dayType, DayType.weekday);
    expect(result.pay, closeTo(8 * 30000, 0.01));
  });

  test('vào sớm hơn khung không tính thêm', () {
    final settings = baseSettings();
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 6, 30),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 8 * 60);
  });

  test('đi muộn, đơn vị phút -> trừ thẳng vào giờ thường', () {
    final settings = baseSettings();
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 30),
      checkOut: DateTime(2026, 9, 21, 16, 0),
      isLate: true,
    );
    final result = computeDay(record, settings);
    // 8h30 trong khung - 1h nghỉ trưa - 30 phút trừ đi muộn = 7h
    expect(result.normalMinutes, 7 * 60);
  });

  test('đi muộn, đơn vị tiền -> trừ vào lương, không đổi giờ', () {
    final settings = baseSettings().copyWith(
      lateRule: const LateRule(after: Clock(7, 0), unit: LateUnit.money, amount: 20000),
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 30),
      checkOut: DateTime(2026, 9, 21, 16, 0),
      isLate: true,
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 7 * 60 + 30);
    expect(result.pay, closeTo((7.5 * 30000) - 20000, 0.01));
  });

  test('chấm vào đã sau giờ ra (ca ngắn ngoài khung) -> tăng ca tính từ giờ vào, không phải giờ ra', () {
    // Bug thật gặp: giờ ra cài 09:00, chấm vào 10:17 ra 10:27 (chỉ 10 phút) không được tính thành
    // hàng giờ tăng ca "giờ ra tới giờ ra thực" — phải tính từ giờ vào thực (10:17) tới giờ ra (10:27).
    final settings = baseSettings().copyWith(workEnd: const Clock(9, 0));
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 10, 17),
      checkOut: DateTime(2026, 9, 21, 10, 27),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 0);
    expect(result.overtimeMinutes, 10);
  });

  test('tăng ca theo khung: phần giờ trong khung trừ phút nghỉ của khung', () {
    final settings = baseSettings().copyWith(
      overtimeBrackets: [const OvertimeBracket(from: Clock(17, 0), to: Clock(22, 0), breakMinutes: 30)],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 19, 0), // 16:00-19:00 sau ca, nhưng khung OT từ 17:00
    );
    final result = computeDay(record, settings);
    // Khung OT 17:00-19:00 = 120 phút, trừ 30 phút nghỉ = 90 phút.
    expect(result.overtimeMinutes, 90);
  });

  test('làm quá khung tăng ca cuối cùng -> phần dư vẫn tính, không mất trắng', () {
    final settings = baseSettings().copyWith(
      overtimeBrackets: [
        const OvertimeBracket(from: Clock(18, 0), to: Clock(19, 0), breakMinutes: 0),
        const OvertimeBracket(from: Clock(22, 0), to: Clock(23, 0), breakMinutes: 15),
      ],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 23, 48), // quá khung cuối (kết thúc 23:00) 48 phút
    );
    final result = computeDay(record, settings);
    // Khung 1: 60 phút. Khung 2: 60 - 15 = 45 phút. Dư sau 23:00 tới 23:48 = 48 phút.
    expect(result.overtimeMinutes, 60 + 45 + 48);
  });

  test('ngày lễ dùng đúng cột hệ số Ngày lễ', () {
    final settings = baseSettings().copyWith(
      holidays: [Holiday(date: DateTime(2026, 9, 21), name: 'Test')],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.dayType, DayType.holiday);
    expect(result.pay, closeTo(8 * 90000, 0.01));
  });

  test('giờ nghỉ trưa 11:30-12:30 luôn không tính công', () {
    final settings = baseSettings();
    DayCalcResult day(int inH, int inM, int outH, int outM) => computeDay(
      DayRecord(
        date: DateTime(2026, 9, 21),
        checkIn: DateTime(2026, 9, 21, inH, inM),
        checkOut: DateTime(2026, 9, 21, outH, outM),
      ),
      settings,
    );
    // Làm qua cả giờ nghỉ: 7:00-16:00 = 9h, trừ 60p.
    expect(day(7, 0, 16, 0).normalMinutes, 8 * 60);
    // Vào giữa giờ nghỉ: 12:00-16:00 chỉ tính từ 12:30.
    expect(day(12, 0, 16, 0).normalMinutes, 3 * 60 + 30);
    // Ca chiều bắt đầu sau giờ nghỉ: không trừ gì.
    expect(day(13, 0, 16, 0).normalMinutes, 3 * 60);
    // Về trước giờ nghỉ: không trừ gì.
    expect(day(7, 0, 11, 0).normalMinutes, 4 * 60);
  });

  test('ngoại lệ: về trong giờ nghỉ trưa -> phần trong giờ nghỉ vẫn tính', () {
    final settings = baseSettings();
    DayCalcResult day(int outH, int outM) => computeDay(
      DayRecord(
        date: DateTime(2026, 9, 21),
        checkIn: DateTime(2026, 9, 21, 7, 0),
        checkOut: DateTime(2026, 9, 21, outH, outM),
      ),
      settings,
    );
    // Về 12:00: tính đủ 7:00-12:00 = 5h.
    expect(day(12, 0).normalMinutes, 5 * 60);
    expect(day(12, 29).normalMinutes, 5 * 60 + 29);
    // Về đúng 12:30 (hết giờ nghỉ) là đã qua trọn giờ nghỉ: trừ 60p.
    expect(day(12, 30).normalMinutes, 4 * 60 + 30);
  });

  test('khung cố định cũ còn trong dữ liệu -> bỏ qua, chỉ trừ giờ nghỉ trưa', () {
    final settings = baseSettings().copyWith(
      fixedBreakRules: [
        const FixedBreakRule(
          checkInFrom: Clock(7, 0),
          checkInTo: Clock(7, 0),
          checkOutFrom: Clock(16, 0),
          checkOutTo: Clock(16, 0),
          deltaMinutes: -15,
        ),
      ],
      breakSegments: [const BreakSegment(from: Clock(7, 0), to: Clock(9, 0), breakMinutes: 15)],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    expect(computeDay(record, settings).normalMinutes, 8 * 60);
  });

  group('liveEstimatedPay', () {
    test('ca đang mở -> tăng theo giây, không đứng yên chờ đủ phút', () {
      final settings = baseSettings();
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      final at30s = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 7, 0, 30));
      final at45s = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 7, 0, 45));
      expect(at30s, greaterThan(0));
      expect(at45s, greaterThan(at30s));
      // 30 giây với lương 30.000đ/giờ = 30.000 / 3600 * 30 = 250đ.
      expect(at30s, closeTo(250, 0.5));
    });

    test('chưa chấm vào -> 0', () {
      final settings = baseSettings();
      final record = DayRecord(date: DateTime(2026, 9, 21));
      expect(liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 8, 0)), 0);
    });

    test('đã chấm ra -> dùng đúng số chính thức (theo phút)', () {
      final settings = baseSettings();
      final record = DayRecord(
        date: DateTime(2026, 9, 21),
        checkIn: DateTime(2026, 9, 21, 7, 0),
        checkOut: DateTime(2026, 9, 21, 16, 0),
      );
      final live = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 20, 0));
      final official = computeDay(record, settings).pay;
      expect(live, official);
    });

    test('vào sớm hơn khung -> chỉ tính từ giờ bắt đầu khung, không tính phần đến sớm', () {
      final settings = baseSettings();
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 6, 30));
      final at7h1m = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 7, 1));
      // Chỉ 1 phút trong khung (6:30-7:00 không tính) = 30.000/60 = 500đ.
      expect(at7h1m, closeTo(500, 1));
    });

    test('có đi muộn -> số lúc đang chạy khớp số chính thức ngay khi chấm ra (không tụt đột ngột)', () {
      final settings = baseSettings().copyWith(
        lateRule: const LateRule(after: Clock(7, 0), unit: LateUnit.minutes, amount: 30),
      );
      final checkIn = DateTime(2026, 9, 21, 7, 0);
      final checkOutMoment = DateTime(2026, 9, 21, 16, 0);
      final openRecord = DayRecord(date: DateTime(2026, 9, 21), checkIn: checkIn, isLate: true);

      // Số ngay trước lúc chấm ra (còn đang mở ca) phải bằng số chính thức ngay sau khi chấm ra.
      final liveJustBefore = liveEstimatedPay(openRecord, settings, checkOutMoment);
      final closedRecord = openRecord.copyWith(checkOut: checkOutMoment);
      final official = computeDay(closedRecord, settings).pay;
      expect(liveJustBefore, closeTo(official, 0.01));
    });

    test('ca đang mở -> số đứng yên trong giờ nghỉ 11:30-12:30 rồi chạy tiếp, khớp số lúc chấm ra', () {
      final settings = baseSettings();
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      double at(int h, int m) => liveEstimatedPay(record, settings, DateTime(2026, 9, 21, h, m));
      // 7:00-11:30 = 4h30, lương 30.000đ/giờ = 135.000đ; suốt giờ nghỉ số không đổi.
      expect(at(11, 30), closeTo(135000, 1));
      expect(at(12, 0), closeTo(135000, 1));
      expect(at(12, 30), closeTo(135000, 1));
      expect(at(13, 0), closeTo(150000, 1));

      // Chấm ra 16:00: số chính thức bằng đúng số đang chạy, không nhảy.
      final closed = record.copyWith(checkOut: DateTime(2026, 9, 21, 16, 0));
      expect(computeDay(closed, settings).pay, closeTo(at(16, 0), 1));
    });

    test('chấm ra trong giờ nghỉ -> số chốt gồm cả phần giờ nghỉ đã qua', () {
      final settings = baseSettings();
      final record = DayRecord(
        date: DateTime(2026, 9, 21),
        checkIn: DateTime(2026, 9, 21, 7, 0),
        checkOut: DateTime(2026, 9, 21, 12, 0),
      );
      // 7:00-12:00 = 5h = 150.000đ.
      expect(liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 12, 0)), closeTo(150000, 1));
    });

    test('còn mở ca sau khi qua hết mọi khung tăng ca đã cài -> vẫn tăng tiếp, không đứng yên', () {
      final settings = baseSettings().copyWith(
        overtimeBrackets: [const OvertimeBracket(from: Clock(18, 0), to: Clock(19, 0), breakMinutes: 0)],
      );
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      final at2000 = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 20, 0));
      final at2010 = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 20, 10));
      expect(at2010, greaterThan(at2000));
    });
  });

  group('computePeriodStats khoản thu nhập/khấu trừ', () {
    test('% lương cơ bản -> tính theo baseSalary, chỉ cộng khi bật includeItemsInEstimate', () {
      final settings = baseSettings().copyWith(
        baseSalary: 3000000,
        incomeItems: [
          const IncomeItem(
            id: '1',
            name: 'Bảo hiểm',
            type: IncomeItemType.deduction,
            calcMethod: IncomeCalcMethod.percentOfBaseSalary,
            amount: 10,
          ),
        ],
      );
      final period = PayPeriod(DateTime(2026, 9, 1), DateTime(2026, 9, 30));

      final off = computePeriodStats(period, const [], settings);
      expect(off.itemsIncome, 0);

      final on = computePeriodStats(period, const [], settings.copyWith(includeItemsInEstimate: true));
      expect(on.itemsIncome, -300000);
    });
  });

  group('liveItemsEstimate', () {
    test('tắt includeItemsInEstimate -> luôn 0', () {
      final settings = baseSettings().copyWith(
        incomeItems: [const IncomeItem(id: '1', name: 'Phụ cấp', amount: 900000)],
      );
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      expect(liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 12, 0), 20), 0);
    });

    test('khoản cố định chia đều theo ngày công, chạy dần trong ca và nhận đủ lúc hết ca', () {
      final settings = baseSettings().copyWith(
        includeItemsInEstimate: true,
        incomeItems: [const IncomeItem(id: '1', name: 'Phụ cấp', amount: 900000)],
      );
      // Kỳ có 20 ngày công -> phần của hôm nay = 900.000/20 = 45.000. Ca chuẩn 7:00-16:00 = 9 giờ.
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      final half = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 11, 30), 20);
      expect(half, closeTo(22500, 1));
      final atEnd = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 16, 0), 20);
      expect(atEnd, closeTo(45000, 1));
      final afterEnd = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 20, 0), 20);
      expect(afterEnd, closeTo(45000, 1)); // không chạy quá phần của ngày dù còn đang tăng ca
    });

    test('khoản có mốc giờ (vd tiền cơm trưa sau 13h) -> trước mốc chưa tính, nhận đủ lúc hết ca', () {
      final settings = baseSettings().copyWith(
        includeItemsInEstimate: true,
        incomeItems: [
          const IncomeItem(id: '1', name: 'Tiền cơm trưa', amount: 450000, activeAfter: Clock(13, 0)),
        ],
      );
      // Kỳ 15 ngày công -> phần/ngày = 30.000.
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      expect(liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 12, 0), 15), 0); // chưa tới 13h
      expect(liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 13, 0), 15), 0); // vừa chạm mốc

      final mid = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 14, 30), 15);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(30000));

      final atEnd = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 16, 0), 15);
      expect(atEnd, closeTo(30000, 1)); // hết ca là nhận đủ, không bị "ăn non" vì mốc giờ bắt đầu muộn
    });

    test('khoản khấu trừ -> trả về số âm', () {
      final settings = baseSettings().copyWith(
        includeItemsInEstimate: true,
        baseSalary: 3000000,
        incomeItems: [
          const IncomeItem(
            id: '1',
            name: 'Bảo hiểm',
            type: IncomeItemType.deduction,
            calcMethod: IncomeCalcMethod.percentOfBaseSalary,
            amount: 10,
          ),
        ],
      );
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      // 3.000.000*10% = 300.000 / 20 ngày = 15.000/ngày, hết ca thì đủ -15.000.
      final atEnd = liveItemsEstimate(record, settings, DateTime(2026, 9, 21, 16, 0), 20);
      expect(atEnd, closeTo(-15000, 1));
    });
  });
}
