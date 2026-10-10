import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/gps_engine.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

AppSettings settingsWithGps({bool enabled = true, List<GpsPlace> extraPlaces = const []}) {
  return AppSettings(
    gps: GpsConfig(
      enabled: enabled,
      latitude: 21.0285,
      longitude: 105.8542,
      radiusMeters: 30,
      departRadiusMeters: 200,
      activeWindows: [
        const TimeWindow(from: Clock(6, 50), to: Clock(7, 5)),
        const TimeWindow(from: Clock(16, 0), to: Clock(22, 0)),
      ],
      extraPlaces: extraPlaces,
    ),
  );
}

/// Địa điểm khác đặt cách tâm [metersNorth] mét về phía bắc.
GpsPlace placeNorth(double metersNorth, {required bool checkOut, double radius = 30}) {
  final (lat, lng) = pointNorth(metersNorth);
  return GpsPlace(latitude: lat, longitude: lng, radiusMeters: radius, checkOut: checkOut);
}

final day = DateTime(2026, 9, 21);
DateTime at(int h, int m) => DateTime(2026, 9, 21, h, m);

/// Đã chấm vào 07:00, giờ về tạm gần nhất lúc [tentative].
DayRecord checkedIn({DateTime? tentative}) =>
    DayRecord(date: day, checkIn: at(7, 0), gpsLastSeenNearby: tentative);

/// Tọa độ cách tâm (21.0285, 105.8542) một khoảng xấp xỉ [meters] mét về phía bắc.
(double, double) pointNorth(double meters) => (21.0285 + meters / 111000, 105.8542);

