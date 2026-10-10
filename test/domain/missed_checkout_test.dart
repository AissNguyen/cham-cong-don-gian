import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 10, 12);
  final open = DayRecord(date: day, checkIn: DateTime(2026, 10, 12, 7, 0));

  test('ca hôm nay đang mở, chưa tới 23:00 -> chưa coi là quên chấm về', () {
    expect(isMissedCheckOut(open, DateTime(2026, 10, 12, 16, 30)), isFalse);
    expect(isMissedCheckOut(open, DateTime(2026, 10, 12, 22, 59)), isFalse);
  });

  test('ca hôm nay vẫn mở khi đã qua 23:00 -> quên chấm về', () {
    expect(isMissedCheckOut(open, DateTime(2026, 10, 12, 23, 0)), isTrue);
    expect(isMissedCheckOut(open, DateTime(2026, 10, 12, 23, 45)), isTrue);
  });

  test('ca của ngày đã qua mà chưa có giờ về -> quên chấm về, bất kể mấy giờ', () {
    expect(isMissedCheckOut(open, DateTime(2026, 10, 13, 6, 0)), isTrue);
    expect(isMissedCheckOut(open, DateTime(2026, 10, 20, 12, 0)), isTrue);
  });

  test('đã có giờ về, chưa chấm vào, hoặc ngày nghỉ -> không phải quên chấm về', () {
    final late = DateTime(2026, 10, 13, 9, 0);
    expect(isMissedCheckOut(open.copyWith(checkOut: DateTime(2026, 10, 12, 16, 0)), late), isFalse);
    expect(isMissedCheckOut(DayRecord(date: day), late), isFalse);
    expect(isMissedCheckOut(DayRecord(date: day, isDayOff: true), late), isFalse);
  });
}
