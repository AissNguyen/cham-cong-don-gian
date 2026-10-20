/// Dịch vụ chạy nền có thông báo: báo thức bật nó đúng mốc dò (phút 00/15/30/45), nó dò vị trí, thử lại
/// tối đa 2 lần cách 3 phút nếu không dò ra, ghi kết quả rồi tắt ngay. Cách chấm ghi ở đầu
/// `domain/gps_engine.dart`; lịch báo thức ở `gps_scheduler.dart`.
library;

import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wifi_scan/wifi_scan.dart' show WiFiAccessPoint;

import '../analytics/analytics_service.dart' show eventGpsUsed;
import '../data/data_file.dart';
import '../domain/gps_engine.dart';
import '../domain/models.dart';
import '../share/share_state_file.dart';
import '../widget/widget_sync.dart';
import 'gps_log.dart';
import 'gps_notify.dart';
import 'gps_wifi.dart';

/// Phải là hàm cấp cao nhất (top-level) để dịch vụ nền gọi lại được.
@pragma('vm:entry-point')
void gpsStartCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTaskHandler());
}

class GpsTaskHandler extends TaskHandler {
  /// Mốc đang dò (cố định suốt các lần thử lại) và số lần đã dò ở mốc đó.
  GpsPlan? _plan;
  int _attempts = 0;

  String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Ghi mốc vào danh sách đã làm của ngày đó, để báo thức dự phòng không dò lại.
  DayRecord _withDone(DayRecord r, DateTime mark) =>
      r.copyWith(gpsDoneMarks: [mark, ...r.gpsDoneMarks.where((m) => m != mark)].take(12).toList());

  Future<void> _markDone(GpsPlan p) async {
    final json = await readDataJson();
    await writeDataJson(putRecordJson(json, _withDone(recordFromJson(json, p.day), p.mark)));
  }
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _tick();

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _stop() => FlutterForegroundTask.stopService();

  /// Lấy tọa độ GPS; null nếu không dò ra (mất sóng, tắt định vị, lỗi khác).
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
      var json = await readDataJson();
      final settings = settingsFromJson(json);
      final started = DateTime.now();
      // Mỗi lượt xem lại các mốc còn dở: ghi nhật ký mốc bị bỏ (báo thức trễ quá hạn hoặc không reo, hoặc
      // mốc đang thử lại mà đã quá hạn trễ), rồi lấy mốc mới nhất còn trong giới hạn trễ.
      final plans = gpsPendingPlans(
        settings: settings,
        today: recordFromJson(json, started),
        yesterday: recordFromJson(json, started.subtract(const Duration(days: 1))),
        now: started,
      );
      for (final p in plans.where((p) => p.tooLate)) {
        final retrying = p.mark == _plan?.mark;
        if (!retrying) _attempts = 1;
        await _log(
          p,
          started,
          '',
          '',
          retrying
              ? 'Bỏ mốc: thử lại chưa xong mà đã quá hạn trễ (${p.lateMinutes} phút)'
              : 'Bỏ mốc: tới ${_hm(started)} máy mới chạy, trễ ${p.lateMinutes} phút',
        );
        await _markDone(p);
      }
      final live = plans.where((p) => !p.tooLate).toList();
      if (live.isEmpty) {
        await _stop();
        return;
      }
      json = await readDataJson();
      final plan = live.last;
      if (_plan?.mark != plan.mark) {
        // Sang mốc mới (kể cả khi báo thức của mốc này bị bỏ qua vì dịch vụ đang chạy): đếm lại từ đầu.
        _plan = plan;
        _attempts = 0;
        if (!await autoFeatureAllowed()) {
          _attempts = 1;
          await _log(plan, started, '', '', 'Bỏ qua: chấm công tự động đang bị khóa (hết dùng thử)');
          await _markDone(plan);
          await _stop();
          return;
        }
      }
      _attempts++;
      final today = recordFromJson(json, started);
      final yesterday = recordFromJson(json, started.subtract(const Duration(days: 1)));
      final original = dateOnly(today.date) == plan.day ? today : yesterday;
      var record = original;

