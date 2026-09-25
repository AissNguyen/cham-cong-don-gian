/// Lưu trữ dữ liệu app: một file JSON trong thư mục dữ liệu app, không cần mạng.
/// Cùng file này còn được widget màn hình chính và dịch vụ chấm công GPS đọc/ghi trực tiếp
/// (xem `data_file.dart`) khi app không chạy, nên mỗi lần lưu đều đọc lại từ đĩa trước để không
/// ghi đè mất những gì các tiến trình đó vừa ghi.
library;

import 'package:flutter/foundation.dart';

import '../domain/default_holidays.dart';
import '../domain/models.dart';
import '../widget/widget_sync.dart';
import 'data_file.dart';

class AppStore extends ChangeNotifier {
  AppSettings settings = AppSettings();
  final Map<String, DayRecord> _records = {};

  /// Số tiền người dùng nhập tay để ghi đè cả kỳ, khóa là [PayPeriod.key].
  final Map<String, double> periodOverrides = {};

  /// Khoản "nhập tay mỗi kỳ", khóa là "itemId|periodKey".
  final Map<String, double> manualIncomeEntries = {};

  bool loaded = false;

  Map<String, DayRecord> get records => _records;

  DayRecord recordFor(DateTime date) {
    final key = dateKey(dateOnly(date));
    return _records[key] ?? DayRecord(date: dateOnly(date));
  }

  Future<void> load() async {
    final isFirstRun = !await dataFileExists();
    final json = await readDataJson();
    _applyJson(json);
    if (isFirstRun) {
      final now = DateTime.now();
      settings = settings.copyWith(holidays: defaultVietnameseHolidays([now.year, now.year + 1, now.year + 2]));
    }
    loaded = true;
    notifyListeners();
    if (isFirstRun) await _save();
  }

  void _applyJson(Map<String, dynamic> json) {
    settings = settingsFromJson(json);
    _records.clear();
    final recs = json['records'] as Map<String, dynamic>? ?? {};
    recs.forEach((k, v) => _records[k] = DayRecord.fromJson(v as Map<String, dynamic>));
    periodOverrides.clear();
    final overrides = json['periodOverrides'] as Map<String, dynamic>? ?? {};
    overrides.forEach((k, v) => periodOverrides[k] = (v as num).toDouble());
    manualIncomeEntries.clear();
    final manual = json['manualIncomeEntries'] as Map<String, dynamic>? ?? {};
    manual.forEach((k, v) => manualIncomeEntries[k] = (v as num).toDouble());
  }

  /// Đọc lại từ đĩa — gọi khi app quay lại foreground, để thấy các thay đổi widget/GPS vừa ghi.
  Future<void> reloadFromDisk() async {
    final json = await readDataJson();
    _applyJson(json);
    notifyListeners();
  }

  Future<void> _save() async {
    final json = {
      'settings': settings.toJson(),
      'records': _records.map((k, v) => MapEntry(k, v.toJson())),
      'periodOverrides': periodOverrides,
      'manualIncomeEntries': manualIncomeEntries,
    };
    await writeDataJson(json);
  }

  Future<void> _putRecord(DayRecord record) async {
    _records[dateKey(dateOnly(record.date))] = record;
    notifyListeners();
    await _save();
    if (dateOnly(record.date) == dateOnly(DateTime.now())) {
      await refreshWidgetDisplay();
    }
  }

  Future<void> punchIn(DateTime date, DateTime time) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(checkIn: time, isDayOff: false));
  }

  Future<void> punchOut(DateTime date, DateTime time) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(checkOut: time));
  }

  Future<void> clearCheckIn(DateTime date) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(clearCheckIn: true, clearCheckOut: true));
  }

  Future<void> clearCheckOut(DateTime date) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(clearCheckOut: true));
  }

  Future<void> setDayOff(DateTime date, bool value) async {
    final r = recordFor(date);
    await _putRecord(
      r.copyWith(isDayOff: value, clearCheckIn: value, clearCheckOut: value, isLate: value ? false : r.isLate),
    );
  }

  Future<void> setLate(DateTime date, bool value) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(isLate: value));
  }

  Future<void> setNote(DateTime date, {String? note, List<String>? tags}) async {
    final r = recordFor(date);
    await _putRecord(r.copyWith(note: note, tags: tags));
  }

  Future<void> updateSettings(AppSettings Function(AppSettings) update) async {
    settings = update(settings);
    notifyListeners();
    await _save();
  }

  Future<void> replaceSettings(AppSettings newSettings) async {
    settings = newSettings;
    notifyListeners();
    await _save();
  }

  Future<void> setPeriodOverride(String periodKey, double? amount) async {
    if (amount == null) {
      periodOverrides.remove(periodKey);
    } else {
      periodOverrides[periodKey] = amount;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setManualIncomeEntry(String itemId, String periodKey, double amount) async {
    manualIncomeEntries['$itemId|$periodKey'] = amount;
    notifyListeners();
    await _save();
  }

  double? manualIncomeEntry(String itemId, String periodKey) => manualIncomeEntries['$itemId|$periodKey'];
}
