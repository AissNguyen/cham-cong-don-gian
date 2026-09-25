/// Đặt báo thức đánh thức máy đúng lúc mỗi khung giờ kiểm tra GPS bắt đầu, rồi khởi động dịch vụ
/// chạy nền (có thông báo) để kiểm tra vị trí đều đặn cho tới khi hết khung giờ hôm đó.
library;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/data_file.dart';
import '../domain/models.dart';
import 'gps_task_handler.dart';

const _maxWindowsPerDirection = 10;
const _serviceId = 300;

int _checkInAlarmId(int index) => 5000 + index;
int _checkOutAlarmId(int index) => 5100 + index;

DateTime _nextOccurrence(Clock time) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

Future<void> cancelAllGpsAlarms() async {
  for (var i = 0; i < _maxWindowsPerDirection; i++) {
    await AndroidAlarmManager.cancel(_checkInAlarmId(i));
    await AndroidAlarmManager.cancel(_checkOutAlarmId(i));
  }
}

/// Gọi lại mỗi khi cài đặt GPS đổi (bật/tắt, thêm/sửa/xóa khung giờ, đổi vị trí) để báo thức khớp
/// với cấu hình mới nhất.
Future<void> rescheduleGpsAlarms(GpsConfig gps) async {
  await cancelAllGpsAlarms();
  if (!gps.enabled || gps.latitude == null) return;

  for (var i = 0; i < gps.checkInWindows.length && i < _maxWindowsPerDirection; i++) {
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      _checkInAlarmId(i),
      gpsAlarmCallback,
      startAt: _nextOccurrence(gps.checkInWindows[i].from),
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }
  for (var i = 0; i < gps.checkOutWindows.length && i < _maxWindowsPerDirection; i++) {
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      _checkOutAlarmId(i),
      gpsAlarmCallback,
      startAt: _nextOccurrence(gps.checkOutWindows[i].from),
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      allowWhileIdle: true,
    );
  }
}

/// Chạy trong tiến trình nền riêng khi báo thức reo — khởi động dịch vụ kiểm tra vị trí.
/// Phải là hàm cấp cao nhất.
@pragma('vm:entry-point')
Future<void> gpsAlarmCallback() async {
  final json = await readDataJson();
  final settings = settingsFromJson(json);
  if (!settings.gps.enabled) return;

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'gps_checkin_service',
      channelName: 'Chấm công GPS',
      channelDescription: 'Hiện khi app đang kiểm tra vị trí để tự chấm công.',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(settings.gps.frequencyMinutes * 60 * 1000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  if (await FlutterForegroundTask.isRunningService) return;

  await FlutterForegroundTask.startService(
    serviceId: _serviceId,
    notificationTitle: 'Chấm công GPS',
    notificationText: 'Đang kiểm tra vị trí chấm công...',
    callback: gpsStartCallback,
  );
}
