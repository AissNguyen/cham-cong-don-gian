import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../gps/gps_scheduler.dart';
import 'settings_card.dart';

TimeOfDay _toTod(Clock c) => TimeOfDay(hour: c.hour, minute: c.minute);
Clock _toClock(TimeOfDay t) => Clock(t.hour, t.minute);

/// Chấm công tự động bằng GPS: vị trí, bán kính, khung giờ kiểm tra chấm vào/ra riêng, tần suất.
class GpsSection extends StatelessWidget {
  const GpsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _updateGps(GpsConfig Function(GpsConfig) update) async {
    await store.updateSettings((s) => s.copyWith(gps: update(s.gps)));
    await rescheduleGpsAlarms(store.settings.gps);
  }

  Future<void> _openWindowForm(BuildContext context, {required bool isCheckIn, TimeWindow? editing}) async {
    var from = editing?.from ?? (isCheckIn ? const Clock(6, 50) : const Clock(16, 0));
    var to = editing?.to ?? (isCheckIn ? const Clock(7, 0) : const Clock(16, 15));

    List<TimeWindow> currentList(GpsConfig gps) => isCheckIn ? gps.checkInWindows : gps.checkOutWindows;
    GpsConfig applyList(GpsConfig gps, List<TimeWindow> list) =>
        isCheckIn ? gps.copyWith(checkInWindows: list) : gps.copyWith(checkOutWindows: list);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isCheckIn ? 'Khung giờ chấm vào' : 'Khung giờ chấm ra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dùng cho khung đúng giờ, hoặc thêm khung dự phòng cho người được phép đi muộn hơn.'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  TimeChip(label: 'Từ', time: _toTod(from), onPick: (t) => setState(() => from = _toClock(t))),
                  TimeChip(label: 'Đến', time: _toTod(to), onPick: (t) => setState(() => to = _toClock(t))),
                ],
              ),
            ],
          ),
          actions: [
            if (editing != null)
              TextButton(
                onPressed: () {
                  _updateGps((gps) => applyList(gps, currentList(gps).where((w) => w != editing).toList()));
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final window = TimeWindow(from: from, to: to);
                _updateGps((gps) {
                  final list = [...currentList(gps)];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = window;
                  } else {
                    list.add(window);
                  }
                  return applyList(gps, list);
                });
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _windowList(BuildContext context, {required bool isCheckIn, required List<TimeWindow> windows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCheckIn ? 'Khung giờ kiểm tra chấm vào' : 'Khung giờ kiểm tra chấm ra',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final w in windows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${w.from.formatted}–${w.to.formatted}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openWindowForm(context, isCheckIn: isCheckIn, editing: w),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(isCheckIn ? 'Thêm khung chấm vào' : 'Thêm khung chấm ra'),
          onPressed: () => _openWindowForm(context, isCheckIn: isCheckIn),
        ),
      ],
    );
  }

  Future<void> _pickCurrentLocation(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        messenger.showSnackBar(const SnackBar(content: Text('Chưa cấp quyền vị trí.')));
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        messenger.showSnackBar(const SnackBar(content: Text('Hãy bật định vị (GPS) trên máy.')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _updateGps((gps) => gps.copyWith(latitude: pos.latitude, longitude: pos.longitude));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Không lấy được vị trí: $e')));
    }
  }

  Future<void> _requestPermissions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Vị trí (kể cả khi chạy nền) — chấm ra thường xảy ra lúc app không mở.
    var locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
    }
    if (locationPermission == LocationPermission.whileInUse) {
      locationPermission = await Geolocator.requestPermission();
    }

    // Thông báo (Android 13+, bắt buộc để dịch vụ nền hiện được).
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Báo thức chính xác (Android 12+).
    if (!await FlutterForegroundTask.canScheduleExactAlarms) {
      await FlutterForegroundTask.openAlarmsAndRemindersSettings();
    }

    // Bỏ qua tối ưu hóa pin — máy Android hay tự tắt app chạy nền nếu không xin quyền này.
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(content: Text('Đã xin các quyền cần thiết.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gps = store.settings.gps;
    return SettingsCard(
      title: 'Chấm công GPS',
      subtitle: 'Đứng ở nơi chấm công rồi bấm lấy tọa độ. Cần cấp đủ quyền thì mới tự chấm khi app không mở.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bật chấm công GPS'),
            value: gps.enabled,
            onChanged: (v) => _updateGps((gps) => gps.copyWith(enabled: v)),
          ),
          if (gps.enabled) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Cấp quyền cần thiết'),
              onPressed: () => _requestPermissions(context),
            ),
            const SizedBox(height: 12),
            Text(
              gps.latitude != null
                  ? 'Vị trí đã lưu: ${gps.latitude!.toStringAsFixed(5)}, ${gps.longitude!.toStringAsFixed(5)}'
                  : 'Chưa có vị trí',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.my_location),
              label: const Text('Lấy vị trí hiện tại'),
              onPressed: () => _pickCurrentLocation(context),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: gps.radiusMeters.round().toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Bán kính (mét)', border: OutlineInputBorder()),
              onChanged: (v) {
                final r = double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? gps.radiusMeters;
                _updateGps((gps) => gps.copyWith(radiusMeters: r));
              },
            ),
            const SizedBox(height: 12),
            _windowList(context, isCheckIn: true, windows: gps.checkInWindows),
            const SizedBox(height: 12),
            _windowList(context, isCheckIn: false, windows: gps.checkOutWindows),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Trong khung chấm ra, máy chỉ tự chấm nếu hôm đó đã có chấm vào rồi. Lúc kiểm tra, máy hiện một thông báo nhỏ, tự tắt khi hết khung giờ.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: gps.frequencyMinutes.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tần suất kiểm tra (phút/lần)', border: OutlineInputBorder()),
              onChanged: (v) {
                final f = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? gps.frequencyMinutes;
                _updateGps((gps) => gps.copyWith(frequencyMinutes: f));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kêu chuông/rung khi tự chấm công'),
              value: gps.soundEnabled,
              onChanged: (v) => _updateGps((gps) => gps.copyWith(soundEnabled: v)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kỳ lương: theo tháng (chọn ngày bắt đầu) hoặc 2 kỳ mỗi tháng (1-15, 16-cuối tháng).
class PayPeriodSection extends StatelessWidget {
  const PayPeriodSection({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cfg = store.settings.payPeriod;
    return SettingsCard(
      title: 'Kỳ lương',
      subtitle: 'Thu nhập tạm tính ở màn chính tính từ đầu kỳ hiện tại đến hôm nay.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<PayPeriodType>(
            segments: const [
              ButtonSegment(value: PayPeriodType.monthly, label: Text('Theo tháng')),
              ButtonSegment(value: PayPeriodType.semiMonthly, label: Text('2 kỳ/tháng')),
            ],
            selected: {cfg.type},
            onSelectionChanged: (v) =>
                store.updateSettings((s) => s.copyWith(payPeriod: s.payPeriod.copyWith(type: v.first))),
          ),
          if (cfg.type == PayPeriodType.monthly) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: cfg.monthlyStartDay.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Ngày bắt đầu kỳ mỗi tháng (1–31)', border: OutlineInputBorder()),
              onChanged: (v) {
                final parsed = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                if (parsed == null) return;
                final day = parsed.clamp(1, 31);
                store.updateSettings((s) => s.copyWith(payPeriod: s.payPeriod.copyWith(monthlyStartDay: day)));
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Kỳ 1: ngày 1–15. Kỳ 2: ngày 16–cuối tháng.', style: TextStyle(fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
