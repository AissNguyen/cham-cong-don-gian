/// Quyết định máy có nên tự chấm công theo GPS ngay lúc này không — tách riêng khỏi các plugin
/// vị trí/thông báo để kiểm tra được bằng test thuần Dart.
///
/// Cách chấm (chốt ngày 2026-10-10):
/// - **Chấm vào**: trong khung giờ bật GPS, thấy trong [GpsConfig.radiusMeters] là chấm vào.
/// - **Chấm ra**: sau khi chấm vào, mỗi nửa tiếng kiểm tra đúng một lần ở phút 05 và phút 35. Còn
///   trong [GpsConfig.departRadiusMeters] (hoặc mất GPS nhưng thấy Wi-Fi quen của chỗ làm) thì ghi
///   **giờ về tạm**; lần kiểm tra sau thấy đã ra ngoài thì giờ về tạm đó thành giờ chấm ra.
/// - **Mở lại ca**: giờ ra do GPS chốt thì cứ 2 tiếng kiểm tra lại một lần; thấy vẫn ở chỗ làm thì bỏ
///   giờ ra, theo dõi lại từ đầu (đi ăn trưa rồi quay lại...).
/// - Không xác định được (không GPS, không Wi-Fi quen) sau vài lần thử: báo đỏ để người dùng tự xem.
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

// ---- Lịch kiểm tra ----

/// Phút trong mỗi nửa tiếng mà app kiểm tra giờ về: phút 05 và phút 35.
const gpsMarkMinute = 5;

/// Mỗi mốc kiểm tra kéo dài tối đa ngần này phút (để còn thử lại khi chưa xác định được).
const gpsMarkSpanMinutes = 10;

/// Chưa chấm vào thì chỉ các khung trước giờ này mới dò lặp lại để bắt lúc tới nơi; sau giờ này mỗi
/// khung dò một lần.
const gpsArrivalPollUntil = Clock(13, 0);

/// Giờ về tạm cũ hơn ngần này so với lúc thấy đã ra ngoài thì không dùng được (lần kiểm tra liền
/// trước đã không xác định được còn ở chỗ làm).
const gpsTentativeMaxAge = Duration(minutes: 45);

/// Giờ ra do GPS chốt thì cứ ngần này phút kiểm tra lại một lần xem có quay lại chỗ làm không.
const gpsReopenEveryMinutes = 120;

/// Không xác định được vị trí thì thử lại thêm ngần này lần (mỗi lần cách nhau theo tần suất đã cài).
const gpsUnknownRetries = 3;

/// Việc dịch vụ nền cần làm lúc này.
enum GpsTask {
  none,

  /// Chưa chấm vào, đang trong khung giờ: dò xem đã tới nơi chưa.
  arrival,

  /// Đã chấm vào, đang ở mốc phút 05/35: kiểm tra còn ở chỗ làm không.
  departure,

  /// Giờ ra do GPS chốt, tới lượt kiểm tra lại sau 2 tiếng.
  reopen,
}

/// Lúc [now] có nằm trong khung giờ bật GPS nào không.
bool inGpsWindow(AppSettings settings, DateTime now) => _inWindow(Clock(now.hour, now.minute), settings.gps.allWindows);

/// [now] có nằm trong một mốc kiểm tra giờ về (phút 05–14 hoặc 35–44) không.
bool isGpsMark(DateTime now) {
  final m = now.minute % 30;
  return m >= gpsMarkMinute && m < gpsMarkMinute + gpsMarkSpanMinutes;
}

/// Các giờ trong ngày cần đặt báo thức kiểm tra giờ về: phút 05 và 35, từ lúc khung giờ đầu tiên bắt
/// đầu tới một tiếng sau khi hết khung giờ cuối cùng (để còn kịp chốt giờ ra của người về muộn nhất).
/// Không có khung giờ nào thì không có mốc nào.
List<Clock> gpsMarkTimes(GpsConfig gps) {
  final windows = gps.allWindows;
  if (windows.isEmpty) return const [];
  final first = windows.map((w) => w.from.totalMinutes).reduce(math.min);
  final last = windows.map((w) => w.to.totalMinutes).reduce(math.max) + 60;
  return [
    for (var t = gpsMarkMinute; t < 24 * 60; t += 30)
      if (t >= first && t <= last) Clock(t ~/ 60, t % 60),
  ];
}

bool _inMarkSpan(GpsConfig gps, DateTime now) {
  if (!isGpsMark(now)) return false;
  final mark = now.hour * 60 + now.minute - (now.minute % 30) + gpsMarkMinute;
  return gpsMarkTimes(gps).any((c) => c.totalMinutes == mark);
}

/// Việc cần làm lúc [now] với dữ liệu chấm công của hôm nay.
GpsTask gpsTaskAt({required AppSettings settings, required DayRecord todayRecord, required DateTime now}) {
  final gps = settings.gps;
  if (!gps.enabled || gps.latitude == null || gps.longitude == null) return GpsTask.none;
  if (todayRecord.isDayOff) return GpsTask.none;

  if (todayRecord.checkIn == null) return inGpsWindow(settings, now) ? GpsTask.arrival : GpsTask.none;
  if (!_inMarkSpan(gps, now)) return GpsTask.none;
  if (todayRecord.checkOut == null) return GpsTask.departure;

  // Giờ ra bấm tay thì không đụng tới; giờ ra do GPS chốt thì 2 tiếng kiểm tra lại một lần.
  if (!todayRecord.checkOutByGps) return GpsTask.none;
  final slots = now.difference(todayRecord.checkOut!).inMinutes ~/ 30;
  final every = gpsReopenEveryMinutes ~/ 30;
  return slots >= every && slots % every == 0 ? GpsTask.reopen : GpsTask.none;
}

