/// Các khối còn lại của màn Cài đặt mới (theo `mockup/luong-va-cai-dat.html`): thông báo, hai nút
/// Công nhân / Công nhật, thẻ Chấm công GPS rút gọn và thẻ "Nâng cao và cài đặt khác".
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../data/store.dart';
import '../../domain/models.dart';
import '../../gps/gps_scheduler.dart';
import '../../notice/notice.dart';
import '../../theme/app_theme.dart';
import 'android_download_section.dart';
import 'backup_section.dart';
import 'config_share_section.dart';
import 'feedback_section.dart';
import 'help_screen.dart';
import 'number_inputs.dart';
import 'payslip_card.dart';
import 'settings_sections_extra.dart';
import 'settings_sections_rules.dart';
import 'settings_sections_time.dart';
import 'share_section.dart';

/// Thẻ Thông báo ở đầu Cài đặt: 2 hàng rõ, hàng thứ 3 mờ dần, nút "Xem thêm" / "Thu gọn". Không có
/// nút xóa. Ẩn khi không có thông báo hoặc người dùng đã tắt "Hiện thông báo".
class SettingsNoticeCard extends StatefulWidget {
  const SettingsNoticeCard({super.key});

  @override
  State<SettingsNoticeCard> createState() => _SettingsNoticeCardState();
}

class _SettingsNoticeCardState extends State<SettingsNoticeCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final show = context.select<AppStore, bool>((s) => s.settings.showNotice);
    if (!show) return const SizedBox.shrink();
    return ValueListenableBuilder<AppNotice?>(
      valueListenable: activeNotice,
      builder: (context, notice, _) {
        if (notice == null) return const SizedBox.shrink();
        final colors = context.appColors;
        const style = TextStyle(fontSize: 12.5, height: 1.5);
        final body = Text.rich(
          TextSpan(
            style: style.copyWith(color: colors.ink2),
            children: [
              if (notice.title.isNotEmpty)
                TextSpan(
                  text: '${notice.title}\n',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                ),
              TextSpan(text: notice.text),
            ],
          ),
        );
        return TitledCard(
          title: 'Thông báo',
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Đo xem có quá 3 hàng không; quá thì cắt ở 3 hàng, hàng thứ 3 mờ dần.
              final painter = TextPainter(
                text: TextSpan(text: '${notice.title}\n${notice.text}', style: style),
                maxLines: 3,
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final tooLong = painter.didExceedMaxLines;
              final lineHeight = painter.preferredLineHeight;
              painter.dispose();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (_open || !tooLong)
                    body
                  else
                    SizedBox(
                      height: lineHeight * 3,
                      child: ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Colors.black, Colors.transparent],
                          stops: [0, 0.6, 1],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: ClipRect(child: OverflowBox(alignment: Alignment.topLeft, maxHeight: double.infinity, child: body)),
                      ),
                    ),
                  if (_open && notice.hasLink) ...[const SizedBox(height: 8), NoticeLinkButtons(links: notice.links)],
                  if (tooLong || notice.hasLink)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => setState(() => _open = !_open),
                      child: Text(_open ? 'Thu gọn' : 'Xem thêm'),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Hai nút nhỏ Công nhân / Công nhật, chỉ chọn một. Đổi loại thì hỏi lại rồi đặt phần lương và cài
/// đặt tính công về mặc định của loại mới (giờ chấm công, GPS, ngày lễ, khung tăng ca giữ nguyên).
class WorkerKindToggle extends StatelessWidget {
  const WorkerKindToggle({super.key, required this.store});

  final AppStore store;

  Future<void> _change(BuildContext context, WorkerKind kind) async {
    if (kind == store.settings.workerKind) return;
    final name = kind == WorkerKind.worker ? 'Công nhân' : 'Công nhật';
    final ok = await confirmAsk(
      context,
      title: 'Đổi sang $name?',
      text:
          'Nếu bạn đổi thì phần lương và cài đặt tính công cũ sẽ bị mất hết (giờ chấm công từng ngày vẫn giữ '
          'nguyên). Bạn chắc chắn đổi không?',
      yes: 'Đổi',
    );
    if (ok) await store.replaceSettings(AppSettings.defaultsFor(kind, keep: store.settings));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SegmentedButton<WorkerKind>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: WorkerKind.worker, label: Text('Công nhân')),
            ButtonSegment(value: WorkerKind.daily, label: Text('Công nhật')),
          ],
          selected: {store.settings.workerKind},
          onSelectionChanged: (v) => _change(context, v.first),
        ),
      ),
    );
  }
}

