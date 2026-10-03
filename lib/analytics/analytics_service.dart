/// Ghi các sự kiện dùng để đánh giá mức độ dùng app (mở app, dùng GPS, bấm widget...), mỗi sự
/// kiện chỉ gửi tối đa 1 lần/ngày cho mỗi máy — đủ để biết có bao nhiêu người thực sự dùng app
/// mỗi ngày mà không cần gửi dồn dập từng thao tác nhỏ.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_file.dart';
import '../domain/models.dart';

const eventAppOpen = 'app_open_daily';
const eventWidgetTap = 'widget_tap_daily';
const eventGpsUsed = 'gps_used_daily';
const eventViewedPeriodStats = 'viewed_period_stats_daily';
const eventOpenedSettings = 'opened_settings_daily';

/// Ghi 1 sự kiện Analytics, bỏ qua nếu hôm nay đã ghi rồi (dựa vào ngày lưu trong máy). Thống kê
/// chỉ là phụ trợ — lỗi hoặc treo khi gửi (mất mạng, bị chặn...) thì bỏ qua, không được làm crash
/// hay treo app.
Future<void> logOncePerDay(String eventName) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'analytics_last_$eventName';
    final today = dateKey(dateOnly(DateTime.now()));
    if (prefs.getString(key) == today) return;
    await prefs.setString(key, today);
    await FirebaseAnalytics.instance.logEvent(name: eventName).timeout(const Duration(seconds: 5));
  } catch (_) {
    // Bỏ qua — hôm sau thử lại.
  }
}

/// Ghi các sự kiện do tiến trình nền (widget, GPS) đánh dấu chờ — tiến trình nền không có sẵn
/// Firebase nên chỉ ghi lại vào file, để app chính ghi hộ vào lần mở/quay lại foreground kế tiếp.
Future<void> processPendingAnalyticsEvents() async {
  try {
    final json = await readDataJson();
    final (pending, cleared) = takePendingAnalyticsEvents(json);
    if (pending.isEmpty) return;
    for (final event in pending) {
      await logOncePerDay(event);
    }
    await writeDataJson(cleared);
  } catch (_) {
    // Bỏ qua — lần mở app sau thử lại.
  }
}
