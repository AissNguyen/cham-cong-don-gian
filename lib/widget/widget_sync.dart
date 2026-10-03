/// Đồng bộ widget màn hình chính: ghi ngày + trạng thái chấm công lên widget, và xử lý khi
/// người dùng chạm nút chấm vào/ra ngay trên widget (kể cả khi app không chạy).
library;

import 'package:home_widget/home_widget.dart';

import '../analytics/analytics_service.dart' show eventWidgetTap;
import '../data/data_file.dart';
import '../domain/models.dart';
import '../share/share_state_file.dart';
import '../ui/format.dart';

const _providerName = 'ChamCongWidgetProvider';

/// Đọc dữ liệu hôm nay từ file chung, ghi lên widget rồi vẽ lại. Gọi sau mỗi lần chấm công
/// (trong app, từ GPS, hoặc từ chính widget) để widget luôn khớp với dữ liệu mới nhất.
Future<void> refreshWidgetDisplay() async {
  final json = await readDataJson();
  final today = dateOnly(DateTime.now());
  final record = recordFromJson(json, today);

  // Hết ngày dùng thử mà chưa mở khóa: widget đổi thành lời mời mở app để chia sẻ.
  final locked = !await autoFeatureAllowed();

  await HomeWidget.saveWidgetData('locked', locked);
  await HomeWidget.saveWidgetData('date_label', '${today.day}/${today.month}');
  await HomeWidget.saveWidgetData(
    'checkin_label',
    locked ? 'Hết dùng thử' : (record.checkIn != null ? fmtTime(record.checkIn!) : 'Chấm vào'),
  );
  await HomeWidget.saveWidgetData(
    'checkout_label',
    locked ? 'Mở khóa' : (record.checkOut != null ? fmtTime(record.checkOut!) : 'Chấm ra'),
  );
  await HomeWidget.updateWidget(name: _providerName);
}

/// Chạy khi người dùng chạm nút trên widget — có thể chạy trong tiến trình nền riêng, tách biệt
/// với app chính, nên đọc/ghi thẳng file chung rồi tự vẽ lại widget.
@pragma('vm:entry-point')
Future<void> widgetInteractiveCallback(Uri? uri) async {
  final action = uri?.queryParameters['action'];
  if (action != 'checkin' && action != 'checkout') return;

  // Hết ngày dùng thử: không chấm, chỉ vẽ lại widget sang trạng thái khóa.
  if (!await autoFeatureAllowed()) {
    await refreshWidgetDisplay();
    return;
  }

  final json = await readDataJson();
  final today = dateOnly(DateTime.now());
  final record = recordFromJson(json, today);
  final now = DateTime.now();

  final updated = action == 'checkin'
      ? record.copyWith(checkIn: now, isDayOff: false)
      : record.copyWith(checkOut: now);
  await writeDataJson(markPendingAnalyticsEvent(putRecordJson(json, updated), eventWidgetTap));
  await recordAutoUse();
  await recordUsage(usageWidgetUses);

  await refreshWidgetDisplay();
}
