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
      checkInWindows: [const TimeWindow(from: Clock(6, 50), to: Clock(7, 0))],
      checkOutWindows: [const TimeWindow(from: Clock(16, 0), to: Clock(16, 15))],
    ),
  );
}

void main() {
  group('distanceMeters', () {
    test('cùng tọa độ -> 0 mét', () {
      expect(distanceMeters(21.0285, 105.8542, 21.0285, 105.8542), closeTo(0, 0.01));
    });

    test('cách nhau khoảng 111km theo vĩ độ (1 độ) -> đúng cỡ', () {
      expect(distanceMeters(21.0, 105.0, 22.0, 105.0), closeTo(111195, 500));
    });
  });

  group('decideGpsAction', () {
    test('tắt GPS -> không làm gì', () {
      final settings = settingsWithGps(enabled: false);
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.none);
    });

    test('trong bán kính, trong khung chấm vào, chưa chấm vào -> chấm vào', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.checkIn);
    });

    test('ngoài bán kính -> không làm gì dù đúng khung giờ', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.05, // xa hơn 50m nhiều
        currentLng: 105.87,
      );
      expect(action, GpsAction.none);
    });

    test('đã chấm vào rồi -> khung chấm vào không chấm lại', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 6, 52)),
        now: DateTime(2026, 9, 21, 6, 58),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.none);
    });

    test('trong khung chấm ra nhưng CHƯA chấm vào -> không tự chấm ra', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
        now: DateTime(2026, 9, 21, 16, 5),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.none);
    });

    test('trong khung chấm ra, đã có chấm vào -> chấm ra', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 6, 52)),
        now: DateTime(2026, 9, 21, 16, 5),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.checkOut);
    });

    test('ngày nghỉ -> không tự chấm', () {
      final settings = settingsWithGps();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: DayRecord(date: DateTime(2026, 9, 21), isDayOff: true),
        now: DateTime(2026, 9, 21, 6, 55),
        currentLat: 21.0285,
        currentLng: 105.8542,
      );
      expect(action, GpsAction.none);
    });
  });

  group('hasWindowLeftToday', () {
    test('trước khung chấm vào -> còn', () {
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

    test('đã qua hết khung chấm vào và chưa chấm vào, khung chấm ra thì cần chấm vào trước nên vẫn coi là hết việc hôm nay', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21)),
          now: DateTime(2026, 9, 21, 15, 0),
        ),
        isFalse,
      );
    });

    test('đã chấm vào, còn khung chấm ra phía trước -> còn', () {
      final settings = settingsWithGps();
      expect(
        hasWindowLeftToday(
          settings: settings,
          todayRecord: DayRecord(date: DateTime(2026, 9, 21), checkIn: DateTime(2026, 9, 21, 6, 52)),
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
            checkIn: DateTime(2026, 9, 21, 6, 52),
            checkOut: DateTime(2026, 9, 21, 16, 5),
          ),
          now: DateTime(2026, 9, 21, 16, 10),
        ),
        isFalse,
      );
    });
  });
}
