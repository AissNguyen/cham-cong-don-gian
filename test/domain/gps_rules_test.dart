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

  test('dữ liệu bản cũ: bỏ hết khung đã đặt trước đây, chuyển sang các khung cài sẵn', () {
    // Bản chưa có khung lặp.
    final old = GpsConfig(
      enabled: true,
      latitude: 10,
      longitude: 106,
      activeWindows: [
        const TimeWindow(from: Clock(5, 30), to: Clock(6, 0)),
        const TimeWindow(from: Clock(16, 0), to: Clock(16, 15)),
      ],
    ).toJson()..remove('rules')..remove('v');
    final gps = GpsConfig.fromJson(old);
    expect(gps.repeatRules.length, 2);
    expect(gps.activeWindows.map(show), ['12:50-13:10']);
    // Tọa độ và việc đang bật GPS giữ nguyên.
    expect(gps.enabled, isTrue);
    expect(gps.latitude, 10);

    // Bản thử đầu tiên đã có khung lặp nhưng chưa ghi phiên bản: cũng đặt lại một lần.
    final trial = GpsConfig(
      activeWindows: [const TimeWindow(from: Clock(5, 30), to: Clock(6, 0))],
    ).toJson()..remove('v');
    expect(GpsConfig.fromJson(trial).activeWindows.map(show), ['12:50-13:10']);
    expect(GpsConfig.fromJson(trial).repeatRules.length, 2);
  });

  test('từ bản này về sau: khung người dùng tự đặt được giữ nguyên', () {
    final mine = GpsConfig(activeWindows: [const TimeWindow(from: Clock(5, 30), to: Clock(6, 0))]);
    final gps = GpsConfig.fromJson(mine.toJson());
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
    GpsTask at(int h, int m) => gpsTaskAt(
      settings: settings,
      todayRecord: DayRecord(date: DateTime(2026, 10, 12)),
      now: DateTime(2026, 10, 12, h, m),
    );
    expect(at(6, 55), GpsTask.arrival); // trong 06:50-07:05
    expect(at(7, 10), GpsTask.none); // giữa hai khung
    expect(at(7, 30), GpsTask.arrival); // trong 07:25-07:35
    expect(at(13, 0), GpsTask.arrival); // khung lẻ 12:50-13:10
    expect(at(13, 20), GpsTask.none);
    expect(at(18, 5), GpsTask.arrival); // trong 18:00-18:10
    expect(at(23, 5), GpsTask.none);
  });

  test('mốc kiểm tra giờ về: phút 05 và 35, từ khung đầu tới một tiếng sau khung cuối', () {
    final marks = gpsMarkTimes(GpsConfig()).map((c) => c.formatted).toList();
    expect(marks.first, '07:05'); // khung đầu bắt đầu 06:50
    expect(marks[1], '07:35');
    expect(marks.last, '23:35'); // khung cuối hết 22:40, cộng một tiếng
    expect(gpsMarkTimes(GpsConfig(activeWindows: const [], repeatRules: const [])), isEmpty);
  });
}
