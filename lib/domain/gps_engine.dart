/// Quyết định máy có nên tự chấm công theo GPS ngay lúc này không — tách riêng khỏi các plugin
/// vị trí/thông báo để kiểm tra được bằng test thuần Dart.
///
/// Cách chấm (người dùng chốt ngày 2026-10-14, bỏ Wi-Fi ngày 2026-10-23). Mỗi lần dò: lấy GPS; không
/// lấy được thì thử lại 2 lần, mỗi lần cách 3 phút. Cả 3 lần đều không dò ra vị trí thì coi như đang ở
/// chỗ làm (trong nhà xưởng hay mất GPS). Riêng khi định vị của máy bị tắt (hoặc app mất quyền vị trí)
/// thì không kết luận gì.
/// - **Chấm vào**, từ [GpsConfig.arriveFrom] (7:00) tới [GpsConfig.arriveTo] (14:00):
///   - Dò trước ở phút 45 và 15 (có cả 6:45): chỉ để biết điện thoại còn dò ra vị trí, ở đâu cũng được.
///   - Dò chính ở phút 00 và 30: trong [GpsConfig.departRadiusMeters] (200 m) thì chấm vào, giờ vào là
///     đúng mốc đó; ngoài 200 m thì chờ mốc sau. Không dò ra vị trí thì cũng chấm vào.
/// - **Chấm ra**: sau khi chấm vào, dò ở phút 15 và 45 tới [GpsConfig.departUntil] (2:30 sáng hôm
///   sau). Trong 200 m: vẫn đang làm. Ngoài 200 m: chấm ra, giờ ra là x:00 (dò phút 15) hoặc x:30
///   (dò phút 45). Không dò ra vị trí: coi như vẫn đang làm.
/// - **Mở lại ca**: giờ ra do GPS chốt thì dò thêm 3 lần, cách nhau 1 tiếng. Trong 200 m, hoặc không
///   dò ra vị trí: bỏ giờ ra, chấm lại từ đầu.
library;

import 'dart:math' as math;

import 'models.dart';

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

/// Làm tròn về mốc 30 phút gần nhất — ví dụ 6:50 -> 7:00, 7:20 -> 7:30. (Dùng cho dữ liệu cũ; cách
/// chấm GPS mới lấy thẳng mốc giờ, không làm tròn.)
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

// ---- Lịch dò ----

/// Không dò ra vị trí thì thử lại ngần này lần, mỗi lần cách [gpsRetryMinutes] phút.
const gpsRetries = 2;
const gpsRetryMinutes = 3;

/// Giờ ra do GPS chốt thì dò lại ngần này lần, mỗi lần cách [gpsReopenEveryMinutes] phút.
const gpsReopenChecks = 3;
const gpsReopenEveryMinutes = 60;

int _minutes(Clock c) => c.totalMinutes;

/// Giờ cuối dò giờ về có sang ngày hôm sau không (ví dụ 2:30 sáng).
bool _departOvernight(GpsConfig gps) => _minutes(gps.departUntil) < _minutes(gps.arriveFrom);

/// Các giờ trong ngày cần đặt báo thức: phút 00/15/30/45 trong khoảng chấm vào (kể cả 15 phút trước
/// giờ bắt đầu), và phút 15/45 từ sau giờ bắt đầu tới giờ cuối dò giờ về (có thể sang sáng hôm sau).
List<Clock> gpsProbeTimes(GpsConfig gps) {
  final set = <int>{};
  final from = _minutes(gps.arriveFrom);
  final to = _minutes(gps.arriveTo);
  for (var t = from - 15; t <= to; t += 15) {
    set.add((t + 24 * 60) % (24 * 60));
  }
  final until = _minutes(gps.departUntil) + (_departOvernight(gps) ? 24 * 60 : 0);
  for (var t = from + 15; t <= until; t += 30) {
    set.add(t % (24 * 60));
  }
  final list = set.toList()..sort();
  return [for (final t in list) Clock(t ~/ 60, t % 60)];
}

