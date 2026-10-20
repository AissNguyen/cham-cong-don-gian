/// Đặt báo thức đánh thức máy đúng từng mốc dò GPS (phút 00/15/30/45 lúc chờ chấm vào, phút 15/45
/// sau khi đã vào), rồi khởi động dịch vụ chạy nền (có thông báo) để dò vị trí. Dịch vụ dò xong mốc đó
/// thì tự tắt; mốc kế tiếp báo thức bật lại.
library;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/data_file.dart';
import '../domain/gps_engine.dart';
import '../domain/models.dart';
import '../share/background_unlock.dart';
import '../share/share_state_file.dart';
import 'gps_log.dart';
import 'gps_task_handler.dart';

const _serviceId = 300;

/// Mỗi mốc dò có một báo thức chính đúng giờ và một báo thức dự phòng ngần này phút sau (nếu báo thức
/// chính bị máy hoãn hay bỏ thì báo thức dự phòng dò thay; mốc đã dò xong thì nó bỏ qua).
const _backupAfterMinutes = 4;

// Tối đa 200 báo thức (mỗi mốc 2 cái).
const _maxAlarms = 200;
int _alarmId(int index) => 5200 + index;

// Các dãy số báo thức của những bản trước (khung giờ 5000+, mốc 05/35 5100+), hủy khi đặt lại.
final _oldAlarmIds = [for (var i = 5000; i < 5200; i++) i];

/// Báo thức loại "đồng hồ báo thức": máy không được hoãn để tiết kiệm pin (đổi lại, nhiều máy hiện
/// biểu tượng đồng hồ báo thức trên thanh trạng thái). Mỗi báo thức chỉ reo một lần; khi reo, nó tự
/// đặt lại cho hôm sau (xem [gpsAlarmCallback]).
Future<void> _alarmAt(int id, Clock at) => AndroidAlarmManager.oneShotAt(
  _nextOccurrence(at),
  id,
  gpsAlarmCallback,
  alarmClock: true,
  exact: true,
  wakeup: true,
  allowWhileIdle: true,
  rescheduleOnReboot: true,
  params: {'h': at.hour, 'm': at.minute},
);

DateTime _nextOccurrence(Clock time) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

/// Giờ của tất cả báo thức: mỗi mốc dò một báo thức chính và một báo thức dự phòng.
List<Clock> _alarmTimes(GpsConfig gps) {
  final set = <int>{};
  for (final c in gpsProbeTimes(gps)) {
    set.add(c.totalMinutes);
    set.add((c.totalMinutes + _backupAfterMinutes) % (24 * 60));
  }
  final list = set.toList()..sort();
  return [for (final t in list) Clock(t ~/ 60, t % 60)];
}

Future<void> cancelAllGpsAlarms() async {
  for (final id in _oldAlarmIds) {
    await AndroidAlarmManager.cancel(id);
  }
  for (var i = 0; i < _maxAlarms; i++) {
    await AndroidAlarmManager.cancel(_alarmId(i));
  }
}

/// Gọi lại mỗi khi cài đặt GPS đổi (bật/tắt, đổi giờ, đổi vị trí) để báo thức khớp với cấu hình mới
/// nhất. App cũng gọi mỗi lần mở.
Future<void> rescheduleGpsAlarms(GpsConfig gps) async {
  await cancelAllGpsAlarms();
  if (!gps.enabled || gps.latitude == null) return;
  final times = _alarmTimes(gps);
  for (var i = 0; i < times.length && i < _maxAlarms; i++) {
    await _alarmAt(_alarmId(i), times[i]);
  }
}

/// Chạy trong tiến trình nền riêng khi báo thức reo: đặt lại chính báo thức này cho hôm sau, rồi
/// khởi động dịch vụ dò vị trí nếu có mốc cần dò (hoặc mốc bị bỏ cần ghi nhật ký). Phải là hàm cấp cao
/// nhất.
@pragma('vm:entry-point')
Future<void> gpsAlarmCallback(int id, Map<String, dynamic> params) async {
  final h = params['h'];
  final m = params['m'];
  if (h is int && m is int) await _alarmAt(id, Clock(h, m));

  final json = await readDataJson();
  final settings = settingsFromJson(json);
  if (!settings.effectiveGps.enabled) return;
  final now = DateTime.now();
  final plans = gpsPendingPlans(
    settings: settings,
    today: recordFromJson(json, now),
    yesterday: recordFromJson(json, now.subtract(const Duration(days: 1))),
    now: now,
  );
  if (plans.isEmpty) return;
  // Những lần báo thức reo mà không bật được việc dò thì ghi vào nhật ký GPS, để biết vì sao một mốc
  // không có lần dò nào (trước đây các trường hợp này dừng im lặng).
  final plan = plans.last;
  Future<void> note(String result) => addGpsLog(
    GpsLogEntry(mark: plan.mark, at: DateTime.now(), task: plan.label, gps: '', wifi: '', result: result),
  );
  // Hết ngày dùng thử mà chưa mở khóa: hỏi máy chủ xem đã có ai nhập mã của máy này chưa; chưa
  // thì không khởi động dịch vụ dò vị trí.
  if (!await autoFeatureAllowed() && !await tryUnlockInBackground()) {
    await note('Báo thức reo nhưng chấm công tự động đang bị khóa (hết dùng thử), không dò');
    return;
  }

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
      // Không dò ra vị trí thì thử lại sau 3 phút (lượt "tick" kế tiếp).
      eventAction: ForegroundTaskEventAction.repeat(gpsRetryMinutes * 60 * 1000),
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  if (await FlutterForegroundTask.isRunningService) {
    // Dịch vụ lần trước còn chạy (thường là đang chờ thử lại 3 phút): nó tự lo mốc này.
    await note('Báo thức reo khi lần dò trước còn đang chạy, không bật thêm');
    return;
  }

  final result = await FlutterForegroundTask.startService(
    serviceId: _serviceId,
    notificationTitle: 'Chấm công GPS',
    notificationText: 'Đang kiểm tra vị trí chấm công...',
    callback: gpsStartCallback,
  );
  if (result is ServiceRequestFailure) {
    await note('Báo thức reo nhưng máy không cho bật việc dò (${result.error}). Xem quyền chạy nền của app');
  }
}
