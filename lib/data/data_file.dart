/// Đọc/ghi trực tiếp file dữ liệu chung (`cham_cong_data.json`), dùng được từ tiến trình chính
/// (AppStore) lẫn các tiến trình nền tách biệt (widget màn hình chính, dịch vụ chấm công GPS)
/// — các tiến trình nền không có chung bộ nhớ với app nên phải đọc/ghi thẳng vào file.
library;

import 'dart:convert';

import '../domain/models.dart';
import 'data_storage_io.dart' if (dart.library.js_interop) 'data_storage_web.dart';

Map<String, dynamic> _emptyJson() => {
  'settings': AppSettings().toJson(),
  'records': <String, dynamic>{},
  'periodOverrides': <String, dynamic>{},
  'manualIncomeEntries': <String, dynamic>{},
};

Future<bool> dataFileExists() => rawDataExists();

Future<Map<String, dynamic>> readDataJson() async {
  final raw = await readRawData();
  if (raw == null) return _emptyJson();
  try {
    return jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    return _emptyJson();
  }
}

Future<void> writeDataJson(Map<String, dynamic> json) async {
  await writeRawData(jsonEncode(json));
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