/// Báo thức trễ so với mốc quá ngần này phút thì bỏ mốc đó (mốc kế tiếp vẫn dò bình thường): lúc chờ
/// chấm vào (mốc cách nhau 15 phút) cho trễ 5 phút; dò giờ về và dò lại (mốc phút 15/45) cho trễ tới
/// phút 35 hoặc 05, tức 20 phút.
int gpsLateLimitMinutes(GpsTask task) =>
    task == GpsTask.arrival || task == GpsTask.arrivalCheck ? 5 : 20;

/// Mốc [p] có quá trễ để dò không. [retrying]: mốc này đang dò dở (đã dò ít nhất một lần, đang chờ thử
/// lại). Giới hạn trễ chỉ tính cho lần dò đầu; đang thử lại thì cho thêm thời gian của các lần thử lại,
/// để lúc nào cũng dò đủ 3 lần.
bool gpsPlanTooLate(GpsPlan p, {required bool retrying}) => retrying
    ? p.lateMinutes > gpsLateLimitMinutes(p.task) + gpsRetries * (gpsRetryMinutes + 1)
    : p.tooLate;

/// Mỗi lần chạy, xem lại các mốc trong ngần này phút gần nhất để ghi nhật ký những mốc bị bỏ.
const gpsLookBackMinutes = 60;

/// Việc của một lần dò.
enum GpsTask {
  /// Dò trước ở phút 45/15 trong khoảng chấm vào: chỉ để biết điện thoại còn dò ra vị trí.
  arrivalCheck,

  /// Dò chính ở phút 00/30 trong khoảng chấm vào.
  arrival,

  /// Đã chấm vào, dò ở phút 15/45 xem đã về chưa.
  departure,

  /// Giờ ra do GPS chốt, dò lại xem có quay lại chỗ làm không.
  reopen,
}

/// Một lần dò: làm việc gì, ở mốc nào, cho ngày chấm công nào (ca qua nửa đêm thuộc về hôm trước), và
/// lúc chạy trễ mốc bao nhiêu phút.
class GpsPlan {
  const GpsPlan(this.task, this.mark, this.day, {this.lateMinutes = 0});

  final GpsTask task;
  final DateTime mark;
  final DateTime day;
  final int lateMinutes;

  /// Trễ quá giới hạn: bỏ mốc này.
  bool get tooLate => lateMinutes > gpsLateLimitMinutes(task);

  String get label => switch (task) {
    GpsTask.arrivalCheck => 'Vào (dò trước)',
    GpsTask.arrival => 'Vào',
    GpsTask.departure => 'Ra',
    GpsTask.reopen => 'Mở lại ca',
  };
}

DateTime _quarterFloor(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute - t.minute % 15);

/// Việc ở đúng mốc [mark] (phút 00/15/30/45), hoặc null nếu mốc đó không có việc hay đã làm xong.
/// [recordOf] trả về dữ liệu chấm công của một ngày (null nếu không có trong tay).
GpsPlan? gpsPlanForMark({
  required AppSettings settings,
  required DayRecord? Function(DateTime day) recordOf,
  required DateTime mark,
  required DateTime now,
}) {
  final gps = settings.gps;
  if (!gps.enabled || gps.latitude == null || gps.longitude == null) return null;
  final t = mark.hour * 60 + mark.minute;
  final quarterOff = mark.minute % 30 == 15; // phút 15 hoặc 45
  final late = now.difference(mark).inMinutes;
  GpsPlan? done(GpsPlan? p, DayRecord r) => p == null || r.gpsDoneMarks.contains(mark)
      ? null
      : GpsPlan(p.task, p.mark, p.day, lateMinutes: late);

  // Sau nửa đêm, trước giờ cuối dò giờ về: làm cho ca của hôm trước.
  if (_departOvernight(gps) && t <= _minutes(gps.departUntil)) {
    final prev = recordOf(dateOnly(mark).subtract(const Duration(days: 1)));
    if (prev == null || prev.isDayOff || prev.checkIn == null) return null;
    return done(_afterCheckIn(prev, mark, quarterOff), prev);
  }

  final record = recordOf(dateOnly(mark));
  if (record == null || record.isDayOff) return null;
  if (record.checkIn == null) {
    final from = _minutes(gps.arriveFrom);
    if (t < from - 15 || t > _minutes(gps.arriveTo)) return null;
    final task = quarterOff ? GpsTask.arrivalCheck : GpsTask.arrival;
    return done(GpsPlan(task, mark, dateOnly(record.date)), record);
  }
  if (_departOvernight(gps) || t <= _minutes(gps.departUntil)) {
    return done(_afterCheckIn(record, mark, quarterOff), record);
  }
  return null;
}

