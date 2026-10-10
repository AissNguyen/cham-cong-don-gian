/// Đọc/ghi trực tiếp file dữ liệu chung (`cham_cong_data.json`), dùng được từ tiến trình chính
/// (AppStore) lẫn các tiến trình nền tách biệt (widget màn hình chính, dịch vụ chấm công GPS)
/// — các tiến trình nền không có chung bộ nhớ với app nên phải đọc/ghi thẳng vào file.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Bản web không có hệ thống file / tiến trình nền riêng (không có GPS/widget) nên dùng
/// localStorage (qua shared_preferences) thay cho file — chỉ đường chính (AppStore) đọc/ghi.
const _webPrefsKey = 'cham_cong_data';

Future<File> dataFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/cham_cong_data.json');
}

Map<String, dynamic> _emptyJson() => {
  'settings': AppSettings.defaultsFor(WorkerKind.worker).toJson(),
  'records': <String, dynamic>{},
  'periodOverrides': <String, dynamic>{},
  'manualIncomeEntries': <String, dynamic>{},
};

Future<bool> dataFileExists() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_webPrefsKey);
  }
  return (await dataFile()).exists();
}

Future<Map<String, dynamic>> readDataJson() async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webPrefsKey);
    if (raw == null) return _emptyJson();
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return _emptyJson();
    }
  }
  final file = await dataFile();
  if (!await file.exists()) return _emptyJson();
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return _emptyJson();
  }
}

Future<void> writeDataJson(Map<String, dynamic> json) async {
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webPrefsKey, jsonEncode(json));
    return;
  }
  final file = await dataFile();
  await file.writeAsString(jsonEncode(json));
}

AppSettings settingsFromJson(Map<String, dynamic> json) =>
    AppSettings.fromJson(json['settings'] as Map<String, dynamic>);

DayRecord recordFromJson(Map<String, dynamic> json, DateTime date) {
  final key = dateKey(dateOnly(date));
  final records = (json['records'] as Map?)?.cast<String, dynamic>() ?? {};
  final raw = records[key];
  return raw != null ? DayRecord.fromJson((raw as Map).cast<String, dynamic>()) : DayRecord(date: dateOnly(date));
}

/// Ghi một [DayRecord] vào JSON đang có, trả về JSON đã cập nhật (không ghi file — gọi [writeDataJson] sau).
Map<String, dynamic> putRecordJson(Map<String, dynamic> json, DayRecord record) {
  final records = (json['records'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  records[dateKey(dateOnly(record.date))] = record.toJson();
  json['records'] = records;
  return json;
}

/// Đánh dấu 1 sự kiện thống kê cần ghi — dùng khi hành động xảy ra ở tiến trình nền (widget, GPS)
/// không có sẵn Firebase, để app chính ghi hộ vào lần mở/quay lại kế tiếp.
Map<String, dynamic> markPendingAnalyticsEvent(Map<String, dynamic> json, String eventName) {
  final pending = ((json['pendingAnalyticsEvents'] as List?) ?? const []).cast<String>().toSet();
  pending.add(eventName);
  json['pendingAnalyticsEvents'] = pending.toList();
  return json;
}

/// Lấy danh sách sự kiện đang chờ ghi và xóa khỏi JSON (trả về JSON đã dọn — gọi [writeDataJson] sau).
(List<String> pending, Map<String, dynamic> cleared) takePendingAnalyticsEvents(Map<String, dynamic> json) {
  final pending = ((json['pendingAnalyticsEvents'] as List?) ?? const []).cast<String>().toList();
  json['pendingAnalyticsEvents'] = <String>[];
  return (pending, json);
}
