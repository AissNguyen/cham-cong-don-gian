import 'package:cham_cong_don_gian/domain/gps_engine.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

AppSettings settingsWithGps({bool enabled = true}) {
  return AppSettings(
    gps: GpsConfig(
      enabled: enabled,
      latitude: 21.0285,
      longitude: 105.8542,
      radiusMeters: 50,
      departRadiusMeters: 200,
      activeWindows: [
        const TimeWindow(from: Clock(6, 50), to: Clock(7, 0)),
        const TimeWindow(from: Clock(16, 0), to: Clock(16, 15)),
      ],
    ),
  );
}

/// Tọa độ cách tâm (21.0285, 105.8542) một khoảng xấp xỉ [meters] mét về phía bắc.
(double, double) pointNorth(double meters) => (21.0285 + meters / 111000, 105.8542);

void main() {
  group('distanceMeters', () {
    test('cùng tọa độ -> 0 mét', () {
      expect(distanceMeters(21.0285, 105.8542, 21.0285, 105.8542), closeTo(0, 0.01));
    });

    test('cách nhau khoảng 111km theo vĩ độ (1 độ) -> đúng cỡ', () {
      expect(distanceMeters(21.0, 105.0, 22.0, 105.0), closeTo(111195, 500));
    });
  });

  group('roundToHalfHour', () {
    test('6:50 -> 7:00', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 6, 50)), DateTime(2026, 9, 21, 7, 0));
    });

    test('7:20 -> 7:30 (không phải 7:20)', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 7, 20)), DateTime(2026, 9, 21, 7, 30));
    });

    test('7:58 -> 8:00', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 7, 58)), DateTime(2026, 9, 21, 8, 0));
    });

    test('23:50 -> 0:00 hôm sau', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 23, 50)), DateTime(2026, 9, 22, 0, 0));
    });
  });

  group('decideGpsAction', () {
    test('tắt GPS -> không làm gì', () {
      final settings = settingsWithGps(enabled: false);
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(decision.action, GpsAction.none);
    });

    test('trong bán kính, trong khung giờ, chưa chấm vào -> chấm vào ngay, giờ đã làm tròn', () {
      final settings = settingsWithGps();
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(decision.action, GpsAction.checkIn);
      expect(decision.time, DateTime(2026, 9, 21, 7, 0));
    });

    test('ngoài bán kính -> không làm gì dù đúng khung giờ', () {
      final settings = settingsWithGps();
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.05, // xa hơn 50m nhiều
        currentLng: 105.87,
      );
      expect(decision.action, GpsAction.none);
    });

    test('ngoài khung giờ -> không làm gì dù trong bán kính', () {
      final settings = settingsWithGps();
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 10, 0),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(decision.action, GpsAction.none);
    });

    test('đã chấm vào rồi, vẫn trong bán kính (≤ departRadius) -> chưa chấm ra, chỉ cập nhật mốc gần đó', () {
      final settings = settingsWithGps();
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)),
        now: DateTime(2026, 9, 21, 16, 5),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(decision.action, GpsAction.none);
      expect(decision.lastSeenNearby, DateTime(2026, 9, 21, 16, 5));
    });

    test('đã chấm vào, cách 30-200m (đang làm gần đó) -> vẫn chưa chấm ra, chỉ cập nhật mốc gần đó', () {
      final settings = settingsWithGps();
      final (lat, lng) = pointNorth(100); // cách tâm ~100m, trong khoảng 50m(radius)-200m(depart)
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)),
        now: DateTime(2026, 9, 21, 16, 5),
        currentLat: lat,
        currentLng: lng,
      );
      expect(decision.action, GpsAction.none);
      expect(decision.lastSeenNearby, DateTime(2026, 9, 21, 16, 5));
    });

    test('đã chấm vào, cách xa hẳn > departRadius -> chấm ra, dùng giờ lần cuối còn gần đó (đã làm tròn)', () {
      final settings = settingsWithGps();
      final (lat, lng) = pointNorth(300); // xa hơn 200m
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(
          date: DateTime(2026, 9, 21),
          checkIn: DateTime(2026, 9, 21, 7, 0),
          gpsLastSeenNearby: DateTime(2026, 9, 21, 16, 8), // lần quét trước đó, lúc còn gần
        ),
        now: DateTime(2026, 9, 21, 16, 12),
        currentLat: lat,
        currentLng: lng,
      );
      expect(decision.action, GpsAction.checkOut);
      // 16:08 làm tròn -> 16:00 (không phải giờ hiện tại 16:12).
      expect(decision.time, DateTime(2026, 9, 21, 16, 0));
    });

    test('đã chấm vào, cách xa hẳn nhưng chưa từng ghi mốc gần đó -> dùng giờ hiện tại làm tròn', () {
      final settings = settingsWithGps();
      final (lat, lng) = pointNorth(300);
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)),
        now: DateTime(2026, 9, 21, 16, 12),
        currentLat: lat,
        currentLng: lng,
      );
      expect(decision.action, GpsAction.checkOut);
      expect(decision.time, DateTime(2026, 9, 21, 16, 0));
    });

    test('ngày nghỉ -> không tự chấm', () {
      final settings = settingsWithGps();
      final decision = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), isDayOff: true),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(decision.action, GpsAction.none);
    });
  });

  group('hasWindowLeftToday', () {
    test('trước khung đầu tiên -> còn', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
          now: DateTime(2026, 9, 21, 6, 45),
        ),
        isTrue,
      );
    });

    test('chưa chấm vào nhưng còn khung sau (chấm ra) phía trước -> vẫn còn (dùng chung 1 danh sách)', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
          now: DateTime(2026, 9, 21, 15, 0),
        ),
        isTrue,
      );
    });

    test('đã chấm vào, còn khung phía trước -> còn', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)),
          now: DateTime(2026, 9, 21, 15, 0),
        ),
        isTrue,
      );
    });

    test('đã chấm đủ vào lẫn ra -> hết', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(
            date: DateTime(2026, 9, 21),
            checkIn: DateTime(2026, 9, 21, 7, 0),
            checkOut: DateTime(2026, 9, 21, 16, 0),
          ),
          now: DateTime(2026, 9, 21, 16, 10),
        ),
        isFalse,
      );
    });

    test('qua hết mọi khung, chưa chấm đủ -> hết (không còn khung nào để dịch vụ nền chạy tiếp)', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 7, 0)),
          now: DateTime(2026, 9, 21, 23, 0),
        ),
        isFalse,
      );
    });
  });
}
