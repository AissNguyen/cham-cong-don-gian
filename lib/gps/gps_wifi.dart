/// Wi-Fi quen, dùng khi không có sóng GPS. Không kết nối, không cần mật khẩu: chỉ xem điện thoại đang
/// "thấy" những mạng nào. App tự học hai danh sách: mạng thấy khi GPS báo đang ở chỗ làm (trong 200 m)
/// và mạng thấy khi GPS báo ở ngoài (nhà, quán...). Lưu ở file riêng `gps_wifi.json` (không gộp vào file
/// dữ liệu chấm công vì AppStore ghi đè cả file đó mỗi lần lưu).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../domain/gps_engine.dart' show GpsSight;

/// Mỗi danh sách nhớ tối đa ngần này mạng, mạng thấy gần đây nhất đứng đầu.
const _maxKnown = 60;

/// Danh sách mọi mạng đã thấy nhớ tối đa ngần này thiết bị phát.
const _maxAll = 200;

/// Sóng yếu hơn mức này (dBm) thì không học (mạng ở xa, lúc có lúc không).
const _minLearnLevel = -82;

/// Mỗi mạng nhớ tối đa ngần này mốc dò đã thấy nó (mới nhất trước).
const _maxMarks = 60;

/// Một mạng Wi-Fi app đã học (một thiết bị phát; nhiều thiết bị có thể cùng tên mạng).
class KnownWifi {
  const KnownWifi(this.bssid, this.ssid, this.lastSeen, {this.marks = const [], this.days = const {}});

  final String bssid;
  final String ssid;
  final DateTime lastSeen;

  /// Các mốc dò đã thấy mạng này, mới nhất trước.
  final List<DateTime> marks;

  /// Các ngày (yyyy-mm-dd) đã thấy mạng này.
  final Set<String> days;

  KnownWifi seenAt(DateTime mark, String newSsid) => KnownWifi(
    bssid,
    newSsid.isNotEmpty ? newSsid : ssid,
    mark,
    marks: [mark, ...marks.where((m) => m != mark)].take(_maxMarks).toList(),
    days: {...days, _dayKey(mark)},
  );

  Map<String, dynamic> toJson() => {
    'b': bssid,
    's': ssid,
    't': lastSeen.toIso8601String(),
    'm': marks.map((m) => m.toIso8601String()).toList(),
    'd': days.toList(),
  };

  static KnownWifi? fromJson(Object? j) {
    if (j is String) return KnownWifi(j, '', DateTime(2000)); // bản 1.2.0: chỉ có mã thiết bị phát
    if (j is! Map) return null;
    return KnownWifi(
      j['b'] as String,
      j['s'] as String? ?? '',
      DateTime.tryParse(j['t'] as String? ?? '') ?? DateTime(2000),
      marks: [for (final m in (j['m'] as List?) ?? const []) ?DateTime.tryParse(m as String)],
      days: {for (final d in (j['d'] as List?) ?? const []) d as String},
    );
  }
}

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Một mạng xuất hiện từ ngần này lần (mốc dò) trở lên mới được dùng để quyết định.
const wifiMinSightings = 4;

/// Mỗi danh sách chỉ dùng ngần này mạng xuất hiện nhiều nhất.
const wifiTopNetworks = 3;

/// Mạng thấy lần đầu đã ngần này ngày mà vẫn xuất hiện dưới [wifiMinSightings] lần thì xóa hẳn (cả khỏi
/// nhật ký Wi-Fi), cho danh sách gọn.
const wifiPruneAfterDays = 3;

/// Cứ ngần này ngày, mạng nào xuất hiện quá [wifiResetTo] lần thì hạ về [wifiResetTo], để mạng cũ không
/// chiếm chỗ mãi và mạng mới xuất hiện nhiều có thể vượt lên.
const wifiResetEveryDays = 3;
const wifiResetTo = 5;

