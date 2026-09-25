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
