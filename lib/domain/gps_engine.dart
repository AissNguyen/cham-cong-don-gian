/// Quyết định máy có nên tự chấm công theo GPS ngay lúc này không — tách riêng khỏi các plugin
/// vị trí/thông báo để kiểm tra được bằng test thuần Dart.
library;

import 'dart:math' as math;

import 'models.dart';

bool _inWindow(Clock now, List<TimeWindow> windows) => windows.any((w) => now >= w.from && now <= w.to);

/// Khoảng cách giữa 2 tọa độ (mét), công thức Haversine.
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Làm tròn về mốc 30 phút gần nhất (không công ty nào nhận giờ lẻ) — ví dụ 6:50 -> 7:00, 7:20 -> 7:30.
DateTime roundToHalfHour(DateTime t) {
  final total = t.hour * 60 + t.minute;
  final rounded = ((total + 15) ~/ 30) * 30;
  final dayOverflow = rounded ~/ (24 * 60);
  final clamped = rounded % (24 * 60);
  final base = DateTime(t.year, t.month, t.day, clamped ~/ 60, clamped % 60);
  return dayOverflow > 0 ? base.add(Duration(days: dayOverflow)) : base;
}

/// Địa điểm khác mà điện thoại đang ở trong bán kính; ở trong nhiều địa điểm thì lấy cái gần nhất.
GpsPlace? _extraPlaceAt(GpsConfig gps, double lat, double lng) {
  GpsPlace? best;
  double? bestDist;
  for (final p in gps.extraPlaces) {
    final d = distanceMeters(lat, lng, p.latitude, p.longitude);
    if (d <= p.radiusMeters && (bestDist == null || d < bestDist)) {
      best = p;
      bestDist = d;
    }
  }
  return best;
}

enum GpsAction { none, checkIn, checkOut }

/// Kết quả 1 lượt quyết định: hành động cần ghi (nếu có, giờ đã làm tròn) và mốc "lần cuối còn
/// gần đó" cần cập nhật lại cho [DayRecord.gpsLastSeenNearby] (dùng cho lần quét sau).
class GpsDecision {
  const GpsDecision({this.action = GpsAction.none, this.time, this.lastSeenNearby});

  final GpsAction action;
  final DateTime? time;
  final DateTime? lastSeenNearby;
}

/// Đứng ở [currentLat]/[currentLng] lúc [now] thì có nên tự chấm không.
///
/// Quy tắc: chưa chấm vào hôm nay, trong khung giờ bật GPS, trong bán kính -> chấm vào ngay lúc
/// đó (không chờ xác nhận, để tiền tính liên tục ngay từ lúc vào). Đã chấm vào, chưa chấm ra ->
/// liên tục theo dõi khoảng cách các lần quét sau: xa hơn [GpsConfig.departRadiusMeters] mới coi
/// là chắc chắn đã rời đi, lúc đó chấm ra bằng giờ lần quét gần nhất còn chưa rời xa (không phải
/// giờ hiện tại) — còn trong khoảng ≤ departRadiusMeters (dù trong hay ngoài bán kính chính) thì
/// coi là vẫn đang ở/làm gần đó, chưa chấm ra, chỉ cập nhật lại mốc "lần cuối còn gần đó".
/// Riêng khi đang ở một [GpsConfig.extraPlaces] thì địa điểm đó quyết định: "chấm về" thì chấm ra
/// ngay, "không chấm về" thì coi như vẫn đang làm. Chấm vào không bị địa điểm khác ảnh hưởng.
GpsDecision decideGpsAction({
  required AppSettings settings,
  required DayRecord todayRecord,
  required DateTime now,
  required double currentLat,
  required double currentLng,
}) {
  final gps = settings.gps;
  if (!gps.enabled || gps.latitude == null || gps.longitude == null) return const GpsDecision();
  if (todayRecord.isDayOff) return const GpsDecision();

  final clock = Clock(now.hour, now.minute);
  if (!_inWindow(clock, gps.allWindows)) return const GpsDecision();

  final dist = distanceMeters(currentLat, currentLng, gps.latitude!, gps.longitude!);

  if (todayRecord.checkIn == null) {
    if (dist <= gps.radiusMeters) {
      return GpsDecision(action: GpsAction.checkIn, time: roundToHalfHour(now));
    }
    return const GpsDecision();
  }

  if (todayRecord.checkOut == null) {
    // Đang ở một địa điểm khác (nhà trọ, xưởng xa...) thì địa điểm đó quyết định, bỏ qua vòng
    // "rời đi hẳn" của điểm chính.
    final place = _extraPlaceAt(gps, currentLat, currentLng);
    if (place != null && place.checkOut) {
      final base = todayRecord.gpsLastSeenNearby ?? now;
      return GpsDecision(action: GpsAction.checkOut, time: roundToHalfHour(base));
    }
    if (place != null) return GpsDecision(lastSeenNearby: now);

    if (dist > gps.departRadiusMeters) {
      final base = todayRecord.gpsLastSeenNearby ?? now;
      return GpsDecision(action: GpsAction.checkOut, time: roundToHalfHour(base));
    }
    return GpsDecision(lastSeenNearby: now);
  }

  return const GpsDecision();
}

/// Còn khung giờ kiểm tra nào của hôm nay chưa qua không (dùng để biết lúc nào dừng dịch vụ nền).
bool hasWindowLeftToday({required AppSettings settings, required DayRecord todayRecord, required DateTime now}) {
  if (todayRecord.checkOut != null) return false;
  final clock = Clock(now.hour, now.minute);
  return settings.gps.allWindows.any((w) => clock <= w.to);
}
