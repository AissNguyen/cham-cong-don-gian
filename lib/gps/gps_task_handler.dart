/// Dịch vụ chạy nền có thông báo: chỉ sống trong lúc có việc (khung giờ chấm vào, hoặc mốc kiểm tra
/// giờ về phút 05/35). Mỗi lần "tick" xác định vị trí, tự chấm công nếu đúng điều kiện, xong việc thì
/// tắt ngay; báo thức của khung / mốc kế tiếp bật lại (xem `gps_scheduler.dart`). Cách chấm ghi ở đầu
/// `domain/gps_engine.dart`.
library;

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../analytics/analytics_service.dart' show eventGpsUsed;
import '../data/data_file.dart';
import '../domain/gps_engine.dart';
import '../domain/models.dart';
import '../share/share_state_file.dart';
import '../widget/widget_sync.dart';
import 'gps_notify.dart';
import 'gps_wifi.dart';

/// Phải là hàm cấp cao nhất (top-level) để dịch vụ nền gọi lại được.
@pragma('vm:entry-point')
void gpsStartCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTaskHandler());
}

/// Sau một lần xong việc trong khung chấm vào dài, nghỉ ngần này rồi mới dò lại trong cùng khung.
const _restInLongWindow = Duration(minutes: 30);

class GpsTaskHandler extends TaskHandler {
  /// Số lần liên tiếp chưa xác định được vị trí trong việc đang làm.
  int _failures = 0;

  /// Đang nghỉ giữa một khung chấm vào dài: trước giờ này không lấy vị trí.
  DateTime? _restUntil;
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _tick();

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _stop() => FlutterForegroundTask.stopService();

  /// Lấy tọa độ GPS; null nếu không lấy được (mất sóng, tắt định vị, lỗi khác).
  Future<Position?> _fix() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final json = await readDataJson();
      final settings = settingsFromJson(json);
      final started = DateTime.now();
      final record = recordFromJson(json, started);

      final task = gpsTaskAt(settings: settings, todayRecord: record, now: started);
      if (task == GpsTask.none || !await autoFeatureAllowed()) {
        await _stop();
        return;
      }
      if (_restUntil != null && started.isBefore(_restUntil!)) return;

      final position = await _fix();
      final now = DateTime.now();
      switch (task) {
        case GpsTask.none:
          break;
        case GpsTask.arrival:
          await _arrival(json, settings, record, position, now);
        case GpsTask.departure:
          await _departure(json, settings, record, position, now);
        case GpsTask.reopen:
          await _reopen(json, settings, record, position, now);
      }
    } catch (_) {
      // Một lượt kiểm tra lỗi thì bỏ qua, lượt sau (vài phút nữa) thử lại.
    } finally {
      _busy = false;
    }
  }

  Future<void> _arrival(
    Map<String, dynamic> json,
    AppSettings settings,
    DayRecord record,
    Position? position,
    DateTime now,
  ) async {
    if (position == null) {
      // Không có sóng: thử lại vài lần rồi bỏ qua khung này.
      if (++_failures > gpsUnknownRetries) await _restOrStop(settings, now);
      return;
    }
    _failures = 0;
    if (isInsideCheckInRadius(settings.gps, position.latitude, position.longitude)) {
      final decision = GpsDecision(GpsAction.checkIn, time: roundToHalfHour(now));
      await _savePunch(json, settings, applyGpsDecision(record, decision, now), isCheckIn: true, time: decision.time!);
      await learnWifiHere();
      await _stop();
      return;
    }
    if (!arrivalShouldPollAgain(now)) await _restOrStop(settings, now);
  }

  Future<void> _departure(
    Map<String, dynamic> json,
    AppSettings settings,
    DayRecord record,
    Position? position,
    DateTime now,
  ) async {
    final sight = await _sight(settings, position);
    // Không GPS, không Wi-Fi quen: thử lại vài lần (cách nhau theo tần suất đã cài) rồi mới báo đỏ.
    if (sight == GpsSight.unknown && ++_failures <= gpsUnknownRetries) return;

    final decision = decideDeparture(todayRecord: record, now: now, sight: sight);
    final updated = applyGpsDecision(record, decision, now);
    switch (decision.action) {
      case GpsAction.checkOut:
        await _savePunch(json, settings, updated, isCheckIn: false, time: decision.time!);
      case GpsAction.flagUnknown:
        await writeDataJson(putRecordJson(json, updated));
        // Chỉ báo một lần khi ngày chuyển sang đỏ, không nhắc lại mỗi nửa tiếng.
        if (!record.gpsLeftUnknown) {
          await refreshWidgetDisplay();
          await showGpsUnknownNotification(soundEnabled: settings.gps.soundEnabled);
        }
      default:
        await writeDataJson(putRecordJson(json, updated));
        if (position != null) await learnWifiHere();
    }
    await _stop();
  }

  Future<void> _reopen(
    Map<String, dynamic> json,
    AppSettings settings,
    DayRecord record,
    Position? position,
    DateTime now,
  ) async {
    final decision = decideReopen(await _sight(settings, position));
    if (decision.action == GpsAction.reopen) {
      final oldCheckOut = record.checkOut!;
      await writeDataJson(putRecordJson(json, applyGpsDecision(record, decision, now)));
      await refreshWidgetDisplay();
      await showGpsReopenNotification(oldCheckOut: oldCheckOut, soundEnabled: settings.gps.soundEnabled);
    }
    await _stop();
  }

  /// Có tọa độ thì phân loại theo tọa độ; không có thì xem có thấy Wi-Fi quen của chỗ làm không.
  Future<GpsSight> _sight(AppSettings settings, Position? position) async {
    if (position != null) return classifyGpsFix(settings.gps, position.latitude, position.longitude);
    return await seesKnownWifi() ? GpsSight.near : GpsSight.unknown;
  }

  Future<void> _savePunch(
    Map<String, dynamic> json,
    AppSettings settings,
    DayRecord updated, {
    required bool isCheckIn,
    required DateTime time,
  }) async {
    await writeDataJson(markPendingAnalyticsEvent(putRecordJson(json, updated), eventGpsUsed));
    await recordAutoUse();
    await recordUsage(usageGpsUses);
    await refreshWidgetDisplay();
    await showGpsPunchNotification(isCheckIn: isCheckIn, time: time, soundEnabled: settings.gps.soundEnabled);
  }

  /// Khung chấm vào này xong lượt: tắt dịch vụ chờ báo thức của khung sau. Riêng khung còn mở lâu hơn
  /// [_restInLongWindow] thì giữ dịch vụ, nghỉ ngần đó rồi dò lại trong cùng khung.
  Future<void> _restOrStop(AppSettings settings, DateTime now) async {
    _failures = 0;
    final until = now.add(_restInLongWindow);
    final a = Clock(now.hour, now.minute);
    final b = Clock(until.hour, until.minute);
    final sameWindow = settings.gps.allWindows.any((w) => a >= w.from && a <= w.to && b <= w.to);
    if (dateOnly(until) == dateOnly(now) && sameWindow) {
      _restUntil = until;
    } else {
      await _stop();
    }
  }
}
