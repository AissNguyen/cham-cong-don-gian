/// Còi báo giờ: đặt báo thức loại "đồng hồ báo thức" cho từng giờ người dùng cài; tới giờ thì hú còi
/// (cả khi máy để im lặng, vì phát qua luồng âm thanh báo thức), trừ ngày đã đánh dấu nghỉ. Trong lúc hú
/// có thông báo với nút "Tắt còi".
library;

import 'dart:async';
import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../data/data_file.dart';
import '../domain/models.dart';
import 'bell_sounds.dart';

const _maxBells = 50;
int _bellAlarmId(int index) => 6000 + index;
const _notificationId = 1100;

DateTime _next(Clock time) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  return next;
}

Future<void> _schedule(int index, BellConfig bell) => AndroidAlarmManager.oneShotAt(
  _next(bell.time),
  _bellAlarmId(index),
  bellAlarmCallback,
  alarmClock: true,
  exact: true,
  wakeup: true,
  allowWhileIdle: true,
  rescheduleOnReboot: true,
  params: {'i': index, 'h': bell.time.hour, 'm': bell.time.minute},
);

/// Đặt lại báo thức cho mọi giờ hú còi đang bật. Gọi khi mở app và mỗi khi sửa danh sách còi.
Future<void> rescheduleBells(List<BellConfig> bells) async {
  for (var i = 0; i < _maxBells; i++) {
    await AndroidAlarmManager.cancel(_bellAlarmId(i));
  }
  for (var i = 0; i < bells.length && i < _maxBells; i++) {
    if (bells[i].enabled) await _schedule(i, bells[i]);
  }
}

/// Chạy trong tiến trình nền khi tới giờ hú còi. Phải là hàm cấp cao nhất.
@pragma('vm:entry-point')
Future<void> bellAlarmCallback(int id, Map<String, dynamic> params) async {
  final json = await readDataJson();
  final bells = settingsFromJson(json).bells;
  final i = params['i'];
  if (i is! int || i >= bells.length) return;
  final bell = bells[i];
  // Danh sách đã bị sửa mà báo thức cũ còn sót: bỏ qua (app đặt lại khi sửa).
  if (!bell.enabled || bell.time.hour != params['h'] || bell.time.minute != params['m']) return;
  await _schedule(i, bell); // hẹn lại cho hôm sau
  if (recordFromJson(json, DateTime.now()).isDayOff) return;
  await ringBell(bell, notify: true);
}

/// File đánh dấu "tắt còi": nút Tắt còi (ở thông báo hoặc ở màn cài đặt) ghi vào đây, vòng hú thấy thì dừng.
Future<File> _stopFile() async => File('${(await getApplicationSupportDirectory()).path}/bell_stop.flag');

/// Bấm "Tắt còi" ở thông báo. Chạy ở tiến trình nền riêng, không cần plugin: chỉ ghi file theo đường dẫn
/// gửi kèm thông báo.
@pragma('vm:entry-point')
void bellNotificationAction(NotificationResponse response) {
  final path = response.payload;
  if (path == null || path.isEmpty) return;
  try {
    File(path).writeAsStringSync(DateTime.now().toIso8601String(), flush: true);
  } catch (_) {}
}

/// Dừng còi đang hú (dùng cho nút trong app).
Future<void> stopBell() async {
  try {
    (await _stopFile()).writeAsStringSync(DateTime.now().toIso8601String(), flush: true);
  } catch (_) {}
}

final _notifications = FlutterLocalNotificationsPlugin();

Future<void> _showRinging(BellConfig bell, String stopPath) async {
  await _notifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    onDidReceiveNotificationResponse: bellNotificationAction,
    onDidReceiveBackgroundNotificationResponse: bellNotificationAction,
  );
  await _notifications.show(
    _notificationId,
    'Còi ${bell.time.formatted}',
    'Đang hú còi. Bấm "Tắt còi" để dừng.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'bell_ringing',
        'Còi báo giờ',
        channelDescription: 'Hiện trong lúc còi báo giờ đang hú, có nút tắt còi',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false,
        ongoing: true,
        autoCancel: false,
        category: AndroidNotificationCategory.alarm,
        actions: [AndroidNotificationAction('stop_bell', 'Tắt còi', cancelNotification: true)],
      ),
    ),
    payload: stopPath,
  );
}

/// Hú còi [bell.repeats] lần, mỗi lần cách nhau nửa giây, tới khi hết lượt hoặc có người bấm tắt.
/// [notify]: hiện thông báo có nút "Tắt còi" (lúc tới giờ thật); nghe thử trong cài đặt thì không.
Future<void> ringBell(BellConfig bell, {bool notify = false}) async {
  final stop = await _stopFile();
  if (await stop.exists()) await stop.delete();
  bool stopped() => stop.existsSync();

  if (notify) await _showRinging(bell, stop.path);
  final player = AudioPlayer();
  try {
    await player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm, // phát qua âm lượng báo thức: máy im lặng vẫn hú
          audioFocus: AndroidAudioFocus.gainTransient,
        ),
      ),
    );
    await player.setVolume(bell.volume.clamp(0.1, 1.0));
    final path = await bellSoundPath(bell.sound);
    for (var k = 0; k < bell.repeats && !stopped(); k++) {
      var finished = false;
      final sub = player.onPlayerComplete.listen((_) => finished = true);
      await player.play(DeviceFileSource(path));
      // Chờ hết một lần hú (tối đa 10 giây), cứ 0,3 giây xem có ai bấm tắt không.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!finished && !stopped() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      await sub.cancel();
      if (stopped()) {
        await player.stop();
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  } catch (e, st) {
    // Không phát được (thiếu file, lỗi âm thanh): bỏ qua, không làm hỏng các việc khác.
    // ignore: avoid_print
    print('CCDG_BELL lỗi phát còi: $e\n$st');
  } finally {
    await player.dispose();
    if (notify) await _notifications.cancel(_notificationId);
  }
}
