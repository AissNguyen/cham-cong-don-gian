/// Thông báo một lần xác nhận "đã tự động chấm" — tách khỏi thông báo dịch vụ nền vì thông báo
/// dịch vụ biến mất ngay khi dừng, còn thông báo này cần ở lại để người dùng thấy sau đó.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../ui/format.dart';

final _plugin = FlutterLocalNotificationsPlugin();
var _initialized = false;

Future<void> _ensureInitialized() async {
  if (_initialized) return;
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _plugin.initialize(const InitializationSettings(android: androidInit));
  _initialized = true;
}

Future<void> showGpsPunchNotification({
  required bool isCheckIn,
  required DateTime time,
  bool soundEnabled = true,
}) async {
  await _ensureInitialized();
  final details = AndroidNotificationDetails(
    'gps_punch_result',
    'Kết quả chấm công GPS',
    channelDescription: 'Báo khi máy tự chấm công theo GPS',
    importance: Importance.high,
    priority: Priority.high,
    playSound: soundEnabled,
    enableVibration: soundEnabled,
  );
  await _plugin.show(
    isCheckIn ? 1001 : 1002,
    'Đã tự động chấm công',
    '${isCheckIn ? 'Chấm vào' : 'Chấm ra'} lúc ${fmtTime(time)} bằng GPS.',
    NotificationDetails(android: details),
  );
}