/// Thẻ Chấm công GPS rút gọn: nút "Lấy tọa độ" (lấy xong là bật GPS luôn), nút "Cấp quyền chấm công"
/// và một dòng trạng thái. Các tùy chọn khác nằm ở Nâng cao › GPS: tùy chọn thêm.
class GpsQuickCard extends StatefulWidget {
  const GpsQuickCard({super.key, required this.store});

  final AppStore store;

  @override
  State<GpsQuickCard> createState() => _GpsQuickCardState();
}

class _GpsQuickCardState extends State<GpsQuickCard> {
  late Future<LocationPermission> _permission;

  @override
  void initState() {
    super.initState();
    _permission = _check();
  }

  Future<LocationPermission> _check() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<void> _takeLocation() async {
    final pos = await currentGpsPosition(context);
    if (pos == null) return;
    final store = widget.store;
    await store.updateSettings(
      (s) => s.copyWith(gps: s.gps.copyWith(latitude: pos.latitude, longitude: pos.longitude, enabled: true)),
    );
    await rescheduleGpsAlarms(store.settings.effectiveGps);
    setState(() => _permission = _check());
  }

  Future<void> _grant() async {
    await requestGpsPermissions(context);
    setState(() => _permission = _check());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final gps = widget.store.settings.gps;
    final buttonStyle = OutlinedButton.styleFrom(shape: const StadiumBorder());
    return TitledCard(
      title: 'Chấm công GPS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'Đứng ở nơi chấm công rồi bấm lấy tọa độ. Cấp đủ quyền thì app mới tự chấm khi không mở.',
              style: TextStyle(fontSize: 12.5, color: colors.ink2),
            ),
          ),
          const AutoLockNotice(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: buttonStyle,
                icon: const Icon(Icons.my_location, size: 18),
                label: const Text('Lấy tọa độ'),
                onPressed: _takeLocation,
              ),
              OutlinedButton(style: buttonStyle, onPressed: _grant, child: const Text('Cấp quyền chấm công')),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<LocationPermission>(
            future: _permission,
            builder: (context, snap) {
              final granted = snap.data == LocationPermission.always;
              final parts = [
                gps.latitude != null ? 'Đã có tọa độ' : 'Chưa có tọa độ',
                granted ? 'đã cấp quyền' : 'chưa cấp quyền',
                if (gps.latitude != null && !gps.enabled) 'GPS đang tắt',
              ];
              return Text(parts.join(' · '), style: TextStyle(fontSize: 12, color: colors.ink3));
            },
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Nâng cao và cài đặt khác": bình thường chỉ là một dòng gợi ý, bấm mới xổ.
class MoreSettingsCard extends StatefulWidget {
  const MoreSettingsCard({super.key, required this.store});

  final AppStore store;

  @override
  State<MoreSettingsCard> createState() => _MoreSettingsCardState();
}

class _MoreSettingsCardState extends State<MoreSettingsCard> {
  bool _open = false;

  void _push(String title, Widget Function(AppStore store) section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Consumer<AppStore>(
            builder: (context, store, _) =>
                ListView(padding: const EdgeInsets.all(16), children: [section(store)]),
          ),
        ),
      ),
    );
  }

  Future<void> _setShowGps(bool value) async {
    final store = widget.store;
    await store.updateSettings((s) => s.copyWith(showGps: value));
    if (!kIsWeb) await rescheduleGpsAlarms(store.settings.effectiveGps);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final settings = widget.store.settings;

    Widget item(String title, {String? sub, Widget? trailing, VoidCallback? onTap}) => InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14)),
                  if (sub != null) Text(sub, style: TextStyle(fontSize: 11.5, color: colors.ink3)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: colors.ink2),
          ],
        ),
      ),
    );

    return TitledCard(
      title: 'Nâng cao và cài đặt khác',
      trailing: IconButton(
        icon: Icon(_open ? Icons.expand_less : Icons.expand_more, color: colors.ink2),
        tooltip: _open ? 'Thu gọn' : 'Mở',
        onPressed: () => setState(() => _open = !_open),
      ),
      child: !_open
          ? InkWell(
              onTap: () => setState(() => _open = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  kIsWeb
                      ? 'Tắt thông báo, ngày lễ, tăng ca theo khung, sao lưu, sao chép cấu hình, chia sẻ app, '
                            'góp ý, hướng dẫn dùng, tải bản Android.'
                      : 'Tắt thông báo, tắt chấm công GPS, ngày lễ, tăng ca theo khung, sao lưu, sao chép cấu '
                            'hình, chia sẻ app, góp ý, hướng dẫn dùng.',
                  style: TextStyle(fontSize: 12.5, color: colors.ink2, height: 1.45),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  item(
                    'Hiện thông báo',
                    sub: 'Thẻ Thông báo ở đầu Cài đặt và băng thông báo ở màn chính',
                    trailing: Switch(
                      value: settings.showNotice,
                      onChanged: (v) => widget.store.updateSettings((s) => s.copyWith(showNotice: v)),
                    ),
                  ),
                  if (!kIsWeb)
                    item(
                      'Dùng chấm công GPS',
                      sub: 'Tắt thì ẩn mục Chấm công GPS và app không tự chấm',
                      trailing: Switch(value: settings.showGps, onChanged: _setShowGps),
                    ),
                  item(
                    'Ngày lễ',
                    sub: '${settings.holidays.length} ngày lễ đã thêm',
                    onTap: () => _push('Ngày lễ', (s) => HolidaysSection(store: s)),
                  ),
                  item(
                    'Tăng ca theo khung',
                    sub: 'Trừ phút nghỉ theo từng khung giờ tăng ca',
                    onTap: () => _push('Tăng ca theo khung', (s) => OvertimeBracketsSection(store: s)),
                  ),
                  if (!kIsWeb && settings.showGps)
                    item(
                      'GPS: tùy chọn thêm',
                      sub: 'Bán kính, khung giờ, địa điểm khác',
                      onTap: () => _push('GPS: tùy chọn thêm', (s) => GpsSection(store: s)),
                    ),
                  item(
                    'Sao lưu dữ liệu',
                    sub: 'Xuất file Excel, khôi phục từ file',
                    onTap: () => _push('Sao lưu dữ liệu', (s) => BackupSection(store: s)),
                  ),
                  item(
                    'Sao chép / dán cấu hình',
                    sub: 'Chỉ gồm các con số; không kèm ngày lễ',
                    onTap: () => _push('Sao chép / dán cấu hình', (s) => ConfigShareSection(store: s)),
                  ),
                  item('Chia sẻ app', onTap: () => _push('Chia sẻ app', (_) => const ShareSection())),
                  item('Góp ý', onTap: () => _push('Góp ý', (_) => const FeedbackSection())),
                  item(
                    'Hướng dẫn dùng',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
                  ),
                  if (kIsWeb)
                    item('Tải bản Android', onTap: () => _push('Tải bản Android', (_) => const AndroidDownloadSection())),
                ],
              ),
            ),
    );
  }
}
