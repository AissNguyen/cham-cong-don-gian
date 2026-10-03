import 'package:cham_cong_don_gian/domain/default_holidays.dart';
import 'package:cham_cong_don_gian/domain/lunar.dart' as lunar;
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('backfillMissingYears', () {
    test('danh sách rỗng -> bù đủ cả năm yêu cầu', () {
      final result = backfillMissingYears([], [2026]);
      expect(result, isNotEmpty);
      expect(result.every((h) => h.date.year == 2026), isTrue);
    });

    test('đã có 1 ngày lễ tự thêm (không trùng ngày mặc định) -> vẫn bù thêm các ngày mặc định còn thiếu', () {
      // Ngày tự thêm không khớp bất kỳ ngày lễ mặc định nào (24/9 không phải ngày lễ chuẩn).
      final existing = [Holiday(date: DateTime(2026, 9, 24), name: '')];
      final result = backfillMissingYears(existing, [2026]);
      // Vẫn giữ ngày tự thêm, và có thêm ít nhất Tết Dương lịch, Quốc khánh (2/9)...
      expect(result.any((h) => h.date == DateTime(2026, 9, 24)), isTrue);
      expect(result.any((h) => h.date == DateTime(2026, 1, 1)), isTrue);
      expect(result.any((h) => h.date == DateTime(2026, 9, 2)), isTrue);
    });

    test('ngày đã trùng với ngày lễ mặc định -> không cộng dồn trùng', () {
      final existing = [Holiday(date: DateTime(2026, 1, 1), name: 'Tết Dương lịch')];
      final result = backfillMissingYears(existing, [2026]);
      expect(result.where((h) => h.date == DateTime(2026, 1, 1)).length, 1);
    });

    test('đã đủ hết ngày lễ mặc định của năm đó -> không thêm gì, trả về đúng danh sách cũ', () {
      final full = defaultVietnameseHolidays([2026]);
      final result = backfillMissingYears(full, [2026]);
      expect(result.length, full.length);
    });

    test('nhiều năm, năm sau chưa có gì -> chỉ bù cho năm còn thiếu', () {
      final existing = defaultVietnameseHolidays([2026]);
      final result = backfillMissingYears(existing, [2026, 2027]);
      expect(result.any((h) => h.date.year == 2027), isTrue);
      expect(result.where((h) => h.date.year == 2026).length, existing.length);
    });

    test('ngày lễ tự thêm lặp theo dương lịch -> tự sinh thêm năm sau, giữ nguyên ngày/tháng', () {
      final existing = [
        Holiday(date: DateTime(2026, 6, 15), name: 'Thành lập công ty', recurrence: HolidayRecurrence.solarYearly),
      ];
      final result = backfillMissingYears(existing, [2026, 2027, 2028]);
      expect(result.any((h) => h.date == DateTime(2027, 6, 15) && h.name == 'Thành lập công ty'), isTrue);
      expect(result.any((h) => h.date == DateTime(2028, 6, 15) && h.name == 'Thành lập công ty'), isTrue);
      // Bản gốc vẫn còn, không bị nhân đôi.
      expect(result.where((h) => h.date == DateTime(2026, 6, 15)).length, 1);
    });

    test('ngày lễ tự thêm lặp theo âm lịch -> mỗi năm tính lại đúng ngày dương theo lịch âm', () {
      const originSolar = (day: 15, month: 8, year: 2026);
      final originLunar = lunar.solarToLunar(originSolar.day, originSolar.month, originSolar.year);
      final existing = [
        Holiday(
          date: DateTime(originSolar.year, originSolar.month, originSolar.day),
          name: 'Giỗ tổ nghề',
          recurrence: HolidayRecurrence.lunarYearly,
        ),
      ];
      final result = backfillMissingYears(existing, [2026, 2027]);
      final expected2027 = lunar.lunarToSolar(originLunar.day, originLunar.month, 2027, leap: originLunar.leap);
      expect(result.any((h) => h.date == expected2027 && h.name == 'Giỗ tổ nghề'), isTrue);
    });

    test('ngày lễ đã sinh ra (không phải bản gốc) -> không tự sinh thêm, xóa bản gốc thì ngừng', () {
      final generated = Holiday(date: DateTime(2027, 6, 15), name: 'Thành lập công ty');
      final result = backfillMissingYears([generated], [2026, 2027, 2028]);
      expect(result.any((h) => h.date == DateTime(2026, 6, 15)), isFalse);
      expect(result.any((h) => h.date == DateTime(2028, 6, 15)), isFalse);
      expect(result.contains(generated), isTrue);
    });
  });
}
