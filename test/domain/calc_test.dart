import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
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

  test('cộng trừ giờ theo giờ vào (giải lao)', () {
    final settings = baseSettings().copyWith(
      breakRules: [const BreakRule(from: Clock(7, 0), to: Clock(8, 59), deltaMinutes: -15)],
    );
    final record = DayRecord(
      date: DateTime(2026, 9, 21),
      checkIn: DateTime(2026, 9, 21, 7, 0),
      checkOut: DateTime(2026, 9, 21, 16, 0),
    );
    final result = computeDay(record, settings);
    expect(result.normalMinutes, 9 * 60 - 15);
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

    test('có cộng trừ giờ và đi muộn -> số lúc đang chạy khớp số chính thức ngay khi chấm ra (không tụt đột ngột)', () {
      final settings = baseSettings().copyWith(
        breakRules: [const BreakRule(from: Clock(7, 0), to: Clock(8, 59), deltaMinutes: -15)],
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
}
