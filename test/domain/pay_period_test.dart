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

  test('recentPeriods trả về đúng số kỳ liền trước, mới nhất trước', () {
    const cfg = PayPeriodConfig(type: PayPeriodType.semiMonthly);
    final periods = recentPeriods(DateTime(2026, 9, 20), cfg, count: 3);
    expect(periods.length, 3);
    expect(periods[0].start, DateTime(2026, 9, 16));
    expect(periods[1].start, DateTime(2026, 9, 1));
    expect(periods[2].start, DateTime(2026, 8, 16));
  });
}
