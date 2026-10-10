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

AndroidNotificationDetails _resultDetails(bool soundEnabled) => AndroidNotificationDetails(
  'gps_punch_result',
  'Kết quả chấm công GPS',
  channelDescription: 'Báo khi máy tự chấm công theo GPS',
  importance: Importance.high,
  priority: Priority.high,
  playSound: soundEnabled,
  enableVibration: soundEnabled,
);

/// Báo khi GPS không xác định được còn ở chỗ làm hay đã về (không có sóng GPS, không thấy Wi-Fi quen).
Future<void> showGpsUnknownNotification({bool soundEnabled = true}) async {
  await _ensureInitialized();
  await _plugin.show(
    1003,
    'Không xác định được vị trí',
    'Không có sóng GPS và không thấy Wi-Fi quen nên chưa biết bạn còn ở chỗ làm hay đã về. Hãy mở app '
        'xem lại giờ về của hôm nay.',
    NotificationDetails(android: _resultDetails(soundEnabled)),
  );
}

/// Báo khi GPS thấy người dùng quay lại chỗ làm và bỏ giờ ra đã chốt trước đó.
Future<void> showGpsReopenNotification({required DateTime oldCheckOut, bool soundEnabled = true}) async {
  await _ensureInitialized();
  await _plugin.show(
    1004,
    'Đã mở lại ca',
    'Thấy bạn vẫn ở chỗ làm nên đã bỏ giờ ra ${fmtTime(oldCheckOut)}, tiếp tục tính công.',
    NotificationDetails(android: _resultDetails(soundEnabled)),
  );
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
