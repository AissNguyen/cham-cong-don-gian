/// Màn "Nhật ký GPS": từng lần dò (mốc giờ, dò cho việc gì, GPS cách bao xa, Wi-Fi thấy gì, app quyết
/// định gì) và hai danh sách Wi-Fi quen. Dùng khi người dùng đang thử chấm công GPS.
library;

import 'package:flutter/material.dart';

import '../../gps/gps_log.dart';
import '../../gps/gps_manual.dart';
import '../../gps/gps_wifi.dart';
import 'gps_measure_dialog.dart';
import 'number_inputs.dart';

class GpsLogView extends StatefulWidget {
  const GpsLogView({super.key});

  @override
  State<GpsLogView> createState() => _GpsLogViewState();
}

class _GpsLogViewState extends State<GpsLogView> {
  List<GpsLogEntry> _log = const [];
  List<ManualGpsCheck> _manual = const [];
  KnownWifiLists _wifi = const KnownWifiLists();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await readGpsLog();
    final wifi = await readKnownWifi();
    final manual = await readManualChecks();
    if (!mounted) return;
    setState(() {
      _log = log;
      _manual = manual;
      _wifi = wifi;
      _loading = false;
    });
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _hm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _dm(DateTime t) => '${_two(t.day)}/${_two(t.month)}';

  Future<void> _clearLog() async {
    final ok = await confirmAsk(context, title: 'Xóa nhật ký?', text: 'Bạn chắc chắn muốn xóa hết nhật ký GPS không?', yes: 'Xóa');
    if (!ok) return;
    await clearGpsLog();
    await _load();
  }

  Future<void> _clearWifi() async {
    final ok = await confirmAsk(
      context,
      title: 'Xóa Wi-Fi quen?',
      text: 'Bạn chắc chắn muốn xóa cả hai danh sách Wi-Fi quen không? App sẽ tự học lại từ đầu.',
      yes: 'Xóa',
    );
    if (!ok) return;
    await clearKnownWifi();
    await _load();
  }

  /// Mỗi tên mạng một khối: số lần xuất hiện, số ngày, có đang được dùng để chấm không, các mốc theo ngày.
  /// [allSeen]: danh sách mọi mạng đã thấy (chỉ để xem), không ghi chuyện dùng làm mốc.
  Widget _wifiList(String title, List<KnownWifi> list, Set<String> ambiguous, {bool allSeen = false}) {
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final accent = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary);
    final all = groupWifi(list);
    // Mạng xuất hiện dưới [wifiMinSightings] lần thì ẩn (app vẫn đếm ngầm).
    final shown = all.where((g) => g.sightings >= wifiMinSightings).toList();
    final named = shown.where((g) => g.name.isNotEmpty).toList();
    final nameless = shown.where((g) => g.name.isEmpty).expand((g) => g.members).toList();
    final used = allSeen ? <String>{} : _wifi.trusted(list).map((g) => g.name).toSet();

