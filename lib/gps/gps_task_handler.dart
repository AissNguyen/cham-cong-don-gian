/// Dịch vụ chạy nền có thông báo: mỗi lần "tick" kiểm tra vị trí hiện tại, tự chấm công nếu đúng
/// điều kiện, rồi tự dừng khi hết khung giờ của hôm nay.
library;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../data/data_file.dart';
import '../domain/gps_engine.dart';
import '../widget/widget_sync.dart';
import 'gps_notify.dart';

/// Phải là hàm cấp cao nhất (top-level) để dịch vụ nền gọi lại được.
@pragma('vm:entry-point')
void gpsStartCallback() {
  FlutterForegroundTask.setTaskHandler(GpsTaskHandler());
}

class GpsTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) => _tick();

  @override
  void onRepeatEvent(DateTime timestamp) => _tick();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  Future<void> _tick() async {
    try {
      final json = await readDataJson();
      final settings = settingsFromJson(json);
      var now = DateTime.now();
      final record = recordFromJson(json, now);

      if (!hasWindowLeftToday(settings: settings, todayRecord: record, now: now)) {
        await FlutterForegroundTask.stopService();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)),
      );
      now = DateTime.now();
      final action = decideGpsAction(
        settings: settings,
        todayRecord: record,
        now: now,
        currentLat: position.latitude,
        currentLng: position.longitude,
      );

      if (action == GpsAction.none) return;

      final updated = action == GpsAction.checkIn
          ? record.copyWith(checkIn: now, isDayOff: false)
          : record.copyWith(checkOut: now);
      await writeDataJson(putRecordJson(json, updated));
      await refreshWidgetDisplay();
      await showGpsPunchNotification(
        isCheckIn: action == GpsAction.checkIn,
        time: now,
        soundEnabled: settings.gps.soundEnabled,
      );

      if (!hasWindowLeftToday(settings: settings, todayRecord: updated, now: now)) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Một lượt kiểm tra lỗi (vd tạm mất tín hiệu GPS) thì bỏ qua, lượt sau (vài phút nữa) thử lại.
    }
  }
}