/// Hạ số lần xuất hiện của mỗi mạng (theo tên) về tối đa [wifiResetTo]: giữ lại các mốc gần nhất.
List<KnownWifi> resetWifi(List<KnownWifi> list) {
  final keep = <String, Set<DateTime>>{};
  for (final g in groupWifi(list)) {
    if (g.sightings <= wifiResetTo) continue;
    final recent = g.marks.take(wifiResetTo).toSet();
    for (final b in g.bssids) {
      keep[b] = recent;
    }
  }
  return [
    for (final w in list)
      keep.containsKey(w.bssid)
          ? KnownWifi(w.bssid, w.ssid, w.lastSeen, marks: w.marks.where(keep[w.bssid]!.contains).toList(), days: w.days)
          : w,
  ];
}

/// Bỏ các mạng thấy lần đầu từ [wifiPruneAfterDays] ngày trước mà vẫn xuất hiện ít (tính theo tên mạng).
List<KnownWifi> pruneWifi(List<KnownWifi> list, DateTime now) {
  final cutoff = now.subtract(const Duration(days: wifiPruneAfterDays));
  final drop = <String>{};
  for (final g in groupWifi(list)) {
    final first = g.marks.isEmpty ? DateTime(2000) : g.marks.last;
    if (g.sightings < wifiMinSightings && !first.isAfter(cutoff)) drop.addAll(g.bssids);
  }
  return [for (final w in list) if (!drop.contains(w.bssid)) w];
}

/// Các thiết bị phát cùng tên mạng gộp làm một (không có tên thì mỗi thiết bị một nhóm).
class WifiGroup {
  WifiGroup(this.name, this.members);

  final String name;
  final List<KnownWifi> members;

  /// Các mốc dò đã thấy mạng này, mới nhất trước.
  late final List<DateTime> marks = members.expand((w) => w.marks).toSet().toList()..sort((a, b) => b.compareTo(a));
  late final Set<String> days = members.expand((w) => w.days).toSet();

  /// Số lần xuất hiện = số mốc dò đã thấy.
  int get sightings => marks.length;
  Set<String> get bssids => {for (final w in members) w.bssid};
}

/// Gộp theo tên mạng, mạng xuất hiện nhiều nhất trước.
List<WifiGroup> groupWifi(List<KnownWifi> list) {
  final byName = <String, List<KnownWifi>>{};
  for (final w in list) {
    (byName[w.ssid.isEmpty ? w.bssid : w.ssid] ??= []).add(w);
  }
  return [
    for (final e in byName.entries) WifiGroup(e.value.first.ssid.isEmpty ? '' : e.key, e.value),
  ]..sort((a, b) => b.sightings.compareTo(a.sightings));
}

/// Hai danh sách Wi-Fi quen.
class KnownWifiLists {
  const KnownWifiLists({this.work = const [], this.outside = const [], this.all = const [], this.resetAt});

  /// Lần gần nhất hạ số lần xuất hiện của các mạng về [wifiResetTo] (xem [resetWifi]).
  final DateTime? resetAt;

  /// Thấy khi GPS báo đang ở chỗ làm.
  final List<KnownWifi> work;

  /// Thấy khi GPS báo đang ở ngoài chỗ làm.
  final List<KnownWifi> outside;

  /// Mọi mạng quét được ở mọi lần dò (kể cả sóng yếu, kể cả lúc mất GPS), chỉ để xem nhật ký.
  final List<KnownWifi> all;

  /// Mạng có ở cả hai danh sách (Wi-Fi hàng xóm sát chỗ làm...) thì không dùng để phân biệt.
  Set<String> get ambiguous => work.map((w) => w.bssid).toSet().intersection(outside.map((w) => w.bssid).toSet());

  /// Các nhóm mạng được dùng để quyết định: xuất hiện từ [wifiMinSightings] lần, lấy [wifiTopNetworks]
  /// nhóm nhiều nhất, bỏ mạng có ở cả hai danh sách và Wi-Fi do điện thoại phát.
  List<WifiGroup> trusted(List<KnownWifi> list) {
    final skip = ambiguous;
    return groupWifi(list)
        .where((g) => g.sightings >= wifiMinSightings && !g.bssids.every(skip.contains) && !isPhoneHotspot(g.name))
        .take(wifiTopNetworks)
        .toList();
  }
}