    Widget group(WifiGroup g, String name) {
      final byDay = <String, List<DateTime>>{};
      for (final m in g.marks) {
        (byDay[_dm(m)] ??= []).add(m);
      }
      final shared = g.members.any((w) => ambiguous.contains(w.bssid));
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name · xuất hiện ${g.sightings} lần · ${g.days.length} ngày'
              '${g.members.length > 1 ? ' · ${g.members.length} thiết bị phát' : ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (!allSeen && g.name.isNotEmpty && used.contains(g.name))
              Text('Đang dùng làm mốc chấm công', style: accent)
            else if (!allSeen && isPhoneHotspot(g.name))
              Text('Không dùng: Wi-Fi do điện thoại phát', style: muted)
            else if (!allSeen)
              Text('Chưa dùng: chỉ $wifiTopNetworks mạng xuất hiện nhiều nhất được dùng', style: muted),
            if (shared && !allSeen) Text('Có ở cả chỗ làm lẫn ngoài, sẽ bị xóa', style: muted),
            for (final e in byDay.entries.take(7))
              Text('${e.key}: ${(e.value..sort()).map(_hm).join(', ')}', style: muted),
            if (byDay.length > 7) Text('… và ${byDay.length - 7} ngày trước đó', style: muted),
            if (g.marks.isEmpty) Text('Học từ bản trước, chưa thấy lại', style: muted),
          ],
        ),
      );
    }

    return _fold(
      title: '$title (${named.length} mạng)',
      subtitle: allSeen
          ? 'Mọi mạng quét được ở mọi lần dò, kể cả sóng yếu và lúc mất GPS. Chỉ để xem.'
          : 'Chỉ $wifiTopNetworks mạng xuất hiện nhiều nhất (từ $wifiMinSightings lần trở lên) được dùng làm mốc.',
      children: [
        if (list.isEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Chưa có', style: muted)),
        for (final g in named) group(g, g.name),
        if (nameless.isNotEmpty) group(WifiGroup('', nameless), '(chưa biết tên)'),
      ],
    );
  }

  /// Khung gập: bấm tiêu đề mới sổ ra.
  Widget _fold({required String title, String? subtitle, required List<Widget> children}) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ExpansionTile(
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle, style: const TextStyle(fontSize: 12)),
      shape: const Border(),
      collapsedShape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _entry(GpsLogEntry e, TextStyle muted) {
    final late = e.at.difference(e.mark).inMinutes;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mốc ${_hm(e.mark)} · ${e.task} · lần ${e.attempt} · dò lúc ${_hm(e.at)}'
            '${e.attempt == 1 && late > 0 ? ' (trễ $late phút)' : ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (e.gps.isNotEmpty) Text('GPS: ${e.gps}', style: muted),
          if (e.wifi.isNotEmpty) Text('Wi-Fi quen: ${e.wifi}', style: muted),
          if (e.wifiSeen.isNotEmpty) Text('Wi-Fi thấy: ${e.wifiSeen}', style: muted),
          Text('Kết quả: ${e.result}', style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  /// Dòng tóm tắt của một ngày: số lần dò, số mốc bị bỏ, các lần chấm.
  String _daySummary(List<GpsLogEntry> entries) {
    final marks = entries.map((e) => e.mark).toSet().length;
    final skipped = entries.where((e) => e.result.startsWith('Bỏ')).length;
    final punches = [
      for (final e in entries.reversed)
        if (e.result.startsWith('Chấm') || e.result.startsWith('Mở lại')) e.result,
    ];
    return [
      '$marks mốc',
      if (skipped > 0) 'bỏ $skipped mốc',
      ...punches,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final muted = TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    final ambiguous = _wifi.ambiguous;
    // Gom các lần dò theo ngày của mốc, ngày mới nhất trước.
    final byDay = <String, List<GpsLogEntry>>{};
    for (final e in _log) {
      (byDay['${_dm(e.mark)}/${e.mark.year}'] ??= []).add(e);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Tải lại')),
              TextButton(onPressed: _clearLog, child: const Text('Xóa nhật ký')),
              TextButton(onPressed: _clearWifi, child: const Text('Xóa Wi-Fi quen')),
            ],
          ),
          Text(
            'Chỉ hiện mạng xuất hiện từ $wifiMinSightings lần. Mạng thấy lần đầu từ $wifiPruneAfterDays ngày trước mà vẫn dưới '
            '$wifiMinSightings lần thì tự xóa; mạng có ở cả chỗ làm lẫn ngoài thì xóa; cứ $wifiResetEveryDays ngày số lần được hạ về '
            'tối đa $wifiResetTo.',
            style: muted,
          ),
          _wifiList('Wi-Fi chỗ làm (trong phạm vi)', _wifi.work, ambiguous),
          _wifiList('Wi-Fi ngoài phạm vi (nhà, quán...)', _wifi.outside, ambiguous),
          _wifiList('Tất cả Wi-Fi đã thấy', _wifi.all, ambiguous, allSeen: true),
          _fold(
            title: 'Đo vị trí thủ công (${_manual.length} lần)',
            subtitle: 'Các lần bấm Đo vị trí ngay trong cài đặt GPS',
            children: [
              if (_manual.isEmpty) Text('Chưa đo lần nào', style: muted),
              for (final c in _manual)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${c.no}${c.name.isEmpty ? '' : ' · ${c.name}'} · ${_hm(c.at)} ${_dm(c.at)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(describeManualCheck(c), style: muted),
                    ],
                  ),
                ),
              if (_manual.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final ok = await confirmAsk(context, title: 'Xóa nhật ký đo?', text: 'Bạn chắc chắn muốn xóa hết các lần đo thủ công không?', yes: 'Xóa');
                    if (!ok) return;
                    await clearManualChecks();
                    await _load();
                  },
                  child: const Text('Xóa nhật ký đo'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Các lần dò theo ngày (${_log.length} dòng)', style: const TextStyle(fontWeight: FontWeight.w600)),
          if (_log.isEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Chưa có lần dò nào', style: muted)),
          for (final day in byDay.entries)
            _fold(
              title: 'Ngày ${day.key.substring(0, 5)}',
              subtitle: _daySummary(day.value),
              children: [for (final e in day.value) _entry(e, muted)],
            ),
        ],
      ),
    );
  }
}
