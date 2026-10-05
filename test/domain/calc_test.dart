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

  test('chấm đủ ca thứ Hai 07:00-16:00 -> 9 giờ thường, đúng lương', () {
    final settings = baseSettings();
    final record = DayRecord(
      date: DateTime(2026, 9, 21), // Thứ Hai
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 9 * 60);
    expect(result.dayType, DayType.weekday);
    expect(result.pay, closeTo(9 * 30000, 0.01));
  });

  test('vào sớm hơn khung không tính thêm', () {
    final settings = baseSettings();
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 6, 30),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 9 * 60);
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
    // 8h30 trong khung - 30 phút trừ đi muộn = 8h
    expect(result.normalMinutes, 8 * 60);
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
    expect(result.normalMinutes, 8 * 60 + 30);
    expect(result.pay, closeTo((8.5 * 30000) - 20000, 0.01));
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
    expect(result.pay, closeTo(9 * 90000, 0.01));
  });

  test('khung cố định: giờ vào/ra đúng 1 điểm (từ = đến) -> khớp, không cảnh báo', () {
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
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 9 * 60 - 15);
    expect(result.breakRuleWarning, false);
    expect(result.breakRuleDeltaMinutes, -15);
  });

  test('khung cố định: giờ vào/ra nằm trong khoảng (không cần trùng chính xác) -> vẫn khớp', () {
    final settings = baseSettings().copyWith(
      fixedBreakRules: [
        const FixedBreakRule(
          checkInFrom: Clock(7, 0),
          checkInTo: Clock(8, 0),
          checkOutFrom: Clock(11, 0),
          checkOutTo: Clock(12, 0),
          deltaMinutes: -15,
        ),
      ],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 30), // trong khoảng 7:00-8:00
      checkOut: DateTime(2026, 9, 21, 11, 45), // trong khoảng 11:00-12:00
    );
    final result = computeDay(record, settings);
    // 7:30-11:45 trong khung chuẩn (7:00-16:00) = 4h15, trừ 15p.
    expect(result.normalMinutes, 4 * 60 + 15 - 15);
    expect(result.breakRuleWarning, false);
  });

  test('không khung cố định nào khớp -> chỉ trừ phần giờ làm rơi vào giờ nghỉ 11:30-12:30, kèm cảnh báo', () {
    final settings = baseSettings().copyWith(
      fixedBreakRules: [
        const FixedBreakRule(
          checkInFrom: Clock(9, 0),
          checkInTo: Clock(9, 0),
          checkOutFrom: Clock(16, 0),
          checkOutTo: Clock(16, 0),
          deltaMinutes: -30,
        ),
      ],
    );
    DayCalcResult calc(DateTime checkIn, DateTime checkOut) =>
        computeDay(DayRecord(date: DateTime(2026, 9, 21), checkIn: checkIn, checkOut: checkOut), settings);

    // Ra trước giờ nghỉ: không trừ gì, vẫn cảnh báo.
    final morning = calc(DateTime(2026, 9, 21, 7, 0), DateTime(2026, 9, 21, 10, 0));
    expect(morning.breakRuleWarning, true);
    expect(morning.breakRuleDeltaMinutes, 0);
    expect(morning.normalMinutes, 3 * 60);

    // Ra giữa giờ nghỉ (12:00): chỉ trừ 30 phút đã rơi vào 11:30-12:00.
    final half = calc(DateTime(2026, 9, 21, 7, 0), DateTime(2026, 9, 21, 12, 0));
    expect(half.breakRuleDeltaMinutes, -30);
    expect(half.normalMinutes, 5 * 60 - 30);

    // Vào sau giờ nghỉ: không trừ gì.
    final afternoon = calc(DateTime(2026, 9, 21, 13, 0), DateTime(2026, 9, 21, 15, 0));
    expect(afternoon.breakRuleWarning, true);
    expect(afternoon.breakRuleDeltaMinutes, 0);
    expect(afternoon.normalMinutes, 2 * 60);
  });

  test('không khung cố định nào khớp, làm qua cả giờ nghỉ -> trừ đủ 60 phút (khung nhiều mục cũ bị bỏ qua)', () {
    final settings = baseSettings().copyWith(
      fixedBreakRules: [
        const FixedBreakRule(
          checkInFrom: Clock(9, 0),
          checkInTo: Clock(9, 0),
          checkOutFrom: Clock(16, 0),
          checkOutTo: Clock(16, 0),
          deltaMinutes: -30,
        ),
      ],
      // Dữ liệu cũ còn lưu "khung nhiều mục": không còn dùng để tính nữa.
      breakSegments: [
        const BreakSegment(from: Clock(7, 0), to: Clock(12, 0), breakMinutes: 15),
        const BreakSegment(from: Clock(12, 0), to: Clock(16, 0), breakMinutes: 30),
      ],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0), // không khớp khung cố định (cần đúng 9:00)
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.breakRuleWarning, true);
    expect(result.breakRuleDeltaMinutes, -60);
    expect(result.normalMinutes, 9 * 60 - 60);
  });

  test('chưa cài khung cố định nào -> không cộng trừ, không cảnh báo (kể cả còn khung nhiều mục cũ)', () {
    final settings = baseSettings().copyWith(
      breakSegments: [const BreakSegment(from: Clock(7, 0), to: Clock(16, 0), breakMinutes: 15)],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.breakRuleWarning, false);
    expect(result.breakRuleDeltaMinutes, 0);
    expect(result.normalMinutes, 9 * 60);
  });

  test('giờ ra muộn hơn giờ ra chuẩn (tăng ca) vẫn coi là khớp khung cố định, không rơi xuống dự phòng', () {
    final settings = baseSettings().copyWith(
      fixedBreakRules: [
        const FixedBreakRule(
          checkInFrom: Clock(9, 0),
          checkInTo: Clock(9, 0),
          checkOutFrom: Clock(16, 0), // trùng đúng giờ ra chuẩn (workEnd) -> hiểu là "từ đó trở lên"
          checkOutTo: Clock(16, 0),
          deltaMinutes: -30,
        ),
      ],
      overtimeBrackets: [const OvertimeBracket(from: Clock(16, 0), to: Clock(20, 0), breakMinutes: 0)],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 9, 0),
      checkOut: DateTime(2026, 9, 21, 19, 0), // ra muộn hơn 16:00 vì tăng ca
    );
    final result = computeDay(record, settings);
    expect(result.breakRuleWarning, false);
    expect(result.breakRuleDeltaMinutes, -30);
    // 9:00-16:00 trong khung chuẩn = 7h, trừ 30p.
    expect(result.normalMinutes, 7 * 60 - 30);
    expect(result.overtimeMinutes, 3 * 60); // 16:00-19:00
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

    test('ca đang mở, có cài khung cố định -> số đứng yên trong giờ nghỉ 11:30-12:30 rồi chạy tiếp', () {
      final settings = baseSettings().copyWith(
        fixedBreakRules: [
          const FixedBreakRule(
            checkInFrom: Clock(7, 0),
            checkInTo: Clock(7, 0),
            checkOutFrom: Clock(16, 0),
            checkOutTo: Clock(16, 0),
            deltaMinutes: -60,
          ),
        ],
      );
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      double at(int h, int m) => liveEstimatedPay(record, settings, DateTime(2026, 9, 21, h, m));
      // 7:00-11:30 = 4h30, lương 30.000đ/giờ = 135.000đ; suốt giờ nghỉ số không đổi.
      expect(at(11, 30), closeTo(135000, 1));
      expect(at(12, 0), closeTo(135000, 1));
      expect(at(12, 30), closeTo(135000, 1));
      expect(at(13, 0), closeTo(150000, 1));

      // Chấm ra 16:00 khớp khung cố định (trừ 60p): số chính thức bằng đúng số đang chạy, không nhảy.
      final closed = record.copyWith(checkOut: DateTime(2026, 9, 21, 16, 0));
      expect(computeDay(closed, settings).pay, closeTo(at(16, 0), 1));
    });

    test('ca đang mở, chưa cài khung cố định nào -> không ngừng tính ở giờ nghỉ', () {
      final settings = baseSettings();
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      // 7:00-12:30 = 5h30 = 165.000đ.
      expect(liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 12, 30)), closeTo(165000, 1));
    });

    test('ca đang mở -> chưa cộng trừ theo khung cố định, lúc chấm ra mới chốt theo khung khớp', () {
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
        // Dữ liệu cũ còn lưu "khung nhiều mục": không ảnh hưởng số đang chạy.
        breakSegments: [const BreakSegment(from: Clock(7, 0), to: Clock(9, 0), breakMinutes: 15)],
      );
      final record = DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0));
      // Đang mở ca lúc 9:00: đủ 2h, lương 30.000đ/giờ = 60.000đ, chưa trừ gì.
      final at9h = liveEstimatedPay(record, settings, DateTime(2026, 9, 21, 9, 0));
      expect(at9h, closeTo(60000, 1));

      // Chấm ra 16:00 khớp khung cố định -> trừ 15p: 8h45p = 262.500đ.
      final closed = record.copyWith(checkOut: DateTime(2026, 9, 21, 16, 0));
      expect(liveEstimatedPay(closed, settings, DateTime(2026, 9, 21, 16, 0)), closeTo(262500, 1));
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
