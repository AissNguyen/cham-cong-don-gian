import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:cham_cong_don_gian/domain/pay_period.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('periodContaining theo tháng, ngày bắt đầu tự chọn', () {
    test('20/09 -> 20/09 tới 19/10 nếu ngày bắt đầu là 20', () {
      final cfg = const PayPeriodConfig(type: PayPeriodType.monthly, monthlyStartDay: 20);
      final p = periodContaining(DateTime(2026, 9, 25), cfg);
      expect(p.start, DateTime(2026, 9, 20));
      expect(p.end, DateTime(2026, 10, 19));
    });

    test('15/09 (trước ngày bắt đầu) -> kỳ của tháng trước, 20/08 tới 19/09', () {
      final cfg = const PayPeriodConfig(type: PayPeriodType.monthly, monthlyStartDay: 20);
      final p = periodContaining(DateTime(2026, 9, 15), cfg);
      expect(p.start, DateTime(2026, 8, 20));
      expect(p.end, DateTime(2026, 9, 19));
    });

    test('ngày bắt đầu 31 ở tháng 2 (không đủ ngày) -> ép về ngày cuối tháng 2, tính từ kỳ trước', () {
      final cfg = const PayPeriodConfig(type: PayPeriodType.monthly, monthlyStartDay: 31);
      final p = periodContaining(DateTime(2026, 2, 27), cfg);
      expect(p.start, DateTime(2026, 1, 31));
      expect(p.end, DateTime(2026, 2, 27));
    });
  });

  group('periodContaining 2 kỳ mỗi tháng', () {
    const cfg = PayPeriodConfig(type: PayPeriodType.semiMonthly);

    test('10/09 -> kỳ 1-15/09', () {
      final p = periodContaining(DateTime(2026, 9, 10), cfg);
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.end, DateTime(2026, 9, 15));
    });

    test('20/09 -> kỳ 16-30/09', () {
      final p = periodContaining(DateTime(2026, 9, 20), cfg);
      expect(p.start, DateTime(2026, 9, 16));
      expect(p.end, DateTime(2026, 9, 30));
    });
  });

  group('2 kỳ mỗi tháng, kỳ 1 tự chọn ngày', () {
    const cfg = PayPeriodConfig(type: PayPeriodType.semiMonthly, semiFirstStart: 5, semiFirstEnd: 19);

    test('10/09 -> kỳ 1 từ 05/09 tới 19/09', () {
      final p = periodContaining(DateTime(2026, 9, 10), cfg);
      expect(p.start, DateTime(2026, 9, 5));
      expect(p.end, DateTime(2026, 9, 19));
    });

    test('25/09 -> kỳ 2 từ 20/09 tới 04/10 (trước ngày đầu kỳ 1 của tháng sau)', () {
      final p = periodContaining(DateTime(2026, 9, 25), cfg);
      expect(p.start, DateTime(2026, 9, 20));
      expect(p.end, DateTime(2026, 10, 4));
    });

    test('03/10 (trước ngày đầu kỳ 1) -> vẫn thuộc kỳ 2 của tháng trước', () {
      final p = periodContaining(DateTime(2026, 10, 3), cfg);
      expect(p.start, DateTime(2026, 9, 20));
      expect(p.end, DateTime(2026, 10, 4));
    });

    test('qua năm: 02/01/2027 -> kỳ 2 từ 20/12/2026 tới 04/01/2027', () {
      final p = periodContaining(DateTime(2027, 1, 2), cfg);
      expect(p.start, DateTime(2026, 12, 20));
      expect(p.end, DateTime(2027, 1, 4));
    });

    test('các kỳ nối liền nhau, không hở không trùng', () {
      var p = periodContaining(DateTime(2026, 1, 1), cfg);
      for (var i = 0; i < 30; i++) {
        final next = periodContaining(p.end.add(const Duration(days: 1)), cfg);
        expect(next.start, p.end.add(const Duration(days: 1)));
        expect(next.end.isBefore(next.start), isFalse);
        p = next;
      }
    });

    test('số ngoài khoảng an toàn bị ép lại: kỳ 1 từ 1 tới 31 -> 1 tới 27, tháng 2 vẫn có kỳ 2', () {
      const bad = PayPeriodConfig(type: PayPeriodType.semiMonthly, semiFirstStart: 1, semiFirstEnd: 31);
      expect(semiMonthlyBounds(bad), (1, 27));
      final p = periodContaining(DateTime(2026, 2, 28), bad);
      expect(p.start, DateTime(2026, 2, 28));
      expect(p.end, DateTime(2026, 2, 28));
    });
  });

  test('recentPeriods trả về đúng số kỳ liền trước, mới nhất trước', () {
    const cfg = PayPeriodConfig(type: PayPeriodType.semiMonthly);
    final periods = recentPeriods(DateTime(2026, 9, 20), cfg, count: 3);
    expect(periods.length, 3);
    expect(periods[0].start, DateTime(2026, 9, 16));
    expect(periods[1].start, DateTime(2026, 9, 1));
    expect(periods[2].start, DateTime(2026, 8, 16));
  });
}