/// Tên mạng giống điểm phát Wi-Fi của điện thoại (iPhone, Redmi, OPPO...). Điện thoại thì người ta mang
/// đi khắp nơi nên không dùng làm mốc chấm công.
bool isPhoneHotspot(String name) => _phoneHotspot.hasMatch(name.trim());

final _phoneHotspot = RegExp(
  r"(^|[\s'’_-])(iphone|ipad|redmi|xiaomi|poco|oppo|realme|vivo|samsung|galaxy|huawei|honor|nokia|"
  r'oneplus|pixel|motorola|moto|tecno|infinix|itel|zte|androidap|android)([\s_-]|\d|$)',
  caseSensitive: false,
);

Future<File> _wifiFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/gps_wifi.json');
}

Future<KnownWifiLists> readKnownWifi() async {
  if (kIsWeb) return const KnownWifiLists();
  try {
    final file = await _wifiFile();
    if (!await file.exists()) return const KnownWifiLists();
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    List<KnownWifi> list(Object? raw) => [
      for (final e in (raw as List?) ?? const []) ?KnownWifi.fromJson(e),
    ];
    // Bản trước chỉ có một danh sách 'bssids' (Wi-Fi chỗ làm).
    return KnownWifiLists(
      work: list(json['work'] ?? json['bssids']),
      outside: list(json['outside']),
      all: list(json['all']),
      resetAt: DateTime.tryParse(json['resetAt'] as String? ?? ''),
    );
  } catch (_) {
    return const KnownWifiLists();
  }
}

Future<void> _writeKnownWifi(KnownWifiLists lists) async {
  final file = await _wifiFile();
  await file.writeAsString(
    jsonEncode({
      'work': lists.work.map((w) => w.toJson()).toList(),
      'outside': lists.outside.map((w) => w.toJson()).toList(),
      'all': lists.all.map((w) => w.toJson()).toList(),
      if (lists.resetAt != null) 'resetAt': lists.resetAt!.toIso8601String(),
    }),
  );
}

