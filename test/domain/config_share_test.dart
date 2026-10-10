import 'dart:convert';

import 'package:cham_cong_don_gian/domain/config_share.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mine = AppSettings.defaultsFor(WorkerKind.worker).copyWith(
    holidays: [Holiday(date: DateTime(2026, 9, 2), name: 'Quốc khánh')],
    gps: AppSettings().gps.copyWith(enabled: true, latitude: 21, longitude: 105),
  );

  test('chuỗi kiểu mới gọn một dòng, không kèm ngày lễ và GPS', () {
    final s = AppSettings.defaultsFor(WorkerKind.worker).copyWith(holidays: mine.holidays, gps: mine.gps);
    final text = encodeSettings(s);
    expect(text.startsWith(configSharePrefix), isTrue);
    expect(text.contains('\n'), isFalse);
    expect(text.contains('Quốc khánh'), isFalse);
    expect(text.contains('105'), isFalse);
    expect(text.length, lessThan(700));
  });

  test('dán chuỗi kiểu mới: lấy phần lương, giữ ngày lễ và GPS của máy nhận', () {
    final sender = AppSettings.defaultsFor(WorkerKind.daily).copyWith(
      dailyWage: 400000,
      lateRule: const LateRule(after: Clock(7, 0), unit: LateUnit.money, amount: 20000),
      incomeItems: [
        ...AppSettings.defaultsFor(WorkerKind.daily).incomeItems,
        const IncomeItem(id: 'x', name: 'Xăng xe', amount: 1.5, calcMethod: IncomeCalcMethod.percentOfBaseSalary),
      ],
    );
    final got = decodeSettings(encodeSettings(sender), current: mine)!;
    expect(got.workerKind, WorkerKind.daily);
    expect(got.dailyWage, 400000);
    expect(got.payPeriod.type, PayPeriodType.semiMonthly);
    expect(got.lateRule.unit, LateUnit.money);
    expect(got.lateRule.amount, 20000);
    expect(got.incomeItems.map((i) => i.name), [...sender.incomeItems.map((i) => i.name)]);
    expect(got.incomeItems.last.amount, 1.5);
    expect(got.incomeItems.firstWhere((i) => i.id == payItemLunch).activeAfter, const Clock(12, 30));
    expect(got.holidays.single.name, 'Quốc khánh');
    expect(got.gps.latitude, 21);
  });

  test('khoản căn cứ và bảng lương/giờ giữ đúng sau khi chép', () {
    final sender = AppSettings.defaultsFor(WorkerKind.worker);
    final got = decodeSettings(encodeSettings(sender), current: mine)!;
    expect(got.incomeItems.firstWhere((i) => i.id == payItemPerformance).inBasis, isTrue);
    expect(got.wageTable.of(DayType.holiday).normalPerHour, 63000);
    expect(got.payPeriod.monthlyStartDay, 21);
    expect(got.baseSalary, 4000000);
  });

  test('khung tăng ca được chép theo; chuỗi gọn chưa có khung tăng ca thì giữ khung của máy nhận', () {
    const bracket = OvertimeBracket(from: Clock(16, 0), to: Clock(18, 0), breakMinutes: 15);
    const myBracket = OvertimeBracket(from: Clock(17, 0), to: Clock(22, 0), breakMinutes: 30);
    final receiver = mine.copyWith(overtimeBrackets: [myBracket]);

    final sender = AppSettings.defaultsFor(WorkerKind.worker).copyWith(overtimeBrackets: [bracket]);
    final got = decodeSettings(encodeSettings(sender), current: receiver)!;
    expect(got.overtimeBrackets.single.from, const Clock(16, 0));
    expect(got.overtimeBrackets.single.to, const Clock(18, 0));
    expect(got.overtimeBrackets.single.breakMinutes, 15);

    // Máy gửi không có khung nào thì máy nhận cũng không còn khung nào.
    final none = decodeSettings(encodeSettings(AppSettings.defaultsFor(WorkerKind.worker)), current: receiver)!;
    expect(none.overtimeBrackets, isEmpty);

    // Chuỗi gọn của bản chưa kèm khung tăng ca (không có khóa "o").
    final body = jsonDecode(encodeSettings(sender).substring(configSharePrefix.length)) as Map<String, dynamic>;
    final legacy = '$configSharePrefix${jsonEncode(body..remove('o'))}';
    final kept = decodeSettings(legacy, current: receiver)!;
    expect(kept.overtimeBrackets.single.breakMinutes, 30);
  });

  test('vẫn đọc được chuỗi kiểu cũ (JSON đầy đủ của bản cũ, chưa có workerKind)', () {
    final old = AppSettings(
      wageTable: WageTable(rates: {DayType.weekday: const WageRate(normalPerHour: 25000, overtimePerHour: 40000)}),
      holidays: [Holiday(date: DateTime(2026, 1, 1), name: 'Tết dương')],
    ).toJson()..remove('workerKind');
    final text = const JsonEncoder.withIndent('  ').convert(old);
    final got = decodeSettings(text, current: mine)!;
    expect(got.workerKind, WorkerKind.worker);
    expect(got.baseSalary, 25000 * 8 * 26);
    expect(got.incomeItems.first.id, payItemSalary);
    // Ngày lễ của máy nhận giữ nguyên, không lấy theo chuỗi.
    expect(got.holidays.single.name, 'Quốc khánh');
  });

  test('chuỗi rác -> null', () {
    expect(decodeSettings('xin chào', current: mine), isNull);
    expect(decodeSettings('$configSharePrefix{hỏng', current: mine), isNull);
  });
}
