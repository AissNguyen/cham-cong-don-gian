/// Nhận ra chỗ làm bằng các mạng Wi-Fi quen khi không có sóng GPS (làm trong kho, nhà xưởng kín).
/// Không kết nối, không cần mật khẩu: chỉ xem điện thoại đang "thấy" những mạng nào. Danh sách mạng
/// quen do app tự học mỗi lần GPS xác nhận đang ở chỗ làm, lưu ở file riêng `gps_wifi.json` (không gộp
/// vào file dữ liệu chấm công vì AppStore ghi đè cả file đó mỗi lần lưu).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:wifi_scan/wifi_scan.dart';

/// Nhớ tối đa ngần này mạng, mạng thấy gần đây nhất đứng đầu.
const _maxKnown = 40;

/// Sóng yếu hơn mức này (dBm) thì không học (mạng ở xa, lúc có lúc không).
const _minLearnLevel = -82;

Future<File> _wifiFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/gps_wifi.json');
}

Future<List<String>> readKnownWifi() async {
  if (kIsWeb) return const [];
  try {
    final file = await _wifiFile();
    if (!await file.exists()) return const [];
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return (json['bssids'] as List?)?.map((e) => e as String).toList() ?? const [];
  } catch (_) {
    return const [];
  }
}

Future<void> _writeKnownWifi(List<String> bssids) async {
  final file = await _wifiFile();
  await file.writeAsString(jsonEncode({'bssids': bssids}));
}

/// Xóa danh sách mạng quen (khi người dùng lấy lại tọa độ chỗ làm ở nơi khác).
Future<void> clearKnownWifi() async {
  if (kIsWeb) return;
  try {
    final file = await _wifiFile();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// Quét các mạng Wi-Fi đang thấy. Trả về null nếu không quét được (tắt Wi-Fi, thiếu quyền, máy không
/// cho quét lúc này) — khi đó không kết luận được gì từ Wi-Fi.
Future<List<WiFiAccessPoint>?> _scan() async {
  if (kIsWeb) return null;
  try {
    final wifi = WiFiScan.instance;
    if (await wifi.canStartScan(askPermissions: false) != CanStartScan.yes) return null;
    final done = wifi.onScannedResultsAvailable.first.timeout(const Duration(seconds: 10));
    if (!await wifi.startScan()) {
      done.ignore();
      return null;
    }
    return await done;
  } catch (_) {
    return null;
  }
}

/// Đang ở chỗ làm (GPS vừa xác nhận): ghi nhớ các mạng Wi-Fi sóng đủ mạnh đang thấy.
Future<void> learnWifiHere() async {
  final found = await _scan();
  if (found == null) return;
  final strong = [
    for (final ap in found)
      if (ap.level >= _minLearnLevel && ap.bssid.isNotEmpty) ap.bssid.toLowerCase(),
  ];
  if (strong.isEmpty) return;
  final known = await readKnownWifi();
  final merged = <String>{...strong, ...known}.take(_maxKnown).toList();
  await _writeKnownWifi(merged);
}

/// Có đang thấy mạng Wi-Fi quen nào của chỗ làm không. false cả khi không quét được.
Future<bool> seesKnownWifi() async {
  final known = (await readKnownWifi()).toSet();
  if (known.isEmpty) return false;
  final found = await _scan();
  if (found == null) return false;
  return found.any((ap) => known.contains(ap.bssid.toLowerCase()));
}
