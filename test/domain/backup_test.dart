import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cham_cong_don_gian/domain/backup.dart';
import 'package:cham_cong_don_gian/domain/models.dart';

DayRecord _day(int month, int day, {int inH = 8, int? outH = 17, bool off = false, String? note}) {
  final d = DateTime(2026, month, day);
  return DayRecord(
    date: d,
    checkIn: off ? null : DateTime(2026, month, day, inH),
    checkOut: off || outH == null ? null : DateTime(2026, month, day, outH),
    isDayOff: off,
    note: note,
  );
}

Map<String, dynamic> _appData(List<DayRecord> days, {AppSettings? settings, Map<String, double>? overrides}) => {
  'settings': (settings ?? AppSettings()).toJson(),
  'records': {for (final d in days) dateKey(d.date): d.toJson()},
  'periodOverrides': overrides ?? <String, double>{},
  'pendingAnalyticsEvents': ['app_open'],
};

BackupPayload _backup(
  List<DayRecord> days,
  DateTime exportedAt, {
  AppSettings? settings,
  Map<String, double>? overrides,
}) => BackupPayload(
  exportedAt: exportedAt,
  appVersion: '1.0.0',
  data: _appData(days, settings: settings, overrides: overrides)..remove('pendingAnalyticsEvents'),
);

DayRecord _recordIn(RestoreResult r, int month, int day) =>
    DayRecord.fromJson((r.merged['records'] as Map)[dateKey(DateTime(2026, month, day))] as Map<String, dynamic>);