/// Các mốc trong [gpsLookBackMinutes] phút gần nhất (tính cả mốc đang chạy) có việc mà chưa làm, cũ
/// trước. Mốc nào [GpsPlan.tooLate] là mốc bị bỏ (báo thức trễ quá hoặc không reo).
List<GpsPlan> gpsPendingPlans({
  required AppSettings settings,
  required DayRecord today,
  required DayRecord yesterday,
  required DateTime now,
}) {
  DayRecord? recordOf(DateTime day) {
    if (day == dateOnly(today.date)) return today;
    if (day == dateOnly(yesterday.date)) return yesterday;
    return null;
  }

  final latest = _quarterFloor(now);
  // Mốc cũ hơn (hoặc bằng) mốc đã làm gần nhất là chuyện đã qua: lúc đó nó không có việc (ví dụ đã chấm
  // ra rồi) dù giờ dữ liệu đã đổi (ví dụ vừa mở lại ca), nên không tính là "mốc bị bỏ".
  DateTime? lastDone;
  for (final r in [today, yesterday]) {
    for (final m in r.gpsDoneMarks) {
      if (lastDone == null || m.isAfter(lastDone)) lastDone = m;
    }
  }
  final plans = <GpsPlan>[];
  for (var k = gpsLookBackMinutes ~/ 15; k >= 0; k--) {
    final mark = latest.subtract(Duration(minutes: 15 * k));
    if (lastDone != null && !mark.isAfter(lastDone)) continue;
    final p = gpsPlanForMark(settings: settings, recordOf: recordOf, mark: mark, now: now);
    if (p != null) plans.add(p);
  }
  return plans;
}

/// Việc cần làm ngay lúc [now] (mốc gần nhất chưa làm, còn trong giới hạn trễ), hoặc null.
GpsPlan? gpsPlanAt({
  required AppSettings settings,
  required DayRecord today,
  required DayRecord yesterday,
  required DateTime now,
}) {
  final plans = gpsPendingPlans(settings: settings, today: today, yesterday: yesterday, now: now);
  if (plans.isEmpty || plans.last.tooLate) return null;
  return plans.last;
}

GpsPlan? _afterCheckIn(DayRecord record, DateTime mark, bool quarterOff) {
  if (!quarterOff) return null;
  final day = dateOnly(record.date);
  if (record.checkOut == null) {
    return mark.isAfter(record.checkIn!) ? GpsPlan(GpsTask.departure, mark, day) : null;
  }
  // Giờ ra bấm tay thì không đụng tới. Giờ ra do GPS chốt là mốc dò trừ 15 phút, nên lần dò lại thứ
  // n rơi vào giờ ra + 15 phút + n tiếng.
  if (!record.checkOutByGps) return null;
  final since = mark.difference(record.checkOut!).inMinutes - 15;
  for (var n = 1; n <= gpsReopenChecks; n++) {
    if (since == n * gpsReopenEveryMinutes) return GpsPlan(GpsTask.reopen, mark, day);
  }
  return null;
}

// ---- Quyết định ----

/// Một lần dò cho biết gì.
enum GpsSight {
  /// Ở chỗ làm: GPS thấy trong 200 m (hoặc ở địa điểm khác loại "không chấm về").
  near,

  /// Đã đi: GPS thấy ngoài 200 m.
  away,

  /// GPS thấy đang ở địa điểm khác loại "chấm về" (nhà trọ...).
  atCheckOutPlace,

  /// Định vị bật mà không dò ra vị trí (trong nhà xưởng, mất sóng): coi như đang ở chỗ làm.
  unknown,

  /// Định vị của máy đang tắt, hoặc app không có quyền vị trí: không kết luận gì.
  locationOff,
}