/// Xóa cả hai danh sách (khi người dùng lấy lại tọa độ chỗ làm ở nơi khác, hoặc bấm xóa).
Future<void> clearKnownWifi() async {
  if (kIsWeb) return;
  try {
    final file = await _wifiFile();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// Lý do của lần quét gần nhất không thành (để ghi vào nhật ký GPS); rỗng nếu quét được.
String lastWifiScanNote = '';

/// Quét các mạng Wi-Fi đang thấy. Trả về null nếu không quét được (tắt Wi-Fi, thiếu quyền, máy không
/// cho quét lúc này); lý do nằm ở [lastWifiScanNote].
Future<List<WiFiAccessPoint>?> scanWifi() async {
  lastWifiScanNote = '';
  if (kIsWeb) {
    lastWifiScanNote = 'bản web không quét Wi-Fi';
    return null;
  }
  try {
    final wifi = WiFiScan.instance;
    final can = await wifi.canStartScan(askPermissions: false);
    if (can != CanStartScan.yes) {
      lastWifiScanNote = 'máy chặn quét: ${can.name}';
      return null;
    }
    final done = wifi.onScannedResultsAvailable.first.timeout(const Duration(seconds: 10));
    if (!await wifi.startScan()) {
      done.ignore();
      lastWifiScanNote = 'máy từ chối quét (thường do giới hạn số lần quét khi chạy nền)';
      return null;
    }
    return await done;
  } on TimeoutException {
    lastWifiScanNote = 'đã quét nhưng sau 10 giây không nhận được kết quả';
    return null;
  } catch (e) {
    lastWifiScanNote = 'lỗi khi quét: $e';
    return null;
  }
}

/// Sau mỗi lần dò quét được Wi-Fi: ghi mốc [mark] cho các mạng quen đang thấy (ở cả hai danh sách).
/// [learnAtWork]: GPS vừa xác định được đang ở chỗ làm (true) hay ở ngoài (false) thì học thêm các mạng
/// mới sóng đủ mạnh vào danh sách tương ứng; null (mất GPS) thì không học thêm.
Future<void> noteWifi(List<WiFiAccessPoint>? found, {required DateTime mark, bool? learnAtWork}) async {
  if (found == null || found.isEmpty) return;
  final seen = {
    for (final ap in found)
      if (ap.bssid.isNotEmpty) ap.bssid.toLowerCase(): ap,
  };
  List<KnownWifi> update(List<KnownWifi> list, bool learn, {int minLevel = _minLearnLevel, int max = _maxKnown}) {
    final known = {for (final w in list) w.bssid};
    final result = [
      for (final w in list) seen.containsKey(w.bssid) ? w.seenAt(mark, seen[w.bssid]!.ssid) : w,
      if (learn)
        for (final ap in seen.values)
          if (ap.level >= minLevel && !known.contains(ap.bssid.toLowerCase()))
            KnownWifi(ap.bssid.toLowerCase(), ap.ssid, mark, marks: [mark], days: {_dayKey(mark)}),
    ]..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    return result.take(max).toList();
  }

  final lists = await readKnownWifi();
  var work = pruneWifi(update(lists.work, learnAtWork == true), mark);
  var outside = pruneWifi(update(lists.outside, learnAtWork == false), mark);
  var all = pruneWifi(update(lists.all, true, minLevel: -200, max: _maxAll), mark);
  // Mạng có ở cả chỗ làm lẫn ngoài phạm vi thì không phân biệt được gì: xóa hẳn khỏi hai danh sách.
  final both = work.map((w) => w.bssid).toSet().intersection(outside.map((w) => w.bssid).toSet());
  work = [for (final w in work) if (!both.contains(w.bssid)) w];
  outside = [for (final w in outside) if (!both.contains(w.bssid)) w];
  // Cứ [wifiResetEveryDays] ngày, hạ số lần xuất hiện của các mạng về tối đa [wifiResetTo].
  var resetAt = lists.resetAt ?? mark;
  if (mark.difference(resetAt).inDays >= wifiResetEveryDays) {
    work = resetWifi(work);
    outside = resetWifi(outside);
    all = resetWifi(all);
    resetAt = mark;
  }
  await _writeKnownWifi(KnownWifiLists(work: work, outside: outside, all: all, resetAt: resetAt));
}

/// Kết quả xem Wi-Fi khi mất GPS: cho biết gì ([GpsSight.near], [GpsSight.away] hoặc
/// [GpsSight.unknown]) và một dòng chữ để ghi nhật ký.
class WifiReading {
  const WifiReading(this.sight, this.text);

  final GpsSight sight;
  final String text;
}

/// Mất GPS: so các mạng đang thấy với hai danh sách đã học.
WifiReading readWifi(List<WiFiAccessPoint>? found, KnownWifiLists lists) {
  if (found == null) return const WifiReading(GpsSight.unknown, 'không quét được Wi-Fi');
  final ambiguous = lists.ambiguous;
  Map<String, String> names(List<WifiGroup> groups) => {
    for (final g in groups)
      for (final b in g.bssids)
        if (!ambiguous.contains(b)) b: g.name,
  };
  final work = names(lists.trusted(lists.work));
  final outside = names(lists.trusted(lists.outside));
  final seenWork = <String>{};
  final seenOutside = <String>{};
  for (final ap in found) {
    final b = ap.bssid.toLowerCase();
    if (work.containsKey(b)) seenWork.add(_name(work[b]!, b));
    if (outside.containsKey(b)) seenOutside.add(_name(outside[b]!, b));
  }
  if (seenWork.isNotEmpty && seenOutside.isEmpty) {
    return WifiReading(GpsSight.near, 'thấy Wi-Fi chỗ làm: ${seenWork.join(', ')}');
  }
  if (seenOutside.isNotEmpty && seenWork.isEmpty) {
    return WifiReading(GpsSight.away, 'thấy Wi-Fi ngoài 200 m: ${seenOutside.join(', ')}');
  }
  if (seenWork.isNotEmpty) {
    return WifiReading(GpsSight.unknown, 'thấy cả Wi-Fi chỗ làm lẫn Wi-Fi ngoài');
  }
  return WifiReading(GpsSight.unknown, 'không thấy Wi-Fi quen (${found.length} mạng)');
}

String _name(String ssid, String bssid) => ssid.isNotEmpty ? ssid : bssid;