GpsSight sightAt(AppSettings s, double meters) {
  final (lat, lng) = pointNorth(meters);
  return classifyGpsFix(s.gps, lat, lng);
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

  group('roundToHalfHour', () {
    test('6:50 -> 7:00', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 6, 50)), DateTime(2026, 9, 21, 7, 0));
    });

    test('7:20 -> 7:30 (không phải 7:20)', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 7, 20)), DateTime(2026, 9, 21, 7, 30));
    });

    test('mốc kiểm tra 17:05 -> 17:00, 17:35 -> 17:30', () {
      expect(roundToHalfHour(at(17, 5)), at(17, 0));
      expect(roundToHalfHour(at(17, 35)), at(17, 30));
    });

    test('23:50 -> 0:00 hôm sau', () {
      expect(roundToHalfHour(DateTime(2026, 9, 21, 23, 50)), DateTime(2026, 9, 22, 0, 0));
    });
  });

  group('việc cần làm lúc này (gpsTaskAt)', () {
    final settings = settingsWithGps();
    GpsTask task(DayRecord r, DateTime now, {AppSettings? s}) =>
        gpsTaskAt(settings: s ?? settings, todayRecord: r, now: now);

    test('tắt GPS, chưa có tọa độ, ngày nghỉ -> không làm gì', () {
      expect(task(DayRecord(date: day), at(6, 55), s: settingsWithGps(enabled: false)), GpsTask.none);
      expect(task(DayRecord(date: day), at(6, 55), s: AppSettings(gps: GpsConfig(enabled: true))), GpsTask.none);
      expect(task(DayRecord(date: day, isDayOff: true), at(6, 55)), GpsTask.none);
    });

    test('chưa chấm vào: chỉ dò trong khung giờ', () {
      expect(task(DayRecord(date: day), at(6, 55)), GpsTask.arrival);
      expect(task(DayRecord(date: day), at(10, 0)), GpsTask.none);
      // Chưa chấm vào thì mốc phút 05 ngoài khung cũng không làm gì.
      expect(task(DayRecord(date: day), at(10, 5)), GpsTask.none);
    });

    test('đã chấm vào: chỉ kiểm tra ở mốc phút 05 và 35, kể cả ngoài khung giờ', () {
      expect(task(checkedIn(), at(10, 5)), GpsTask.departure);
      expect(task(checkedIn(), at(10, 35)), GpsTask.departure);
      expect(task(checkedIn(), at(10, 12)), GpsTask.departure); // còn trong 10 phút của mốc (đang thử lại)
      expect(task(checkedIn(), at(10, 0)), GpsTask.none);
      expect(task(checkedIn(), at(10, 20)), GpsTask.none);
      expect(task(checkedIn(), at(16, 2)), GpsTask.none); // trong khung giờ nhưng chưa tới mốc
    });

    test('mốc kiểm tra chỉ có từ khung đầu tới một tiếng sau khung cuối', () {
      expect(task(checkedIn(), at(6, 35)), GpsTask.none); // trước khung đầu 06:50
      expect(task(checkedIn(), at(22, 35)), GpsTask.departure);
      expect(task(checkedIn(), at(23, 35)), GpsTask.none); // khung cuối hết 22:00
    });

    test('giờ ra bấm tay -> GPS không đụng tới nữa', () {
      final manual = checkedIn().copyWith(checkOut: at(12, 0));
      expect(manual.checkOutByGps, isFalse);
      expect(task(manual, at(14, 5)), GpsTask.none);
    });

    test('giờ ra do GPS chốt -> 2 tiếng kiểm tra lại một lần', () {
      final byGps = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);
      expect(task(byGps, at(12, 35)), GpsTask.none);
      expect(task(byGps, at(13, 5)), GpsTask.none);
      expect(task(byGps, at(13, 35)), GpsTask.none);
      expect(task(byGps, at(14, 5)), GpsTask.reopen);
      expect(task(byGps, at(14, 35)), GpsTask.none);
      expect(task(byGps, at(16, 5)), GpsTask.reopen);
    });

    test('sửa tay giờ ra do GPS chốt thì thành giờ ra bấm tay', () {
      final byGps = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);
      expect(byGps.copyWith(checkOut: at(12, 30)).checkOutByGps, isFalse);
      expect(byGps.copyWith(note: 'ghi chú').checkOutByGps, isTrue);
      expect(DayRecord.fromJson(byGps.toJson()).checkOutByGps, isTrue);
    });
  });

  group('chấm vào', () {
    final settings = settingsWithGps();

    test('trong bán kính chấm 30 m thì chấm vào, ngoài thì chưa', () {
      final (nearLat, nearLng) = pointNorth(20);
      final (farLat, farLng) = pointNorth(100);
      expect(isInsideCheckInRadius(settings.gps, nearLat, nearLng), isTrue);
      expect(isInsideCheckInRadius(settings.gps, farLat, farLng), isFalse);
    });

    test('chưa tới nơi: trước 13:00 dò lại, sau 13:00 mỗi khung một lần', () {
      expect(arrivalShouldPollAgain(at(6, 55)), isTrue);
      expect(arrivalShouldPollAgain(at(12, 55)), isTrue);
      expect(arrivalShouldPollAgain(at(13, 0)), isFalse);
      expect(arrivalShouldPollAgain(at(16, 5)), isFalse);
    });

    test('chấm vào xong thì có luôn giờ về tạm đầu tiên', () {
      final r = applyGpsDecision(DayRecord(date: day), GpsDecision(GpsAction.checkIn, time: at(7, 0)), at(6, 56));
      expect(r.checkIn, at(7, 0));
      expect(r.gpsLastSeenNearby, at(6, 56));
    });
  });

  group('phân loại vị trí', () {
    test('trong 200 m là còn ở chỗ làm, ngoài 200 m là đã ra', () {
      final s = settingsWithGps();
      expect(sightAt(s, 0), GpsSight.near);
      expect(sightAt(s, 100), GpsSight.near); // ngoài 30 m nhưng trong 200 m vẫn tính
      expect(sightAt(s, 300), GpsSight.away);
    });

    test('đứng ở địa điểm khác thì địa điểm đó quyết định', () {
      // Nhà trọ "chấm về" nằm trong vòng 200 m; xưởng xa "không chấm về" nằm ngoài vòng 200 m.
      final s = settingsWithGps(
        extraPlaces: [placeNorth(120, checkOut: true), placeNorth(500, checkOut: false)],
      );
      expect(sightAt(s, 125), GpsSight.atCheckOutPlace);
      expect(sightAt(s, 510), GpsSight.near);
      expect(sightAt(s, 60), GpsSight.near); // ngoài mọi địa điểm khác: theo vòng 200 m
    });

    test('nằm trong 2 địa điểm chồng nhau -> theo địa điểm gần nhất', () {
      final s = settingsWithGps(
        extraPlaces: [placeNorth(100, checkOut: true, radius: 60), placeNorth(140, checkOut: false, radius: 60)],
      );
      expect(sightAt(s, 135), GpsSight.near); // gần xưởng (140) hơn nhà trọ (100)
    });
  });

  group('chấm ra (decideDeparture)', () {
    GpsDecision decide(GpsSight sight, DateTime now, {DateTime? tentative}) =>
        decideDeparture(todayRecord: checkedIn(tentative: tentative), now: now, sight: sight);

    test('còn ở chỗ làm -> chỉ ghi giờ về tạm, chưa chấm ra', () {
      final d = decide(GpsSight.near, at(16, 35), tentative: at(16, 5));
      expect(d.action, GpsAction.tentative);
      final r = applyGpsDecision(checkedIn(tentative: at(16, 5)), d, at(16, 35));
      expect(r.checkOut, isNull);
      expect(r.gpsLastSeenNearby, at(16, 35));
    });

    test('lần sau thấy đã ra ngoài -> chốt giờ ra bằng giờ về tạm của lần trước', () {
      final d = decide(GpsSight.away, at(17, 35), tentative: at(17, 5));
      expect(d.action, GpsAction.checkOut);
      expect(d.time, at(17, 0)); // 17:05 làm tròn về 17:00, không phải giờ hiện tại 17:35
      final r = applyGpsDecision(checkedIn(tentative: at(17, 5)), d, at(17, 35));
      expect(r.checkOut, at(17, 0));
      expect(r.checkOutByGps, isTrue);
      expect(r.gpsLastSeenNearby, isNull);
    });

    test('thấy đã ra ngoài mà không có giờ về tạm, hoặc giờ về tạm đã cũ -> báo đỏ, không tự chấm ra', () {
      expect(decide(GpsSight.away, at(17, 35)).action, GpsAction.flagUnknown);
      // Mốc 17:05 không xác định được nên giờ về tạm vẫn là 16:35 (cũ hơn 45 phút).
      expect(decide(GpsSight.away, at(17, 35), tentative: at(16, 35)).action, GpsAction.flagUnknown);
    });

    test('không GPS, không Wi-Fi quen -> báo đỏ; ngày đó được coi là chưa có giờ về', () {
      final d = decide(GpsSight.unknown, at(17, 12), tentative: at(16, 35));
      expect(d.action, GpsAction.flagUnknown);
      final r = applyGpsDecision(checkedIn(tentative: at(16, 35)), d, at(17, 12));
      expect(r.gpsLeftUnknown, isTrue);
      expect(r.checkOut, isNull);
      expect(r.gpsLastSeenNearby, at(16, 35)); // giờ về tạm cũ giữ nguyên
      expect(isMissedCheckOut(r, at(17, 15)), isTrue); // báo đỏ ngay, không chờ tới 23:00
    });

    test('đang báo đỏ mà lần sau xác định được còn ở chỗ làm -> hết đỏ', () {
      final red = checkedIn(tentative: at(16, 35)).copyWith(gpsLeftUnknown: true);
      final r = applyGpsDecision(red, const GpsDecision(GpsAction.tentative), at(17, 35));
      expect(r.gpsLeftUnknown, isFalse);
      expect(r.gpsLastSeenNearby, at(17, 35));
    });

    test('về tới nhà trọ "chấm về" -> chấm ra bằng giờ về tạm; chưa có thì lấy giờ lúc đó', () {
      expect(decide(GpsSight.atCheckOutPlace, at(17, 35), tentative: at(17, 5)).time, at(17, 0));
      expect(decide(GpsSight.atCheckOutPlace, at(17, 35)).time, at(17, 30));
    });

    test('bấm tay chấm ra thì hết báo đỏ', () {
      final red = checkedIn().copyWith(gpsLeftUnknown: true);
      expect(red.copyWith(checkOut: at(17, 0)).gpsLeftUnknown, isFalse);
      expect(red.copyWith(clearCheckIn: true).gpsLeftUnknown, isFalse);
    });
  });

  group('mở lại ca (decideReopen)', () {
    final closed = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);

    test('vẫn ở chỗ làm -> bỏ giờ ra, theo dõi lại từ đầu', () {
      final d = decideReopen(GpsSight.near);
      expect(d.action, GpsAction.reopen);
      final r = applyGpsDecision(closed, d, at(14, 5));
      expect(r.checkOut, isNull);
      expect(r.checkOutByGps, isFalse);
      expect(r.checkIn, at(7, 0));
      expect(r.gpsLastSeenNearby, at(14, 5));
    });

    test('đã ra ngoài, ở nhà trọ "chấm về", hoặc không xác định được -> giữ nguyên giờ ra', () {
      for (final sight in [GpsSight.away, GpsSight.atCheckOutPlace, GpsSight.unknown]) {
        final d = decideReopen(sight);
        expect(d.action, GpsAction.none);
        expect(applyGpsDecision(closed, d, at(14, 5)).checkOut, at(12, 0));
      }
    });
  });

  group('còn việc trong ngày', () {
    final settings = settingsWithGps();
    bool left(DayRecord r, DateTime now) => gpsHasWorkLeftToday(settings: settings, todayRecord: r, now: now);

    test('còn khung phía trước thì còn; qua hết khung thì hết', () {
      expect(left(DayRecord(date: day), at(6, 45)), isTrue);
      expect(left(checkedIn(), at(15, 0)), isTrue);
      expect(left(checkedIn(), at(22, 30)), isFalse);
    });

    test('giờ ra bấm tay thì hết; giờ ra do GPS chốt thì còn (để kiểm tra lại)', () {
      expect(left(checkedIn().copyWith(checkOut: at(16, 0)), at(16, 10)), isFalse);
      expect(left(checkedIn().copyWith(checkOut: at(16, 0), checkOutByGps: true), at(16, 10)), isTrue);
    });
  });

  test('lưu rồi đọc lại cấu hình giữ nguyên địa điểm; dữ liệu cũ không có mục này -> danh sách rỗng', () {
    final gps = GpsConfig(
      latitude: 21.0285,
      longitude: 105.8542,
      extraPlaces: [const GpsPlace(name: 'Nhà trọ', latitude: 21.03, longitude: 105.85, radiusMeters: 40, checkOut: true)],
    );
    final back = GpsConfig.fromJson(gps.toJson());
    expect(back.extraPlaces, hasLength(1));
    expect(back.extraPlaces.first.name, 'Nhà trọ');
    expect(back.extraPlaces.first.radiusMeters, 40);
    expect(back.extraPlaces.first.checkOut, isTrue);

    final old = GpsConfig.fromJson({'enabled': true, 'lat': 21.0285, 'lng': 105.8542});
    expect(old.extraPlaces, isEmpty);
  });
}
