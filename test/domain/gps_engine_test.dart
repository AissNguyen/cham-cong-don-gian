import 'package:cham_cong_don_gian/domain/calc.dart';
import 'package:cham_cong_don_gian/domain/gps_engine.dart';
import 'package:cham_cong_don_gian/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cài đặt mặc định: chấm vào 7:00–14:00, dò giờ về tới 2:30 sáng, phạm vi chỗ làm 200 m.
AppSettings settingsWithGps({bool enabled = true, List<GpsPlace> extraPlaces = const []}) {
  return AppSettings(
    gps: GpsConfig(
      enabled: enabled,
      latitude: 21.0285,
      longitude: 105.8542,
      departRadiusMeters: 200,
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
DateTime at(int h, int m, {int dayOffset = 0}) => DateTime(2026, 9, 21 + dayOffset, h, m);
DayRecord empty([int dayOffset = 0]) => DayRecord(date: DateTime(2026, 9, 21 + dayOffset));

/// Đã chấm vào lúc [h]:[m] hôm 21/9.
DayRecord checkedIn([int h = 7, int m = 0]) => DayRecord(date: day, checkIn: at(h, m));

/// Tọa độ cách tâm (21.0285, 105.8542) một khoảng xấp xỉ [meters] mét về phía bắc.
(double, double) pointNorth(double meters) => (21.0285 + meters / 111000, 105.8542);

GpsSight sightAt(AppSettings s, double meters) {
  final (lat, lng) = pointNorth(meters);
  return classifyGpsFix(s.gps, lat, lng);
}

void main() {
  final settings = settingsWithGps();

  GpsPlan? plan(DayRecord today, DateTime now, {DayRecord? yesterday, AppSettings? s}) =>
      gpsPlanAt(settings: s ?? settings, today: today, yesterday: yesterday ?? empty(-1), now: now);

  group('tiện ích', () {
    test('khoảng cách 1 độ vĩ ~ 111 km', () {
      expect(distanceMeters(21.0, 105.0, 22.0, 105.0), closeTo(111195, 500));
    });

    test('báo thức trễ: chờ chấm vào cho trễ 5 phút, dò giờ về cho trễ tới phút 35 hoặc 05', () {
      expect(plan(empty(), at(8, 5))!.mark, at(8, 0));
      expect(plan(empty(), at(8, 6)), isNull); // mốc 8:00 trễ 6 phút: bỏ
      expect(plan(empty(), at(8, 19))!.mark, at(8, 15));
      expect(plan(checkedIn(), at(18, 35))!.mark, at(18, 15));
      expect(plan(checkedIn(), at(18, 36)), isNull); // mốc 18:15 trễ quá: bỏ, chờ mốc 18:45
      expect(plan(checkedIn(), at(19, 5))!.mark, at(18, 45));
    });

    test('mốc bị bỏ được liệt kê để ghi nhật ký, mốc đã làm xong thì không dò lại', () {
      final pending = gpsPendingPlans(settings: settings, today: checkedIn(), yesterday: empty(-1), now: at(18, 50));
      expect(pending.map((p) => (p.mark, p.tooLate)), [(at(17, 45), true), (at(18, 15), true), (at(18, 45), false)]);
      final done = checkedIn().copyWith(gpsDoneMarks: [at(17, 45), at(18, 15), at(18, 45)]);
      expect(gpsPendingPlans(settings: settings, today: done, yesterday: empty(-1), now: at(18, 50)), isEmpty);
      // Báo thức dự phòng 18:49 sau khi báo thức chính 18:45 đã dò xong: không dò lại.
      expect(plan(done, at(18, 49)), isNull);
    });

    test('mốc cũ hơn mốc đã làm gần nhất không bị tính là "mốc bị bỏ" (ví dụ sau khi mở lại ca)', () {
      // Hôm nay: vào 07:00, dò 11:15 thấy đã đi (chấm ra 11:00), dò 12:15 thấy quay lại nên mở lại ca.
      // Lúc đó mốc 11:45 không có việc (đã chấm ra rồi); giờ ca đã mở lại thì không được coi là bỏ lỡ.
      final reopened = checkedIn().copyWith(gpsDoneMarks: [at(12, 15), at(11, 15)]);
      expect(gpsPendingPlans(settings: settings, today: reopened, yesterday: empty(-1), now: at(12, 19)), isEmpty);
      // Còn mốc thật sự bị lỡ (sau mốc đã làm gần nhất) thì vẫn được liệt kê.
      final missed = checkedIn().copyWith(gpsDoneMarks: [at(11, 15)]);
      final pending = gpsPendingPlans(settings: settings, today: missed, yesterday: empty(-1), now: at(12, 19));
      expect(pending.map((p) => (p.mark, p.tooLate)), [(at(11, 45), true), (at(12, 15), false)]);
    });

    test('lưu rồi đọc lại giữ các mốc đã làm', () {
      final r = checkedIn().copyWith(gpsDoneMarks: [at(18, 15)]);
      expect(DayRecord.fromJson(r.toJson()).gpsDoneMarks, [at(18, 15)]);
    });

    test('lịch báo thức: 6:45 tới 14:00 mỗi 15 phút, rồi phút 15 và 45 tới 2:15 sáng', () {
      final times = gpsProbeTimes(settings.gps).map((c) => c.formatted).toList();
      expect(times.first, '00:15');
      expect(times, containsAll(['02:15', '06:45', '07:00', '07:15', '13:45', '14:00', '14:15', '23:45']));
      expect(times, isNot(contains('02:45')));
      expect(times, isNot(contains('06:30')));
      expect(times, isNot(contains('14:30'))); // sau 14:00 chỉ còn phút 15 và 45
      expect(times.toSet().length, times.length);
    });
  });

  group('việc của từng mốc (gpsPlanAt)', () {
    test('tắt GPS, chưa có tọa độ, ngày nghỉ, ngoài mốc -> không làm gì', () {
      expect(plan(empty(), at(7, 0), s: settingsWithGps(enabled: false)), isNull);
      expect(plan(empty(), at(7, 0), s: AppSettings(gps: GpsConfig(enabled: true))), isNull);
      expect(plan(DayRecord(date: day, isDayOff: true), at(7, 0)), isNull);
      expect(plan(empty(), at(7, 12)), isNull);
    });

    test('chưa chấm vào: dò trước phút 45/15 (có 6:45), dò chính phút 00/30, từ 7:00 tới 14:00', () {
      expect(plan(empty(), at(6, 30)), isNull);
      expect(plan(empty(), at(6, 45))!.task, GpsTask.arrivalCheck);
      expect(plan(empty(), at(7, 0))!.task, GpsTask.arrival);
      expect(plan(empty(), at(7, 15))!.task, GpsTask.arrivalCheck);
      expect(plan(empty(), at(13, 45))!.task, GpsTask.arrivalCheck);
      expect(plan(empty(), at(14, 0))!.task, GpsTask.arrival);
      expect(plan(empty(), at(14, 15)), isNull); // sau 14:00 không tự chấm vào nữa
      expect(plan(empty(), at(7, 3))!.mark, at(7, 0)); // lần thử lại vẫn thuộc mốc 7:00
    });

    test('đã chấm vào: chỉ dò giờ về ở phút 15 và 45', () {
      expect(plan(checkedIn(), at(7, 15))!.task, GpsTask.departure);
      expect(plan(checkedIn(), at(7, 30))!.mark, at(7, 15)); // phút 30 không có mốc giờ về; vẫn là mốc 7:15 (trễ 15 phút)
      expect(plan(checkedIn(), at(17, 45))!.task, GpsTask.departure);
      expect(plan(checkedIn(), at(23, 45))!.task, GpsTask.departure);
      expect(plan(checkedIn(7, 30), at(7, 15)), isNull); // mốc trước giờ vào
    });

    test('sau nửa đêm, tới 2:30: dò giờ về cho ca của hôm qua', () {
      final p = plan(empty(1), at(1, 15, dayOffset: 1), yesterday: checkedIn());
      expect(p!.task, GpsTask.departure);
      expect(p.day, day);
      expect(plan(empty(1), at(2, 45, dayOffset: 1), yesterday: checkedIn()), isNull);
      expect(plan(empty(1), at(1, 15, dayOffset: 1)), isNull); // hôm qua không đi làm
    });

    test('giờ ra bấm tay -> GPS không đụng tới nữa', () {
      final manual = checkedIn().copyWith(checkOut: at(12, 0));
      expect(manual.checkOutByGps, isFalse);
      expect(plan(manual, at(13, 15)), isNull);
    });

    test('giờ ra do GPS chốt -> dò lại 3 lần, cách nhau 1 tiếng', () {
      // Dò lúc 12:15 thấy đã đi -> giờ ra 12:00. Dò lại lúc 13:15, 14:15, 15:15.
      final byGps = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);
      expect(plan(byGps, at(12, 45)), isNull);
      expect(plan(byGps, at(13, 15))!.task, GpsTask.reopen);
      expect(plan(byGps, at(13, 45)), isNull);
      expect(plan(byGps, at(14, 15))!.task, GpsTask.reopen);
      expect(plan(byGps, at(15, 15))!.task, GpsTask.reopen);
      expect(plan(byGps, at(16, 15)), isNull); // hết 3 lần
    });

    test('sửa tay giờ ra do GPS chốt thì thành giờ ra bấm tay', () {
      final byGps = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);
      expect(byGps.copyWith(checkOut: at(12, 30)).checkOutByGps, isFalse);
      expect(byGps.copyWith(note: 'ghi chú').checkOutByGps, isTrue);
      expect(DayRecord.fromJson(byGps.toJson()).checkOutByGps, isTrue);
    });
  });

  group('phân loại vị trí', () {
    test('trong 200 m là ở chỗ làm, ngoài 200 m là đã đi', () {
      expect(sightAt(settings, 0), GpsSight.near);
      expect(sightAt(settings, 150), GpsSight.near);
      expect(sightAt(settings, 300), GpsSight.away);
    });

    test('đứng ở địa điểm khác thì địa điểm đó quyết định', () {
      final s = settingsWithGps(extraPlaces: [placeNorth(120, checkOut: true), placeNorth(500, checkOut: false)]);
      expect(sightAt(s, 125), GpsSight.atCheckOutPlace);
      expect(sightAt(s, 510), GpsSight.near);
      expect(sightAt(s, 60), GpsSight.near);
    });
  });

  group('chấm vào', () {
    test('dò chính trong 200 m -> chấm vào, giờ vào đúng mốc', () {
      final d = decideArrival(mark: at(7, 30), sight: GpsSight.near, previousCheckGotFix: false);
      expect(d.action, GpsAction.checkIn);
      expect(d.time, at(7, 30));
    });

    test('dò chính ngoài 200 m -> chờ mốc sau, kể cả khi lần dò trước dò ra vị trí', () {
      expect(decideArrival(mark: at(7, 30), sight: GpsSight.away, previousCheckGotFix: true).action, GpsAction.none);
    });

    test('dò chính không dò ra vị trí: lần dò trước dò ra được (ở đâu cũng được) thì chấm vào', () {
      final yes = decideArrival(mark: at(8, 0), sight: GpsSight.unknown, previousCheckGotFix: true);
      expect(yes.action, GpsAction.checkIn);
      expect(yes.time, at(8, 0));
      expect(decideArrival(mark: at(8, 0), sight: GpsSight.unknown, previousCheckGotFix: false).action, GpsAction.none);
    });

    test('lần dò trước = lần dò ra vị trí gần nhất nằm trong 15 phút trước mốc', () {
      DayRecord fixAt(DateTime t) => empty().copyWith(gpsLastFixAt: t);
      expect(previousCheckGotFix(fixAt(at(7, 45)), at(8, 0)), isTrue);
      expect(previousCheckGotFix(fixAt(at(7, 51)), at(8, 0)), isTrue); // dò ra ở lần thử lại
      expect(previousCheckGotFix(fixAt(at(7, 30)), at(8, 0)), isFalse); // của mốc trước nữa
      expect(previousCheckGotFix(empty(), at(8, 0)), isFalse);
    });

    test('chấm vào xong ghi giờ vào, các giờ khác giữ nguyên', () {
      final r = applyGpsDecision(empty(), GpsDecision(GpsAction.checkIn, time: at(7, 0)));
      expect(r.checkIn, at(7, 0));
      expect(r.checkOut, isNull);
    });
  });

  group('chấm ra', () {
    test('trong 200 m hoặc không dò ra vị trí -> vẫn đang làm', () {
      expect(decideDeparture(mark: at(17, 15), sight: GpsSight.near).action, GpsAction.none);
      expect(decideDeparture(mark: at(17, 15), sight: GpsSight.unknown).action, GpsAction.none);
    });

    test('ngoài 200 m: dò phút 15 -> giờ ra x:00, dò phút 45 -> giờ ra x:30', () {
      expect(decideDeparture(mark: at(17, 15), sight: GpsSight.away).time, at(17, 0));
      expect(decideDeparture(mark: at(17, 45), sight: GpsSight.away).time, at(17, 30));
      expect(decideDeparture(mark: at(17, 45), sight: GpsSight.atCheckOutPlace).time, at(17, 30));
      final r = applyGpsDecision(checkedIn(), decideDeparture(mark: at(17, 15), sight: GpsSight.away));
      expect(r.checkOut, at(17, 0));
      expect(r.checkOutByGps, isTrue);
    });

    test('dò sau nửa đêm: giờ ra là giờ của sáng hôm sau', () {
      expect(decideDeparture(mark: at(1, 15, dayOffset: 1), sight: GpsSight.away).time, at(1, 0, dayOffset: 1));
    });
  });

  group('mở lại ca', () {
    final closed = checkedIn().copyWith(checkOut: at(12, 0), checkOutByGps: true);

    test('còn ở chỗ làm, hoặc không dò ra vị trí -> bỏ giờ ra', () {
      for (final sight in [GpsSight.near, GpsSight.unknown]) {
        final r = applyGpsDecision(closed, decideReopen(sight));
        expect(r.checkOut, isNull);
        expect(r.checkOutByGps, isFalse);
        expect(r.checkIn, at(7, 0));
      }
    });

    test('đã đi xa, hoặc ở nhà trọ "chấm về" -> giữ giờ ra', () {
      for (final sight in [GpsSight.away, GpsSight.atCheckOutPlace]) {
        expect(applyGpsDecision(closed, decideReopen(sight)).checkOut, at(12, 0));
      }
    });
  });

  test('báo đỏ quên chấm ra từ 22:00', () {
    final open = checkedIn();
    expect(isMissedCheckOut(open, at(21, 59)), isFalse);
    expect(isMissedCheckOut(open, at(22, 0)), isTrue);
  });

  test('cấu hình GPS lưu rồi đọc lại giữ ba mốc giờ; dữ liệu cũ không có thì lấy mặc định', () {
    final gps = GpsConfig(arriveFrom: const Clock(6, 30), arriveTo: const Clock(12, 0), departUntil: const Clock(1, 0));
    final back = GpsConfig.fromJson(gps.toJson());
    expect(back.arriveFrom, const Clock(6, 30));
    expect(back.arriveTo, const Clock(12, 0));
    expect(back.departUntil, const Clock(1, 0));
    final old = GpsConfig.fromJson({'enabled': true, 'lat': 21.0285, 'lng': 105.8542});
    expect(old.arriveFrom, const Clock(7, 0));
    expect(old.arriveTo, const Clock(14, 0));
    expect(old.departUntil, const Clock(2, 30));
    expect(old.extraPlaces, isEmpty);
  });
}
