/// Nhật ký từng lần dò GPS, để người dùng xem lại khi đang thử (Cài đặt › GPS: tùy chọn thêm ›
/// Nhật ký GPS). Lưu ở file riêng `gps_log.json`, giữ [_maxEntries] dòng gần nhất.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Khoảng 40 lần dò mỗi ngày, giữ được hơn một tháng.
const _maxEntries = 1500;

class GpsLogEntry {
  const GpsLogEntry({
    required this.mark,
    required this.at,
    required this.task,
    required this.gps,
    required this.wifi,
    required this.result,
    this.attempt = 1,
    this.wifiSeen = '',
  });

  /// Mốc dò đã cài (ví dụ 8:15).
  final DateTime mark;

  /// Lúc dò thật.
  final DateTime at;

  /// Dò cho việc gì: "Vào", "Ra", "Mở lại ca" (nhật ký cũ có thêm "Vào (dò trước)").
  final String task;

  /// Kết quả GPS: "cách 85 m", "không có sóng"...
  final String gps;

  /// Wi-Fi quen cho biết gì (chỉ khi mất GPS), hoặc chuỗi rỗng.
  final String wifi;

  /// App đã quyết định gì.
  final String result;

  /// Lần dò thứ mấy ở mốc này (1; 2 và 3 là thử lại khi không dò ra vị trí).
  final int attempt;

  /// Các mạng Wi-Fi quét được ở lần dò này.
  final String wifiSeen;

  Map<String, dynamic> toJson() => {
    'm': mark.toIso8601String(),
    'a': at.toIso8601String(),
    'k': task,
    'g': gps,
    'w': wifi,
    'r': result,
    'n': attempt,
    's': wifiSeen,
  };

  static GpsLogEntry fromJson(Map<String, dynamic> j) => GpsLogEntry(
    mark: DateTime.parse(j['m'] as String),
    at: DateTime.parse(j['a'] as String),
    task: j['k'] as String? ?? '',
    gps: j['g'] as String? ?? '',
    wifi: j['w'] as String? ?? '',
    result: j['r'] as String? ?? '',
    attempt: j['n'] as int? ?? 1,
    wifiSeen: j['s'] as String? ?? '',
  );
}

Future<File> _logFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/gps_log.json');
}

/// Nhật ký, dòng mới nhất đứng đầu.
Future<List<GpsLogEntry>> readGpsLog() async {
  if (kIsWeb) return const [];
  try {
    final file = await _logFile();
    if (!await file.exists()) return const [];
    final list = jsonDecode(await file.readAsString()) as List;
    return [for (final e in list) GpsLogEntry.fromJson((e as Map).cast<String, dynamic>())];
  } catch (_) {
    return const [];
  }
}

Future<void> addGpsLog(GpsLogEntry entry) async {
  if (kIsWeb) return;
  try {
    final list = [entry, ...await readGpsLog()].take(_maxEntries).toList();
    await (await _logFile()).writeAsString(jsonEncode([for (final e in list) e.toJson()]));
  } catch (_) {}
}

Future<void> clearGpsLog() async {
  if (kIsWeb) return;
  try {
    final file = await _logFile();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}
