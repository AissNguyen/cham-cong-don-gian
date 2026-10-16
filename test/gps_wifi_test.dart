import 'package:cham_cong_don_gian/gps/gps_wifi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mạng [name] (thiết bị [bssid]) đã xuất hiện [times] lần, mỗi lần một mốc 15 phút.
KnownWifi seen(String bssid, String name, int times, {int startHour = 7}) {
  final marks = [for (var i = 0; i < times; i++) DateTime(2026, 10, 14, startHour, 0).add(Duration(minutes: 15 * i))];
  return KnownWifi(bssid, name, marks.isEmpty ? DateTime(2000) : marks.last, marks: marks.reversed.toList(), days: {'2026-10-14'});
}

void main() {
  test('chỉ mạng xuất hiện từ 4 lần trở lên mới được dùng', () {
    final lists = KnownWifiLists(work: [seen('a', 'Xuong', 4), seen('b', 'Quan', 3)]);
    expect(lists.trusted(lists.work).map((g) => g.name), ['Xuong']);
  });

  test('Wi-Fi điện thoại phát không được dùng làm mốc', () {
    for (final name in ['iPhone', "Lan's iPhone", 'Redmi 15', 'Redmi Note 14', 'OPPO A31', 'realme C30s', 'Galaxy A12']) {
      expect(isPhoneHotspot(name), isTrue, reason: name);
    }
    for (final name in ['Xuong A', 'Cao Hương', 'VIETTEL_BINH', 'Hoang Khang']) {
      expect(isPhoneHotspot(name), isFalse, reason: name);
    }
    final lists = KnownWifiLists(work: [seen('a', 'iPhone', 9), seen('b', 'Xuong', 4)]);
    expect(lists.trusted(lists.work).map((g) => g.name), ['Xuong']);
  });

  test('chỉ lấy 3 mạng xuất hiện nhiều nhất', () {
    final lists = KnownWifiLists(work: [for (var i = 0; i < 7; i++) seen('b$i', 'Mang$i', 4 + i)]);
    expect(lists.trusted(lists.work).map((g) => g.name), ['Mang6', 'Mang5', 'Mang4']);
  });

  test('thấy lần đầu từ 3 ngày trước mà xuất hiện dưới 4 lần thì xóa; mạng mới hoặc đủ lần thì giữ', () {
    final list = [seen('a', 'Xuong', 6), seen('b', 'HiemGap', 2), seen('c', 'MoiThay', 1, startHour: 9), KnownWifi.fromJson('dd:ee')!];
    // Chưa đủ 3 ngày thì giữ; riêng mạng học từ bản 1.2.0 (không có mốc nào) thì xóa luôn.
    expect(pruneWifi(list, DateTime(2026, 10, 15, 9)).map((w) => w.ssid), ['Xuong', 'HiemGap', 'MoiThay']);
    expect(pruneWifi(list, DateTime(2026, 10, 17, 9, 30)).map((w) => w.ssid), ['Xuong']);
  });

  test('các thiết bị phát cùng tên đếm chung, mốc trùng chỉ tính một lần', () {
    final lists = KnownWifiLists(work: [seen('a1', 'Xuong', 2), seen('a2', 'Xuong', 3)]);
    final g = groupWifi(lists.work).single;
    expect(g.sightings, 3); // hai thiết bị cùng thấy ở các mốc 7:00, 7:15 -> 3 mốc khác nhau
    expect(lists.trusted(lists.work), isEmpty);
  });

  test('ghi thêm một mốc thì số lần tăng, tên được điền, lưu rồi đọc lại giữ nguyên', () {
    final old = KnownWifi.fromJson('aa:bb')!; // bản 1.2.0 chỉ có mã thiết bị
    expect(old.ssid, '');
    final now = old.seenAt(DateTime(2026, 10, 14, 7, 15), 'Xuong');
    expect(now.ssid, 'Xuong');
    expect(now.marks, [DateTime(2026, 10, 14, 7, 15)]);
    final back = KnownWifi.fromJson(now.toJson())!;
    expect(back.marks, now.marks);
    expect(back.days, {'2026-10-14'});
  });
}
