/// Đo vị trí thủ công: người dùng bấm nút để xem lúc này cách điểm chấm bao xa, GPS mạnh hay yếu, sai
/// số bao nhiêu, rồi tự ước lượng mà chỉnh phạm vi chỗ làm. Mỗi lần đo ghi một dòng vào `gps_manual.json`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/gps_engine.dart' show distanceToWork;
import '../domain/models.dart';

const _maxEntries = 300;

class ManualGpsCheck {
  const ManualGpsCheck({
    required this.no,
    required this.name,
    required this.at,
    required this.distance,
    required this.accuracy,
    required this.satellites,
    required this.satellitesUsed,
  });

  /// Số thứ tự (tăng dần, không đổi khi xóa bớt dòng cũ).
  final int no;

  /// Tên người dùng tự ghi (ví dụ "cổng", "kho B"), có thể để trống.
  final String name;
  final DateTime at;

  /// Cách điểm chấm (mét).
  final double distance;

  /// Sai số GPS (mét).
  final double accuracy;

  /// Số vệ tinh bắt được và số vệ tinh dùng để tính vị trí (0 nếu máy không cho biết).
  final int satellites;
  final int satellitesUsed;

  /// "Độ mạnh" dễ hiểu theo số vệ tinh dùng được và sai số.
  String get strength {
    if (satellitesUsed >= 12 || (satellitesUsed == 0 && accuracy <= 10)) return 'mạnh';
    if (satellitesUsed >= 7 || (satellitesUsed == 0 && accuracy <= 30)) return 'trung bình';
    return 'yếu';
  }

  Map<String, dynamic> toJson() => {
    'n': no,
    'name': name,
    'at': at.toIso8601String(),
    'd': distance,
    'acc': accuracy,
    'sat': satellites,
    'used': satellitesUsed,
  };

  static ManualGpsCheck fromJson(Map<String, dynamic> j) => ManualGpsCheck(
    no: j['n'] as int? ?? 0,
    name: j['name'] as String? ?? '',
    at: DateTime.parse(j['at'] as String),
    distance: (j['d'] as num?)?.toDouble() ?? 0,
    accuracy: (j['acc'] as num?)?.toDouble() ?? 0,
    satellites: (j['sat'] as num?)?.toInt() ?? 0,
    satellitesUsed: (j['used'] as num?)?.toInt() ?? 0,
  );
}

Future<File> _file() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/gps_manual.json');
}

/// Nhật ký đo thủ công, mới nhất đứng đầu.
Future<List<ManualGpsCheck>> readManualChecks() async {
  if (kIsWeb) return const [];
  try {
    final file = await _file();
    if (!await file.exists()) return const [];
    final list = jsonDecode(await file.readAsString()) as List;
    return [for (final e in list) ManualGpsCheck.fromJson((e as Map).cast<String, dynamic>())];
  } catch (_) {
    return const [];
  }
}

Future<void> clearManualChecks() async {
  if (kIsWeb) return;
  try {
    final file = await _file();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// Đo vị trí ngay và ghi nhật ký. Trả về null nếu không dò ra vị trí (mất sóng, tắt định vị).
Future<ManualGpsCheck?> measureNow(GpsConfig gps, {String name = ''}) async {
  if (gps.latitude == null || gps.longitude == null) return null;
  final Position pos;
  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 30)),
    );
  } catch (_) {
    return null;
  }
  final old = await readManualChecks();
  final check = ManualGpsCheck(
    no: (old.isEmpty ? 0 : old.first.no) + 1,
    name: name.trim(),
    at: DateTime.now(),
    distance: distanceToWork(gps, pos.latitude, pos.longitude),
    accuracy: pos.accuracy,
    satellites: pos is AndroidPosition ? pos.satelliteCount.round() : 0,
    satellitesUsed: pos is AndroidPosition ? pos.satellitesUsedInFix.round() : 0,
  );
  try {
    final list = [check, ...old].take(_maxEntries).toList();
    await (await _file()).writeAsString(jsonEncode([for (final c in list) c.toJson()]));
  } catch (_) {}
  return check;
}
