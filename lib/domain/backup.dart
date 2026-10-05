/// Sao lưu / khôi phục dữ liệu chấm công (thuần Dart, không phụ thuộc Flutter).
///
/// Bản sao lưu là toàn bộ dữ liệu app (cài đặt, các ngày đã chấm, tiền nhập tay theo kỳ) kèm
/// thời điểm xuất. Khi khôi phục, dữ liệu được **gộp theo từng ngày**:
/// - Ngày có trong bản sao lưu: lấy theo bản sao lưu (thay ngày đó trong app nếu có).
/// - Ngày chỉ có trong app: giữ nguyên.
/// - Riêng từ ngày xuất bản sao lưu trở về sau, ngày nào app đã có dữ liệu thì giữ bản trong app
///   (người dùng có thể đã chấm tiếp sau khi xuất, vd xuất lúc mới chấm vào, chiều mới chấm ra).
/// - Tiền nhập tay theo kỳ: cùng cách, theo ngày cuối kỳ.
/// - Cài đặt: người dùng chọn có lấy theo bản sao lưu hay không (mặc định: lấy khi app chưa có ngày
///   nào có dữ liệu, tức máy mới / vừa cài lại); GPS được khôi phục nhưng để tắt, người dùng tự bật
///   lại để app xin quyền vị trí trên máy này.
library;

import 'dart:convert';

import 'models.dart';

const backupFormat = 'cham-cong-don-gian-backup';
const backupFormatVersion = 1;

class BackupPayload {
  const BackupPayload({required this.exportedAt, required this.appVersion, required this.data});

  final DateTime exportedAt;
  final String appVersion;

  /// Cùng dạng với file dữ liệu của app: `settings`, `records`, `periodOverrides`.
  final Map<String, dynamic> data;

  Map<String, dynamic> get records => (data['records'] as Map?)?.cast<String, dynamic>() ?? {};

  Map<String, dynamic> toJson() => {
    'format': backupFormat,
    'version': backupFormatVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'appVersion': appVersion,
    'data': data,
  };

  String encode() => jsonEncode(toJson());

  /// Ném [FormatException] nếu không phải bản sao lưu của app hoặc dữ liệu hỏng.
  factory BackupPayload.decode(String text) {
    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Dữ liệu sao lưu bị hỏng.');
    }
    if (raw is! Map || raw['format'] != backupFormat) {
      throw const FormatException('Không phải file sao lưu của app.');
    }
    final version = raw['version'];
    if (version is! int || version > backupFormatVersion) {
      throw const FormatException('File được tạo từ bản app mới hơn, hãy cập nhật app rồi thử lại.');
    }
    final data = raw['data'];
    final exportedAt = DateTime.tryParse('${raw['exportedAt']}');
    if (data is! Map || exportedAt == null) throw const FormatException('Dữ liệu sao lưu bị hỏng.');
    final payload = BackupPayload(
      exportedAt: exportedAt,
      appVersion: '${raw['appVersion'] ?? ''}',
      data: data.cast<String, dynamic>(),
    );
    // Đọc thử từng phần để báo lỗi ngay, không để hỏng giữa chừng lúc khôi phục.
    try {
      AppSettings.fromJson((payload.data['settings'] as Map).cast<String, dynamic>());
      payload.records.forEach((_, v) => DayRecord.fromJson((v as Map).cast<String, dynamic>()));
      ((payload.data['periodOverrides'] as Map?) ?? {}).forEach((_, v) => (v as num).toDouble());
    } catch (_) {
      throw const FormatException('Dữ liệu sao lưu bị hỏng.');
    }
    return payload;
  }
}

/// Ngày có dữ liệu thật (đã chấm, nghỉ, đi muộn hoặc có ghi chú) — ngày trống không tính.
bool recordHasData(DayRecord r) =>
    r.checkIn != null ||
    r.checkOut != null ||
    r.isDayOff ||
    r.isLate ||
    (r.note?.isNotEmpty ?? false) ||
    r.tags.isNotEmpty;

class RestoreResult {
  const RestoreResult({
    required this.merged,
    required this.added,
    required this.replaced,
    required this.keptNewer,
    required this.settingsRestored,
    required this.appHadData,
  });

  /// Dữ liệu app sau khi gộp (giữ nguyên các khóa khác có trong file dữ liệu của app).
  final Map<String, dynamic> merged;

  /// Số ngày app chưa có, lấy thêm từ bản sao lưu.
  final int added;

  /// Số ngày app đã có và khác bản sao lưu, được thay bằng bản sao lưu.
  final int replaced;

  /// Số ngày (từ ngày xuất trở về sau) khác bản sao lưu nhưng giữ bản trong app.
  final int keptNewer;
  final bool settingsRestored;

  /// App đã có ngày nào có dữ liệu trước khi khôi phục chưa (chưa có thì nên lấy cả cài đặt).
  final bool appHadData;

  int get changedDays => added + replaced;
}

/// Gộp [backup] vào dữ liệu hiện tại [current] (dạng file dữ liệu của app), xem quy tắc ở đầu file.
/// [restoreSettings] null = lấy cài đặt theo file chỉ khi app chưa có dữ liệu.
RestoreResult mergeBackup(Map<String, dynamic> current, BackupPayload backup, {bool? restoreSettings}) {
  final merged = Map<String, dynamic>.of(current);
  final records = Map<String, dynamic>.of((current['records'] as Map?)?.cast<String, dynamic>() ?? {});
  final exportDay = dateOnly(backup.exportedAt);

  bool appHasData(Object? raw) => raw is Map && recordHasData(DayRecord.fromJson(raw.cast<String, dynamic>()));
  final appHadAnyData = records.values.any(appHasData);

  var added = 0;
  var replaced = 0;
  var keptNewer = 0;
  backup.records.forEach((key, value) {
    final incoming = DayRecord.fromJson((value as Map).cast<String, dynamic>());
    if (!recordHasData(incoming)) return;
    final existing = records[key];
    if (!appHasData(existing)) {
      records[key] = incoming.toJson();
      added++;
      return;
    }
    if (jsonEncode(existing) == jsonEncode(incoming.toJson())) return;
    if (!dateOnly(incoming.date).isBefore(exportDay)) {
      keptNewer++;
      return;
    }
    records[key] = incoming.toJson();
    replaced++;
  });
  merged['records'] = records;

  final overrides = Map<String, dynamic>.of((current['periodOverrides'] as Map?)?.cast<String, dynamic>() ?? {});
  ((backup.data['periodOverrides'] as Map?) ?? {}).forEach((key, value) {
    final k = '$key';
    final periodEnd = DateTime.tryParse(k.split('_').last);
    final isCurrentOrLater = periodEnd == null || !periodEnd.isBefore(exportDay);
    if (overrides.containsKey(k) && isCurrentOrLater) return;
    overrides[k] = (value as num).toDouble();
  });
  merged['periodOverrides'] = overrides;

  final settingsRestored = restoreSettings ?? !appHadAnyData;
  if (settingsRestored) {
    final settings = AppSettings.fromJson((backup.data['settings'] as Map).cast<String, dynamic>());
    merged['settings'] = settings.copyWith(gps: settings.gps.copyWith(enabled: false)).toJson();
  }

  return RestoreResult(
    merged: merged,
    added: added,
    replaced: replaced,
    keptNewer: keptNewer,
    settingsRestored: settingsRestored,
    appHadData: appHadAnyData,
  );
}
