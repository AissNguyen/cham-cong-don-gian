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

enum GpsAction { none, checkIn, checkOut }

/// Đứng ở [currentLat]/[currentLng] lúc [now] thì có nên tự chấm không, và chấm vào hay chấm ra.
///
/// Quy tắc: trong bán kính đã cài, đang trong khung giờ chấm vào và hôm nay chưa có giờ vào ->
/// tự chấm vào. Đang trong khung giờ chấm ra và hôm nay đã có giờ vào nhưng chưa có giờ ra ->
/// tự chấm ra. Ngày nghỉ, đã chấm đủ, hoặc ngoài bán kính/khung giờ thì không làm gì.
GpsAction decideGpsAction({
  required AppSettings settings,
  required DayRecord todayRecord,
  required DateTime now,
  required double currentLat,
  required double currentLng,
}) {
  final gps = settings.gps;
  if (!gps.enabled || gps.latitude == null || gps.longitude == null) return GpsAction.none;
  if (todayRecord.isDayOff) return GpsAction.none;

  final dist = distanceMeters(currentLat, currentLng, gps.latitude!, gps.longitude!);
  if (dist > gps.radiusMeters) return GpsAction.none;

  final clock = Clock(now.hour, now.minute);
  if (todayRecord.checkIn == null && _inWindow(clock, gps.checkInWindows)) return GpsAction.checkIn;
  if (todayRecord.checkIn != null && todayRecord.checkOut == null && _inWindow(clock, gps.checkOutWindows)) {
    return GpsAction.checkOut;
  }
  return GpsAction.none;
}

/// Còn khung giờ kiểm tra nào của hôm nay chưa qua không (dùng để biết lúc nào dừng dịch vụ nền).
bool hasWindowLeftToday({required AppSettings settings, required DayRecord todayRecord, required DateTime now}) {
  final gps = settings.gps;
  final clock = Clock(now.hour, now.minute);
  bool notPassed(TimeWindow w) => clock <= w.to;
  if (todayRecord.checkIn == null && gps.checkInWindows.any(notPassed)) return true;
  if (todayRecord.checkIn != null && todayRecord.checkOut == null && gps.checkOutWindows.any(notPassed)) {
    return true;
  }
  return false;
}
