import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:provider/provider.dart';

import '../../data/store.dart';
import 'payslip_card.dart';
import 'settings_blocks.dart';
import 'work_config_card.dart';

/// Màn Cài đặt theo `mockup/luong-va-cai-dat.html`, từ trên xuống: thông báo, Công nhân / Công
/// nhật, phiếu lương, cài đặt tính công, chấm công GPS (ẩn trên web hoặc khi đã tắt), nâng cao.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.scrollToGps = false});

  /// Mở màn rồi tự cuộn tới thẻ "Chấm công GPS" (cuối chuyến hướng dẫn làm thử).
  final bool scrollToGps;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _gpsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.scrollToGps) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _gpsKey.currentContext;
        if (mounted && ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        // Cần dựng sẵn thẻ GPS (nằm khá xa phía dưới) thì mới cuộn tới được.
        scrollCacheExtent: widget.scrollToGps ? const ScrollCacheExtent.pixels(6000) : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          const SettingsNoticeCard(),
          WorkerKindToggle(store: store),
          PayslipCard(store: store),
          WorkConfigCard(store: store),
          if (!kIsWeb && store.settings.showGps) GpsQuickCard(key: _gpsKey, store: store),
          MoreSettingsCard(store: store),
        ],
      ),
    );
  }
}
