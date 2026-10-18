import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/config_share.dart';
import 'package:cham_cong_don_gian/domain/leave.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:cham_cong_don_gian/domain/payslip.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cách tính bù tăng ca (`Y-TUONG-MOI.md`): công nhân bật công tắc thì lấy tăng ca bù giờ thiếu.
DayRecord _shift(DateTime day, int inH, int inM, int outH, int outM, {bool late = false}) => DayRecord(
  date: day,
  checkIn: DateTime(day.year, day.month, day.day, inH, inM),
  checkOut: DateTime(day.year, day.month, day.day, outH, outM),
  isLate: late,
);

void main() {
  // Bộ số gốc: không có khung tăng ca (không trừ phút nghỉ), trợ cấp 0, đi muộn trừ 30 phút.
  final defaults = AppSettings.defaultsFor(WorkerKind.worker);
  final off = defaults.copyWith(
    overtimeBrackets: const [],
    incomeItems: [for (final i in defaults.incomeItems) i.id == payItemAllowance ? i.copyWith(amount: 0) : i],
  );
  // Mức "bù cả ngày tự nghỉ", chưa có ngày phép.
  final on = off.copyWith(offsetMode: OvertimeOffsetMode.all);
  final company = off.copyWith(offsetMode: OvertimeOffsetMode.company);

  // Kỳ 21/07–20/08/2026, công chuẩn 27 ngày. 21/07 là thứ Ba, 25/07 thứ Bảy, 26/07 chủ nhật.
  final period = PayPeriod(DateTime(2026, 7, 21), DateTime(2026, 8, 20));
  final after = DateTime(2026, 8, 25, 9);

  Payslip slip(AppSettings s, List<DayRecord> list, {DateTime? now}) {
    final recs = {for (final r in list) dateKey(r.date): r};
    return computePayslip(
      settings: s,
      period: period,
      recordOf: (d) => recs[dateKey(d)] ?? DayRecord(date: dateOnly(d)),
      now: now ?? after,
    );
  }

  group('chia giờ của một ngày', () {
    test('vào 9:00 về 18:00: tắt thì 6h thường + 2h tăng ca, bật thì 8h thường', () {
      final r = _shift(DateTime(2026, 7, 21), 9, 0, 18, 0);
      final a = computeDay(r, off);
      expect((a.normalMinutes, a.overtimeMinutes), (360, 120));
      final b = computeDay(r, on);
      expect((b.normalMinutes, b.overtimeMinutes), (480, 0));
    });

    test('thứ 7: 7:00–11:30 là giờ thường, từ 12:30 là tăng ca', () {
      final sat = DateTime(2026, 7, 25);
      final r = computeDay(_shift(sat, 7, 0, 14, 0), on);
      expect((r.normalMinutes, r.overtimeMinutes), (270, 90));
      final morning = computeDay(_shift(sat, 7, 0, 11, 30), on);
      expect((morning.normalMinutes, morning.overtimeMinutes), (270, 0));
    });

    test('đi muộn: mức "cả ngày tự nghỉ" không trừ phút, mức "chỉ ngày do công ty" vẫn trừ', () {
      final r = _shift(DateTime(2026, 7, 21), 7, 0, 16, 0, late: true);
      expect(computeDay(r, off).normalMinutes, 450);
      expect(computeDay(r, on).normalMinutes, 480);
      // Phút bị trừ không được tăng ca của chính ngày đó bù lại.
      final longer = _shift(DateTime(2026, 7, 21), 7, 0, 17, 0, late: true);
      final c = computeDay(longer, company);
      expect((c.normalMinutes, c.overtimeMinutes), (450, 60));
    });

    test('giờ sửa tay thay cho số tự tính', () {
      final r = _shift(DateTime(2026, 7, 21), 9, 0, 16, 0).copyWith(manualNormalMinutes: 480, manualOvertimeMinutes: 30);
      final a = computeDay(r, on);
      expect((a.normalMinutes, a.overtimeMinutes), (480, 30));
      // Không có giờ vào/ra mà có giờ sửa tay thì vẫn tính.
      final only = DayRecord(date: DateTime(2026, 7, 22), manualNormalMinutes: 240);
      expect(computeDay(only, off).normalMinutes, 240);
      expect(slip(off, [only]).normalSeconds, 240 * 60);
      // JSON giữ được giờ sửa tay.
      final back = DayRecord.fromJson(r.toJson());
      expect((back.manualNormalMinutes, back.manualOvertimeMinutes), (480, 30));
    });

    test('ca đang mở chia giống như khi đã chấm ra', () {
      final day = DateTime(2026, 7, 21);
      final open = DayRecord(date: day, checkIn: DateTime(2026, 7, 21, 9));
      final live = liveDayHours(open, on, DateTime(2026, 7, 21, 18));
      expect((live.normalSeconds, live.overtimeSeconds), (8 * 3600, 0));
    });

    test('chủ nhật không chia lại', () {
      final r = computeDay(_shift(DateTime(2026, 7, 26), 7, 0, 18, 0), on);
      final a = computeDay(_shift(DateTime(2026, 7, 26), 7, 0, 18, 0), off);
      expect((r.normalMinutes, r.overtimeMinutes), (a.normalMinutes, a.overtimeMinutes));
    });
  });

  group('bù theo kỳ', () {
    final days = [
      _shift(DateTime(2026, 7, 21), 7, 0, 18, 0), // T3: 8h + 2h tăng ca
      _shift(DateTime(2026, 7, 22), 7, 30, 16, 0, late: true), // T4: thiếu 0,5h
      DayRecord(date: DateTime(2026, 7, 23), isDayOff: true), // T5: nghỉ không lương, thiếu 8h
      DayRecord(date: DateTime(2026, 7, 24), isDayOff: true, paidLeave: true), // T6: nghỉ có lương, không bù
      _shift(DateTime(2026, 7, 26), 7, 0, 11, 0), // CN: 4h
      _shift(DateTime(2026, 7, 27), 7, 0, 20, 0), // T2: 8h + 4h tăng ca
    ];

    test('lấy tăng ca T2–T7 trước, rồi mới tới chủ nhật', () {
      final s = slip(on, days);
      expect(s.overtimeOffset, isTrue);
      expect([for (final d in s.offsetDays) (d.date.day, d.dayOff, d.shortSeconds, d.coveredSeconds)], [
        (22, false, 1800, 1800),
        (23, true, 8 * 3600, 8 * 3600),
      ]);
      expect(s.offsetTakenSeconds, 8 * 3600 + 1800);
      expect(s.offsetUncoveredSeconds, 0);
      // Tăng ca 6h (T3, T2) + chủ nhật 4h = 10h, trừ 8,5h bù thì còn 1,5h (của chủ nhật).
      expect(s.overtimeSeconds, 5400);
      // Giờ công: 8 + 7,5 + 8 + 8,5 giờ bù = 32h, tức 4 ngày công.
      expect(s.normalSeconds, 32 * 3600);
      expect(s.workDays, closeTo(4, 1e-9));
      final salary = s.incomes.firstWhere((l) => l.id == payItemSalary).amount;
      expect(salary, closeTo(4000000 / 27 * (4 + 1), 0.01));
      final overtime = s.incomes.firstWhere((l) => l.id == payItemOvertime);
      expect(overtime.amount, closeTo(1.5 * 45000, 0.01));
      expect(overtime.how, contains('bù giờ thiếu'));
      // Tiền từng ngày cộng lại vẫn bằng Thực nhận.
      expect(s.dayAmounts.values.fold(0.0, (a, b) => a + b), closeTo(s.net, 0.01));
    });

    test('tắt công tắc: tính như cũ, không bù', () {
      final s = slip(off, days);
      expect(s.overtimeOffset, isFalse);
      expect(s.offsetDays, isEmpty);
    });

    test('tăng ca không đủ bù thì phần thiếu giữ nguyên', () {
      final s = slip(on, [
        _shift(DateTime(2026, 7, 21), 7, 0, 18, 0),
        DayRecord(date: DateTime(2026, 7, 23), isDayOff: true),
      ]);
      expect(s.offsetTakenSeconds, 2 * 3600);
      expect(s.offsetUncoveredSeconds, 6 * 3600);
      expect(s.overtimeSeconds, 0);
      expect(s.workDays, closeTo(10 / 8, 1e-9));
    });

    test('nghỉ không lương thứ 7 bù 4,5h; chủ nhật và ngày lễ không bù', () {
      final s = slip(on, [
        _shift(DateTime(2026, 7, 21), 7, 0, 22, 0),
        DayRecord(date: DateTime(2026, 7, 25), isDayOff: true),
        DayRecord(date: DateTime(2026, 7, 26), isDayOff: true),
      ]);
      expect([for (final d in s.offsetDays) (d.date.day, d.shortSeconds)], [(25, 4 * 3600 + 1800)]);
    });

    test('ca đang mở của hôm nay chưa tính là thiếu giờ', () {
      final today = DateTime(2026, 7, 22);
      final s = slip(on, [
        _shift(DateTime(2026, 7, 21), 7, 0, 18, 0),
        DayRecord(date: today, checkIn: DateTime(2026, 7, 22, 7)),
      ], now: DateTime(2026, 7, 22, 10));
      expect(s.offsetDays, isEmpty);
    });

    test('công nhật bật công tắc cũng không đổi gì', () {
      final daily = AppSettings.defaultsFor(
        WorkerKind.daily,
      ).copyWith(overtimeBrackets: const [], offsetMode: OvertimeOffsetMode.all);
      final s = slip(daily, days);
      expect(s.overtimeOffset, isFalse);
      expect(computeDay(days.first, daily).overtimeMinutes, 120);
    });
  });

  group('mức "chỉ ngày do công ty"', () {
    test('công ty cho nghỉ và ngày vào muộn theo yêu cầu thì bù; tự nghỉ, tự đi muộn thì không', () {
      final s = slip(company, [
        _shift(DateTime(2026, 7, 21), 7, 0, 22, 0), // 8h + 6h tăng ca
        _shift(DateTime(2026, 7, 22), 9, 0, 16, 0), // công ty cho vào 9h: thiếu 2h, được bù
        _shift(DateTime(2026, 7, 23), 7, 30, 16, 0, late: true), // tự đi muộn: không bù, trừ 30 phút
        DayRecord(date: DateTime(2026, 7, 24), isDayOff: true, companyOff: true), // công ty cho nghỉ: bù 8h
        DayRecord(date: DateTime(2026, 7, 27), isDayOff: true), // tự nghỉ, không có phép: mất công
      ]);
      expect([for (final d in s.offsetDays) (d.date.day, d.dayOff, d.companyOff, d.shortSeconds, d.coveredSeconds)], [
        (22, false, false, 2 * 3600, 2 * 3600),
        (24, true, true, 8 * 3600, 4 * 3600),
      ]);
      expect(s.offsetUncoveredSeconds, 4 * 3600);
      // Ngày 22 được 6h; ngày 23: 7h30–16h là 7,5h, trừ 30 phút đi muộn còn 7h. Bù thêm 6h.
      expect(s.normalSeconds, (8 + 6 + 7 + 6) * 3600);
    });

    test('mức "cả ngày tự nghỉ" thì tự nghỉ, tự đi muộn cũng được bù', () {
      final s = slip(on, [
        _shift(DateTime(2026, 7, 21), 7, 0, 22, 0),
        _shift(DateTime(2026, 7, 23), 7, 30, 16, 0, late: true),
        DayRecord(date: DateTime(2026, 7, 27), isDayOff: true),
      ]);
      expect([for (final d in s.offsetDays) (d.date.day, d.late, d.coveredSeconds)], [
        (23, true, 1800),
        (27, false, 5 * 3600 + 1800),
      ]);
    });
  });

  group('ngày phép', () {
    // Bật bù từ đầu kỳ 21/07 với 1 ngày phép; kỳ sau bắt đầu 21/08 được cộng thêm 1.
    final withLeave = company.copyWith(leaveAnchors: [LeaveAnchor(date: DateTime(2026, 7, 21), days: 1)]);
    final days = [
      DayRecord(date: DateTime(2026, 7, 23), isDayOff: true), // dùng phép
      DayRecord(date: DateTime(2026, 7, 24), isDayOff: true), // hết phép: không lương
      DayRecord(date: DateTime(2026, 7, 26), isDayOff: true), // chủ nhật: không trừ phép
      DayRecord(date: DateTime(2026, 8, 24), isDayOff: true), // kỳ sau: dùng phép mới
    ];
    final recs = {for (final r in days) dateKey(r.date): r};
    DayRecord recordOf(DateTime d) => recs[dateKey(d)] ?? DayRecord(date: dateOnly(d));

    test('tự nghỉ trừ phép trước, hết phép mới là không lương; mỗi kỳ cộng 1', () {
      final s = slip(withLeave, days);
      expect(s.leaveDates, {DateTime(2026, 7, 23)});
      expect(s.leaveUsedDays, 1);
      expect(s.paidLeaveDays, 1);
      expect(s.leaveBalance, 0);
      final salary = s.incomes.firstWhere((l) => l.id == payItemSalary).amount;
      expect(salary, closeTo(4000000 / 27, 0.01));
      expect(leaveBalanceFor(withLeave, recordOf, DateTime(2026, 7, 23)), 1);
      expect(leaveBalanceFor(withLeave, recordOf, DateTime(2026, 7, 24)), 0);
      expect(leaveBalanceFor(withLeave, recordOf, DateTime(2026, 8, 21)), 1);
      expect(leaveState(withLeave, recordOf, DateTime(2026, 8, 30)).used, {DateTime(2026, 7, 23), DateTime(2026, 8, 24)});
    });

    test('sửa số phép thì tính lại từ ngày sửa', () {
      final edited = withLeave.copyWith(
        leaveAnchors: [...withLeave.leaveAnchors, LeaveAnchor(date: DateTime(2026, 7, 24), days: 3)],
      );
      expect(leaveState(edited, recordOf, DateTime(2026, 7, 31)).used, {DateTime(2026, 7, 23), DateTime(2026, 7, 24)});
      expect(leaveBalanceFor(edited, recordOf, DateTime(2026, 7, 31)), 2);
    });

    test('tắt bù thì không có ngày phép', () {
      final offLeave = withLeave.copyWith(offsetMode: OvertimeOffsetMode.off);
      expect(leaveState(offLeave, recordOf, DateTime(2026, 8, 30)).used, isEmpty);
    });
  });

  group('sửa tay số của kỳ', () {
    test('ngày công thực tế và giờ tăng ca theo số công ty chốt', () {
      final records = [_shift(DateTime(2026, 7, 21), 7, 0, 18, 0), _shift(DateTime(2026, 7, 22), 7, 0, 16, 0)];
      final s = slip(
        off.copyWith(workDaysOverride: {period.key: 20}, overtimeHoursOverride: {period.key: 10}),
        records,
      );
      expect(s.workDaysOverridden && s.overtimeOverridden, isTrue);
      expect(s.autoWorkDays, closeTo(2, 1e-9));
      expect(s.workDays, 20);
      expect(s.incomes.firstWhere((l) => l.id == payItemSalary).amount, closeTo(4000000 / 27 * 20, 0.01));
      expect(s.incomes.firstWhere((l) => l.id == payItemOvertime).amount, closeTo(10 * 45000, 0.01));
      expect(s.overtimeSeconds, 10 * 3600);
      expect(s.dayAmounts.values.fold(0.0, (a, b) => a + b), closeTo(s.net, 0.01));
    });

    test('kỳ chưa có giờ tăng ca nào: tính theo giá tăng ca T2–T7', () {
      final s = slip(off.copyWith(overtimeHoursOverride: {period.key: 4}), [_shift(DateTime(2026, 7, 21), 7, 0, 16, 0)]);
      expect(s.incomes.firstWhere((l) => l.id == payItemOvertime).amount, closeTo(4 * 45000, 0.01));
    });
  });

  test('mức bù, ngày phép, số sửa tay được lưu; mức bù đi kèm khi sao chép cấu hình', () {
    final full = company.copyWith(
      leaveAnchors: [LeaveAnchor(date: DateTime(2026, 7, 21), days: 2)],
      workDaysOverride: {'k': 20},
      overtimeHoursOverride: {'k': 5.5},
    );
    final back = AppSettings.fromJson(full.toJson());
    expect(back.offsetMode, OvertimeOffsetMode.company);
    expect((back.leaveAnchors.single.date, back.leaveAnchors.single.days), (DateTime(2026, 7, 21), 2.0));
    expect((back.workDaysOverride['k'], back.overtimeHoursOverride['k']), (20.0, 5.5));
    // Bản thử đầu lưu công tắc bật/tắt: bật thì là bù mọi ngày.
    final legacy = off.toJson()..remove('offsetMode');
    expect(AppSettings.fromJson({...legacy, 'overtimeOffset': true}).offsetMode, OvertimeOffsetMode.all);
    for (final m in OvertimeOffsetMode.values) {
      expect(decodeSettings(encodeSettings(off.copyWith(offsetMode: m)), current: on)!.offsetMode, m);
    }
    final dayOff = DayRecord(date: DateTime(2026, 7, 24), isDayOff: true, companyOff: true);
    expect(DayRecord.fromJson(dayOff.toJson()).companyOff, isTrue);
    expect(dayOff.copyWith(isDayOff: false).companyOff, isFalse);
  });
}