/// Hôm nay còn lần kiểm tra nào ở phía trước không (để biết có cần bật dịch vụ nữa không).
bool gpsHasWorkLeftToday({required AppSettings settings, required DayRecord todayRecord, required DateTime now}) {
  final gps = settings.gps;
  if (!gps.enabled || gps.latitude == null || gps.longitude == null || todayRecord.isDayOff) return false;
  if (todayRecord.checkOut != null && !todayRecord.checkOutByGps) return false;
  final clock = Clock(now.hour, now.minute);
  return gps.allWindows.any((w) => clock <= w.to);
}

// ---- Quyết định ----

/// Một lần xác định vị trí cho biết gì.
enum GpsSight {
  /// Còn ở chỗ làm: GPS thấy trong [GpsConfig.departRadiusMeters], hoặc đang ở một địa điểm khác
  /// loại "không chấm về", hoặc mất GPS nhưng thấy Wi-Fi quen.
  near,

  /// GPS thấy đã ra ngoài [GpsConfig.departRadiusMeters].
  away,

  /// GPS thấy đang ở một địa điểm khác loại "chấm về" (nhà trọ...).
  atCheckOutPlace,

  /// Không có GPS và cũng không thấy Wi-Fi quen.
  unknown,
}

/// Phân loại một tọa độ GPS lấy được.
GpsSight classifyGpsFix(GpsConfig gps, double lat, double lng) {
  final place = _extraPlaceAt(gps, lat, lng);
  if (place != null) return place.checkOut ? GpsSight.atCheckOutPlace : GpsSight.near;
  final dist = distanceMeters(lat, lng, gps.latitude!, gps.longitude!);
  return dist <= gps.departRadiusMeters ? GpsSight.near : GpsSight.away;
}

/// Chưa chấm vào: đứng ở [lat]/[lng] có trong bán kính chấm không.
bool isInsideCheckInRadius(GpsConfig gps, double lat, double lng) =>
    distanceMeters(lat, lng, gps.latitude!, gps.longitude!) <= gps.radiusMeters;

/// Chưa chấm vào và lần dò này chưa thấy tới nơi: có dò lại trong khung này không. Khung trước
/// [gpsArrivalPollUntil] thì dò lại, sau đó mỗi khung một lần.
bool arrivalShouldPollAgain(DateTime now) => Clock(now.hour, now.minute) < gpsArrivalPollUntil;

enum GpsAction {
  none,
  checkIn,
  checkOut,

  /// Ghi giờ về tạm (mốc ngầm, chưa phải chấm ra).
  tentative,

  /// Không xác định được: báo đỏ, người dùng tự xem lại giờ về.
  flagUnknown,

  /// Bỏ giờ ra do GPS chốt, theo dõi lại từ đầu.
  reopen,
}

class GpsDecision {
  const GpsDecision(this.action, {this.time});

  final GpsAction action;

  /// Giờ chấm (đã làm tròn) của [GpsAction.checkIn] / [GpsAction.checkOut].
  final DateTime? time;
}

/// Đã chấm vào, tới mốc kiểm tra, lần xác định vị trí cho ra [sight] thì làm gì.
GpsDecision decideDeparture({required DayRecord todayRecord, required DateTime now, required GpsSight sight}) {
  final tentative = todayRecord.gpsLastSeenNearby;
  switch (sight) {
    case GpsSight.near:
      return const GpsDecision(GpsAction.tentative);
    case GpsSight.unknown:
      return const GpsDecision(GpsAction.flagUnknown);
    case GpsSight.atCheckOutPlace:
      // Về tới nhà trọ là chắc chắn đã về: có giờ về tạm thì lấy, không thì lấy giờ lúc này.
      return GpsDecision(GpsAction.checkOut, time: roundToHalfHour(tentative ?? now));
    case GpsSight.away:
      // Lần kiểm tra liền trước không xác nhận được còn ở chỗ làm thì không biết về lúc nào.
      if (tentative == null || now.difference(tentative) > gpsTentativeMaxAge) {
        return const GpsDecision(GpsAction.flagUnknown);
      }
      return GpsDecision(GpsAction.checkOut, time: roundToHalfHour(tentative));
  }
}

/// Giờ ra do GPS chốt, tới lượt kiểm tra lại: chỉ mở lại ca khi chắc chắn vẫn ở chỗ làm.
GpsDecision decideReopen(GpsSight sight) =>
    GpsDecision(sight == GpsSight.near ? GpsAction.reopen : GpsAction.none);

/// Áp một quyết định vào dữ liệu của ngày. [fixTime] là lúc lấy được vị trí.
DayRecord applyGpsDecision(DayRecord record, GpsDecision decision, DateTime fixTime) {
  switch (decision.action) {
    case GpsAction.none:
      return record;
    case GpsAction.checkIn:
      // Lúc chấm vào cũng là lần đầu thấy ở chỗ làm.
      return record.copyWith(checkIn: decision.time, isDayOff: false, gpsLastSeenNearby: fixTime);
    case GpsAction.tentative:
      return record.copyWith(gpsLastSeenNearby: fixTime, gpsLeftUnknown: false);
    case GpsAction.checkOut:
      return record.copyWith(checkOut: decision.time, checkOutByGps: true, clearGpsLastSeenNearby: true);
    case GpsAction.flagUnknown:
      return record.copyWith(gpsLeftUnknown: true);
    case GpsAction.reopen:
      return record.copyWith(clearCheckOut: true, gpsLastSeenNearby: fixTime);
  }
}