      final gps = settings.gps;
      final position = await _fix();
      final now = DateTime.now();
      final found = await scanWifi();
      GpsSight sight;
      String gpsText;
      var wifiText = '';
      if (position != null) {
        sight = classifyGpsFix(gps, position.latitude, position.longitude);
        final dist = distanceToWork(gps, position.latitude, position.longitude).round();
        final where = switch (sight) {
          GpsSight.atCheckOutPlace => 'ở địa điểm "chấm về"',
          GpsSight.near => dist <= gps.departRadiusMeters ? 'trong phạm vi' : 'ở địa điểm "không chấm về"',
          _ => 'ngoài phạm vi',
        };
        gpsText = 'dò ra vị trí, cách $dist m, $where (sai số ${position.accuracy.round()} m)';
        record = record.copyWith(gpsLastFixAt: now);
        await noteWifi(found, mark: plan.mark, learnAtWork: sight == GpsSight.near);
      } else {
        gpsText = 'không dò ra vị trí';
        final reading = readWifi(found, await readKnownWifi());
        sight = reading.sight;
        wifiText = reading.text;
        await noteWifi(found, mark: plan.mark);
      }

      // Không biết gì: thử lại (lượt tick sau, cách 3 phút), tối đa 2 lần.
      if (sight == GpsSight.unknown && _attempts <= gpsRetries) {
        await _log(plan, now, gpsText, wifiText, 'Thử lại sau $gpsRetryMinutes phút', seen: _seenText(found));
        return;
      }

      final decision = switch (plan.task) {
        GpsTask.arrivalCheck => const GpsDecision(GpsAction.none),
        GpsTask.arrival => decideArrival(
          mark: plan.mark,
          sight: sight,
          previousCheckGotFix: previousCheckGotFix(record, plan.mark),
        ),
        GpsTask.departure => decideDeparture(mark: plan.mark, sight: sight),
        GpsTask.reopen => decideReopen(sight),
      };
      final before = record;
      final updated = _withDone(applyGpsDecision(record, decision), plan.mark);
      if (updated.toJson().toString() != original.toJson().toString()) {
        // Đọc lại file ngay trước khi ghi để không đè mất thay đổi người dùng vừa làm trong lúc dò.
        final fresh = await readDataJson();
        final punched = decision.action == GpsAction.checkIn || decision.action == GpsAction.checkOut;
        final next = putRecordJson(fresh, updated);
        await writeDataJson(punched ? markPendingAnalyticsEvent(next, eventGpsUsed) : next);
      }

      var result = describeDecision(plan.task, decision, sight);
      if (plan.task == GpsTask.arrival && decision.action == GpsAction.checkIn && sight == GpsSight.unknown) {
        result += ' (lần dò trước đã dò ra vị trí)';
      }
      await _log(plan, now, gpsText, wifiText, result, seen: _seenText(found));

      switch (decision.action) {
        case GpsAction.checkIn:
        case GpsAction.checkOut:
          await recordAutoUse();
          await recordUsage(usageGpsUses);
          await refreshWidgetDisplay();
          await showGpsPunchNotification(
            isCheckIn: decision.action == GpsAction.checkIn,
            time: decision.time!,
            soundEnabled: gps.soundEnabled,
          );
        case GpsAction.reopen:
          await refreshWidgetDisplay();
          await showGpsReopenNotification(oldCheckOut: before.checkOut!, soundEnabled: gps.soundEnabled);
        case GpsAction.none:
          break;
      }
      await _stop();
    } catch (e) {
      // Một lượt lỗi thì bỏ qua (ghi nhật ký để biết); mốc sau dò lại.
      final plan = _plan;
      if (plan != null) {
        try {
          await _log(plan, DateTime.now(), '', '', 'Lỗi khi dò: $e');
        } catch (_) {}
      }
      await _stop();
    } finally {
      _busy = false;
    }
  }

  /// Các mạng quét được, sóng mạnh trước: "Xuong (-55), NhaTro (-80) · 6 mạng".
  String _seenText(List<WiFiAccessPoint>? found) {
    if (found == null) return 'không quét được Wi-Fi${lastWifiScanNote.isEmpty ? '' : ' ($lastWifiScanNote)'}';
    if (found.isEmpty) return 'không thấy mạng nào';
    final best = <String, int>{};
    for (final ap in found) {
      final name = ap.ssid.isEmpty ? '(mạng ẩn)' : ap.ssid;
      if (!best.containsKey(name) || ap.level > best[name]!) best[name] = ap.level;
    }
    final sorted = best.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return '${sorted.map((e) => '${e.key} (${e.value})').join(', ')} · ${found.length} thiết bị phát';
  }

  Future<void> _log(GpsPlan plan, DateTime now, String gps, String wifi, String result, {String seen = ''}) =>
      addGpsLog(
        GpsLogEntry(
          mark: plan.mark,
          at: now,
          task: plan.label,
          gps: gps,
          wifi: wifi,
          result: result,
          attempt: _attempts == 0 ? 1 : _attempts,
          wifiSeen: seen,
        ),
      );
}