void main() {
  group('Khôi phục: gộp theo từng ngày', () {
    test('ngày có trong file thay ngày trong app; ngày chỉ có trong app giữ nguyên', () {
      final current = _appData([_day(9, 1, inH: 9), _day(9, 2), _day(10, 20)]);
      final backup = _backup([_day(9, 1, inH: 7), _day(9, 3, off: true)], DateTime(2026, 10, 5, 14));
      final r = mergeBackup(current, backup);
      expect(_recordIn(r, 9, 1).checkIn!.hour, 7); // thay bằng bản trong file
      expect(_recordIn(r, 9, 2).checkIn!.hour, 8); // chỉ có trong app: giữ
      expect(_recordIn(r, 9, 3).isDayOff, isTrue); // app chưa có: thêm
      expect(_recordIn(r, 10, 20).checkIn, isNotNull); // chấm sau khi xuất: giữ
      expect(r.added, 1);
      expect(r.replaced, 1);
      expect(r.keptNewer, 0);
      // Các khóa khác trong file dữ liệu của app không bị mất.
      expect(r.merged['pendingAnalyticsEvents'], ['app_open']);
    });

    test('từ ngày xuất file trở về sau, app đã có dữ liệu thì giữ bản trong app', () {
      // Xuất lúc mới chấm vào ngày 5/10, chiều chấm ra trong app, sau đó khôi phục.
      final current = _appData([_day(10, 5, outH: 17)]);
      final backup = _backup([_day(10, 5, outH: null)], DateTime(2026, 10, 5, 9));
      final r = mergeBackup(current, backup);
      expect(_recordIn(r, 10, 5).checkOut, isNotNull);
      expect(r.keptNewer, 1);
      expect(r.changedDays, 0);
    });

    test('ngày giống hệt nhau không tính là thay', () {
      final r = mergeBackup(_appData([_day(9, 1)]), _backup([_day(9, 1)], DateTime(2026, 10, 5)));
      expect(r.changedDays, 0);
    });

    test('file sao lưu của bản cũ (cài đặt chưa có workerKind) vẫn đọc và khôi phục được', () {
      final oldSettings = AppSettings(
        wageTable: WageTable(rates: {DayType.weekday: const WageRate(normalPerHour: 30000, overtimePerHour: 45000)}),
      ).toJson()..remove('workerKind');
      final text = jsonEncode({
        'format': backupFormat,
        'version': 1,
        'exportedAt': DateTime(2026, 10, 5).toIso8601String(),
        'appVersion': '1.0.0',
        'data': {
          'settings': oldSettings,
          'records': {dateKey(DateTime(2026, 9, 1)): _day(9, 1).toJson()},
          'periodOverrides': {},
        },
      });
      final payload = BackupPayload.decode(text);
      final r = mergeBackup(_appData([]), payload);
      expect(r.added, 1);
      final restored = AppSettings.fromJson(r.merged['settings'] as Map<String, dynamic>);
      expect(restored.workerKind, WorkerKind.worker);
      expect(restored.baseSalary, 30000 * 8 * 26);
      expect(restored.incomeItems.first.id, payItemSalary);
    });

    test('ngày trống trong app (không có dữ liệu) coi như chưa có', () {
      final current = _appData([DayRecord(date: DateTime(2026, 9, 1))]);
      final r = mergeBackup(current, _backup([_day(9, 1)], DateTime(2026, 10, 5)));
      expect(r.added, 1);
    });

    test('cài đặt chỉ lấy theo file khi app chưa có dữ liệu; GPS khôi phục nhưng để tắt', () {
      final fromFile = AppSettings().copyWith(
        baseSalary: 7000000,
        gps: AppSettings().gps.copyWith(enabled: true, latitude: 21, longitude: 105),
      );
      final backup = _backup([_day(9, 1)], DateTime(2026, 10, 5), settings: fromFile);

      final fresh = mergeBackup(_appData([]), backup);
      expect(fresh.settingsRestored, isTrue);
      final restored = AppSettings.fromJson(fresh.merged['settings'] as Map<String, dynamic>);
      expect(restored.baseSalary, 7000000);
      expect(restored.gps.latitude, 21);
      expect(restored.gps.enabled, isFalse);

      final inUse = mergeBackup(_appData([_day(9, 2)]), backup);
      expect(inUse.settingsRestored, isFalse);
      expect(AppSettings.fromJson(inUse.merged['settings'] as Map<String, dynamic>).baseSalary, 0);
      expect(inUse.appHadData, isTrue);

      // Người dùng tự chọn lấy cả cài đặt (vd máy mới nhưng lỡ chấm 1 lần trước khi khôi phục).
      final chosen = mergeBackup(_appData([_day(9, 2)]), backup, restoreSettings: true);
      expect(chosen.settingsRestored, isTrue);
      expect(AppSettings.fromJson(chosen.merged['settings'] as Map<String, dynamic>).baseSalary, 7000000);
    });

    test('tiền nhập tay theo kỳ: kỳ cũ lấy theo file, kỳ đang chạy lúc xuất giữ bản trong app', () {
      const oldKey = '2026-08-01_2026-08-31';
      const currentKey = '2026-10-01_2026-10-31';
      final current = _appData([], overrides: {oldKey: 1, currentKey: 2});
      final backup = _backup(
        [],
        DateTime(2026, 10, 5),
        overrides: {oldKey: 10, currentKey: 20, '2026-09-01_2026-09-30': 30},
      );
      final o = mergeBackup(current, backup).merged['periodOverrides'] as Map;
      expect(o[oldKey], 10);
      expect(o[currentKey], 2);
      expect(o['2026-09-01_2026-09-30'], 30);
    });
  });

  group('Đọc bản sao lưu', () {
    test('đọc lại đúng bản vừa tạo', () {
      final b = _backup([_day(9, 1, note: 'Ca "đêm" & tăng ca')], DateTime(2026, 10, 5, 8, 30));
      final back = BackupPayload.decode(b.encode());
      expect(back.exportedAt, DateTime(2026, 10, 5, 8, 30));
      expect(back.records.length, 1);
    });

    test('không phải bản sao lưu, hỏng, hoặc từ bản app mới hơn thì báo lỗi dễ hiểu', () {
      expect(() => BackupPayload.decode('abc'), throwsFormatException);
      expect(() => BackupPayload.decode('{"x":1}'), throwsFormatException);
      expect(
        () => BackupPayload.decode('{"format":"$backupFormat","version":99,"exportedAt":"2026-10-05","data":{}}'),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('mới hơn'))),
      );
      expect(
        () => BackupPayload.decode(
          '{"format":"$backupFormat","version":1,"exportedAt":"2026-10-05","data":{"settings":{}}}',
        ),
        throwsFormatException,
      );
    });
  });
}
