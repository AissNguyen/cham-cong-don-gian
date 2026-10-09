import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../gps/gps_scheduler.dart';
import 'settings_card.dart';
import 'share_section.dart';

TimeOfDay _toTod(Clock c) => TimeOfDay(hour: c.hour, minute: c.minute);
Clock _toClock(TimeOfDay t) => Clock(t.hour, t.minute);

const _maxExtraPlaces = 10;

/// Lấy tọa độ hiện tại (xin quyền nếu cần); lỗi thì báo lên màn hình và trả về null.
Future<Position?> currentGpsPosition(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      messenger.showSnackBar(const SnackBar(content: Text('Chưa cấp quyền vị trí.')));
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      messenger.showSnackBar(const SnackBar(content: Text('Hãy bật định vị (GPS) trên máy.')));
      return null;
    }
    return await Geolocator.getCurrentPosition();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Không lấy được vị trí: $e')));
    return null;
  }
}

/// Xin đủ các quyền để GPS tự chấm được cả khi app không mở.
Future<void> requestGpsPermissions(BuildContext context) async {
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

/// Chấm công tự động bằng GPS: vị trí, bán kính, khung giờ kiểm tra chấm vào/ra riêng, tần suất.
class GpsSection extends StatelessWidget {
  const GpsSection({super.key, required this.store});

  final AppStore store;

  Future<void> _updateGps(GpsConfig Function(GpsConfig) update) async {
    await store.updateSettings((s) => s.copyWith(gps: update(s.gps)));
    await rescheduleGpsAlarms(store.settings.effectiveGps);
  }

  Future<void> _openWindowForm(BuildContext context, {TimeWindow? editing}) async {
    var from = editing?.from ?? const Clock(6, 50);
    var to = editing?.to ?? const Clock(7, 0);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Khung giờ bật GPS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Máy chỉ kiểm tra vị trí trong các khung này. Lần xác nhận đầu tiên trong ngày tính '
                'là chấm vào, lần tiếp theo tính là chấm ra — không cần khai riêng khung nào là vào/ra.',
              ),
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
                  _updateGps((gps) => gps.copyWith(activeWindows: gps.activeWindows.where((w) => w != editing).toList()));
                  Navigator.pop(context);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            FilledButton(
              onPressed: () {
                final window = TimeWindow(from: from, to: to);
                _updateGps((gps) {
                  final list = [...gps.activeWindows];
                  if (editing != null) {
                    final i = list.indexOf(editing);
                    if (i >= 0) list[i] = window;
                  } else {
                    list.add(window);
                  }
                  return gps.copyWith(activeWindows: list);
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

  Widget _windowList(BuildContext context, {required List<TimeWindow> windows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Khung giờ bật GPS', style: TextStyle(fontWeight: FontWeight.w600)),
        for (final w in windows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text('${w.from.formatted}–${w.to.formatted}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openWindowForm(context, editing: w),
          ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Thêm khung giờ'),
          onPressed: () => _openWindowForm(context),
        ),
      ],
    );
  }

  Future<void> _pickCurrentLocation(BuildContext context) async {
    final pos = await currentGpsPosition(context);
    if (pos == null) return;
    await _updateGps((gps) => gps.copyWith(latitude: pos.latitude, longitude: pos.longitude));
  }

  Future<void> _openPlaceForm(BuildContext context, {int? editingIndex}) async {
    final editing = editingIndex != null ? store.settings.gps.extraPlaces[editingIndex] : null;
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final radiusCtrl = TextEditingController(text: (editing?.radiusMeters ?? 50).round().toString());
    var lat = editing?.latitude;
    var lng = editing?.longitude;
    var checkOut = editing?.checkOut ?? true;
    var loading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Địa điểm khác'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Tên (vd: Nhà trọ, Xưởng B)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Text(
                  lat != null ? 'Vị trí: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}' : 'Chưa có vị trí',
                  style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurfaceVariant, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Lấy vị trí hiện tại'),
                  onPressed: loading
                      ? null
                      : () async {
                          setState(() => loading = true);
                          final pos = await currentGpsPosition(context);
                          if (!dialogContext.mounted) return;
                          setState(() {
                            loading = false;
                            if (pos != null) {
                              lat = pos.latitude;
                              lng = pos.longitude;
                            }
                          });
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: radiusCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bán kính (mét)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Chấm về')),
                    ButtonSegment(value: false, label: Text('Không chấm về')),
                  ],
                  selected: {checkOut},
                  onSelectionChanged: (v) => setState(() => checkOut = v.first),
                ),
                const SizedBox(height: 8),
                Text(
                  checkOut
                      ? 'Đã chấm vào mà tới đây thì chấm ra ngay (vd: nhà trọ sát công ty).'
                      : 'Ở đây thì không chấm ra dù đã xa điểm chấm công (vd: xưởng ở xa máy chấm công).',
                  style: TextStyle(fontSize: 12, color: Theme.of(dialogContext).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            if (editingIndex != null)
              TextButton(
                onPressed: () {
                  _updateGps((gps) => gps.copyWith(extraPlaces: [...gps.extraPlaces]..removeAt(editingIndex)));
                  Navigator.pop(dialogContext);
                },
                child: const Text('Xóa'),
              ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            FilledButton(
              onPressed: lat == null
                  ? null
                  : () {
                      final radius = double.tryParse(radiusCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 50;
                      final place = GpsPlace(
                        name: nameCtrl.text.trim(),
                        latitude: lat!,
                        longitude: lng!,
                        radiusMeters: radius,
                        checkOut: checkOut,
                      );
                      _updateGps((gps) {
                        final list = [...gps.extraPlaces];
                        if (editingIndex != null) {
                          list[editingIndex] = place;
                        } else {
                          list.add(place);
                        }
                        return gps.copyWith(extraPlaces: list);
                      });
                      Navigator.pop(dialogContext);
                    },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeList(BuildContext context, {required List<GpsPlace> places}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Địa điểm khác', style: TextStyle(fontWeight: FontWeight.w600)),
        Text(
          'Chỉ dùng cho chấm ra. Ví dụ nhà trọ sát công ty (chấm về) hoặc xưởng ở xa máy chấm công '
          '(không chấm về).',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        for (var i = 0; i < places.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(places[i].name.isEmpty ? 'Địa điểm ${i + 1}' : places[i].name),
            subtitle: Text(
              '${places[i].checkOut ? 'Chấm về' : 'Không chấm về'} · bán kính ${places[i].radiusMeters.round()} m',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openPlaceForm(context, editingIndex: i),
          ),
        if (places.length < _maxExtraPlaces)
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Thêm địa điểm'),
            onPressed: () => _openPlaceForm(context),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gps = store.settings.gps;
    return SettingsCard(
      title: 'GPS: tùy chọn thêm',
      subtitle: 'Đứng ở nơi chấm công rồi bấm lấy tọa độ. Cần cấp đủ quyền thì mới tự chấm khi app không mở.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AutoLockNotice(),
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
              onPressed: () => requestGpsPermissions(context),
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
              decoration: const InputDecoration(
                labelText: 'Bán kính coi là "đang ở đó" (mét)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final r = double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? gps.radiusMeters;
                _updateGps((gps) => gps.copyWith(radiusMeters: r));
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: gps.departRadiusMeters.round().toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cách bao xa (mét) mới coi là đã rời đi hẳn — dùng xác nhận chấm ra',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                final r = double.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? gps.departRadiusMeters;
                _updateGps((gps) => gps.copyWith(departRadiusMeters: r));
              },
            ),
            const SizedBox(height: 12),
            _placeList(context, places: gps.extraPlaces),
            const SizedBox(height: 12),
            _windowList(context, windows: gps.activeWindows),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Lần đầu vào bán kính trong khung giờ là chấm ngay (chấm vào nếu chưa có giờ vào hôm '
                'nay, chấm ra nếu đã có). Sau khi chấm vào, máy theo dõi tiếp tới khi thấy cách xa hẳn '
                'mới xác nhận chấm ra, tránh chấm nhầm lúc đang di chuyển gần đó.',
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