/// Phân loại một tọa độ GPS lấy được; [distance] trả về để ghi nhật ký.
GpsSight classifyGpsFix(GpsConfig gps, double lat, double lng) {
  final place = _extraPlaceAt(gps, lat, lng);
  if (place != null) return place.checkOut ? GpsSight.atCheckOutPlace : GpsSight.near;
  return distanceToWork(gps, lat, lng) <= gps.departRadiusMeters ? GpsSight.near : GpsSight.away;
}

double distanceToWork(GpsConfig gps, double lat, double lng) =>
    distanceMeters(lat, lng, gps.latitude!, gps.longitude!);

enum GpsAction {
  none,
  checkIn,
  checkOut,

  /// Bỏ giờ ra do GPS chốt, theo dõi lại từ đầu.
  reopen,
}

class GpsDecision {
  const GpsDecision(this.action, {this.time});

  final GpsAction action;

  /// Giờ chấm của [GpsAction.checkIn] / [GpsAction.checkOut].
  final DateTime? time;
}

/// Lần dò chính chấm vào (phút 00/30): ở chỗ làm, hoặc không dò ra vị trí (sau 3 lần thử), thì chấm vào.
GpsDecision decideArrival({required DateTime mark, required GpsSight sight}) {
  switch (sight) {
    case GpsSight.near:
    case GpsSight.unknown:
      return GpsDecision(GpsAction.checkIn, time: mark);
    case GpsSight.away:
    case GpsSight.atCheckOutPlace:
    case GpsSight.locationOff:
      return const GpsDecision(GpsAction.none);
  }
}

/// Dò giờ về (phút 15/45): đã đi thì giờ ra là mốc trừ 15 phút (x:00 hoặc x:30).
GpsDecision decideDeparture({required DateTime mark, required GpsSight sight}) {
  switch (sight) {
    case GpsSight.near:
    case GpsSight.unknown:
    case GpsSight.locationOff:
      return const GpsDecision(GpsAction.none);
    case GpsSight.away:
    case GpsSight.atCheckOutPlace:
      return GpsDecision(GpsAction.checkOut, time: mark.subtract(const Duration(minutes: 15)));
  }
}

/// Dò lại sau khi GPS đã chốt giờ ra: còn ở chỗ làm, hoặc không dò ra vị trí (định vị vẫn bật), thì mở
/// lại ca.
GpsDecision decideReopen(GpsSight sight) => GpsDecision(
  sight == GpsSight.near || sight == GpsSight.unknown ? GpsAction.reopen : GpsAction.none,
);

/// Áp một quyết định vào dữ liệu của ngày.
DayRecord applyGpsDecision(DayRecord record, GpsDecision decision) {
  switch (decision.action) {
    case GpsAction.none:
      return record;
    case GpsAction.checkIn:
      return record.copyWith(checkIn: decision.time, isDayOff: false);
    case GpsAction.checkOut:
      return record.copyWith(checkOut: decision.time, checkOutByGps: true);
    case GpsAction.reopen:
      return record.copyWith(clearCheckOut: true);
  }
}

/// Chữ ngắn của một quyết định, để ghi nhật ký.
String describeDecision(GpsTask task, GpsDecision d, GpsSight sight) {
  String hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  switch (d.action) {
    case GpsAction.checkIn:
      return 'Chấm vào ${hm(d.time!)}';
    case GpsAction.checkOut:
      return 'Chấm ra ${hm(d.time!)}';
    case GpsAction.reopen:
      return 'Mở lại ca';
    case GpsAction.none:
      return switch (task) {
        GpsTask.arrivalCheck => switch (sight) {
          GpsSight.unknown => 'Không dò ra vị trí',
          GpsSight.locationOff => 'Định vị đang tắt',
          _ => 'Dò ra vị trí',
        },
        GpsTask.arrival => sight == GpsSight.locationOff ? 'Chưa vào (định vị đang tắt)' : 'Chưa vào',
        GpsTask.departure => 'Vẫn đang làm',
        GpsTask.reopen => 'Giữ giờ ra',
      };
  }
}
