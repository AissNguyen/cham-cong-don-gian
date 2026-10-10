/// Đặt báo thức đánh thức máy đúng lúc mỗi khung giờ kiểm tra GPS bắt đầu, rồi khởi động dịch vụ
/// chạy nền (có thông báo) để kiểm tra vị trí. Dịch vụ tự tắt khi khung đó xong việc hoặc hết khung;
/// khung kế tiếp báo thức bật lại.
library;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/data_file.dart';
import '../domain/gps_engine.dart';
import '../domain/models.dart';
import '../share/background_unlock.dart';
import '../share/share_state_file.dart';
import 'gps_task_handler.dart';

// Các khung cài sẵn (khung lặp mỗi giờ) đã là hơn 30 khung một ngày.
const _maxWindows = 64;
const _serviceId = 300;

// Mốc kiểm tra giờ về (phút 05 và 35): nhiều nhất 48 mốc một ngày.
const _maxMarks = 48;

/// Kiểm tra giờ về mà chưa xác định được thì thử lại cách nhau ngần này phút.
const _markRetryMinutes = 2;

int _windowAlarmId(int index) => 5000 + index;
int _markAlarmId(int index) => 5100 + index;

Future<void> _dailyAlarm(int id, Clock at) => AndroidAlarmManager.periodic(
  const Duration(days: 1),
  id,
  gpsAlarmCallback,
  startAt: _nextOccurrence(at),
  exact: true,
  wakeup: true,
  rescheduleOnReboot: true,
  allowWhileIdle: true,
);

DateTime _nextOccurrence(Clock time) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

Future<void> cancelAllGpsAlarms() async {
  for (var i = 0; i < _maxWindows; i++) {
    await AndroidAlarmManager.cancel(_windowAlarmId(i));
  }
  for (var i = 0; i < _maxMarks; i++) {
    await AndroidAlarmManager.cancel(_markAlarmId(i));
  }
}

/// Gọi lại mỗi khi cài đặt GPS đổi (bật/tắt, thêm/sửa/xóa khung giờ, đổi vị trí) để báo thức khớp
/// với cấu hình mới nhất.
Future<void> rescheduleGpsAlarms(GpsConfig gps) async {
  await cancelAllGpsAlarms();
  if (!gps.enabled || gps.latitude == null) return;

  // Đầu mỗi khung giờ: dò chấm vào. Phút 05 và 35: kiểm tra giờ về.
  final windows = gps.allWindows;
  for (var i = 0; i < windows.length && i < _maxWindows; i++) {
    await _dailyAlarm(_windowAlarmId(i), windows[i].from);
  }
  final marks = gpsMarkTimes(gps);
  for (var i = 0; i < marks.length && i < _maxMarks; i++) {
    await _dailyAlarm(_markAlarmId(i), marks[i]);
  }
}

/// Chạy trong tiến trình nền riêng khi báo thức reo — khởi động dịch vụ kiểm tra vị trí.
/// Phải là hàm cấp cao nhất.
@pragma('vm:entry-point')
Future<void> gpsAlarmCallback() async {
  final json = await readDataJson();
  final settings = settingsFromJson(json);
  if (!settings.effectiveGps.enabled) return;
  // Lúc này không có việc gì (ngày nghỉ, chưa tới mốc kiểm tra, giờ ra bấm tay...) thì không bật dịch vụ.
  final now = DateTime.now();
  final task = gpsTaskAt(settings: settings, todayRecord: recordFromJson(json, now), now: now);
  if (task == GpsTask.none) return;
  final repeatMinutes = task == GpsTask.arrival ? settings.gps.frequencyMinutes : _markRetryMinutes;
  // Hết ngày dùng thử mà chưa mở khóa: hỏi máy chủ xem đã có ai nhập mã của máy này chưa; chưa
  // thì không khởi động dịch vụ kiểm tra vị trí.
  if (!await autoFeatureAllowed() && !await tryUnlockInBackground()) return;

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
      eventAction: ForegroundTaskEventAction.repeat(repeatMinutes * 60 * 1000),
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
