import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../gps/gps_scheduler.dart';
import '../../gps/gps_wifi.dart';
import 'gps_log_view.dart';
import 'gps_measure_dialog.dart';
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

  /// Ba mốc giờ của chấm công GPS: khoảng giờ tự chấm vào và giờ cuối dò giờ về.
  Widget _timesBlock(BuildContext context, {required GpsConfig gps}) {
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giờ tự chấm', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Tự chấm vào (dò ở phút 00 và 30, dò trước ở phút 45 và 15)', style: muted),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            TimeChip(
              label: 'Từ',
              time: _toTod(gps.arriveFrom),
              onPick: (t) => _updateGps((g) => g.copyWith(arriveFrom: _toClock(t))),
            ),
            TimeChip(
              label: 'Đến',
              time: _toTod(gps.arriveTo),
              onPick: (t) => _updateGps((g) => g.copyWith(arriveTo: _toClock(t))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text('Dò giờ về (phút 15 và 45) tới, có thể sang sáng hôm sau', style: muted),
        const SizedBox(height: 4),
        TimeChip(
          label: 'Tới',
          time: _toTod(gps.departUntil),
          onPick: (t) => _updateGps((g) => g.copyWith(departUntil: _toClock(t))),
        ),
      ],
    );
  }

  Future<void> _pickCurrentLocation(BuildContext context) async {
    final pos = await currentGpsPosition(context);
    if (pos == null) return;
    // Đổi điểm chấm thì các mạng Wi-Fi quen của điểm cũ không còn đúng nữa; app sẽ tự học lại.
    await clearKnownWifi();
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
            if (gps.latitude != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.straighten),
                label: const Text('Đo vị trí ngay'),
                onPressed: () => showMeasureDialog(context, gps),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Xem lúc này cách điểm chấm bao xa, GPS mạnh hay yếu, để ước lượng mà chỉnh phạm vi chỗ làm. '
                  'Mỗi lần đo được ghi vào Nhật ký GPS.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              initialValue: gps.departRadiusMeters.round().toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Phạm vi chỗ làm (mét)',
                helperText: 'Trong khoảng này là đang ở chỗ làm (chấm vào, vẫn đang làm); ra ngoài là đã về.',
                helperMaxLines: 2,
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
            _timesBlock(context, gps: gps),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Chấm vào: dò chính ở phút 00 và 30, ở chỗ làm thì giờ vào là đúng mốc đó. Dò trước ở phút 45 '
                'và 15 để biết điện thoại còn bắt được GPS; lần dò chính mất sóng mà lần dò trước bắt được thì '
                'vẫn chấm vào.\n'
                'Chấm ra: sau khi vào, dò ở phút 15 và 45. Ra khỏi phạm vi chỗ làm thì giờ ra là x:00 (dò phút '
                '15) hoặc x:30 (dò phút 45). Không dò ra vị trí thì coi như vẫn đang làm.\n'
                'Đã chấm ra: dò lại 3 lần, cách nhau 1 tiếng; còn ở chỗ làm hoặc không dò ra vị trí thì bỏ giờ ra, '
                'tính công tiếp. Giờ ra bạn tự bấm thì máy không đụng tới.\n'
                'Mỗi lần không dò ra vị trí thì thử lại 2 lần, cách 3 phút. Lúc mất GPS máy xem Wi-Fi quen (tự học, '
                'không cần mật khẩu): Wi-Fi chỗ làm là đang ở chỗ làm, Wi-Fi ở ngoài (nhà...) là đã về. Hãy để Wi-Fi '
                'của điện thoại ở chế độ bật.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Nhật ký GPS và Wi-Fi quen'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Nhật ký GPS')),
                    body: const GpsLogView(),
                  ),
                ),
              ),
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
