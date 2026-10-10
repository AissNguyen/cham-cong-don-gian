import 'package:cham_cong_don_gian/domain/gps_engine.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String show(TimeWindow w) => '${w.from.formatted}-${w.to.formatted}';

  test('khung lặp buổi sáng: 06:50-12:40, phút 50→05 và phút 25→35', () {
    final windows = defaultGpsRules[0].windows.map(show).toList();
    expect(windows.first, '06:50-07:05');
    expect(windows[1], '07:25-07:35');
    expect(windows[2], '07:50-08:05');
    expect(windows.last, '12:25-12:35'); // 12:50-13:05 vượt quá 12:40 nên không có
    expect(windows.length, 12);
  });

  test('khung lặp chiều tối: 13:30-23:00, phút 00→10 và phút 30→40', () {
    final windows = defaultGpsRules[1].windows.map(show).toList();
    expect(windows.first, '13:30-13:40'); // 13:00-13:10 bắt đầu trước 13:30 nên không có
    expect(windows[1], '14:00-14:10');
    expect(windows.last, '22:30-22:40'); // 23:00-23:10 vượt quá 23:00 nên không có
    expect(windows.length, 19);
  });

  test('máy mới cài: 2 khung lặp và khung 12:50-13:10, tổng 32 khung một ngày', () {
    final gps = GpsConfig();
    expect(gps.repeatRules.length, 2);
    expect(gps.activeWindows.map(show), ['12:50-13:10']);
    expect(gps.allWindows.length, 32);
  });

  test('tự đặt khung riêng thì không có khung lặp', () {
    final gps = GpsConfig(activeWindows: [const TimeWindow(from: Clock(8, 0), to: Clock(8, 10))]);
    expect(gps.repeatRules, isEmpty);
    expect(gps.allWindows.length, 1);
  });

  test('dữ liệu bản cũ: còn hai khung mặc định cũ thì chuyển sang khung cài sẵn mới', () {
    final old = GpsConfig(
      activeWindows: [
        const TimeWindow(from: Clock(6, 50), to: Clock(7, 0)),
        const TimeWindow(from: Clock(16, 0), to: Clock(16, 15)),
      ],
    ).toJson()..remove('rules');
    final gps = GpsConfig.fromJson(old);
    expect(gps.repeatRules.length, 2);
    expect(gps.activeWindows.map(show), ['12:50-13:10']);
  });

  test('dữ liệu bản cũ: đã tự đặt khung thì giữ nguyên, không thêm khung lặp', () {
    final old = GpsConfig(
      activeWindows: [const TimeWindow(from: Clock(5, 30), to: Clock(6, 0))],
    ).toJson()..remove('rules');
    final gps = GpsConfig.fromJson(old);
    expect(gps.repeatRules, isEmpty);
    expect(gps.activeWindows.map(show), ['05:30-06:00']);
  });

  test('xóa hết khung lặp rồi lưu lại thì vẫn không có khung lặp', () {
    final gps = GpsConfig.fromJson(GpsConfig().copyWith(repeatRules: const []).toJson());
    expect(gps.repeatRules, isEmpty);
    expect(gps.activeWindows.map(show), ['12:50-13:10']);
  });

  test('GPS tự chấm trong khung lặp, không chấm ngoài khung', () {
    final settings = AppSettings(gps: GpsConfig(enabled: true, latitude: 10, longitude: 106));
    GpsAction at(int h, int m) => decideGpsAction(
      settings: settings,
      todayRecord: DayRecord(date: DateTime(2026, 10, 12)),
      now: DateTime(2026, 10, 12, h, m),
      currentLat: 10,
      currentLng: 106,
    ).action;
    expect(at(6, 55), GpsAction.checkIn); // trong 06:50-07:05
    expect(at(7, 10), GpsAction.none); // giữa hai khung
    expect(at(7, 30), GpsAction.checkIn); // trong 07:25-07:35
    expect(at(13, 0), GpsAction.checkIn); // khung lẻ 12:50-13:10
    expect(at(13, 20), GpsAction.none);
    expect(at(18, 5), GpsAction.checkIn); // trong 18:00-18:10
    expect(at(23, 5), GpsAction.none);
  });
}
