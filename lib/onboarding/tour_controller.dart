/// Chuyến hướng dẫn làm thử trực tiếp trên màn chính (xem `TIEN-DO.md`, mục khung giới thiệu và
/// chuyến hướng dẫn). Người dùng thử thật nên app ghi dữ liệu thật vào hai ngày "tập" (hôm nay và
/// một ngày nghỉ giả định); trước khi bắt đầu lưu bản chụp hai ngày đó, khi xong thì trả lại đúng
/// như cũ.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import '../domain/models.dart';

/// Các bước của chuyến, theo đúng thứ tự.
enum TourStep {
  /// Lời mở, chỉ khi mở lại từ "Xem lại hướng dẫn làm thử".
  intro,
  manual,
  checkIn,
  checkOut,
  pickDayOff,
  chooseDayOff,
  lateButton,
  note,
  calendar,
  stats,
  topButtons,
  done,
}

extension TourStepInfo on TourStep {
  /// Bước hiện hộp thoại giữa màn hình (không khoét sáng chỗ nào).
  bool get isDialog => this == TourStep.intro || this == TourStep.manual || this == TourStep.done;

  /// Bước chờ người dùng tự thao tác (chỗ sáng bấm được); bước còn lại chỉ giải thích, bấm "Tiếp".
  bool get waitsForAction => switch (this) {
    TourStep.checkIn ||
    TourStep.checkOut ||
    TourStep.pickDayOff ||
    TourStep.chooseDayOff ||
    TourStep.lateButton ||
    TourStep.note => true,
    _ => false,
  };

  /// Số thứ tự hiện ở "Bước x/10" (bước 9, 10 là GPS, hiện ở Cài đặt); hộp thoại thì không có.
  int? get number => switch (this) {
    TourStep.checkIn => 1,
    TourStep.checkOut => 2,
    TourStep.pickDayOff => 3,
    TourStep.chooseDayOff => 4,
    TourStep.lateButton => 5,
    TourStep.note => 6,
    TourStep.calendar => 7,
    TourStep.stats => 8,
    _ => null,
  };
}

const tourSeenKey = 'tour_seen_v1';
const tourSnapshotKey = 'tour_snapshot_v1';

class TourController extends ChangeNotifier {
  TourStep? step;

  /// Ngày hôm nay lúc bắt đầu chuyến, và ngày "nghỉ giả định" (hôm qua; mùng 1 thì lấy ngày mai).
  DateTime? today;
  DateTime? practiceDate;

  /// "Xem lại hướng dẫn" vừa được bấm; màn chính nghe và bắt đầu chuyến.
  bool replayRequested = false;

  bool get active => step != null;

  /// Câu chỉ dẫn của bước 3a, phụ thuộc ngày tập.
  String get pickDayOffText {
    final d = practiceDate;
    if (d == null) return '';
    final isTomorrow = today != null && d.isAfter(today!);
    final when = isTomorrow ? 'ngày mai' : 'hôm qua';
    return 'Giả sử $when (ngày ${d.day}) bạn nghỉ. Hãy chọn ngày ${d.day}.';
  }

  static DateTime practiceDateFor(DateTime today) =>
      today.day == 1 ? DateTime(today.year, today.month, today.day + 1) : DateTime(today.year, today.month, today.day - 1);

