/// Danh sách ngày lễ Việt Nam gợi ý sẵn, để người dùng không phải tự thêm từ đầu.
library;

import 'lunar.dart' as lunar;
import 'models.dart';

/// Ngày lễ theo luật lao động cho từng năm dương lịch trong [years] (Tết tính theo lịch âm).
List<Holiday> defaultVietnameseHolidays(Iterable<int> years) {
  final result = <Holiday>[];
  for (final y in years) {
    result.add(Holiday(date: DateTime(y, 1, 1), name: 'Tết Dương lịch'));
    result.add(Holiday(date: DateTime(y, 4, 30), name: 'Giải phóng miền Nam'));
    result.add(Holiday(date: DateTime(y, 5, 1), name: 'Quốc tế Lao động'));
    result.add(Holiday(date: DateTime(y, 9, 2), name: 'Quốc khánh'));

    final tetEve = lunar.lunarToSolar(30, 12, y - 1);
    if (tetEve != null) result.add(Holiday(date: tetEve, name: 'Tất niên (30 Tết)'));
    for (var d = 1; d <= 4; d++) {
      final solar = lunar.lunarToSolar(d, 1, y);
      if (solar != null) result.add(Holiday(date: solar, name: 'Tết Nguyên Đán (mùng $d)'));
    }
    final gioTo = lunar.lunarToSolar(10, 3, y);
    if (gioTo != null) result.add(Holiday(date: gioTo, name: 'Giỗ Tổ Hùng Vương'));
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

/// Bù thêm ngày lễ mặc định còn thiếu vào [existing] — để dữ liệu cũ (từ trước khi có tính năng
/// gợi ý sẵn, hoặc đã lâu chưa mở app qua năm mới) cũng tự được phủ đủ mà không cần đợi "lần đầu
/// mở app". So khớp theo đúng ngày (không phải theo năm) — ngày nào đã có sẵn (kể cả tự thêm tay,
/// hoặc tên khác) thì bỏ qua, không cộng dồn trùng ngày.
///
/// Ngày lễ tự thêm có đánh dấu lặp hằng năm ([HolidayRecurrence.solarYearly]/[lunarYearly]) cũng
/// được tự sinh thêm cho các năm còn thiếu trong [years] — bản sinh ra luôn là [HolidayRecurrence.once]
/// (chỉ bản gốc do người dùng tự thêm mới tiếp tục sinh thêm năm sau; xóa một năm cụ thể không bị
/// "mọc lại" do năm khác, xóa bản gốc thì ngừng sinh thêm nhưng các năm đã sinh trước đó vẫn giữ).
List<Holiday> backfillMissingYears(List<Holiday> existing, Iterable<int> years) {
  final existingDates = existing.map((h) => DateTime(h.date.year, h.date.month, h.date.day)).toSet();
  final yearsList = years.toList();

  final missingDefaults = defaultVietnameseHolidays(
    yearsList,
  ).where((h) => !existingDates.contains(DateTime(h.date.year, h.date.month, h.date.day)));

  final generated = <Holiday>[];
  for (final h in existing) {
    if (h.recurrence == HolidayRecurrence.once) continue;
    for (final y in yearsList) {
      if (y == h.date.year) continue;
      DateTime? newDate;
      if (h.recurrence == HolidayRecurrence.solarYearly) {
        newDate = DateTime(y, h.date.month, h.date.day);
      } else {
        final origin = lunar.solarToLunar(h.date.day, h.date.month, h.date.year);
        newDate = lunar.lunarToSolar(origin.day, origin.month, y, leap: origin.leap);
      }
      if (newDate == null) continue;
      final key = DateTime(newDate.year, newDate.month, newDate.day);
      if (!existingDates.add(key)) continue;
      generated.add(Holiday(date: newDate, name: h.name));
    }
  }

  final missing = [...missingDefaults, ...generated];
  if (missing.isEmpty) return existing;
  return [...existing, ...missing]..sort((a, b) => a.date.compareTo(b.date));
}