  /// Khung giới thiệu tự hiện: máy chưa từng thấy và chưa có ngày chấm công nào. Chỉ hỏi, không
  /// đánh dấu; gọi [markSeen] khi hiện.
  Future<bool> shouldAutoStart(AppStore store) async {
    if (active || store.records.isNotEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(tourSeenKey) ?? false);
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tourSeenKey, true);
  }

  void requestReplay() {
    replayRequested = true;
    notifyListeners();
  }

  /// Bắt đầu chuyến: chụp và xóa trắng hai ngày tập. [replay] = mở từ "Xem lại hướng dẫn" nên có
  /// lời mở.
  Future<void> start(AppStore store, {required DateTime today, bool replay = false}) async {
    replayRequested = false;
    step = null;
    // Còn bản chụp của lần trước (bị tắt giữa chừng) thì trả lại trước, kẻo chụp nhầm dữ liệu tập.
    await restoreIfInterrupted(store);
    final day = dateOnly(today);
    final practice = practiceDateFor(day);
    final snapshot = <String, DayRecord?>{
      for (final d in [day, practice]) dateKey(d): store.records[dateKey(d)],
    };
    await _writeSnapshot(snapshot);
    this.today = day;
    practiceDate = practice;
    for (final d in [day, practice]) {
      await store.restoreRecord(d, null);
    }
    step = replay ? TourStep.intro : TourStep.manual;
    notifyListeners();
  }

  /// Kết thúc chuyến (xong, "Bỏ qua" hay sang Cài đặt): trả hai ngày tập về đúng bản chụp.
  Future<void> end(AppStore store) async {
    step = null;
    notifyListeners();
    await restoreIfInterrupted(store);
  }

  /// Còn bản chụp mà chuyến không chạy (app bị tắt giữa chừng) thì trả dữ liệu về.
  Future<void> restoreIfInterrupted(AppStore store) async {
    if (active) return; // đang giữa chuyến thì chưa trả
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(tourSnapshotKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final date = DateTime.tryParse(entry.key);
        if (date == null) continue;
        final value = entry.value;
        await store.restoreRecord(date, value == null ? null : DayRecord.fromJson(value as Map<String, dynamic>));
      }
    } catch (_) {
      // Bản chụp hỏng thì thôi, không để chặn app; bỏ bản chụp.
    }
    await prefs.remove(tourSnapshotKey);
  }

  Future<void> _writeSnapshot(Map<String, DayRecord?> snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tourSnapshotKey, jsonEncode({for (final e in snapshot.entries) e.key: e.value?.toJson()}));
  }

  /// Sang bước sau với các bước chỉ giải thích (nút "Tiếp").
  void next() {
    final s = step;
    if (s == null) return;
    final target = switch (s) {
      TourStep.intro => TourStep.manual,
      TourStep.manual => TourStep.checkIn,
      TourStep.calendar => TourStep.stats,
      // Nút âm lịch đã nói ở bước thống kê nên bỏ qua bước riêng của nó.
      TourStep.stats => TourStep.done,
      TourStep.topButtons => TourStep.done,
      _ => null,
    };
    if (target == null) return;
    step = target;
    notifyListeners();
  }

  /// Gọi sau mỗi lần màn chính dựng lại: tự chuyển bước theo thao tác người dùng vừa làm. Trả về
  /// ngày màn chính nên chọn (nếu cần đổi lựa chọn), hoặc null.
  DateTime? update(AppStore store, DateTime selectedDate) {
    final day = today;
    final practice = practiceDate;
    if (step == null || day == null || practice == null) return null;
    final before = step;
    DateTime? select;
    var changed = true;
    while (changed) {
      changed = false;
      switch (step!) {
        case TourStep.checkIn:
          if (store.recordFor(day).checkIn != null) {
            step = TourStep.checkOut;
            changed = true;
          }
        case TourStep.checkOut:
          if (store.recordFor(day).checkOut != null) {
            step = TourStep.pickDayOff;
            changed = true;
          }
        case TourStep.pickDayOff:
          if (selectedDate == practice) {
            step = TourStep.chooseDayOff;
            changed = true;
          }
        case TourStep.chooseDayOff:
          if (store.recordFor(practice).isDayOff) {
            step = TourStep.lateButton;
            select = day;
            selectedDate = day;
            changed = true;
          } else if (selectedDate != practice) {
            // Nút Ngày nghỉ tác động lên ngày đang chọn: chọn nhầm ngày khác thì quay lại chọn ngày tập.
            step = TourStep.pickDayOff;
            changed = true;
          }
        case TourStep.lateButton:
          if (store.recordFor(day).isLate) {
            step = TourStep.note;
            changed = true;
          }
        case TourStep.note:
          final r = store.recordFor(day);
          if ((r.note != null && r.note!.isNotEmpty) || r.tags.isNotEmpty) {
            step = TourStep.calendar;
            changed = true;
          }
        default:
          break;
      }
    }
    if (step != before) notifyListeners();
    return select;
  }
}

final tourController = TourController();
